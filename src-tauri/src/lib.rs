mod pty;
mod session;
mod settings;

use parking_lot::Mutex;
use pty::{PtyManager, TerminalInfo};
use session::SavedSession;
use settings::Settings;
use std::path::PathBuf;
use std::sync::Arc;
use tauri::{AppHandle, Manager, State};

struct AppState {
    pty_manager: PtyManager,
    settings: Mutex<Settings>,
    config_dir: PathBuf,
}

#[tauri::command]
fn spawn_terminal(
    app: AppHandle,
    state: State<'_, Arc<AppState>>,
    label: String,
    command: Option<String>,
    args: Vec<String>,
    cols: u16,
    rows: u16,
) -> Result<TerminalInfo, String> {
    state
        .pty_manager
        .spawn_terminal(&app, label, command, args, cols, rows)
}

#[tauri::command]
fn write_terminal(
    state: State<'_, Arc<AppState>>,
    id: String,
    data: String,
) -> Result<(), String> {
    state.pty_manager.write_to_terminal(&id, &data)
}

#[tauri::command]
fn resize_terminal(
    state: State<'_, Arc<AppState>>,
    id: String,
    cols: u16,
    rows: u16,
) -> Result<(), String> {
    state.pty_manager.resize_terminal(&id, cols, rows)
}

#[tauri::command]
fn close_terminal(state: State<'_, Arc<AppState>>, id: String) -> Result<(), String> {
    state.pty_manager.close_terminal(&id)
}

#[tauri::command]
fn list_terminals(state: State<'_, Arc<AppState>>) -> Vec<TerminalInfo> {
    state.pty_manager.list_terminals()
}

#[tauri::command]
fn get_settings(state: State<'_, Arc<AppState>>) -> Settings {
    state.settings.lock().clone()
}

#[tauri::command]
fn save_settings(state: State<'_, Arc<AppState>>, settings: Settings) -> Result<(), String> {
    settings.save(&state.config_dir)?;
    *state.settings.lock() = settings;
    Ok(())
}

#[tauri::command]
fn get_default_shell() -> String {
    pty::default_shell()
}

#[tauri::command]
fn save_session(state: State<'_, Arc<AppState>>, session: SavedSession) -> Result<(), String> {
    session.save(&state.config_dir)
}

#[tauri::command]
fn load_session(state: State<'_, Arc<AppState>>) -> SavedSession {
    SavedSession::load(&state.config_dir)
}

#[tauri::command]
fn clear_session(state: State<'_, Arc<AppState>>) -> Result<(), String> {
    SavedSession::clear(&state.config_dir)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .setup(|app| {
            let config_dir = app
                .path()
                .app_config_dir()
                .unwrap_or_else(|_| PathBuf::from(".clide"));

            let settings = Settings::load(&config_dir);

            let state = Arc::new(AppState {
                pty_manager: PtyManager::new(),
                settings: Mutex::new(settings),
                config_dir,
            });

            app.manage(state);
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            spawn_terminal,
            write_terminal,
            resize_terminal,
            close_terminal,
            list_terminals,
            get_settings,
            save_settings,
            get_default_shell,
            save_session,
            load_session,
            clear_session,
        ])
        .run(tauri::generate_context!())
        .expect("error while running CLIDE");
}
