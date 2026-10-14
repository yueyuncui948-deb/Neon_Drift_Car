"""Browser regression for persisted settings, mixed inputs and failed-download retry."""
import asyncio
from pathlib import Path
import sys
from playwright.async_api import async_playwright

ROOT=Path(__file__).resolve().parents[1]
URL=sys.argv[1] if len(sys.argv)>1 else 'http://127.0.0.1:8060'

async def ready(page):
    await page.wait_for_function('window.neonQA && window.neonQA.state===0',timeout=90000)

async def main():
    async with async_playwright() as p:
        browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
        context=await browser.new_context(viewport={'width':576,'height':360})
        page=await context.new_page()
        errors=[]
        page.on('pageerror',lambda e:errors.append(str(e)))
        page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
        await page.goto(URL+'/?qa=1')
        await ready(page)
        assert await page.evaluate('window.neonQA.quality_low && !window.neonQA.muted')
        await page.mouse.click(376,20)
        await page.wait_for_function('!window.neonQA.quality_low')
        await page.mouse.click(480,20)
        await page.wait_for_function('window.neonQA.muted')
        assert await page.evaluate("JSON.parse(localStorage.getItem('neon-drift.settings.v1')).muted")
        await page.reload()
        await ready(page)
        assert await page.evaluate('!window.neonQA.quality_low && window.neonQA.muted'), await page.evaluate('({low:neonQA.quality_low,muted:neonQA.muted})')
        print('PASS: quality and mute persist across browser reload',flush=True)
        await page.mouse.click(376,20)
        await page.wait_for_function('window.neonQA.quality_low')
        await page.keyboard.press('Enter')
        await page.wait_for_function('window.neonQA.state===2',timeout=30000)
        await page.keyboard.down('w')
        await page.mouse.click(431,20)
        await page.wait_for_function('window.neonQA.touch && window.neonQA.speed>25',timeout=15000)
        await page.keyboard.up('w')
        before=await page.evaluate('window.neonQA.time')
        await page.mouse.click(44,118)
        await page.wait_for_function('(t)=>window.neonQA.time>=t+5',arg=before)
        print('PASS: touch toggle preserves held keyboard input; on-screen recovery works',flush=True)
        assert not errors,errors
        await context.close()
        # Intentionally interrupt the engine download. These network errors are expected.
        context=await browser.new_context(viewport={'width':864,'height':540})
        page=await context.new_page()
        await page.route('**/*.wasm',lambda route:route.abort('failed'))
        await page.goto(URL+'/?qa=1')
        await page.locator('#retry').wait_for(state='visible',timeout=90000)
        assert '載入未完成' in await page.locator('#loading-title').inner_text()
        await page.screenshot(path=str(ROOT/'docs/neon-web-retry.png'))
        await page.unroute('**/*.wasm')
        await page.locator('#retry').click()
        await ready(page)
        print('PASS: failed download shows Chinese error and retry loads the game',flush=True)
        await browser.close()
        print('OPTIMIZATION WEB TESTS: PASS',flush=True)

asyncio.run(main())
