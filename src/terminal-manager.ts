import { Terminal } from "@xterm/xterm";
import { FitAddon } from "@xterm/addon-fit";
import { WebLinksAddon } from "@xterm/addon-web-links";
import { invoke } from "@tauri-apps/api/core";
import { listen, type UnlistenFn } from "@tauri-apps/api/event";

export interface TerminalInfo {
  id: string;
  label: string;
  command: string;
}

export interface TerminalInstance {
  info: TerminalInfo;
  terminal: Terminal;
  fitAddon: FitAddon;
  wrapper: HTMLElement;
  resizeObserver: ResizeObserver;
  unlistenData: UnlistenFn | null;
  unlistenExit: UnlistenFn | null;
  panel: "main" | "secondary";
  // Track last known size to avoid redundant resize calls
  lastCols: number;
  lastRows: number;
}

export type TerminalEventCallback = (instances: TerminalInstance[]) => void;

const XTERM_THEME = {
  background: "#0d1117",
  foreground: "#e6edf3",
  cursor: "#e6edf3",
  selectionBackground: "#264f78",
  black: "#484f58",
  red: "#f85149",
  green: "#3fb950",
  yellow: "#d29922",
  blue: "#58a6ff",
  magenta: "#bc8cff",
  cyan: "#39d353",
  white: "#e6edf3",
  brightBlack: "#6e7681",
  brightRed: "#ffa198",
  brightGreen: "#56d364",
  brightYellow: "#e3b341",
  brightBlue: "#79c0ff",
  brightMagenta: "#d2a8ff",
  brightCyan: "#56d364",
  brightWhite: "#f0f6fc",
};

export class TerminalManager {
  private instances: Map<string, TerminalInstance> = new Map();
  private activeMain: string | null = null;
  private activeSecondary: string | null = null;
  private onChange: TerminalEventCallback | null = null;

  onChangeCallback(cb: TerminalEventCallback) {
    this.onChange = cb;
  }

  private notify() {
    this.onChange?.(this.getAllInstances());
  }

  async createTerminal(
    panel: "main" | "secondary",
    viewport: HTMLElement,
    label?: string,
    command?: string,
    args: string[] = [],
    cwd?: string
  ): Promise<TerminalInstance> {
    // 1. Clear the viewport
    while (viewport.firstChild) {
      viewport.removeChild(viewport.firstChild);
    }

    // 2. Create wrapper and attach to DOM
    const wrapper = document.createElement("div");
    wrapper.style.width = "100%";
    wrapper.style.height = "100%";
    wrapper.style.overflow = "hidden";
    viewport.appendChild(wrapper);

    // 3. Create xterm with scrollbar disabled to prevent width thrashing
    const terminal = new Terminal({
      cursorBlink: true,
      fontSize: 14,
      fontFamily: "Menlo, Monaco, 'Courier New', monospace",
      scrollback: 10000,
      theme: XTERM_THEME,
    });

    const fitAddon = new FitAddon();
    terminal.loadAddon(fitAddon);
    terminal.loadAddon(new WebLinksAddon());
    terminal.open(wrapper);

    // 4. Force-hide the native scrollbar so it can't change container width
    const xtermViewport = wrapper.querySelector(".xterm-viewport") as HTMLElement;
    if (xtermViewport) {
      xtermViewport.style.overflowY = "hidden";
    }

    // 5. Wait TWO frames for layout to fully settle
    await new Promise<void>((r) => requestAnimationFrame(() => requestAnimationFrame(() => r())));
    fitAddon.fit();
    const cols = terminal.cols;
    const rows = terminal.rows;

    // 6. Spawn PTY with locked dimensions
    const info: TerminalInfo = await invoke("spawn_terminal", {
      label: label || "Terminal",
      command: command || null,
      args,
      cols,
      rows,
      cwd: cwd || null,
    });

    // 7. Wire I/O
    terminal.onData((data) => {
      invoke("write_terminal", { id: info.id, data }).catch(console.error);
    });

    terminal.onResize(({ cols, rows }) => {
      invoke("resize_terminal", { id: info.id, cols, rows }).catch(console.error);
    });

    const unlistenData = await listen<string>(
      `pty-data-${info.id}`,
      (event) => {
        terminal.write(event.payload);
      }
    );

    const unlistenExit = await listen(`pty-exit-${info.id}`, () => {
      terminal.write("\r\n\x1b[90m[Process exited]\x1b[0m\r\n");
    });

    // 8. Set up ResizeObserver — only refit when the CONTAINER changes size,
    // not when terminal content changes. Debounced to avoid thrashing.
    let resizeTimer: ReturnType<typeof setTimeout> | null = null;
    const resizeObserver = new ResizeObserver(() => {
      if (resizeTimer) clearTimeout(resizeTimer);
      resizeTimer = setTimeout(() => {
        this.stableFit(info.id);
      }, 100);
    });
    resizeObserver.observe(wrapper);

    const instance: TerminalInstance = {
      info,
      terminal,
      fitAddon,
      wrapper,
      resizeObserver,
      unlistenData,
      unlistenExit,
      panel,
      lastCols: cols,
      lastRows: rows,
    };

    this.instances.set(info.id, instance);

    if (panel === "main") {
      this.activeMain = info.id;
    } else {
      this.activeSecondary = info.id;
    }

    terminal.focus();
    this.notify();
    return instance;
  }

