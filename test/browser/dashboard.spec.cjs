const { test, expect } = require('@playwright/test');

async function ready(page, url = '/') {
  await page.goto(url);
  await expect(page.getByTestId('state-ready')).toHaveText('true');
  await expect(page.locator('canvas').first()).toBeVisible();
  await expect(page.getByTestId('state-error')).toHaveText('');
}

test('raw slider values survive formatting, dragging and reload', async ({page}) => {
  await ready(page);
  const dropdown = page.locator('.erp-dropdown').filter({hasText: 'luminance'});
  await dropdown.hover();
  const slider = dropdown.getByTestId('continuous-slider');
  await expect(slider).toBeVisible();
  const labels = await slider.locator('.noUi-tooltip').allTextContents();
  expect(labels[0]).not.toEqual(labels[1]);
  await expect(page.getByTestId('state-range')).toHaveText('1000.0,1001.0');
  await slider.evaluate(el => el.noUiSlider.set([1000.12, 1000.89]));
  await expect(page.getByTestId('state-range')).toHaveText('1000.12,1000.89');
  const handle = slider.locator('.noUi-handle').first();
  await handle.focus();
  await page.keyboard.press('ArrowUp');
  await expect(page.getByTestId('state-range')).not.toHaveText('1000.12,1000.89');
  const values = (await page.getByTestId('state-range').textContent()).split(',').map(Number);
  expect(values[0]).toBeGreaterThanOrEqual(1000);
  expect(values[1]).toBeLessThanOrEqual(1001);
  expect(values[0]).toBeLessThan(values[1]);
  const beforeDrag = await page.getByTestId('state-range').textContent();
  const handleBox = await handle.boundingBox();
  await page.mouse.move(handleBox.x + handleBox.width / 2, handleBox.y + handleBox.height / 2);
  await page.mouse.down();
  await page.mouse.move(handleBox.x + handleBox.width / 2, handleBox.y + handleBox.height / 2 + 15, {steps: 4});
  await page.mouse.up();
  await expect(page.getByTestId('state-range')).not.toHaveText(beforeDrag);
  await page.reload();
  await expect(page.getByTestId('state-ready')).toHaveText('true');
  await expect(page.getByTestId('state-range')).toHaveText('1000.0,1001.0');
});

test('production event, channel, layers and series controls update together', async ({page}) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await ready(page);
  await page.getByTestId('channel-select').locator('select').selectOption({label: '3'});
  await expect(page.getByTestId('state-channel')).toHaveText('3');
  await page.getByTestId('event-select').locator('select').selectOption({label: 'stimulus'});
  await expect(page.getByTestId('state-event')).toHaveText('stimulus');
  await page.getByTestId('mapping-markers').locator('input').uncheck();
  await page.getByTestId('mapping-lines').locator('input').uncheck();
  await expect(page.getByTestId('mapping-markers').locator('input')).toBeChecked();
  await page.getByTestId('mapping-color').locator('select').selectOption({label: 'fruit'});
  await page.getByRole('button', {name: 'Topoplots', exact: true}).click();
  await expect(page.getByTestId('series-panel')).toBeVisible();
  await expect(page.getByTestId('series-panel').locator('canvas')).toBeVisible();
  await page.getByTestId('bin-count').locator('select').selectOption({label: '3'});
  await expect(page.getByTestId('state-error')).toHaveText('');
  await page.getByRole('button', {name: 'ERP', exact: true}).click();
  await expect(page.getByTestId('erp-panel')).toBeHidden();
  await expect(page.getByTestId('event-select')).toBeVisible();
  await page.getByRole('button', {name: 'ERP', exact: true}).click();
  await expect(page.getByTestId('erp-panel')).toBeVisible();
  await page.getByRole('button', {name: 'Topoplots', exact: true}).click();
  await page.getByRole('button', {name: 'Topoplots', exact: true}).click();
  await expect(page.getByTestId('series-panel').locator('canvas')).toBeVisible();
  await page.getByRole('button', {name: 'Reset view', exact: true}).click();
  await expect(page.getByTestId('state-error')).toHaveText('');
  expect(errors).toEqual([]);
});

test('small notebook containers retain styles, accessible charts and numeric channels', async ({page}) => {
  await ready(page, '/?small=1&no_montage=1');
  const root = page.getByTestId('erp-explorer');
  const host = page.locator('#notebook-cell');
  const box = await root.boundingBox();
  const hostBox = await host.boundingBox();
  expect(box.width).toBeLessThanOrEqual(hostBox.width);
  expect(box.height).toBe(300);
  expect(await page.locator('body').evaluate(el => getComputedStyle(el).backgroundColor)).toBe('rgb(17, 24, 39)');
  await page.getByTestId('channel-select').locator('select').selectOption({label: '4'});
  await expect(page.getByTestId('state-channel')).toHaveText('4');
  await page.getByTestId('erp-panel').scrollIntoViewIfNeeded();
  const canvas = page.getByTestId('erp-panel').locator('canvas');
  await expect(canvas).toBeVisible();
  const canvasBox = await canvas.boundingBox();
  expect(canvasBox.width).toBeLessThanOrEqual(hostBox.width);
  await page.screenshot({path: 'test-results/small-container.png', fullPage: true});
  // A notebook column can be just above the stacked-layout breakpoint.
  // All sidebar controls must still fit, including Bonito's default select widths.
  for (const width of [680, 760, 900]) {
    await host.evaluate((el, width) => { el.style.width = width + 'px'; }, width);
    await root.evaluate(el => { el.style.width = '100%'; el.style.height = '600px'; el.scrollTop = 0; });
    await expect.poll(() => root.evaluate(el => {
      const right = el.getBoundingClientRect().right;
      return [...el.querySelectorAll('.erp-sidebar select, .erp-sidebar input')]
        .every(control => control.getBoundingClientRect().right <= right);
    })).toBe(true);
  }
  await page.screenshot({path: 'test-results/medium-container.png', fullPage: true});
});
