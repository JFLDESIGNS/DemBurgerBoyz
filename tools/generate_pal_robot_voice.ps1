param([string]$ProjectRoot = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$robotStage = Join-Path $ProjectRoot 'build/pal_robot_release'
$robotOutput = Join-Path $ProjectRoot 'sounds/branding/pal_robot_intro.ogg'
New-Item -ItemType Directory -Force $robotStage,(Split-Path $robotOutput) | Out-Null
Add-Type -AssemblyName System.Speech
$robotVoice = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
 $robotVoice.SelectVoice('Microsoft David Desktop')
 $robotVoice.Rate = -1
 foreach ($phrase in @(@('sorry','I am sorry I.'),@('fine','Okay, fine.'))) {
  $robotVoice.SetOutputToWaveFile((Join-Path $robotStage ($phrase[0]+'.wav')))
  $robotVoice.Speak($phrase[1])
  $robotVoice.SetOutputToNull()
 }
} finally { $robotVoice.Dispose() }
$robotFilter = '[0:a]silenceremove=start_periods=1:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse,asetrate=22050*0.86,aresample=44100,atempo=1.08,highpass=f=100,lowpass=f=4800,tremolo=f=38:d=0.16,apad,atrim=duration=2.75[a];[1:a]silenceremove=start_periods=1:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse,asetrate=22050*0.86,aresample=44100,atempo=1.08,highpass=f=100,lowpass=f=4800,tremolo=f=38:d=0.16[b];[a][b]concat=n=2:v=0:a=1,alimiter=limit=0.85,volume=-1dB,afade=t=out:st=4.3:d=0.15,apad,atrim=duration=4.5[out]'
& ffmpeg -y -hide_banner -loglevel error -i (Join-Path $robotStage 'sorry.wav') -i (Join-Path $robotStage 'fine.wav') -filter_complex $robotFilter -map '[out]' -ac 1 -c:a libvorbis -q:a 5 $robotOutput
if ($LASTEXITCODE -ne 0) { throw 'Voice encoding failed' }
