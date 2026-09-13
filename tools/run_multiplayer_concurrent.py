"""Active process/physics multiplayer ownership and frame-time regression."""
import sys,os,time,json
from pathlib import Path
from verify_multiplayer_release import ROOT,STAGE,EDITOR,launch,finish,env_for
count=int(sys.argv[1]) if len(sys.argv)>1 else 2
transport=sys.argv[2] if len(sys.argv)>2 else 'lan'
folder=STAGE/f'concurrent_{transport}_{count}_{int(time.time())}'
folder.mkdir(parents=True)
relay=None;proxy=None;handles=[]
impaired="impaired" in sys.argv
try:
 if transport=='relay':
  env=os.environ.copy();env['PORT']='18769';env['RELAY_TEST_LOG']='1'
  relay=launch('concurrent_relay',['node',ROOT/'mp_server/server.js'],env);time.sleep(.6)
  if impaired:
   proxy=launch('concurrent_proxy',['node',ROOT/'tools/multiplayer_network_proxy.cjs']);time.sleep(.3)
 for role in range(count):
  name=f'concurrent_{transport}_{count}_{role}'
  env=env_for(name);env.update(MP_TEST_DIR=str(folder),MP_TEST_ROLE_INDEX=str(role),MP_TEST_PEERS=str(count),MP_TEST_TRANSPORT=transport,MP_RELAY_URL="ws://127.0.0.1:18770" if impaired else "ws://127.0.0.1:18769")
  handles.append((name,launch(name,[EDITOR,'--headless','--path',ROOT,'--audio-driver','Dummy','--max-fps','60','--script',ROOT/'tests/multiplayer_concurrent_smoke.gd'],env)))
 for name,handle in handles:finish(name,handle,'MULTIPLAYER_CONCURRENT_OK',timeout=300)
 print('RESULTS',folder,flush=True)
finally:
 for name,(proc,log,start) in handles:
  if proc.poll() is None:proc.kill();proc.wait()
  log.close()
 if proxy:
  proxy[0].terminate();proxy[0].wait();proxy[1].close()
 if relay:
  relay[0].terminate();relay[0].wait();relay[1].close()
