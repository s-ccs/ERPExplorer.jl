const { defineConfig } = require('@playwright/test');
module.exports = defineConfig({
  testDir: '.', testMatch: '*.spec.cjs', workers: 1, timeout: 360000,
  expect: { timeout: 180000 },
  use: {
    baseURL: process.env.ERP_BROWSER_URL || 'http://127.0.0.1:8089',
    viewport: { width: 1280, height: 900 },
    screenshot: 'only-on-failure', trace: 'retain-on-failure',
    launchOptions: {args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader']}
  },
  webServer: process.env.ERP_BROWSER_EXTERNAL ? undefined : {
    command: process.env.ERP_BROWSER_SERVER_COMMAND || 'julia --project=../harness server.jl',
    url: process.env.ERP_BROWSER_URL || 'http://127.0.0.1:8089',
    timeout: 900000, reuseExistingServer: false, stdout: "pipe", stderr: "pipe",
  }
});
