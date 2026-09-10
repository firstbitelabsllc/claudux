import { pathToFileURL, fileURLToPath } from "node:url";
import { spawn, execFileSync } from "node:child_process";
import { mkdir, stat, writeFile } from "node:fs/promises";
import path from "node:path";

const playwright = await import(process.env.PLAYWRIGHT_MODULE ? pathToFileURL(path.resolve(process.env.PLAYWRIGHT_MODULE)).href : "playwright");
const { chromium } = playwright.default ?? playwright;
const root = fileURLToPath(new URL("../", import.meta.url));
const output = path.join(root, "docs/public");
const port = "8832";
const prompt = "Run examples/agent-demo/run.sh. In two bullets, 35 words maximum: state the API change, then whether source, pinned Quick start, and original fixture stayed unchanged.";

execFileSync("ffmpeg", ["-version"], { stdio: "ignore" });
await mkdir(output, { recursive: true });
const server = spawn("ttyd", [
  "-p", port, "-i", "127.0.0.1", "-O", "-o", "-W", "-w", root,
  "-t", "fontSize=18", "-t", "screenReaderMode=true", "-t", "fontFamily=Menlo",
  "-t", 'theme={"background":"#f4f2eb","foreground":"#212920","cursor":"#b6532a"}',
  "claude", "--safe-mode", "--setting-sources", "", "--strict-mcp-config",
  "--mcp-config", '{"mcpServers":{}}', "--model", "sonnet", "--effort", "low",
  "--tools", "Bash,Read", "--allowedTools", "Bash(examples/agent-demo/run.sh)",
], { env: { ...process.env, BASH_SILENCE_DEPRECATION_WARNING: "1" }, stdio: ["ignore", "pipe", "pipe"] });
let logs = "";
server.stderr.on("data", (chunk) => (logs += chunk));
let browser;
try {
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(Error(logs || "ttyd startup timeout")), 10000);
    server.stderr.on("data", () => {
      if (logs.includes("Listening on port")) { clearTimeout(timeout); resolve(); }
    });
    server.once("exit", (code) => { clearTimeout(timeout); reject(Error("ttyd exited " + code + " " + logs)); });
  });
  browser = await chromium.launch();
  const context = await browser.newContext({ viewport: { width: 1440, height: 980 }, recordVideo: { dir: output, size: { width: 1440, height: 980 } } });
  const page = await context.newPage();
  await page.goto(`http://127.0.0.1:${port}`);
  await page.locator(".xterm-helper-textarea").waitFor({ state: "attached" });
  await page.addStyleTag({ content: "body{background:#e6e4dd!important;margin:0!important;padding:0!important}#terminal-container{position:fixed!important;inset:40px!important;width:auto!important;height:auto!important;border-radius:12px;overflow:hidden;padding:0!important;background:#f4f2eb;box-sizing:border-box!important;box-shadow:0 0 0 20px #f4f2eb}.xterm{height:100%!important;padding:0!important}" });
  await page.setViewportSize({ width: 1439, height: 980 });
  await page.setViewportSize({ width: 1440, height: 980 });
  await page.waitForTimeout(800);
  await page.waitForFunction(() => document.body.textContent.includes("Claude Code"), null, { timeout: 15000 });
  await page.locator(".xterm-helper-textarea").focus();
  await page.keyboard.type(prompt, { delay: 25 });
  await page.keyboard.press("Enter");
  await page.waitForFunction(() => /done \d+:\d+ [AP]M/.test(document.body.textContent), null, { timeout: 600000 });
  await page.screenshot({ path: path.join(output, "claudux-demo.png") });
  await page.waitForTimeout(6200);
  const video = page.video();
  await context.close();
  await video.saveAs(path.join(output, "claudux-demo.webm"));
  await video.delete();
  for (const name of ["claudux-demo.png", "claudux-demo.webm"])
    if ((await stat(path.join(output, name))).size < 1000) throw Error(`Capture missing: ${name}`);
  await writeFile(path.join(output, "capture-result.json"), JSON.stringify({
    commands: ["Claude Code runs examples/agent-demo/run.sh; Claudux asks configured Codex to update only the API section"],
    browser: browser.version(), recordedAt: new Date().toISOString(),
  }, null, 2) + "\n");
  execFileSync("ffmpeg", ["-y", "-i", path.join(output, "claudux-demo.webm"), "-an", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-movflags", "+faststart", path.join(output, "claudux-demo.mp4")], { stdio: "ignore" });
  console.log("Verified native Claude Code and Codex recording assets.");
} finally {
  if (browser) await browser.close();
  server.kill("SIGTERM");
}
