import { check } from "@tauri-apps/plugin-updater";

export interface UpdateStatus {
  available: boolean;
  version?: string;
  notes?: string;
  downloading?: boolean;
  progress?: number;
}

export type UpdateCallback = (status: UpdateStatus) => void;

export class Updater {
  private callback: UpdateCallback | null = null;

  onStatus(cb: UpdateCallback) {
    this.callback = cb;
  }

  private notify(status: UpdateStatus) {
    this.callback?.(status);
  }

  async checkForUpdates(): Promise<UpdateStatus> {
    try {
      const update = await check();
      if (update) {
        const status: UpdateStatus = {
          available: true,
          version: update.version,
          notes: update.body ?? undefined,
        };
        this.notify(status);
        return status;
      }
      return { available: false };
    } catch (e) {
      // Expected to fail in dev mode or when no pubkey configured
      console.debug("Update check skipped:", e);
      return { available: false };
    }
  }

  async downloadAndInstall(): Promise<void> {
    try {
      const update = await check();
      if (!update) return;

      this.notify({
        available: true,
        version: update.version,
        downloading: true,
        progress: 0,
      });

      // Save session before updating
      await this.saveCurrentSession();

      let downloaded = 0;
      let contentLength = 0;

      await update.downloadAndInstall((event) => {
        switch (event.event) {
          case "Started":
            contentLength = event.data.contentLength ?? 0;
            break;
          case "Progress":
            downloaded += event.data.chunkLength;
            this.notify({
              available: true,
              version: update.version,
              downloading: true,
              progress: contentLength > 0 ? (downloaded / contentLength) * 100 : 0,
            });
            break;
          case "Finished":
            this.notify({
              available: true,
              version: update.version,
              downloading: false,
              progress: 100,
            });
            break;
        }
      });

      // Tauri will restart the app after install
    } catch (e) {
      console.error("Update failed:", e);
      throw e;
    }
  }

  private async saveCurrentSession(): Promise<void> {
    // This is called from the frontend, which has access to the current terminal state
    // The actual session data will be passed from main.ts
    // This is a hook point - the real save happens in main.ts before update
  }
}

export const updater = new Updater();
