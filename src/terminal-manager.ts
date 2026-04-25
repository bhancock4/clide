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
  unlistenData: UnlistenFn | null;
  unlistenExit: UnlistenFn | null;
  panel: "main" | "secondary";
}

export type TerminalEventCallback = (instances: TerminalInstance[]) => void;

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
    container: HTMLElement,
    label?: string,
    command?: string,
    args: string[] = []
  ): Promise<TerminalInstance> {
    const terminal = new Terminal({
      cursorBlink: true,
      fontSize: 14,
      fontFamily: "Menlo, Monaco, 'Courier New', monospace",
      theme: {
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
      },
    });

    const fitAddon = new FitAddon();
    terminal.loadAddon(fitAddon);
    terminal.loadAddon(new WebLinksAddon());

    terminal.open(container);
    fitAddon.fit();

    const cols = terminal.cols;
    const rows = terminal.rows;

    const info: TerminalInfo = await invoke("spawn_terminal", {
      label: label || "Terminal",
      command: command || null,
      args,
      cols,
      rows,
    });

    // Forward keystrokes to the PTY
    terminal.onData((data) => {
      invoke("write_terminal", { id: info.id, data }).catch(console.error);
    });

    // Handle resize
    terminal.onResize(({ cols, rows }) => {
      invoke("resize_terminal", { id: info.id, cols, rows }).catch(
        console.error
      );
    });

    // Listen for PTY output
    const unlistenData = await listen<string>(
      `pty-data-${info.id}`,
      (event) => {
        terminal.write(event.payload);
      }
    );

    // Listen for PTY exit
    const unlistenExit = await listen(`pty-exit-${info.id}`, () => {
      terminal.write("\r\n\x1b[90m[Process exited]\x1b[0m\r\n");
    });

    const instance: TerminalInstance = {
      info,
      terminal,
      fitAddon,
      unlistenData,
      unlistenExit,
      panel,
    };

    this.instances.set(info.id, instance);

    if (panel === "main") {
      this.activeMain = info.id;
    } else {
      this.activeSecondary = info.id;
    }

    this.notify();
    return instance;
  }

  async closeTerminal(id: string) {
    const instance = this.instances.get(id);
    if (!instance) return;

    instance.unlistenData?.();
    instance.unlistenExit?.();
    instance.terminal.dispose();

    try {
      await invoke("close_terminal", { id });
    } catch {
      // Terminal may already be gone
    }

    this.instances.delete(id);

    if (this.activeMain === id) {
      const mainTerminals = this.getTerminalsByPanel("main");
      this.activeMain = mainTerminals[0]?.info.id ?? null;
    }
    if (this.activeSecondary === id) {
      const secondaryTerminals = this.getTerminalsByPanel("secondary");
      this.activeSecondary = secondaryTerminals[0]?.info.id ?? null;
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
    this.notify();
  }

  getActive(panel: "main" | "secondary"): TerminalInstance | null {
    const id = panel === "main" ? this.activeMain : this.activeSecondary;
    if (!id) return null;
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

  fitAll() {
    for (const instance of this.instances.values()) {
      try {
        instance.fitAddon.fit();
      } catch {
        // Terminal element may not be visible
      }
    }
  }

  sendToTerminal(targetId: string, text: string) {
    invoke("write_terminal", { id: targetId, data: text }).catch(
      console.error
    );
  }
}
