from pathlib import Path
import subprocess,os,json,shutil,hashlib,sys
root=Path(__file__).resolve().parents[1];stage=root/'build/fur_dance_release';stage.mkdir(exist_ok=True)
editor=root/'build/godot_editor/Godot_v4.6.3-stable_win64_console.exe'
env=os.environ.copy()
for key,child in [('APPDATA','roaming'),('LOCALAPPDATA','local')]:
 p=stage/'userdata'/child;p.mkdir(parents=True,exist_ok=True);env[key]=str(p)
checks=[]
def run(name,args,marker=None,timeout=300):
 with (stage/(name+'.log')).open('w') as log:
  result=subprocess.run([str(x) for x in args],cwd=stage,env=env,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW,timeout=timeout)
 text=(stage/(name+'.log')).read_text(errors='replace')
 assert result.returncode==0 and not any(x in text for x in ['SCRIPT ERROR:','Parse Error:','SHADER ERROR:','Shader compilation failed','Export failed','Assertion failed']),(name,result.returncode,text[-3500:])
 assert not marker or marker in text,(name,text[-1500:])
 checks.append(name);print('CHECK_OK',name,flush=True)
target=stage/'FoodTruckFlip.exe'
if '--finish-only' not in sys.argv:
 run('dance_priority',[editor,'--headless','--path',root,'--script',root/'tests/grill_dance_priority_smoke.gd'],'GRILL_DANCE_PRIORITY_OK',40)
 run('cat_visual',[editor,'--path',root,'--script',root/'tests/shipping_cat_smoke.gd','--rendering-method','forward_plus','--audio-driver','Dummy'],'SHIPPING_CAT_SMOKE_OK',80)
 run('polish_visual',[editor,'--path',root,'--script',root/'tests/payment_dance_polish_smoke.gd','--rendering-method','gl_compatibility','--audio-driver','Dummy'],'PAYMENT_DANCE_POLISH_OK',80)
 run('export',[editor,'--headless','--path',root,'--export-release','Windows Desktop',target],timeout=500)
else:
 for file in ['scripts/game.gd','scripts/customer.gd','scripts/customer_life.gd']:
  assert (root/file).stat().st_mtime<=target.stat().st_mtime,file
 checks.extend(['dance_priority','polish_visual','export'])
run('packaged_polish',[editor,'--headless','--main-pack',target,'--script',root/'tests/payment_dance_polish_smoke.gd'],'PAYMENT_DANCE_POLISH_OK',80)
run('native_startup',[target,'--windowed','--resolution','1280x720','--audio-driver','Dummy','--max-fps','30','--quit-after','240'],timeout=100)
installed=root/'build/FoodTruckFlip.exe';backup=stage/'FoodTruckFlip_before_payment_polish.exe'
if installed.exists() and not backup.exists(): os.replace(installed,backup)
os.replace(target,installed)
report={'executable':str(installed),'sha256':hashlib.sha256(installed.read_bytes()).hexdigest(),'checks':checks,'sale_bill_brightness':0.8,'fryer_hint_offset':[-50,20],'tap_dances':['HipHop','WaveHipHop','Gangnam'],'fur':'anisotropic procedural strands and clump mask','eye_roughness':0.58}
(stage/'release_report.json').write_text(json.dumps(report,indent=2));print('INSTALLED',installed,flush=True)
