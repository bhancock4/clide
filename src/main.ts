import { invoke } from "@tauri-apps/api/core";
import { ASCII_LOGO, CLYDE_MASCOT } from "./branding";
import { TerminalManager, type TerminalInstance } from "./terminal-manager";
import { updater } from "./updater";
import "@xterm/xterm/css/xterm.css";

interface ToolConfig {
  name: string;
  command: string;
  args: string[];
  shortcut: string;
  color: string;
}

interface Settings {
  tools: ToolConfig[];
  theme: string;
  font_size: number;
  font_family: string;
  default_shell: string | null;
}

interface SavedTerminal {
  label: string;
  command: string;
  args: string[];
  panel: string;
  cwd: string | null;
}

interface SavedSession {
  terminals: SavedTerminal[];
  sidebar_visible: boolean;
  secondary_panel_visible: boolean;
  secondary_panel_height_percent: number | null;
}

const manager = new TerminalManager();

// DOM references
let welcomeScreen: HTMLElement;
let workspace: HTMLElement;
let mainTerminalEl: HTMLElement;
let secondaryTerminalEl: HTMLElement;
let secondaryPanel: HTMLElement;
let mainTabs: HTMLElement;
let secondaryTabs: HTMLElement;
let sidebar: HTMLElement;
let settings: Settings;
let activeContextMenu: HTMLElement | null = null;

async function init() {
  welcomeScreen = document.getElementById("welcome-screen")!;
  workspace = document.getElementById("workspace")!;
  mainTerminalEl = document.getElementById("main-terminal")!;
  secondaryTerminalEl = document.getElementById("secondary-terminal")!;
  secondaryPanel = document.getElementById("secondary-panel")!;
  mainTabs = document.getElementById("main-terminal-tabs")!;
  secondaryTabs = document.getElementById("secondary-terminal-tabs")!;
  sidebar = document.getElementById("sidebar")!;

  // Load settings
  settings = await invoke<Settings>("get_settings");

  // Render welcome screen
  renderWelcome();

  // Wire up buttons
  document.getElementById("btn-add-terminal")!.addEventListener("click", () => launchInPanel("main"));
  document.getElementById("btn-add-secondary")!.addEventListener("click", () => launchInPanel("secondary"));
  document.getElementById("btn-home")!.addEventListener("click", showWelcome);
  document.getElementById("btn-sidebar-toggle")!.addEventListener("click", toggleSidebar);
  document.getElementById("sidebar-close")!.addEventListener("click", toggleSidebar);
  document.getElementById("btn-collapse-panel")!.addEventListener("click", toggleSecondaryPanel);

  // Panel resize
  setupPanelResize();

  // Keyboard shortcuts (on welcome screen)
  document.addEventListener("keydown", handleGlobalKeys);

  // Dismiss context menu on click elsewhere
  document.addEventListener("click", dismissContextMenu);

  // Window resize
  window.addEventListener("resize", () => manager.fitAll());

  // Terminal change callback
  manager.onChangeCallback(renderTabs);

  // Save session periodically (every 30s)
  setInterval(saveCurrentSession, 30_000);

  // Save session on window close
  window.addEventListener("beforeunload", () => {
    saveCurrentSession();
  });

  // Try to restore previous session
  await restoreSession();

  // Check for updates (non-blocking)
  setupUpdater();
}

// ── Session Persistence ──────────────────────────────────────────────

async function saveCurrentSession() {
  const instances = manager.getAllInstances();
  if (instances.length === 0) return;

  const session: SavedSession = {
    terminals: instances.map((inst) => ({
      label: inst.info.label,
      command: inst.info.command,
      args: [],
      panel: inst.panel,
      cwd: null,
    })),
    sidebar_visible: !sidebar.classList.contains("hidden"),
    secondary_panel_visible: !secondaryPanel.classList.contains("hidden"),
    secondary_panel_height_percent: secondaryPanel.classList.contains("hidden")
      ? null
      : (secondaryPanel.offsetHeight / window.innerHeight) * 100,
  };

  try {
    await invoke("save_session", { session });
  } catch (e) {
    console.error("Failed to save session:", e);
  }
}

