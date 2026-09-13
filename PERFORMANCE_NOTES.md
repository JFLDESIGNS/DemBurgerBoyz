# Performance changes â€” September 11, 2026

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


## Post-serve material hitch (September 12)

Custom customers previously duplicated and recompiled fade shaders for their face and every clothing surface as soon as they started walking away, even at full opacity. The rendered custom-customer probe measured 244â€“246 ms inside `complete_serve`. Full-opacity departure now keeps the original materials; fade shaders are shared by source and rendered during loading, and actual fade frames update cached material uniforms. Whole-mesh material overrides and existing transparency masks are preserved. The same probe measured 0.074â€“0.095 ms for completion and 9.6â€“10.2 ms maximum subsequent frame intervals at a 120 FPS cap. These are isolated customer-path measurements, not a whole-game FPS guarantee.

The phone feed also skips rebuilding hidden or unchanged cards, and rechecks when shown. Dirty checks compare texture identities and omit PNG data, avoiding image readback/serialization. Serve hotspot timings now measure work without counting deliberate coroutine waits.

Regression coverage: `serve_completion_cache_smoke.gd` checks material identity, shared shader/independent opacity, transparency masks, and feed reuse; `customer_leave_fade_clothes_smoke.gd` preserves clothing/paint parameters. `serve_fade_profile.gd` reproduces the focused timing measurement.

Base skin/eye/mouth shaders are also shared while each customer keeps independent materials and colors. New custom-customer construction in the full rendered scene fell from roughly 272–276 ms to 50–59 ms. Loading now actually draws payment bills, review text, transparent customer variants, and the live feedback label behind the loading overlay; allocating hidden resources alone did not warm their first draw.

The full rendered serving integration test checks payment, ticket removal, and review publication with both home and social phone views. In the final RTX 3070 / Godot 4.6.3 run, serve callbacks took 0.71–0.78 ms; subsequent frame intervals had medians of 21.6–22.0 ms and maxima of 38.9–45.1 ms, compared with a roughly 300 ms first-serve rendering spike before the feedback warmup. This improves the measured hitch but does not guarantee a constant 60 FPS. The test reached FULL_SERVE_PIPELINE_OK and exited 0; the pre-existing full-scene texture/ObjectDB shutdown warnings remain. See build/full_serve_live_feedback.log.


## Burger completion beat and flip inspection (September 12)

The pooled burger now pops against a prebuilt yellow comic burst for 0.5 seconds before the existing toss/catch sequence. The real serve entry still stops the customer order clock before presentation; scoring commits before the hold. Companion drinks receive the same added delay. The burst resets and hides when the serve root returns to its pool.

Patty clicks already use the cached sear texture work. The separate spatula pull-flip flourish was allocating fresh nodes/materials per gesture and fresh mesh resources every frame. Its nodes/materials and ribbon meshes now persist between gestures, while the circle animates a static mesh's scale (its stroke scales with the circle). Ribbon vertex updates remain necessary as the moving trail changes. Flip and delivery announcers now use the cache keys warmed during loading. Local patty clicks also record `patty_flip` in the existing hotspot report.

Validation: `burger_completion_flip_smoke.gd` exercises the real serve entry with a lightweight scoring sink, verifies the stationary hold, a fixed 4.95-second order clock, duplicate-serve rejection, launch/cleanup, pool reuse, flip grades, and warmed audio reuse. The rendered Vulkan/Forward+ run passed and its completion frame was inspected. Existing spatula smoothing, serve hitch, performance pipeline, cheese/condiment serve, and patty optimization checks passed. With warmed audio and a freshly reset texture state for each grade, isolated flip calls measured 0.42-0.46 ms; no CPU hitch was reproduced. These focused tests do not prove the absence of whole-game or GPU hitches. No executable was rebuilt.


## Soda prongs, debris scraping, and EXE refresh (September 12)

The two soda push-lever meshes contained cabinet-space vertices under already-translated hinge pivots. Their GLB child transforms now cancel that second translation. The source exporter updates Blender transforms when creating a pivot so regenerated assets preserve the intended world pose. Rendered inspection and hinge-relative bounds checks confirm both levers hang from their dispensers, including after station-scale tuning.

Scrape playback could select six bass/eight kuhh samples while loading prepared only four of each. Playback and warmup now share the complete variant counts, and grill-tool loading prepares all 14 variants. A previously missing kuhh variant cost 3.55 ms on first playback; warmed calls peaked at 0.038 ms in the focused check.

A rendered full-kitchen profile reproduced a much larger frame stall despite scrape script work below 0.5 ms. With unrelated boss entrance events disabled only in the isolated test profile, the pre-fix peak was 233.10 ms. The game now renders real residue geometry/materials during loading and retains those hidden resources to avoid first-scrape pipeline work. The repeat test measured 18.99 ms maximum, 14.08 ms p95, and 0.407 ms peak scrape script work. This is one controlled comparison on an RTX 3070, not a guarantee across machines. The project's previously documented full-scene shutdown resource warnings remain.

Passing cars use one visible preloaded variant at a time, roughly 5,300-5,500 triangles and 29-30 surfaces. Across seven variants, animation averaged 0.004 ms and peaked at 0.021 ms in the focused test. One visible car added 29 draw calls in that test scene. Traffic was left unchanged; these results do not identify it as a major CPU contributor to the scrape stall.

Release validation and the rebuilt executable hash/backup location are recorded in build/soda_scrape_release/release_report.json.

The refreshed EXE was installed at build/FoodTruckFlip.exe (675,423,352 bytes; SHA-256 1c34426709f9cafe5272e14643c5f0a2e5355dbb0cb5345fc7f72531bedbfeb4). Packaged soda/scrape/traffic and burger-completion checks passed, and the native rendered startup exited successfully. The earlier uncapped 30-frame headless startup probe exited with access violation before normal loading could settle; the paced rendered launch passed and retains the previously documented shutdown resource warnings. The prior EXE is saved under build/backup/FoodTruckFlip_before_soda_scrape_20260912_012522.exe.