  /**
   * Fit a terminal only if the dimensions actually changed.
   * This prevents resize loops where fit() triggers onResize
   * which triggers the PTY resize which triggers re-render.
   */
  private stableFit(id: string) {
    const instance = this.instances.get(id);
    if (!instance || !instance.wrapper.parentElement) return;

    try {
      instance.fitAddon.fit();
      const newCols = instance.terminal.cols;
      const newRows = instance.terminal.rows;

      // Only notify the PTY if dimensions actually changed
      if (newCols !== instance.lastCols || newRows !== instance.lastRows) {
        instance.lastCols = newCols;
        instance.lastRows = newRows;
        // The onResize handler on the terminal will fire and tell the PTY
      }
    } catch {
      // not visible
    }
  }

  showInViewport(id: string, viewport: HTMLElement) {
    const instance = this.instances.get(id);
    if (!instance) return;

    if (instance.wrapper.parentElement === viewport) {
      requestAnimationFrame(() => {
        this.stableFit(id);
        instance.terminal.focus();
      });
      return;
    }

    // Detach from current location
    if (instance.wrapper.parentElement) {
      instance.wrapper.parentElement.removeChild(instance.wrapper);
    }

    // Clear viewport
    while (viewport.firstChild) {
      viewport.removeChild(viewport.firstChild);
    }

    viewport.appendChild(instance.wrapper);

    // Wait for layout then fit
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        this.stableFit(id);
        instance.terminal.focus();
      });
    });
  }

  async closeTerminal(id: string) {
    const instance = this.instances.get(id);
    if (!instance) return;

    instance.resizeObserver.disconnect();
    instance.unlistenData?.();
    instance.unlistenExit?.();

    if (instance.wrapper.parentElement) {
      instance.wrapper.parentElement.removeChild(instance.wrapper);
    }
    instance.terminal.dispose();

    try {
      await invoke("close_terminal", { id });
    } catch {
      // Terminal may already be gone
    }

    this.instances.delete(id);

    if (this.activeMain === id) {
      const remaining = this.getTerminalsByPanel("main");
      this.activeMain = remaining[0]?.info.id ?? null;
    }
    if (this.activeSecondary === id) {
      const remaining = this.getTerminalsByPanel("secondary");
      this.activeSecondary = remaining[0]?.info.id ?? null;
    }

    this.notify();
  }

  setActive(id: string) {
    const instance = this.instances.get(id);
    if (!instance) return;

    if (instance.panel === "main") {
      this.activeMain = id;
    } else {
      this.activeSecondary = id;
    }
  }

  renameTerminal(id: string, newLabel: string) {
    const instance = this.instances.get(id);
    if (!instance) return;
    instance.info.label = newLabel;
    this.notify();
  }

  getActive(panel: "main" | "secondary"): TerminalInstance | null {
    const id = panel === "main" ? this.activeMain : this.activeSecondary;
    if (!id) return null;
    return this.instances.get(id) ?? null;
  }

  getInstance(id: string): TerminalInstance | null {
    return this.instances.get(id) ?? null;
  }

  getTerminalsByPanel(panel: "main" | "secondary"): TerminalInstance[] {
    return Array.from(this.instances.values()).filter(
      (i) => i.panel === panel
    );
  }

  getAllInstances(): TerminalInstance[] {
    return Array.from(this.instances.values());
  }

  hasTerminals(): boolean {
    return this.instances.size > 0;
  }

  fitVisible() {
    for (const [id, instance] of this.instances.entries()) {
      if (instance.wrapper.parentElement) {
        this.stableFit(id);
      }
    }
  }

  sendToTerminal(targetId: string, text: string) {
    invoke("write_terminal", { id: targetId, data: text }).catch(
      console.error
    );
  }
}
