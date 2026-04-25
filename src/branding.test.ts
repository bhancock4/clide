import { describe, it, expect } from "vitest";
import { ASCII_LOGO, CLYDE_MASCOT, VERSION } from "./branding";

describe("branding", () => {
  it("ASCII logo contains CLIDE", () => {
    // The block letters should spell out CLIDE (using box drawing chars)
    // Check that key structural characters are present
    expect(ASCII_LOGO).toContain("██");
    expect(ASCII_LOGO).toContain("╗");
    expect(ASCII_LOGO).toContain("╚");
  });

  it("ASCII logo has consistent line count", () => {
    const lines = ASCII_LOGO.split("\n");
    expect(lines.length).toBe(6); // 6-line block letter art
  });

  it("Clyde mascot contains CLYDE label", () => {
    expect(CLYDE_MASCOT).toContain("CLYDE");
  });

  it("Clyde mascot has face elements", () => {
    // Should have eyes
    expect(CLYDE_MASCOT).toContain("◉");
    // Should have mouth
    expect(CLYDE_MASCOT).toContain("╰───╯");
  });

  it("VERSION is a valid semver string", () => {
    expect(VERSION).toMatch(/^\d+\.\d+\.\d+$/);
  });
});
