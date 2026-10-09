// Example capture spec: one test = one captioned video.
// Copy into your project's e2e/ folder as zz-<name>-video.spec.ts, point BASE_URL at
// your dev server, and replace the chapters with your own flow. Delete it afterwards.
import { test, expect, type Page } from '@playwright/test'

const BASE_URL = process.env.BASE_URL ?? 'https://playwright.dev'

test.use({
  video: { mode: 'on', size: { width: 1280, height: 800 } },
  viewport: { width: 1280, height: 800 }
})
test.setTimeout(240000)

async function caption(page: Page, text: string) {
  await page.evaluate((t) => {
    let bar = document.getElementById('demo-caption')
    if (!bar) {
      bar = document.createElement('div')
      bar.id = 'demo-caption'
      bar.style.cssText =
        'position:fixed;left:0;right:0;bottom:0;z-index:99999;background:#142b1e;color:#f7f5f0;' +
        'font:600 15px/1.4 Inter,system-ui,sans-serif;padding:12px 20px;letter-spacing:0.01em'
      document.body.appendChild(bar)
    }
    bar.textContent = t
  }, text)
  await page.waitForTimeout(2200)
}

test('demo: from the home page to the installation docs', async ({ page }) => {
  await page.goto(BASE_URL)
  await caption(page, '1. The home page')
  await expect(page.getByRole('link', { name: 'Get started' })).toBeVisible()

  await page.getByRole('link', { name: 'Get started' }).click()
  await caption(page, '2. "Get started" opens the installation guide')
  await expect(page.getByRole('heading', { name: 'Installation' })).toBeVisible()

  const heading = page.locator('h2#running-the-example-test')
  await heading.evaluate((el) => el.scrollIntoView({ block: 'start' }))
  await caption(page, '3. Each chapter changes what is on screen, not just the caption')
  await expect(heading).toBeInViewport()

  await page.getByRole('link', { name: 'Writing tests', exact: true }).first().click()
  await caption(page, '4. The sidebar leads to "Writing tests"')
  await expect(page.getByRole('heading', { name: 'Writing tests', level: 1 })).toBeVisible()

  await page.goto(BASE_URL)
  await caption(page, '5. Back home: the video ends where it started, and the test passed')
  await expect(page).toHaveTitle(/Playwright/)
})
