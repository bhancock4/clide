use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolConfig {
    pub name: String,
    pub command: String,
    pub args: Vec<String>,
    pub shortcut: String,
    pub color: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Settings {
    pub tools: Vec<ToolConfig>,
    pub theme: String,
    pub font_size: u16,
    pub font_family: String,
    pub font_color: Option<String>,
    pub default_shell: Option<String>,
    pub default_cwd: Option<String>,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            tools: vec![
                ToolConfig {
                    name: "Claude Code".into(),
                    command: "claude".into(),
                    args: vec![],
                    shortcut: "C".into(),
                    color: "#d97706".into(),
                },
                ToolConfig {
                    name: "Gemini CLI".into(),
                    command: "gemini".into(),
                    args: vec![],
                    shortcut: "G".into(),
                    color: "#2563eb".into(),
                },
                ToolConfig {
                    name: "Aider".into(),
                    command: "aider".into(),
                    args: vec![],
                    shortcut: "A".into(),
                    color: "#16a34a".into(),
                },
                ToolConfig {
                    name: "Copilot CLI".into(),
                    command: "gh".into(),
                    args: vec!["copilot".into()],
                    shortcut: "O".into(),
                    color: "#6e40c9".into(),
                },
                ToolConfig {
                    name: "Cursor CLI".into(),
                    command: "cursor".into(),
                    args: vec![],
                    shortcut: "U".into(),
                    color: "#00b4d8".into(),
                },
            ],
            theme: "dark".into(),
            font_size: 14,
            font_family: "Menlo, Monaco, 'Courier New', monospace".into(),
            font_color: None,
            default_shell: None,
            default_cwd: None,
        }
    }
}

impl Settings {
    pub fn load(config_dir: &PathBuf) -> Self {
        let path = config_dir.join("settings.json");
        match fs::read_to_string(&path) {
            Ok(content) => serde_json::from_str(&content).unwrap_or_default(),
            Err(_) => Self::default(),
        }
    }

    pub fn save(&self, config_dir: &PathBuf) -> Result<(), String> {
        fs::create_dir_all(config_dir)
            .map_err(|e| format!("Failed to create config dir: {}", e))?;
        let path = config_dir.join("settings.json");
        let json = serde_json::to_string_pretty(self)
            .map_err(|e| format!("Failed to serialize settings: {}", e))?;
        fs::write(&path, json).map_err(|e| format!("Failed to write settings: {}", e))?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn test_default_settings_has_all_tools() {
        let settings = Settings::default();
        assert_eq!(settings.tools.len(), 5);
        assert_eq!(settings.tools[0].name, "Claude Code");
        assert_eq!(settings.tools[1].name, "Gemini CLI");
        assert_eq!(settings.tools[2].name, "Aider");
        assert_eq!(settings.tools[3].name, "Copilot CLI");
        assert_eq!(settings.tools[4].name, "Cursor CLI");
    }

    #[test]
    fn test_save_and_load_roundtrip() {
        let dir = std::env::temp_dir().join("clide-test-settings");
        let _ = fs::remove_dir_all(&dir);

        let mut settings = Settings::default();
        settings.font_size = 18;
        settings.save(&dir).expect("save should succeed");

        let loaded = Settings::load(&dir);
        assert_eq!(loaded.font_size, 18);
        assert_eq!(loaded.tools.len(), 5);

        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn test_load_missing_file_returns_default() {
        let dir = PathBuf::from("/tmp/clide-nonexistent-test-dir-12345");
        let settings = Settings::load(&dir);
        assert_eq!(settings.font_size, 14);
    }

    #[test]
    fn test_load_corrupt_file_returns_default() {
        let dir = std::env::temp_dir().join("clide-test-corrupt");
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        fs::write(dir.join("settings.json"), "not valid json!!!").unwrap();

        let settings = Settings::load(&dir);
        assert_eq!(settings.font_size, 14); // default

        let _ = fs::remove_dir_all(&dir);
    }
}
