"""Real Chromium/WebGL test. Install Playwright; serve docs/play over HTTP first.
Only keyboard/mouse/touch inputs drive the game. ?qa=1 exposes read-only telemetry.
Usage: python3 tests/test_web.py [http://127.0.0.1:8060]
"""
import asyncio
import json
import math
from pathlib import Path
import sys
import time
from playwright.async_api import async_playwright

ROOT = Path(__file__).resolve().parents[1]
URL = sys.argv[1] if len(sys.argv)>1 else 'http://127.0.0.1:8060'

async def main():
 async with async_playwright() as p:
  browser = await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  context = await browser.new_context(viewport={'width':576,'height':360})
  page = await context.new_page()
  errors=[]
  page.on('pageerror',lambda e:errors.append(str(e)))
  page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
  await page.goto(URL+'/?qa=1')
  await page.wait_for_function('window.neonQA && window.neonQA.state===0',timeout=90000)
  await page.screenshot(path=str(ROOT/'docs/neon-web-menu.png'))
  print('PASS: WebGL startup and Chinese menu',flush=True)
  await page.keyboard.press('Enter')
  await page.wait_for_function('window.neonQA.state===2',timeout=30000)
  await page.keyboard.down('w')
  await page.keyboard.down('Shift')
  await page.wait_for_function('window.neonQA.speed>55 && window.neonQA.boost<90',timeout=20000)
  await page.keyboard.up('Shift')
  await page.keyboard.down('d')
  await page.keyboard.down('Space')
  await page.wait_for_function('window.neonQA.drift>2',timeout=15000)
  for key in ['w','d','Space']:
   await page.keyboard.up(key)
  print('PASS: keyboard acceleration, boost and drift scoring',flush=True)
  await page.keyboard.press('p')
  await page.wait_for_function('window.neonQA.paused')
  paused=await page.evaluate('window.neonQA.time')
  await page.wait_for_timeout(400)
  assert await page.evaluate('window.neonQA.time')==paused
  await page.screenshot(path=str(ROOT/'docs/neon-web-paused.png'))
  await page.keyboard.press('p')
  await page.wait_for_function('!window.neonQA.paused')
  before=await page.evaluate('window.neonQA.time')
  await page.keyboard.press('r')
  await page.wait_for_function('(t)=>window.neonQA.time>=t+5',arg=before)
  print('PASS: pause freezes time; recovery applies penalty',flush=True)
  # Follow the physical track using keys only; no teleport, gate or timer writes.
  held=set()
  previous_lap=0
  stuck_since=None
  recoveries=0
  last_log=0
  deadline=time.monotonic()+600
  while time.monotonic()<deadline:
   d=await page.evaluate('window.neonQA')
   if d['state']==3:
    break
   if d['speed']<1:
    stuck_since=stuck_since or time.monotonic()
    if time.monotonic()-stuck_since>3:
     assert recoveries<8, 'Driver repeatedly stuck'
     await page.keyboard.press('r')
     recoveries+=1
     stuck_since=None
     print('RECOVER: using normal R control',flush=True)
   else:
    stuck_since=None
   if d['paused']:
    raise AssertionError('Unexpected pause during autonomous drive')
   if time.monotonic()-last_log>5:
    print('STATUS: '+json.dumps({k:v for k,v in d.items() if k!='path'}),flush=True)
    last_log=time.monotonic()
   points=d['path']
   nearest=min(range(len(points)),key=lambda i:(points[i][0]-d['x'])**2+(points[i][1]-d['z'])**2)
   target=points[(nearest+5)%len(points)]
   desired=math.atan2(target[0]-d['x'],target[1]-d['z'])
   error=(desired-d['yaw']+math.pi)%(2*math.pi)-math.pi
   keys=set()
   if error>.12: keys.add('a')
   elif error<-.12: keys.add('d')
   if d['speed']<24: keys.add('w')
   elif d['speed']>28: keys.add('s')
   for key in held-keys: await page.keyboard.up(key)
   for key in keys-held: await page.keyboard.down(key)
   held=keys
   if d['lap']!=previous_lap:
    print(f"DRIVING: lap {d['lap']}, time {d['time']:.2f}, next gate {d['gate']}",flush=True)
    previous_lap=d['lap']
    if d['lap']==2:
     await page.screenshot(path=str(ROOT/'docs/neon-web-racing.png'))
   await page.wait_for_timeout(65)
  else:
   raise AssertionError('Three-lap driving timed out: '+json.dumps({k:v for k,v in d.items() if k!='path'}))
  for key in held: await page.keyboard.up(key)
  assert len(d['lap_times'])==3 and d['best']>0
  await page.screenshot(path=str(ROOT/'docs/neon-web-finish.png'))
  print('PASS: physically drove all three laps; finish results '+json.dumps(d['lap_times']),flush=True)
  record=d['best']
  await page.reload()
  await page.wait_for_function('window.neonQA && window.neonQA.state===0',timeout=90000)
  assert abs((await page.evaluate('window.neonQA.best'))-record)<.01
  print('PASS: browser record survives page reload',flush=True)
  await context.close()
  # Fresh touch-capable context; exercise two simultaneous fingers via CDP.
  mobile=await browser.new_context(viewport={'width':576,'height':360},has_touch=True,is_mobile=True)
  page=await mobile.new_page()
  page.on('pageerror',lambda e:errors.append(str(e)))
  page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
  await page.goto(URL+'/?qa=1')
  await page.wait_for_function('window.neonQA && window.neonQA.state===0',timeout=90000)
  assert await page.evaluate('window.neonQA.touch')
  await page.touchscreen.tap(96,260)
  await page.wait_for_function('window.neonQA.state===2',timeout=30000)
  cdp=await mobile.new_cdp_session(page)
  initial=await page.evaluate('window.neonQA.yaw')
  await cdp.send('Input.dispatchTouchEvent',{'type':'touchStart','touchPoints':[{'x':526,'y':300,'id':1},{'x':88,'y':288,'id':2}]})
  await page.wait_for_function('(yaw)=>window.neonQA.speed>15 && Math.abs(window.neonQA.yaw-yaw)>.1',arg=initial,timeout=25000)
  await page.screenshot(path=str(ROOT/'docs/neon-web-touch.png'))
  await cdp.send('Input.dispatchTouchEvent',{'type':'touchEnd','touchPoints':[]})
  print('PASS: simultaneous touch acceleration and steering',flush=True)
  assert not errors,errors
  print('WEB TESTS: PASS; no browser script/runtime errors',flush=True)
  await browser.close()

asyncio.run(main())
