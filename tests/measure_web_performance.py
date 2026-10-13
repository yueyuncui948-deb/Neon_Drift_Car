"""Compare real browser frame pacing, optionally against a separately served baseline.
Example: python3 tests/measure_web_performance.py --baseline http://127.0.0.1:8061
This is a software-renderer observation, not a hardware-independent FPS promise.
"""
import argparse,asyncio,json,statistics
from pathlib import Path
from playwright.async_api import async_playwright

async def main():
 parser=argparse.ArgumentParser()
 parser.add_argument('--url',default='http://127.0.0.1:8060')
 parser.add_argument('--baseline')
 parser.add_argument('--output',default='/tmp/neon-performance.json')
 args=parser.parse_args()
 results=[]
 async with async_playwright() as p:
  browser=await p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  for name,url in ([('baseline',args.baseline)] if args.baseline else [])+[('power_saving',args.url),('standard',args.url)]:
   context=await browser.new_context(viewport={'width':864,'height':540})
   page=await context.new_page()
   errors=[]
   page.on('pageerror',lambda e:errors.append(str(e)))
   page.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
   await page.goto(url+'/?qa=1')
   await page.wait_for_function('window.neonQA && window.neonQA.state===0',timeout=90000)
   if name=='standard':
    await page.mouse.click(565,31)
    await page.wait_for_function('window.neonQA.quality_low===false')
   if name=='power_saving':
    assert await page.evaluate('window.neonQA.quality_low')
   intervals=await page.evaluate('''()=>new Promise(resolve=>{
    let previous=0,frames=0,samples=[];
    function frame(now){
     if(frames>=30 && previous) samples.push(now-previous);
     previous=now;frames++;
     if(samples.length>=90)resolve(samples);else requestAnimationFrame(frame);
    }
    requestAnimationFrame(frame);
   })''')
   qa=await page.evaluate('window.neonQA')
   result={'mode':name,'median_frame_ms':round(statistics.median(intervals),2),'mean_frame_ms':round(statistics.mean(intervals),2),'frames':len(intervals),'draw_calls':qa.get('draw_calls'),'hud_redraws':qa.get('hud_redraws')}
   assert not errors,errors
   results.append(result)
   print(json.dumps(result),flush=True)
   await context.close()
  await browser.close()
 Path(args.output).write_text(json.dumps({'renderer':'Chromium SwiftShader','viewport':[864,540],'scene':'idle main menu','results':results},indent=2)+'\n')
asyncio.run(main())
