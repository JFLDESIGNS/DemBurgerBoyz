from pathlib import Path
import subprocess,os,time,json,hashlib,sys
from deduplicate_embedded_pack import compact
root=Path(__file__).resolve().parents[1];stage=root/'build/compact_release';stage.mkdir(exist_ok=True)
editor=root/'build/godot_editor/Godot_v4.6.3-stable_win64_console.exe'
checks=[]
def env_for(name):
 env=os.environ.copy()
 for k in ['APPDATA','LOCALAPPDATA']:
  p=stage/'userdata'/name/k;p.mkdir(parents=True,exist_ok=True);env[k]=str(p)
 return env
def launch(name,args,env=None):
 log=(stage/(name+'.log')).open('w');p=subprocess.Popen([str(x) for x in args],cwd=stage,env=env or env_for(name),stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
 return p,log
def finish(name,h,marker=None,timeout=180):
 p,log=h
 try:
  began=time.monotonic()
  while p.poll() is None:
   current=(stage/(name+'.log')).read_text(errors='replace')
   if 'SCRIPT ERROR:' in current or time.monotonic()-began>timeout:
    subprocess.run(['taskkill','/PID',str(p.pid),'/T','/F'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,creationflags=subprocess.CREATE_NO_WINDOW);break
   time.sleep(.3)
  code=p.wait(timeout=10)
 except subprocess.TimeoutExpired:p.kill();p.wait();raise
 finally:log.close()
 text=(stage/(name+'.log')).read_text(errors='replace')
 assert code==0 and not any(x in text for x in ['SCRIPT ERROR:','Parse Error:','Failed loading resource','SHADER ERROR:','Assertion failed','Export failed']),(name,code,text[-5000:])
 assert not marker or marker in text,(name,text[-2000:])
 checks.append(name);print('CHECK_OK',name,flush=True)
def run(name,args,marker=None,timeout=180):finish(name,launch(name,args),marker,timeout)
def network(transport,pack=None):
 folder=stage/(transport+('_packed' if pack else '_source')+'_'+str(time.time_ns()));folder.mkdir()
 handles=[]
 for role in ['host','guest']:
  name=folder.name+'_'+role;env=env_for(role);env.update(MP_TEST_DIR=str(folder),MP_TEST_ROLE=role,MP_TEST_TRANSPORT=transport)
  args=[editor,'--headless','--path',stage if pack else root,'--audio-driver','Dummy','--max-fps','60']
  if pack:args+=['--main-pack',pack]
  args+=['--script',root/'tests/delivery_network_smoke.gd']
  handles.append((name,launch(name,args,env)))
 try:
  for name,h in handles:finish(name,h,'DELIVERY_NETWORK_OK',120)
 finally:
  for name,(p,l) in handles:
   if p.poll() is None:p.kill();p.wait()
   l.close()
if __name__=='__main__':
 relay_env=env_for('relay');relay_env['PORT']='18769';relay=launch('relay',['node',root/'mp_server/server.js'],relay_env)
 try:
  time.sleep(.6);assert relay[0].poll() is None
  network('lan');network('relay')
  run('dance',[editor,'--headless','--path',root,'--script',root/'tests/grill_dance_priority_smoke.gd'],'GRILL_DANCE_PRIORITY_OK',60)
  target=stage/'FoodTruckFlip.exe'
  run('export',[editor,'--headless','--path',root,'--export-release','Windows Desktop',target],timeout=500)
  report=compact(target)
  assert target.stat().st_size<430000000,'Size target missed'
  network('lan',target);network('relay',target)
  run('packed_full_load',[editor,'--main-pack',target,'--path',stage,'--script',root/'tests/full_loading_flow_smoke.gd','--audio-driver','Dummy'],'FULL_LOAD_OK',300)
  run('native_startup',[target,'--windowed','--resolution','1280x720','--audio-driver','Dummy','--max-fps','30','--quit-after','360'],timeout=90)
  installed=root/'build/FoodTruckFlip.exe';backup=stage/'FoodTruckFlip_before_compact.exe'
  if installed.exists() and not backup.exists():os.replace(installed,backup)
  os.replace(target,installed)
  report.update(checks=checks,sha256=hashlib.sha256(installed.read_bytes()).hexdigest(),original_bytes=557976072)
  (stage/'release_report.json').write_text(json.dumps(report,indent=2));print('INSTALLED',installed,'BYTES',installed.stat().st_size,flush=True)
 finally:
  relay[0].terminate();relay[0].wait();relay[1].close()
