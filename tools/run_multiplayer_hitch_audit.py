"""Focused multiplayer audit probes. Uses isolated user data; never exports."""
from pathlib import Path
import json
import os
import subprocess

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/multiplayer_hitch_audit"

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    for key, folder in [("APPDATA", "roaming"), ("LOCALAPPDATA", "local")]:
        target = OUT / "userdata" / folder
        target.mkdir(parents=True, exist_ok=True)
        env[key] = str(target)
    env["MP_HITCH_AUDIT_OUTPUT"] = str(OUT / "visual_probe.json")
    editor = ROOT / "build/godot_editor/Godot_v4.6.3-stable_win64_console.exe"
    with (OUT / "visual_probe.log").open("w", encoding="utf-8") as log:
        result = subprocess.run(
            [str(editor), "--headless", "--path", str(ROOT), "--audio-driver", "Dummy",
             "--max-fps", "120", "--script", "res://tests/multiplayer_hitch_audit_probe.gd"],
            env=env, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=90,
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
    (OUT / "exit_status.json").write_text(json.dumps({"exit_code": result.returncode}))
    content = (OUT / "visual_probe.log").read_text(encoding="utf-8", errors="replace")
    if result.returncode or "SCRIPT ERROR:" in content or "MULTIPLAYER_HITCH_AUDIT_OK" not in content:
        raise RuntimeError(content[-8000:])
    subprocess.run(["node", str(ROOT / "tests/relay_protocol.test.cjs")],
                   cwd=ROOT, check=True, timeout=15,
                   creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    print((OUT / "visual_probe.json").read_text(encoding="utf-8"))

if __name__ == "__main__":
    main()
