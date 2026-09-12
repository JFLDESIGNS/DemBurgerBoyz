# Performance changes — September 11, 2026

No executable or export package was built. Existing unrelated workspace changes were preserved.

## Implemented

| Area | Change | Tradeoff / behavior |
| --- | --- | --- |
| Patty cooking | Cache the expensive seeded sear noise; skip identical cooking and cheese-melt states. | Original cooking texture pixels are checked against the previous algorithm for raw, flipped, cooked, and different-seed cases. Cooking simulation is unchanged. |
| Oil fire | Bake 160 original procedural mask frames and reuse emission textures; rebuild emission paths when oil anchors change. | About 0.55 MiB of compressed assets; mask phase now follows the fire lifetime. The eight-second fire remains animated. |
| Audio | Replace six invariant sample generators with twelve-second looping WAV resources: burner hiss, spray, shaker, soda, ice, soft serve. | About 2.52 MiB on disk. Pitch, volume, start/stop controls remain active. Five adaptive generators remain procedural and query free buffer space once per refill. |
| Food art | Prepare twelve ingredient textures and crop/aspect metadata before gameplay; bound generated patty/cheese variants to 96 entries. | About 3.66 MiB on disk. A newer source PNG falls back to the original processing path until rebaked. |
| Cups and bins | Skip unchanged liquid style, settled foam, and stock geometry writes. | Parked-drink bubbles and active slosh still animate. |
| Multiplayer | Send changed review posts/removals instead of the entire history; reuse decoded photos; paginate history in groups of 20. | Late joins receive a reliable reset followed by individual posts. Both peers should use the updated game. |
| Patty networking | Limit moving pose messages to 20 Hz, suppress stationary repeats for up to 500 ms, interpolate remote held movement. | Grab/release transitions send immediately; local control cancels interpolation. |
| Relay | Add a bounded outgoing queue with retry on buffer pressure and replace front-removal of inbox packets with a cursor. | Queue limit is 8 MiB; a persistently overwhelmed connection reports an error and disconnects. |
| Loading | Overlap up to four resource requests, integrating ready resources between frames. | The existing 30-second loading minimum is preserved. |
| Graphics | Add Low / Medium / High buttons, resolution scale, AA, shadow resolution/filter, and secondary-light-shadow controls under Advanced Graphics. | Low/Medium deliberately reduce visual quality. Default shadow atlas drops from 8192 to 4096; High can restore 8192. Existing saved settings remain supported. |
| Textures | Enable GPU compression/mipmaps for four large backgrounds and limit the optional mill background to 2048. | These import-setting changes take effect when Godot reimports the images. Source images are retained. No GPU-memory improvement was measured here. |
| Future exports | Enable shader baking and exclude test/tool scripts. | Configuration only; no export or EXE build was run. |
| Measurement | Add a bounded debug frame/script timing ring, percentile reports, draw-call/memory counters, customer-construction timing, and rate-limited hotspot warnings. | Request `get_performance_report()` on the game node. Script timing covers game.gd's process work, not all CPU work or GPU time. |

## Validation

Godot 4.6.2, headless, with integration tests using a separate project/user profile:

- `performance_optimization_smoke.gd`: exact patty-pixel comparisons, cooking/seed invalidation, oil animation/cache invalidation, remote interpolation/local takeover, review deltas/image reuse/removal, and cached-audio resource validity.
- `performance_settings_smoke.gd`: Low/Medium/High application, settings persistence, and six cached loops' start/stop/live volume controls.
- `relay_performance_smoke.gd`: two actual local WebSocket clients; 400 ordered 4096-byte packets, 2,205,244 transport bytes including handshake, all delivered with an empty final queue. This is a local delivery test, not a WAN congestion benchmark.
- Existing scheduler, pipeline, condiment-input, payment-pool, soda-damping, cheese-serving, and multiplayer-recent-features smoke tests passed.
- Existing serving-art test passed: latest run first crop 0.018 ms, cached crop 0.004 ms, family variant 0.007 ms. The audit's unprepared first crop was approximately 139 ms; these are isolated operations, not whole-frame measurements.
- Optimized changing-state patty texture: representative isolated run median 0.275 ms, p95 0.440 ms. The audit's original flipped-texture result was mean 5.19 ms, p95 7.37 ms. Different runs/statistics should not be treated as an exact FPS multiplier.
- Full startup reported `STARTUP_LOADING_SMOKE_OK`, 81 preload paths, 31.265 seconds to playable gameplay. Full-scene teardown then reports RefCounted/process_frame ObjectDB leaks and exits with Windows access violation `-1073741819`. A separate project using the preserved pre-change scripts and project settings reproduces the same shutdown crash (31.280-second startup). It is therefore a pre-existing full-scene shutdown issue, not a clean test pass and not fixed by this performance pass.

Headless testing cannot verify final rendered appearance, audible loop transitions, GPU frame times, or target-hardware FPS. Customer pooling and larger scene/module restructuring remain deferred until the new construction timing and a rendered gameplay profile justify their complexity.

## Regenerating derived assets

Run these from the project root with the existing Godot editor binary (these commands do not export):

```powershell
$godot = 'C:\Users\joe\Downloads\godot\Godot_v4.6.2-stable_win64_console.exe'
& $godot --headless --path . --script res://tools/bake_ingredient_art.gd
& $godot --headless --path . --script res://tools/bake_oil_animation.gd
& $godot --headless --path . --script res://tools/bake_audio_beds.gd
```

The generated `.res` files belong with the source changes. The audio baker uses the existing audio-synthesis methods; rebake after changing their sound design. Keep the checked-in cached beds available while regenerating, since game_audio.gd preloads them.

The settings integration test intentionally writes configuration and refuses to run without an isolated `application/config/custom_user_dir` beginning with `BurgerPerformanceIsolatedTest`. This run used `C:\Users\joe\AppData\Local\Temp\burger_integration_a4xbzwsl`, with a copied project.godot and linked asset/source folders. Do not run save-writing integration tests against the player's normal profile.