async function restoreSession() {
  try {
    const session = await invoke<SavedSession>("load_session");
    if (!session.terminals || session.terminals.length === 0) return;

    showWorkspace();

    // Restore layout state
    if (session.sidebar_visible) {
      sidebar.classList.remove("hidden");
    }

    if (session.secondary_panel_height_percent) {
      secondaryPanel.style.height = `${session.secondary_panel_height_percent}%`;
    }

    // Restore terminals
    for (const saved of session.terminals) {
      const panel = saved.panel === "secondary" ? "secondary" : "main";
      await createTerminalInPanel(panel, saved.label, saved.command, saved.args);
    }

    // Clear the saved session after successful restore
    await invoke("clear_session");
  } catch (e) {
    console.debug("No session to restore:", e);
  }
}

// ── Updater ──────────────────────────────────────────────────────────

function setupUpdater() {
  updater.onStatus((status) => {
    if (status.available && !status.downloading) {
      showUpdateBanner(status.version ?? "new version");
    }
    if (status.downloading && status.progress !== undefined) {
      updateDownloadProgress(status.progress);
    }
  });

  // Check on launch (delayed to not block startup)
  setTimeout(() => updater.checkForUpdates(), 5_000);
  // Check every 30 minutes
  setInterval(() => updater.checkForUpdates(), 30 * 60 * 1000);
}

function showUpdateBanner(version: string) {
  // Don't duplicate
  if (document.getElementById("update-banner")) return;

  const banner = document.createElement("div");
  banner.id = "update-banner";
  banner.style.cssText = `
    position: fixed; top: 0; left: 0; right: 0;
    background: var(--accent-orange); color: var(--bg-primary);
    padding: 6px 16px; font-size: 12px;
    display: flex; align-items: center; justify-content: space-between;
    z-index: 2000;
  `;
  banner.innerHTML = `
    <span>CLIDE ${version} is available</span>
    <div>
      <button id="update-install-btn" style="
        background: var(--bg-primary); color: var(--text-primary);
        border: none; padding: 3px 12px; border-radius: 3px;
        cursor: pointer; font-family: var(--font-mono); font-size: 11px; margin-right: 8px;
      ">Update & Restart</button>
      <button id="update-dismiss-btn" style="
        background: none; border: none; color: var(--bg-primary);
        cursor: pointer; font-size: 14px;
      ">✕</button>
    </div>
  `;
  document.body.prepend(banner);

  document.getElementById("update-install-btn")!.addEventListener("click", async () => {
    await saveCurrentSession();
    updater.downloadAndInstall();
  });
  document.getElementById("update-dismiss-btn")!.addEventListener("click", () => {
    banner.remove();
  });
}

function updateDownloadProgress(progress: number) {
  const btn = document.getElementById("update-install-btn");
  if (btn) {
    btn.textContent = `Downloading... ${Math.round(progress)}%`;
    btn.setAttribute("disabled", "true");
  }
}

// ── Welcome Screen ───────────────────────────────────────────────────

function renderWelcome() {
  document.getElementById("ascii-logo")!.textContent = ASCII_LOGO;
  document.getElementById("clyde-mascot")!.textContent = CLYDE_MASCOT;

  const toolButtons = document.getElementById("tool-buttons")!;
  toolButtons.innerHTML = "";

  for (const tool of settings.tools) {
    const btn = document.createElement("button");
    btn.className = "tool-btn";
    btn.innerHTML = `<span class="shortcut">${tool.shortcut}</span> ${tool.name}`;
    btn.addEventListener("click", () => launchTool(tool));
    toolButtons.appendChild(btn);
  }

  // Add plain terminal button
  const termBtn = document.createElement("button");
  termBtn.className = "tool-btn";
  termBtn.innerHTML = `<span class="shortcut">T</span> Terminal`;
  termBtn.addEventListener("click", () => launchInPanel("main"));
  toolButtons.appendChild(termBtn);
}

function handleGlobalKeys(e: KeyboardEvent) {
  // Only handle shortcuts when welcome screen is visible
  if (welcomeScreen.classList.contains("hidden")) return;

  const key = e.key.toUpperCase();
  const tool = settings.tools.find((t) => t.shortcut.toUpperCase() === key);
  if (tool) {
    e.preventDefault();
    launchTool(tool);
    return;
  }

  if (key === "T") {
    e.preventDefault();
    launchInPanel("main");
  }
}

