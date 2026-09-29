# Baron Brat boss challenge

Start a normal shift, then press `.` (period). The challenge starts once another scripted event or burger handoff has finished. Pressing the key again during the challenge does not reset it.

The truck/camera rumbles before Baron Brat emerges outside the service window. Build and serve through the existing order ticket and Serve controls. The boss requests 50 distinct burger recipes, one at a time. A perfect recipe advances the count; wrong burgers and 17-second timeouts lose the order and cause a truck-directed hook followed by a ground smash. Each replacement is a different recipe; the deck reshuffles for every challenge. Ten total losses end the challenge with Baron Brat winning. Camera shake and impact sound are timed to both strikes.

Perfect counts are cumulative. At 10 and 30 he slumps and revives, then continues ordering. At 50 he slumps in defeat and the normal queue resumes. Regular customers and the shift timer pause during the encounter; normal burger payments still apply. Each order has a visible 17-second countdown. The clock pauses during accepted burger handoffs, reactions and occasional ambient ground smashes. Ambient smashes preserve the current recipe and remaining time. Win by serving 50 perfect burgers before losing 10 orders.

`Concrete Crack Boss.mp3` loops for the entire encounter, including slump/recovery moments. The truck radio and combat theme yield to the boss song, then normal audio is restored on completion or reset.

He starts farther away at Z = 6.3. Hidden > World > HOTDOG BOSS has live X, Y, Z and uniform Scale sliders, saved in user://hotdog_boss.cfg. Placement is shared with co-op clients.

His entrance uses bossahhhhhentrance.wav and a 1.8-second concrete break with a 0.35-second fade. Ground contact layers the impact thud with randomly selected smash1.wav or smash2.wav. eatboss.wav plays once at the eating callback for each burger, replacing the regular bite effect. Occasional laughboss.wav plays between actions, alongside the existing lower-pitched wawawa chatter. Audio sources are recorded in sounds/boss/SOURCES.md.

The host owns recipes, countdown, scoring and phase transitions in co-op. Clients receive boss state and animation updates and use the existing host-authoritative serving requests.

Implementation: `scripts/hotdog_challenge.gd`, `scripts/hotdog_boss_customer.gd`, integration points in `scripts/game.gd`. Model: `assets/characters/baron_brat_bg/baron_brat_bg.glb`. Song: `sounds/boss/concrete_crack_boss.mp3`.

Validation: encounter smoke covers all 50 successful orders, timeout/wrong-order replacement, 10-loss defeat, paused countdown during flight and ambient smashes, hidden placement controls, duplicate completion, camera impacts, both milestones, recovery, victory, repeat triggers and cleanup. Replica test covers shared progress, animation transitions, late-join victory and ticket retention. Full kitchen test verifies model animation, actual order ticket, visible mouth position and paused shift clock. Live two-machine co-op was not exercised.

The order ticket shows the remaining seconds (red at five seconds), with PAUSED during boss reactions or handoff. The supplied voice clips play at -1 dB, smash clips at -2/-3 dB, and the short concrete at -3 dB. Boss voices, including the entrance, eating and laughter, leave the music volume steady. Ground impacts briefly duck the song by 12 dB, then it returns smoothly. All boss effects respect the SFX bus. Host-triggered sound events replicate the same smash choice to guests.

During the encounter both shadow-catcher planes (including their debug outlines) are hidden through their shared root. Ordinary sidewalk spawning, movement, clicks and replicated movement updates pause. The two existing sidewalk characters enter from opposite sides and idle facing the boss; no extra crowd is instantiated. Their original appearance, pose, visibility, click state and walking/spawn timers are restored on victory, defeat or cancellation. Spectator identities and arrival time are synchronized with boss state.

The rubber material uses full roughness, zero specular and no received shadows to remove sparkling shadow/specular noise on the thin arms. Other character materials retain their lighting. Ticket timer styling is only changed when its displayed value or color changes.

Boss voices now play at 78% pitch through light overdrive; laughs use 70% pitch and a subtle short reverb for fullness. Playback timing accounts for the longer pitched duration. Ground impacts replace the truck knock with a new synthesized cartoon slam at contact, layered under smash1/smash2 and a 12 dB music dip.
