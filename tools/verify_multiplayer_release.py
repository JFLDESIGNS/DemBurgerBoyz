"""Release checks: source | network | export | packaged. Uses isolated save folders.
Packaged gameplay runs with Forward+; the custom shipping template disables script overrides.
"""
from pathlib import Path
import subprocess,os,time,json,sys
ROOT=Path(__file__).resolve().parents[1]
STAGE=ROOT/'build/multiplayer_release'
STAGE.mkdir(parents=True,exist_ok=True)
EDITOR=ROOT/'build/godot_editor/Godot_v4.6.3-stable_win64_console.exe'
checks=[]
def env_for(name):
 env=os.environ.copy(); base=STAGE/'userdata'/(name+'_'+str(time.time_ns()))
 for label in ['roaming','local']:(base/label).mkdir(parents=True,exist_ok=True)
 env['APPDATA']=str(base/'roaming');env['LOCALAPPDATA']=str(base/'local')
 env['BURGER_PROBE_OUTPUT']=str(STAGE)
 return env
def launch(name,args,env=None):
 log=(STAGE/(name+'.log')).open('w',encoding='utf-8')
 p=subprocess.Popen([str(x) for x in args],cwd=STAGE,env=env or env_for(name),stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
 return p,log,time.monotonic()
def finish(name,handle,marker=None,timeout=240):
 p,log,start=handle
 try:
  while p.poll() is None:
   if time.monotonic()-start > timeout: raise subprocess.TimeoutExpired(p.args,timeout)
   current=(STAGE/(name+'.log')).read_text(encoding='utf-8',errors='replace')
   if 'SCRIPT ERROR:' in current:
    p.kill();break
   time.sleep(0.5)
  code=p.wait()
 except subprocess.TimeoutExpired:
  p.kill();p.wait();raise
 finally:log.close()
 content=(STAGE/(name+'.log')).read_text(encoding='utf-8',errors='replace')
 errors=[line for line in content.splitlines() if any(x in line for x in ['SCRIPT ERROR:','Parse Error:','Failed loading resource','Export failed'])]
 known_headless_shutdown = code == 3221225477 and "--headless" in [str(x) for x in p.args] and marker and marker in content and not errors and "ERROR:" not in content.split(marker)[0]
 if (code and not known_headless_shutdown) or errors or (marker and marker not in content):
  print(content[-7000:],flush=True);raise RuntimeError((name,code,errors))
 record=dict(check=name,seconds=round(time.monotonic()-start,2),exit_code=code,known_headless_shutdown=bool(known_headless_shutdown))
 checks.append(record);print(json.dumps(record),flush=True)
def test(name,marker,pack=None):
 args=[EDITOR,'--headless','--path',STAGE if pack else ROOT,'--audio-driver','Dummy','--max-fps','120']
 if pack:args+=['--main-pack',pack]
 args+=['--script',ROOT/'tests'/(name+'.gd')]
 finish(name,launch(name,args),marker)
def multiplayer(transport,pack=None,rendered=False):
 folder=STAGE/('mp_'+transport+('_packaged' if pack else ''))
 folder.mkdir(exist_ok=True)
 for name in ['connection','guest_connected','fixture','requested','host_result','guest_passed']:
  (folder/name).unlink(missing_ok=True)
 handles=[]
 for role in ['host','guest']:
  name=('rendered_' if rendered else '')+'multiplayer_'+transport+'_'+role
  env=env_for(name);env['MP_TEST_DIR']=str(folder);env['MP_TEST_ROLE']=role;env['MP_TEST_TRANSPORT']=transport
  args=[EDITOR,'--audio-driver','Dummy','--max-fps','60' if rendered else '120','--path',STAGE if pack else ROOT]
  # One rendered host and one headless guest keep local VRAM use bounded.
  args+=['--windowed','--resolution','1280x720'] if rendered and role == 'host' else ['--headless']
  if pack:args+=['--main-pack',pack]
  args+=['--script',ROOT/'tests/multiplayer_release_smoke.gd']
  handles.append((name,launch(name,args,env)))
 try:
  for name,handle in handles:finish(name,handle,'MULTIPLAYER_RELEASE_SMOKE_OK')
 finally:
  for _,(p,log,_) in handles:
   if p.poll() is None:p.kill();p.wait()
   log.close()
if __name__=='__main__':
 relay=None
 try:
  mode=sys.argv[1] if len(sys.argv)>1 else 'source'
  if mode in ['source','network','packaged']:
   env=os.environ.copy();env['PORT']='18769'
   relay=launch('local_relay',['node',ROOT/'mp_server/server.js'],env)
   time.sleep(0.6)
   assert relay[0].poll() is None,'Local relay failed to start'
  if mode=='source':
   for name,marker in [('multiplayer_state_codec_smoke','MULTIPLAYER_STATE_CODEC_OK'),('performance_optimization_smoke','PERFORMANCE_OPTIMIZATION_SMOKE_OK'),('release_defaults_smoke','RELEASE_DEFAULTS_SMOKE_OK'),('burger_completion_flip_smoke','BURGER_COMPLETION_FLIP_SMOKE_OK'),('multiplayer_recent_features_smoke','MULTIPLAYER_RECENT_FEATURES_SMOKE_OK'),('serve_completion_cache_smoke','SERVE_COMPLETION_CACHE_OK'),('customer_leave_fade_clothes_smoke','CUSTOMER_LEAVE_FADE_CLOTHES_SMOKE_OK'),('soda_scrape_traffic_smoke','SODA_SCRAPE_TRAFFIC_OK'),('fitted_wardrobe_smoke','FITTED_WARDROBE_SMOKE_OK'),('fitted_footwear_smoke','FITTED_FOOTWEAR_SMOKE_OK'),('relay_performance_smoke','RELAY_PERFORMANCE_SMOKE_OK')]:test(name,marker)
  if mode in ['source','network']:multiplayer('lan');multiplayer('relay')
  if mode=='export':finish('export',launch('export',[EDITOR,'--headless','--path',ROOT,'--export-release','Windows Desktop',STAGE/'FoodTruckFlip.exe'],os.environ.copy()),timeout=900)
  if mode=='packaged':
   target=STAGE/'FoodTruckFlip.exe'
   test('release_defaults_smoke','RELEASE_DEFAULTS_SMOKE_OK',target)
   multiplayer('lan',target,rendered=True)
   multiplayer('relay',target,rendered=True)
   finish('native_startup',launch('native_startup',[target,'--audio-driver','Dummy','--max-fps','30','--windowed','--resolution','1280x720','--quit-after','150']))
  (STAGE/(mode+'_checks.json')).write_text(json.dumps(checks,indent=2))
 finally:
  if relay:
   relay[0].terminate();relay[0].wait();relay[1].close()