// ── Terminal Lifecycle ───────────────────────────────────────────────

async function launchTool(tool: ToolConfig) {
  showWorkspace();
  await createTerminalInPanel("main", tool.name, tool.command, tool.args);
}

async function launchInPanel(panel: "main" | "secondary") {
  showWorkspace();
  await createTerminalInPanel(panel, "Terminal");
}

async function createTerminalInPanel(
  panel: "main" | "secondary",
  label: string,
  command?: string,
  args: string[] = []
) {
  const container = panel === "main" ? mainTerminalEl : secondaryTerminalEl;

  if (panel === "secondary") {
    secondaryPanel.classList.remove("hidden");
  }

  // Hide other terminals in this panel
  const existing = manager.getTerminalsByPanel(panel);
  for (const inst of existing) {
    inst.terminal.element?.parentElement?.classList.add("hidden");
  }

  // Create a wrapper for this terminal
  const wrapper = document.createElement("div");
  wrapper.style.width = "100%";
  wrapper.style.height = "100%";
  container.appendChild(wrapper);

  const instance = await manager.createTerminal(panel, wrapper, label, command, args);

  // Set up context menu for send-to-terminal
  setupTerminalContextMenu(instance);

  // Fit after a brief delay to ensure layout is settled
  requestAnimationFrame(() => {
    instance.fitAddon.fit();
    instance.terminal.focus();
  });
}

// ── Bidirectional Send-to-Terminal ───────────────────────────────────

function setupTerminalContextMenu(instance: TerminalInstance) {
  // xterm.js doesn't have a native right-click event, so we listen on the
  // terminal's DOM element
  const el = instance.terminal.element;
  if (!el) return;

  el.addEventListener("contextmenu", (e: MouseEvent) => {
    e.preventDefault();
    const selection = instance.terminal.getSelection();
    if (!selection) return;

    showSendToMenu(e.clientX, e.clientY, selection, instance);
  });
}

function showSendToMenu(
  x: number,
  y: number,
  selectedText: string,
  sourceInstance: TerminalInstance
) {
  dismissContextMenu();

  const allInstances = manager.getAllInstances();
  const targets = allInstances.filter((i) => i.info.id !== sourceInstance.info.id);

  if (targets.length === 0) return;

  const menu = document.createElement("div");
  menu.className = "context-menu";
  menu.style.left = `${x}px`;
  menu.style.top = `${y}px`;

  // Header
  const header = document.createElement("div");
  header.style.cssText = "padding: 4px 12px; color: var(--text-secondary); font-size: 11px;";
  header.textContent = "Send selection to...";
  menu.appendChild(header);

  const sep = document.createElement("div");
  sep.className = "context-menu-separator";
  menu.appendChild(sep);

  for (const target of targets) {
    const item = document.createElement("button");
    item.className = "context-menu-item";

    const dot = document.createElement("span");
    dot.style.cssText = `
      display: inline-block; width: 8px; height: 8px;
      border-radius: 50%; margin-right: 8px;
      background: ${getToolColor(target.info.command)};
    `;
    item.appendChild(dot);
    item.appendChild(document.createTextNode(`${target.info.label} (${target.panel})`));

    item.addEventListener("click", () => {
      manager.sendToTerminal(target.info.id, selectedText);
      dismissContextMenu();
    });

    menu.appendChild(item);
  }

  // "Send & Execute" section (appends newline)
  const sep2 = document.createElement("div");
  sep2.className = "context-menu-separator";
  menu.appendChild(sep2);

  for (const target of targets) {
    const item = document.createElement("button");
    item.className = "context-menu-item";
    item.style.color = "var(--accent-green)";

    const dot = document.createElement("span");
    dot.style.cssText = `
      display: inline-block; width: 8px; height: 8px;
      border-radius: 50%; margin-right: 8px;
      background: ${getToolColor(target.info.command)};
    `;
    item.appendChild(dot);
    item.appendChild(document.createTextNode(`Run in ${target.info.label} (${target.panel})`));

    item.addEventListener("click", () => {
      // Send with newline to execute
      manager.sendToTerminal(target.info.id, selectedText + "\n");
      dismissContextMenu();
    });

    menu.appendChild(item);
  }

  // Ensure menu stays within viewport
  document.body.appendChild(menu);
  const rect = menu.getBoundingClientRect();
  if (rect.right > window.innerWidth) {
    menu.style.left = `${window.innerWidth - rect.width - 8}px`;
  }
  if (rect.bottom > window.innerHeight) {
    menu.style.top = `${window.innerHeight - rect.height - 8}px`;
  }

  activeContextMenu = menu;
}

