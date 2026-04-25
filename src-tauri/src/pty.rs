use parking_lot::Mutex;
use portable_pty::{native_pty_system, CommandBuilder, PtyPair, PtySize};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::io::{Read, Write};
use tauri::{AppHandle, Emitter};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TerminalInfo {
    pub id: String,
    pub label: String,
    pub command: String,
}

struct PtySession {
    info: TerminalInfo,
    writer: Box<dyn Write + Send>,
    // We hold this to keep the PTY alive
    _pair: PtyPair,
}

pub struct PtyManager {
    sessions: Mutex<HashMap<String, PtySession>>,
}

impl PtyManager {
    pub fn new() -> Self {
        Self {
            sessions: Mutex::new(HashMap::new()),
        }
    }

    pub fn spawn_terminal(
        &self,
        app: &AppHandle,
        label: String,
        command: Option<String>,
        args: Vec<String>,
        cols: u16,
        rows: u16,
        cwd: Option<String>,
    ) -> Result<TerminalInfo, String> {
        let pty_system = native_pty_system();

        let pair = pty_system
            .openpty(PtySize {
                rows,
                cols,
                pixel_width: 0,
                pixel_height: 0,
            })
            .map_err(|e| format!("Failed to open PTY: {}", e))?;

        let shell = command.clone().unwrap_or_else(default_shell);

        let mut cmd = CommandBuilder::new(&shell);
        for arg in &args {
            cmd.arg(arg);
        }
        cmd.env("TERM", "xterm-256color");

        // Set working directory
        if let Some(ref dir) = cwd {
            let path = std::path::Path::new(dir);
            if path.is_dir() {
                cmd.cwd(path);
            }
        }

        let _child = pair
            .slave
            .spawn_command(cmd)
            .map_err(|e| format!("Failed to spawn command: {}", e))?;

        let id = Uuid::new_v4().to_string();
        let display_command = command.unwrap_or_else(|| shell.clone());

        let info = TerminalInfo {
            id: id.clone(),
            label,
            command: display_command,
        };

        let writer = pair
            .master
            .take_writer()
            .map_err(|e| format!("Failed to get PTY writer: {}", e))?;

        let mut reader = pair
            .master
            .try_clone_reader()
            .map_err(|e| format!("Failed to get PTY reader: {}", e))?;

        let session = PtySession {
            info: info.clone(),
            writer,
            _pair: pair,
        };

        self.sessions.lock().insert(id.clone(), session);

        // Spawn a thread to read PTY output and emit events to the frontend
        let app_handle = app.clone();
        let reader_id = id.clone();
        std::thread::spawn(move || {
            let mut buf = [0u8; 4096];
            loop {
                match reader.read(&mut buf) {
                    Ok(0) => {
                        let _ = app_handle.emit(&format!("pty-exit-{}", reader_id), ());
                        break;
                    }
                    Ok(n) => {
                        let data = String::from_utf8_lossy(&buf[..n]).to_string();
                        let _ = app_handle.emit(&format!("pty-data-{}", reader_id), data);
                    }
                    Err(_) => {
                        let _ = app_handle.emit(&format!("pty-exit-{}", reader_id), ());
                        break;
                    }
                }
            }
        });

        Ok(info)
    }

    pub fn write_to_terminal(&self, id: &str, data: &str) -> Result<(), String> {
        let mut sessions = self.sessions.lock();
        let session = sessions
            .get_mut(id)
            .ok_or_else(|| format!("Terminal {} not found", id))?;
        session
            .writer
            .write_all(data.as_bytes())
            .map_err(|e| format!("Failed to write to PTY: {}", e))?;
        session
            .writer
            .flush()
            .map_err(|e| format!("Failed to flush PTY: {}", e))?;
        Ok(())
    }

    pub fn resize_terminal(&self, id: &str, cols: u16, rows: u16) -> Result<(), String> {
        let sessions = self.sessions.lock();
        let session = sessions
            .get(id)
            .ok_or_else(|| format!("Terminal {} not found", id))?;
        session
            ._pair
            .master
            .resize(PtySize {
                rows,
                cols,
                pixel_width: 0,
                pixel_height: 0,
            })
            .map_err(|e| format!("Failed to resize PTY: {}", e))?;
        Ok(())
    }

    pub fn close_terminal(&self, id: &str) -> Result<(), String> {
        self.sessions
            .lock()
            .remove(id)
            .ok_or_else(|| format!("Terminal {} not found", id))?;
        Ok(())
    }

    pub fn list_terminals(&self) -> Vec<TerminalInfo> {
        self.sessions
            .lock()
            .values()
            .map(|s| s.info.clone())
            .collect()
    }
}

pub fn default_shell() -> String {
    #[cfg(target_os = "windows")]
    {
        std::env::var("COMSPEC").unwrap_or_else(|_| "cmd.exe".to_string())
    }
    #[cfg(not(target_os = "windows"))]
    {
        std::env::var("SHELL").unwrap_or_else(|_| "/bin/zsh".to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_shell_is_nonempty() {
        let shell = default_shell();
        assert!(!shell.is_empty(), "Default shell should not be empty");
    }

    #[test]
    fn test_pty_manager_new_has_no_sessions() {
        let mgr = PtyManager::new();
        assert!(mgr.list_terminals().is_empty());
    }

    #[test]
    fn test_write_to_nonexistent_terminal_errors() {
        let mgr = PtyManager::new();
        let result = mgr.write_to_terminal("nonexistent", "hello");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("not found"));
    }

    #[test]
    fn test_close_nonexistent_terminal_errors() {
        let mgr = PtyManager::new();
        let result = mgr.close_terminal("nonexistent");
        assert!(result.is_err());
    }

    #[test]
    fn test_resize_nonexistent_terminal_errors() {
        let mgr = PtyManager::new();
        let result = mgr.resize_terminal("nonexistent", 80, 24);
        assert!(result.is_err());
    }
}
