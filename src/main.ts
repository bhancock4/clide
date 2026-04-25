import { invoke } from "@tauri-apps/api/core";
import { open as openDialog } from "@tauri-apps/plugin-dialog";
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
  font_color: string | null;
  default_shell: string | null;
  default_cwd: string | null;
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
let mainViewport: HTMLElement;
let splitViewport: HTMLElement;
let splitPanel: HTMLElement;
let mainTabs: HTMLElement;
let secondaryTabs: HTMLElement;
let sidebar: HTMLElement;
let settings: Settings;
let activeContextMenu: HTMLElement | null = null;
let splitMode = false;

async function init() {
  welcomeScreen = document.getElementById("welcome-screen")!;
  workspace = document.getElementById("workspace")!;
  mainViewport = document.getElementById("main-terminal")!;
  splitViewport = document.getElementById("split-terminal")!;
  splitPanel = document.getElementById("split-panel")!;
  mainTabs = document.getElementById("main-terminal-tabs")!;
  secondaryTabs = document.getElementById("secondary-terminal-tabs")!;
  sidebar = document.getElementById("sidebar")!;

  settings = await invoke<Settings>("get_settings");

  renderWelcome();

  // Wire up buttons
  document.getElementById("btn-add-terminal")!.addEventListener("click", () => launchInPanel("main"));
  document.getElementById("btn-add-secondary")!.addEventListener("click", () => launchInPanel("secondary"));
  document.getElementById("btn-home")!.addEventListener("click", showWelcome);
  document.getElementById("btn-sidebar-toggle")!.addEventListener("click", toggleSidebar);
  document.getElementById("sidebar-close")!.addEventListener("click", toggleSidebar);
  document.getElementById("btn-collapse-panel")!.addEventListener("click", closeSplitView);
  document.getElementById("btn-split-view")!.addEventListener("click", toggleSplitView);
  document.getElementById("btn-settings")!.addEventListener("click", openSettings);

  setupSplitResize();

  document.addEventListener("keydown", handleGlobalKeys);
  document.addEventListener("click", dismissContextMenu);

  manager.onChangeCallback(renderTabs);

  setInterval(saveCurrentSession, 30_000);
  window.addEventListener("beforeunload", () => saveCurrentSession());

  // Check for saved session and show prompt if one exists
  await checkForSavedSession();
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
    secondary_panel_visible: splitMode,
    secondary_panel_height_percent: null,
  };

  try {
    await invoke("save_session", { session });
  } catch (e) {
    console.error("Failed to save session:", e);
  }
}

async function checkForSavedSession() {
  try {
    const hasSaved = await invoke<boolean>("has_saved_session");
    if (!hasSaved) return;

    // Show the session prompt on the welcome screen
    const sessionPrompt = document.getElementById("session-prompt")!;
    sessionPrompt.classList.remove("hidden");

    document.getElementById("btn-restore-session")!.addEventListener("click", async () => {
      sessionPrompt.classList.add("hidden");
      await doRestoreSession();
    });

    document.getElementById("btn-new-session")!.addEventListener("click", async () => {
      sessionPrompt.classList.add("hidden");
      await invoke("clear_session");
    });
  } catch (e) {
    console.debug("Session check failed:", e);
  }
}

