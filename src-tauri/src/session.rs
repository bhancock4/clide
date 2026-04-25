use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SavedTerminal {
    pub label: String,
    pub command: String,
    pub args: Vec<String>,
    pub panel: String, // "main" or "secondary"
    pub cwd: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SavedSession {
    pub terminals: Vec<SavedTerminal>,
    pub sidebar_visible: bool,
    pub secondary_panel_visible: bool,
    pub secondary_panel_height_percent: Option<f64>,
}

impl Default for SavedSession {
    fn default() -> Self {
        Self {
            terminals: vec![],
            sidebar_visible: false,
            secondary_panel_visible: false,
            secondary_panel_height_percent: None,
        }
    }
}

impl SavedSession {
    fn file_path(config_dir: &PathBuf) -> PathBuf {
        config_dir.join("session.json")
    }

    pub fn load(config_dir: &PathBuf) -> Self {
        let path = Self::file_path(config_dir);
        match fs::read_to_string(&path) {
            Ok(content) => serde_json::from_str(&content).unwrap_or_default(),
            Err(_) => Self::default(),
        }
    }

    pub fn save(&self, config_dir: &PathBuf) -> Result<(), String> {
        fs::create_dir_all(config_dir)
            .map_err(|e| format!("Failed to create config dir: {}", e))?;
        let path = Self::file_path(config_dir);
        let json = serde_json::to_string_pretty(self)
            .map_err(|e| format!("Failed to serialize session: {}", e))?;
        fs::write(&path, json).map_err(|e| format!("Failed to write session: {}", e))?;
        Ok(())
    }

    pub fn clear(config_dir: &PathBuf) -> Result<(), String> {
        let path = Self::file_path(config_dir);
        if path.exists() {
            fs::remove_file(&path).map_err(|e| format!("Failed to remove session file: {}", e))?;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_session_is_empty() {
        let session = SavedSession::default();
        assert!(session.terminals.is_empty());
        assert!(!session.sidebar_visible);
        assert!(!session.secondary_panel_visible);
    }

    #[test]
    fn test_save_and_load_roundtrip() {
        let dir = std::env::temp_dir().join("clide-test-session");
        let _ = fs::remove_dir_all(&dir);

        let session = SavedSession {
            terminals: vec![
                SavedTerminal {
                    label: "Claude Code".into(),
                    command: "claude".into(),
                    args: vec![],
                    panel: "main".into(),
                    cwd: Some("/Users/test/project".into()),
                },
                SavedTerminal {
                    label: "Terminal".into(),
                    command: "/bin/zsh".into(),
                    args: vec![],
                    panel: "secondary".into(),
                    cwd: None,
                },
            ],
            sidebar_visible: true,
            secondary_panel_visible: true,
            secondary_panel_height_percent: Some(35.0),
        };

        session.save(&dir).expect("save should succeed");
        let loaded = SavedSession::load(&dir);
        assert_eq!(loaded.terminals.len(), 2);
        assert_eq!(loaded.terminals[0].label, "Claude Code");
        assert_eq!(loaded.terminals[0].cwd, Some("/Users/test/project".into()));
        assert_eq!(loaded.terminals[1].panel, "secondary");
        assert!(loaded.sidebar_visible);
        assert!(loaded.secondary_panel_visible);
        assert_eq!(loaded.secondary_panel_height_percent, Some(35.0));

        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn test_load_missing_returns_default() {
        let dir = PathBuf::from("/tmp/clide-nonexistent-session-dir");
        let session = SavedSession::load(&dir);
        assert!(session.terminals.is_empty());
    }

    #[test]
    fn test_clear_removes_file() {
        let dir = std::env::temp_dir().join("clide-test-session-clear");
        let _ = fs::remove_dir_all(&dir);

        let session = SavedSession {
            terminals: vec![SavedTerminal {
                label: "test".into(),
                command: "echo".into(),
                args: vec![],
                panel: "main".into(),
                cwd: None,
            }],
            ..Default::default()
        };
        session.save(&dir).unwrap();
        assert!(dir.join("session.json").exists());

        SavedSession::clear(&dir).unwrap();
        assert!(!dir.join("session.json").exists());

        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn test_clear_nonexistent_is_ok() {
        let dir = PathBuf::from("/tmp/clide-nonexistent-clear-dir");
        let result = SavedSession::clear(&dir);
        assert!(result.is_ok());
    }
}