function dismissContextMenu() {
  if (activeContextMenu) {
    activeContextMenu.remove();
    activeContextMenu = null;
  }
}

// ── UI Helpers ───────────────────────────────────────────────────────

function showWorkspace() {
  welcomeScreen.classList.add("hidden");
  workspace.classList.remove("hidden");
  requestAnimationFrame(() => manager.fitAll());
}

function showWelcome() {
  workspace.classList.add("hidden");
  welcomeScreen.classList.remove("hidden");
}

function toggleSidebar() {
  sidebar.classList.toggle("hidden");
  requestAnimationFrame(() => manager.fitAll());
}

function toggleSecondaryPanel() {
  secondaryPanel.classList.toggle("hidden");
  requestAnimationFrame(() => manager.fitAll());
}

function renderTabs(instances: TerminalInstance[]) {
  renderTabsForPanel("main", mainTabs, instances);
  renderTabsForPanel("secondary", secondaryTabs, instances);
}

function renderTabsForPanel(
  panel: "main" | "secondary",
  container: HTMLElement,
  allInstances: TerminalInstance[]
) {
  container.innerHTML = "";
  const panelInstances = allInstances.filter((i) => i.panel === panel);
  const active = manager.getActive(panel);

  for (const inst of panelInstances) {
    const tab = document.createElement("button");
    tab.className = `terminal-tab${inst.info.id === active?.info.id ? " active" : ""}`;

    const dot = document.createElement("span");
    dot.className = "tab-dot";
    dot.style.backgroundColor = getToolColor(inst.info.command);
    tab.appendChild(dot);

    const labelSpan = document.createElement("span");
    labelSpan.textContent = inst.info.label;
    tab.appendChild(labelSpan);

    const closeBtn = document.createElement("span");
    closeBtn.className = "tab-close";
    closeBtn.textContent = "✕";
    closeBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      manager.closeTerminal(inst.info.id);
      inst.terminal.element?.parentElement?.remove();
      if (!manager.hasTerminals()) {
        showWelcome();
      }
    });
    tab.appendChild(closeBtn);

    tab.addEventListener("click", () => switchToTerminal(inst, panel));
    container.appendChild(tab);
  }
}

function switchToTerminal(inst: TerminalInstance, panel: "main" | "secondary") {
  const panelInstances = manager.getTerminalsByPanel(panel);

  for (const other of panelInstances) {
    const el = other.terminal.element?.parentElement;
    if (el) {
      if (other.info.id === inst.info.id) {
        el.classList.remove("hidden");
      } else {
        el.classList.add("hidden");
      }
    }
  }

  manager.setActive(inst.info.id);
  requestAnimationFrame(() => {
    inst.fitAddon.fit();
    inst.terminal.focus();
  });
}

function getToolColor(command: string): string {
  const tool = settings.tools.find((t) => t.command === command);
  return tool?.color ?? "#8b949e";
}

function setupPanelResize() {
  const handle = document.getElementById("panel-resize-handle")!;
  let startY = 0;
  let startHeight = 0;

  handle.addEventListener("mousedown", (e) => {
    startY = e.clientY;
    startHeight = secondaryPanel.offsetHeight;
    document.addEventListener("mousemove", onResize);
    document.addEventListener("mouseup", stopResize);
    e.preventDefault();
  });

  function onResize(e: MouseEvent) {
    const delta = startY - e.clientY;
    const newHeight = Math.max(80, startHeight + delta);
    secondaryPanel.style.height = `${newHeight}px`;
    manager.fitAll();
  }

  function stopResize() {
    document.removeEventListener("mousemove", onResize);
    document.removeEventListener("mouseup", stopResize);
  }
}

window.addEventListener("DOMContentLoaded", init);