async function doRestoreSession() {
  try {
    const session = await invoke<SavedSession>("load_session");
    if (!session.terminals || session.terminals.length === 0) return;

    showWorkspace();

    if (session.sidebar_visible) {
      sidebar.classList.remove("hidden");
    }

    for (const saved of session.terminals) {
      const panel = saved.panel === "secondary" ? "secondary" : "main";
      await createTerminalInPanel(panel, saved.label, saved.command, saved.args);
    }

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

  setTimeout(() => updater.checkForUpdates(), 5_000);
  setInterval(() => updater.checkForUpdates(), 30 * 60 * 1000);
}

function showUpdateBanner(version: string) {
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
      ">&#x2715;</button>
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

  const termBtn = document.createElement("button");
  termBtn.className = "tool-btn";
  termBtn.innerHTML = `<span class="shortcut">T</span> Terminal`;
  termBtn.addEventListener("click", () => launchInPanel("main"));
  toolButtons.appendChild(termBtn);
}

// ── Keyboard Shortcuts ──────────────────────────────────────────────

function handleGlobalKeys(e: KeyboardEvent) {
  const meta = e.metaKey || e.ctrlKey;

  // Cmd+1..9: switch main panel tabs
  if (meta && e.key >= "1" && e.key <= "9" && !e.shiftKey) {
    e.preventDefault();
    const index = parseInt(e.key) - 1;
    const mainTerminals = manager.getTerminalsByPanel("main");
    if (index < mainTerminals.length) {
      switchToTerminal(mainTerminals[index].info.id, "main");
    }
    return;
  }

  // Cmd+Shift+1..9: switch secondary/split panel tabs
  if (meta && e.shiftKey && e.code >= "Digit1" && e.code <= "Digit9") {
    e.preventDefault();
    const index = parseInt(e.code.replace("Digit", "")) - 1;
    const secTerminals = manager.getTerminalsByPanel("secondary");
    if (index < secTerminals.length) {
      switchToTerminal(secTerminals[index].info.id, "secondary");
    }
    return;
  }

  // Cmd+Shift+Left/Right: cycle tabs in main panel
  if (meta && e.shiftKey && (e.key === "ArrowLeft" || e.key === "ArrowRight")) {
    e.preventDefault();
    const mainTerminals = manager.getTerminalsByPanel("main");
    if (mainTerminals.length < 2) return;
    const active = manager.getActive("main");
    const currentIdx = mainTerminals.findIndex((t) => t.info.id === active?.info.id);
    let nextIdx: number;
    if (e.key === "ArrowRight") {
      nextIdx = (currentIdx + 1) % mainTerminals.length;
    } else {
      nextIdx = (currentIdx - 1 + mainTerminals.length) % mainTerminals.length;
    }
    switchToTerminal(mainTerminals[nextIdx].info.id, "main");
    return;
  }

  // Cmd+\: toggle split view
  if (meta && e.key === "\\") {
    e.preventDefault();
    toggleSplitView();
    return;
  }

  // Cmd+N: new terminal in main
  if (meta && e.key === "n" && !e.shiftKey) {
    e.preventDefault();
    launchInPanel("main");
    return;
  }

  // Cmd+Shift+N: new terminal in split/secondary
  if (meta && e.key === "N" && e.shiftKey) {
    e.preventDefault();
    launchInPanel("secondary");
    return;
  }

  // Cmd+W: close active main terminal
  if (meta && e.key === "w") {
    e.preventDefault();
    const active = manager.getActive("main");
    if (active) {
      closeTerminal(active.info.id);
    }
    return;
  }

  // Cmd+,: settings
  if (meta && e.key === ",") {
    e.preventDefault();
    openSettings();
    return;
  }

  // Welcome screen tool shortcuts
  if (!welcomeScreen.classList.contains("hidden")) {
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
}

// ── Terminal Lifecycle ───────────────────────────────────────────────

async function launchTool(tool: ToolConfig) {
  showWorkspace();
  await createTerminalInPanel("main", tool.name, tool.command, tool.args);
}

async function launchInPanel(panel: "main" | "secondary") {
  showWorkspace();
  if (panel === "secondary" && !splitMode) {
    // Open split view if not already open
    splitMode = true;
    splitPanel.classList.remove("hidden");
  }
  await createTerminalInPanel(panel, "Terminal");
}

async function createTerminalInPanel(
  panel: "main" | "secondary",
  label: string,
  command?: string,
  args: string[] = []
) {
  // Determine which viewport to use
  const viewport = panel === "main" ? mainViewport : splitViewport;

  if (panel === "secondary" && !splitMode) {
    splitMode = true;
    splitPanel.classList.remove("hidden");
  }

  // createTerminal now handles attaching to the viewport
  const instance = await manager.createTerminal(
    panel,
    viewport,
    label,
    command,
    args
  );

  setupTerminalContextMenu(instance);
}

function switchToTerminal(id: string, panel: "main" | "secondary") {
  manager.setActive(id);
  const viewport = panel === "main" ? mainViewport : splitViewport;
  manager.showInViewport(id, viewport);
  renderTabs(manager.getAllInstances());
}

function closeTerminal(id: string) {
  const instance = manager.getInstance(id);
  if (!instance) return;

  manager.closeTerminal(id);

  // If we closed the last secondary terminal, close split
  if (instance.panel === "secondary" && manager.getTerminalsByPanel("secondary").length === 0) {
    closeSplitView();
  }

  // If closed active, show the new active
  const panel = instance.panel;
  const newActive = manager.getActive(panel);
  if (newActive) {
    const viewport = panel === "main" ? mainViewport : splitViewport;
    manager.showInViewport(newActive.info.id, viewport);
  }

  if (!manager.hasTerminals()) {
    showWelcome();
  }

  renderTabs(manager.getAllInstances());
}

// ── Split View ──────────────────────────────────────────────────────

function toggleSplitView() {
  if (splitMode) {
    closeSplitView();
  } else {
    openSplitView();
  }
}

function openSplitView() {
  splitMode = true;
  splitPanel.classList.remove("hidden");

  const active = manager.getActive("secondary");
  if (active) {
    manager.showInViewport(active.info.id, splitViewport);
  } else {
    createTerminalInPanel("secondary", "Terminal");
  }

  requestAnimationFrame(() => manager.fitVisible());
}

function closeSplitView() {
  splitMode = false;
  splitPanel.classList.add("hidden");

  // Detach any terminal from split viewport
  while (splitViewport.firstChild) {
    splitViewport.removeChild(splitViewport.firstChild);
  }

  requestAnimationFrame(() => manager.fitVisible());
  renderTabs(manager.getAllInstances());
}

// ── Tab Rendering ───────────────────────────────────────────────────

function renderTabs(instances: TerminalInstance[]) {
  renderTabsForPanel("main", mainTabs, instances);
  // Only show secondary tabs when split is open
  if (splitMode) {
    renderTabsForPanel("secondary", secondaryTabs, instances);
  } else {
    secondaryTabs.innerHTML = "";
  }
}

function renderTabsForPanel(
  panel: "main" | "secondary",
  container: HTMLElement,
  allInstances: TerminalInstance[]
) {
  container.innerHTML = "";
  const panelInstances = allInstances.filter((i) => i.panel === panel);
  const active = manager.getActive(panel);

  panelInstances.forEach((inst, index) => {
    const tab = document.createElement("button");
    tab.className = `terminal-tab${inst.info.id === active?.info.id ? " active" : ""}`;

    const dot = document.createElement("span");
    dot.className = "tab-dot";
    dot.style.backgroundColor = getToolColor(inst.info.command);
    tab.appendChild(dot);

    const labelSpan = document.createElement("span");
    labelSpan.className = "tab-label";
    labelSpan.textContent = inst.info.label;
    tab.appendChild(labelSpan);

    // Tab number hint
    if (index < 9) {
      const numHint = document.createElement("span");
      numHint.className = "tab-num";
      numHint.textContent = `${index + 1}`;
      tab.appendChild(numHint);
    }

    const closeBtn = document.createElement("span");
    closeBtn.className = "tab-close";
    closeBtn.textContent = "\u2715";
    closeBtn.addEventListener("click", (e) => {
      e.stopPropagation();
      closeTerminal(inst.info.id);
    });
    tab.appendChild(closeBtn);

    // Single click: switch
    tab.addEventListener("click", () => switchToTerminal(inst.info.id, panel));

    // Double click: rename
    tab.addEventListener("dblclick", (e) => {
      e.preventDefault();
      e.stopPropagation();
      startRenameInline(tab, inst);
    });

    // Right click: tab context menu
    tab.addEventListener("contextmenu", (e) => {
      e.preventDefault();
      showTabContextMenu(e.clientX, e.clientY, inst);
    });

    container.appendChild(tab);
  });
}

// ── Tab Context Menu ────────────────────────────────────────────────

function showTabContextMenu(x: number, y: number, inst: TerminalInstance) {
  dismissContextMenu();

  const menu = document.createElement("div");
  menu.className = "context-menu";
  menu.style.left = `${x}px`;
  menu.style.top = `${y}px`;

  const renameItem = document.createElement("button");
  renameItem.className = "context-menu-item";
  renameItem.textContent = "Rename...";
  renameItem.addEventListener("click", () => {
    dismissContextMenu();
    // Find the tab and start rename
    const tabs = inst.panel === "main" ? mainTabs : secondaryTabs;
    const tabEls = tabs.querySelectorAll(".terminal-tab");
    const panelInstances = manager.getTerminalsByPanel(inst.panel);
    const idx = panelInstances.findIndex((i) => i.info.id === inst.info.id);
    if (idx >= 0 && tabEls[idx]) {
      startRenameInline(tabEls[idx] as HTMLElement, inst);
    }
  });
  menu.appendChild(renameItem);

  const moveItem = document.createElement("button");
  moveItem.className = "context-menu-item";
  moveItem.textContent = inst.panel === "main" ? "Move to split" : "Move to main";
  moveItem.addEventListener("click", () => {
    dismissContextMenu();
    const newPanel = inst.panel === "main" ? "secondary" : "main";
    inst.panel = newPanel;
    manager.setActive(inst.info.id);
    const viewport = newPanel === "main" ? mainViewport : splitViewport;
    if (newPanel === "secondary" && !splitMode) {
      openSplitView();
    }
    manager.showInViewport(inst.info.id, viewport);
    renderTabs(manager.getAllInstances());
  });
  menu.appendChild(moveItem);

  const sep = document.createElement("div");
  sep.className = "context-menu-separator";
  menu.appendChild(sep);

  const closeItem = document.createElement("button");
  closeItem.className = "context-menu-item";
  closeItem.style.color = "var(--accent-red)";
  closeItem.textContent = "Close";
  closeItem.addEventListener("click", () => {
    dismissContextMenu();
    closeTerminal(inst.info.id);
  });
  menu.appendChild(closeItem);

  document.body.appendChild(menu);

  // Keep in viewport
  const rect = menu.getBoundingClientRect();
  if (rect.right > window.innerWidth) menu.style.left = `${window.innerWidth - rect.width - 8}px`;
  if (rect.bottom > window.innerHeight) menu.style.top = `${window.innerHeight - rect.height - 8}px`;

  activeContextMenu = menu;
}

// ── Tab Rename ──────────────────────────────────────────────────────

function startRenameInline(tabElement: HTMLElement, instance: TerminalInstance) {
  const labelSpan = tabElement.querySelector(".tab-label") as HTMLElement;
  if (!labelSpan) return;

  const input = document.createElement("input");
  input.type = "text";
  input.value = instance.info.label;
  input.className = "tab-rename-input";
  input.style.cssText = `
    background: var(--bg-primary); color: var(--text-primary);
    border: 1px solid var(--accent-orange); border-radius: 2px;
    font-family: var(--font-mono); font-size: 12px;
    padding: 0 4px; width: ${Math.max(60, instance.info.label.length * 8)}px;
    outline: none;
  `;

  const origText = labelSpan.textContent;
  labelSpan.textContent = "";
  labelSpan.appendChild(input);
  input.focus();
  input.select();

  let committed = false;
  const commit = () => {
    if (committed) return;
    committed = true;
    const newLabel = input.value.trim() || origText || "Terminal";
    manager.renameTerminal(instance.info.id, newLabel);
  };

  input.addEventListener("blur", commit);
  input.addEventListener("keydown", (e) => {
    if (e.key === "Enter") { e.preventDefault(); commit(); }
    if (e.key === "Escape") {
      e.preventDefault();
      committed = true;
      renderTabs(manager.getAllInstances()); // cancel
    }
    e.stopPropagation(); // don't trigger global shortcuts
  });
}

// ── Bidirectional Send-to-Terminal ───────────────────────────────────

function setupTerminalContextMenu(instance: TerminalInstance) {
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

  // If in split mode, show quick actions for the split partner
  if (splitMode) {
    const otherPanel = sourceInstance.panel === "main" ? "secondary" : "main";
    const partner = manager.getActive(otherPanel);
    if (partner) {
      const sendItem = document.createElement("button");
      sendItem.className = "context-menu-item";
      sendItem.style.color = "var(--accent-orange)";
      sendItem.textContent = `Paste in ${partner.info.label}`;
      sendItem.addEventListener("click", () => {
        manager.sendToTerminal(partner.info.id, selectedText);
        dismissContextMenu();
      });
      menu.appendChild(sendItem);

      const runItem = document.createElement("button");
      runItem.className = "context-menu-item";
      runItem.style.color = "var(--accent-green)";
      runItem.textContent = `Run in ${partner.info.label}`;
      runItem.addEventListener("click", () => {
        manager.sendToTerminal(partner.info.id, selectedText + "\n");
        dismissContextMenu();
      });
      menu.appendChild(runItem);

      if (targets.length > 1) {
        const sep = document.createElement("div");
        sep.className = "context-menu-separator";
        menu.appendChild(sep);
      }
    }
  }

  // All other targets
  const otherTargets = splitMode
    ? targets.filter((t) => t.info.id !== manager.getActive(sourceInstance.panel === "main" ? "secondary" : "main")?.info.id)
    : targets;

  if (otherTargets.length > 0) {
    const header = document.createElement("div");
    header.style.cssText = "padding: 4px 12px; color: var(--text-secondary); font-size: 11px;";
    header.textContent = "Send to...";
    menu.appendChild(header);

    for (const target of otherTargets) {
      const item = document.createElement("button");
      item.className = "context-menu-item";

      const dot = document.createElement("span");
      dot.style.cssText = `display:inline-block;width:8px;height:8px;border-radius:50%;margin-right:8px;background:${getToolColor(target.info.command)};`;
      item.appendChild(dot);
      item.appendChild(document.createTextNode(target.info.label));

      item.addEventListener("click", () => {
        manager.sendToTerminal(target.info.id, selectedText);
        dismissContextMenu();
      });
      menu.appendChild(item);
    }
  }

  document.body.appendChild(menu);
  const rect = menu.getBoundingClientRect();
  if (rect.right > window.innerWidth) menu.style.left = `${window.innerWidth - rect.width - 8}px`;
  if (rect.bottom > window.innerHeight) menu.style.top = `${window.innerHeight - rect.height - 8}px`;

  activeContextMenu = menu;
}

function dismissContextMenu() {
  if (activeContextMenu) {
    activeContextMenu.remove();
    activeContextMenu = null;
  }
}

// ── Settings Modal ──────────────────────────────────────────────────

function openSettings() {
  document.getElementById("settings-modal")?.remove();

  const inputStyle = `width: 100%; padding: 6px 8px; background: var(--bg-primary); color: var(--text-primary);
    border: 1px solid var(--border-color); border-radius: 4px; font-family: var(--font-mono);
    font-size: 13px; outline: none;`;
  const labelStyle = `display: block; margin-bottom: 4px; font-size: 12px; color: var(--text-secondary);`;
  const fieldStyle = `margin-bottom: 16px;`;

  const overlay = document.createElement("div");
  overlay.id = "settings-modal";
  overlay.style.cssText = `
    position: fixed; inset: 0; background: rgba(0,0,0,0.6);
    display: flex; align-items: center; justify-content: center;
    z-index: 3000;
  `;

  const modal = document.createElement("div");
  modal.style.cssText = `
    background: var(--bg-secondary); border: 1px solid var(--border-color);
    border-radius: 8px; padding: 24px; width: 500px; max-height: 80vh;
    overflow-y: auto; font-family: var(--font-mono);
  `;

  modal.innerHTML = `
    <h2 style="margin: 0 0 20px; font-size: 16px; color: var(--accent-orange);">Settings</h2>

    <div style="${fieldStyle}">
      <label style="${labelStyle}">Default Working Directory</label>
      <div style="display: flex; gap: 8px;">
        <input id="settings-cwd" type="text" value="${settings.default_cwd || ""}"
          placeholder="/Users/you/Code" style="${inputStyle} flex: 1;" />
        <button id="settings-browse-cwd" style="
          padding: 6px 12px; background: var(--bg-tertiary); color: var(--text-primary);
          border: 1px solid var(--border-color); border-radius: 4px; cursor: pointer;
          font-family: var(--font-mono); font-size: 12px; white-space: nowrap;
        ">Browse...</button>
      </div>
    </div>

    <div style="display: flex; gap: 16px; ${fieldStyle}">
      <div style="flex: 1;">
        <label style="${labelStyle}">Font Size</label>
        <input id="settings-fontsize" type="number" value="${settings.font_size}" min="8" max="32"
          style="${inputStyle} width: 80px;" />
      </div>
      <div style="flex: 1;">
        <label style="${labelStyle}">Font Color</label>
        <div style="display: flex; gap: 8px; align-items: center;">
          <input id="settings-fontcolor" type="color" value="${settings.font_color || "#e6edf3"}"
            style="width: 36px; height: 30px; padding: 0; border: 1px solid var(--border-color);
              border-radius: 4px; background: var(--bg-primary); cursor: pointer;" />
          <input id="settings-fontcolor-hex" type="text" value="${settings.font_color || "#e6edf3"}"
            placeholder="#e6edf3" style="${inputStyle} width: 100px;" />
          <button id="settings-fontcolor-reset" style="
            padding: 4px 8px; background: var(--bg-tertiary); color: var(--text-muted);
            border: 1px solid var(--border-color); border-radius: 4px; cursor: pointer;
            font-family: var(--font-mono); font-size: 10px;
          ">Reset</button>
        </div>
      </div>
    </div>

    <div style="${fieldStyle}">
      <label style="${labelStyle}">Default Shell (blank = system default)</label>
      <input id="settings-shell" type="text" value="${settings.default_shell || ""}"
        placeholder="/bin/zsh" style="${inputStyle}" />
    </div>

    <div style="display: flex; gap: 8px; justify-content: flex-end; margin-top: 8px;">
      <button id="settings-cancel" style="
        padding: 6px 16px; background: var(--bg-tertiary); color: var(--text-primary);
        border: 1px solid var(--border-color); border-radius: 4px; cursor: pointer;
        font-family: var(--font-mono); font-size: 12px;">Cancel</button>
      <button id="settings-save" style="
        padding: 6px 16px; background: var(--accent-orange); color: var(--bg-primary);
        border: none; border-radius: 4px; cursor: pointer;
        font-family: var(--font-mono); font-size: 12px; font-weight: bold;">Save</button>
    </div>

    <div style="margin-top: 16px; padding-top: 12px; border-top: 1px solid var(--border-color);
      font-size: 11px; color: var(--text-muted);">
      Settings saved to platform config directory.<br/>
      Keyboard: Cmd+1-9 switch tabs, Cmd+Shift+arrows cycle, Cmd+\\ split, Cmd+N new, Cmd+W close, Cmd+, settings
    </div>
  `;

  overlay.appendChild(modal);
  document.body.appendChild(overlay);

  // Sync color picker <-> hex input
  const colorPicker = document.getElementById("settings-fontcolor") as HTMLInputElement;
  const colorHex = document.getElementById("settings-fontcolor-hex") as HTMLInputElement;

  colorPicker.addEventListener("input", () => {
    colorHex.value = colorPicker.value;
  });
  colorHex.addEventListener("input", () => {
    if (/^#[0-9a-fA-F]{6}$/.test(colorHex.value)) {
      colorPicker.value = colorHex.value;
    }
  });
  document.getElementById("settings-fontcolor-reset")!.addEventListener("click", () => {
    colorPicker.value = "#e6edf3";
    colorHex.value = "#e6edf3";
  });

  // Browse button for directory
  document.getElementById("settings-browse-cwd")!.addEventListener("click", async () => {
    const selected = await openDialog({
      directory: true,
      multiple: false,
      title: "Select Default Working Directory",
    });
    if (selected) {
      (document.getElementById("settings-cwd") as HTMLInputElement).value = selected as string;
    }
  });

  // Close on overlay click
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) overlay.remove();
  });

  document.getElementById("settings-cancel")!.addEventListener("click", () => overlay.remove());

  document.getElementById("settings-save")!.addEventListener("click", async () => {
    const cwdInput = document.getElementById("settings-cwd") as HTMLInputElement;
    const fontInput = document.getElementById("settings-fontsize") as HTMLInputElement;
    const shellInput = document.getElementById("settings-shell") as HTMLInputElement;

    settings.default_cwd = cwdInput.value.trim() || null;
    settings.font_size = parseInt(fontInput.value) || 14;
    settings.font_color = colorHex.value.trim() || null;
    settings.default_shell = shellInput.value.trim() || null;

    try {
      await invoke("save_settings", { settings });
      overlay.remove();
    } catch (e) {
      console.error("Failed to save settings:", e);
    }
  });

  // Escape to close
  const escHandler = (e: KeyboardEvent) => {
    if (e.key === "Escape") {
      overlay.remove();
      document.removeEventListener("keydown", escHandler);
    }
  };
  document.addEventListener("keydown", escHandler);
}

