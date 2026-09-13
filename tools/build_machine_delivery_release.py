from pathlib import Path
import subprocess,os,json,shutil,hashlib,sys
root=Path(__file__).resolve().parents[1];stage=root/'build/machine_delivery_release';stage.mkdir(exist_ok=True)
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
run('machine_delivery',[editor,'--headless','--path',root,'--script',root/'tests/machine_delivery_smoke.gd'],'MACHINE_DELIVERY_OK',70)
run('mail_truck',[editor,'--headless','--path',root,'--script',root/'tests/mail_delivery_truck_smoke.gd'],'MAIL_DELIVERY_TRUCK_OK',60)
run('export',[editor,'--headless','--path',root,'--export-release','Windows Desktop',target],timeout=500)
run('packaged_machine',[editor,'--headless','--main-pack',target,'--script',root/'tests/machine_delivery_smoke.gd'],'MACHINE_DELIVERY_OK',70)
run('native_startup',[target,'--windowed','--resolution','1280x720','--audio-driver','Dummy','--max-fps','30','--quit-after','360'],timeout=80)
installed=root/'build/FoodTruckFlip.exe';backup=stage/'FoodTruckFlip_before_machine_delivery.exe'
if installed.exists() and not backup.exists(): os.replace(installed,backup)
os.replace(target,installed)
report={'executable':str(installed),'sha256':hashlib.sha256(installed.read_bytes()).hexdigest(),'checks':checks,'machine_deliveries':['fryer','soda','icecream','grill_roomba'],'courier_scale_multiplier':1.25,'arrival_audio':['car_pass_by','double_beep'],'truck_fill_light':True}
(stage/'release_report.json').write_text(json.dumps(report,indent=2));print('INSTALLED',installed,flush=True)
