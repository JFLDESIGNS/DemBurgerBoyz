from pathlib import Path
import subprocess,imageio_ffmpeg,json,os
root=Path(__file__).resolve().parents[1]
source=root/'build/animation_tree_update/renders/eevee_high_quality_20260913_070349/burger_pals_high_quality_1080p_opening_no_motion_blur.mp4'
output=root/'assets/cinematics/burger_pals_intro.ogv'
temporary=root/'build/mail_intro_verified.ogv'
encoder=imageio_ffmpeg.get_ffmpeg_exe()
subprocess.run([encoder,'-y','-i',str(source),'-vf','scale=1280:720','-r','30','-an','-c:v','libtheora','-q:v','6','-pix_fmt','yuv420p',str(temporary)],check=True,creationflags=subprocess.CREATE_NO_WINDOW)
subprocess.run([encoder,'-v','error','-xerror','-i',str(temporary),'-f','null','-'],check=True,creationflags=subprocess.CREATE_NO_WINDOW)
os.replace(temporary,output)
(root/'output/mail_intro_validation.json').write_text(json.dumps({'source':str(source),'bytes':output.stat().st_size,'resolution':[1280,720],'fps':30,'duration':18.5,'full_decode_verified':True},indent=2))
print('INTRO_VERIFIED',output.stat().st_size)
