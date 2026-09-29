# Baron Brat boss challenge

Start a normal shift, then press `.` (period). The challenge starts once another scripted event or burger handoff has finished. Pressing the key again during the challenge does not reset it.

The truck/camera rumbles before Baron Brat emerges outside the service window. Build and serve through the existing order ticket and Serve controls. The boss requests 50 distinct burger recipes, one at a time. A perfect recipe advances the count; wrong burgers and 17-second timeouts lose the order and cause a truck-directed hook followed by a ground smash. Each replacement is a different recipe; the deck reshuffles for every challenge. Ten total losses end the challenge with Baron Brat winning. Camera shake and impact sound are timed to both strikes.

Perfect counts are cumulative. At 10 and 30 he slumps and revives, then continues ordering. At 50 he slumps in defeat and the normal queue resumes. Regular customers and the shift timer pause during the encounter; normal burger payments still apply. Each order has a visible 17-second countdown. The clock pauses during accepted burger handoffs, reactions and occasional ambient ground smashes. Ambient smashes preserve the current recipe and remaining time. Win by serving 50 perfect burgers before losing 10 orders.

`Concrete Crack Boss.mp3` loops for the entire encounter, including slump/recovery moments. The truck radio and combat theme yield to the boss song, then normal audio is restored on completion or reset.

He starts farther away at Z = 6.3. Hidden > World > HOTDOG BOSS has live X, Y, Z and uniform Scale sliders, saved in user://hotdog_boss.cfg. Placement is shared with co-op clients.

His entrance uses CC0 concrete breaking and a retro monster yell. Occasional wawawa uses the existing voice at 65% pitch. Audio sources are recorded in sounds/boss/SOURCES.md.

The host owns recipes, countdown, scoring and phase transitions in co-op. Clients receive boss state and animation updates and use the existing host-authoritative serving requests.

Implementation: `scripts/hotdog_challenge.gd`, `scripts/hotdog_boss_customer.gd`, integration points in `scripts/game.gd`. Model: `assets/characters/baron_brat_bg/baron_brat_bg.glb`. Song: `sounds/boss/concrete_crack_boss.mp3`.

Validation: encounter smoke covers all 50 successful orders, timeout/wrong-order replacement, 10-loss defeat, paused countdown during flight and ambient smashes, hidden placement controls, duplicate completion, camera impacts, both milestones, recovery, victory, repeat triggers and cleanup. Replica test covers shared progress, animation transitions, late-join victory and ticket retention. Full kitchen test verifies model animation, actual order ticket, visible mouth position and paused shift clock. Live two-machine co-op was not exercised.

The order ticket shows the remaining seconds (red at five seconds), with PAUSED during boss reactions or handoff. Entrance concrete is +5 dB and the roar +10 dB louder than the initial mix; the song ducks by 12 dB for 3.5 seconds and then returns smoothly.