// ── UI Helpers ───────────────────────────────────────────────────────

function showWorkspace() {
  welcomeScreen.classList.add("hidden");
  workspace.classList.remove("hidden");
  requestAnimationFrame(() => manager.fitVisible());
}

function showWelcome() {
  workspace.classList.add("hidden");
  welcomeScreen.classList.remove("hidden");
}

function toggleSidebar() {
  sidebar.classList.toggle("hidden");
  requestAnimationFrame(() => manager.fitVisible());
}

function getToolColor(command: string): string {
  const tool = settings.tools.find((t) => t.command === command);
  return tool?.color ?? "#8b949e";
}

// ── Split Resize ────────────────────────────────────────────────────

function setupSplitResize() {
  const handle = document.getElementById("split-resize-handle")!;
  let startX = 0;
  let startWidth = 0;

  handle.addEventListener("mousedown", (e) => {
    startX = e.clientX;
    startWidth = splitPanel.getBoundingClientRect().width;
    document.addEventListener("mousemove", onResize);
    document.addEventListener("mouseup", stopResize);
    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
    e.preventDefault();
  });

  function onResize(e: MouseEvent) {
    // Handle is on the left edge of split panel (right side of screen).
    // Dragging left = clientX decreases = panel should grow.
    const delta = startX - e.clientX;
    const parentWidth = splitPanel.parentElement!.getBoundingClientRect().width;
    const newWidth = Math.max(200, Math.min(parentWidth - 300, startWidth + delta));
    splitPanel.style.flex = `0 0 ${newWidth}px`;
  }

  function stopResize() {
    document.removeEventListener("mousemove", onResize);
    document.removeEventListener("mouseup", stopResize);
    document.body.style.cursor = "";
    document.body.style.userSelect = "";
    // Fit terminals once drag is done (not during, to avoid thrashing)
    manager.fitVisible();
  }
}

window.addEventListener("DOMContentLoaded", init);
