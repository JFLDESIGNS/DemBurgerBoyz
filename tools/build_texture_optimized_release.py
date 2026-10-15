"""Export BurgerPals with verified lossless deduplication and texture checks."""
from pathlib import Path
import json, os, subprocess, sys, time
from deduplicate_embedded_pack import compact
root=Path(__file__).resolve().parents[1]
stage=root/'build'/'texture_optimized_release'
stage.mkdir(exist_ok=True)
editor=root/'build/godot_editor/Godot_v4.6.3-stable_win64_console.exe'
target=stage/'BurgerPals.exe'
installed=root/'build/BurgerPals.exe'
before=installed.stat().st_size if installed.exists() else 0

def run(name,args,timeout=300):
 with (stage/(name+'.log')).open('w',encoding='utf-8') as log:
  result=subprocess.run([str(editor),*map(str,args)],cwd=root,stdout=log,stderr=subprocess.STDOUT,timeout=timeout,creationflags=subprocess.CREATE_NO_WINDOW)
 text=(stage/(name+'.log')).read_text(encoding='utf-8',errors='replace')
 assert result.returncode==0 and not any(x in text for x in ['SCRIPT ERROR:','Failed loading resource','Export failed','SHADER ERROR:']), (name,text[-4000:])
 print(name,'OK',flush=True)

run('export',['--headless','--path',root,'--export-release','Windows Desktop',target],600)
report=compact(target)
run('packed_textures',['--headless','--main-pack',target,'--script',root/'tests/texture_size_smoke.gd','--',root/'tools/texture_size_limits.json'])
run('packed_mobile',['--headless','--main-pack',target,'--script',root/'tests/mobile_packing_smoke.gd'])
backup=stage/('BurgerPals_before_'+str(time.time_ns())+'.exe')
if installed.exists(): os.replace(installed,backup)
try: os.replace(target,installed)
except BaseException:
 if backup.exists(): os.replace(backup,installed)
 raise
report.update(original_exe_bytes=before,final_exe_bytes=installed.stat().st_size,total_saved_bytes=before-installed.stat().st_size,backup=str(backup))
(stage/'report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2),flush=True)
