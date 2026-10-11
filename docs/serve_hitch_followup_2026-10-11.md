# Burger, departure and fries performance follow-up

## Scope and changes

This follow-up targets burger serving, three simultaneous angry departures, and fries serving. It builds on the earlier queue/cola audit.

- Keep the loading-prepared fade materials alive for the bounded local wardrobe. Freeing the warmup actors previously dropped the last references to some generated material variants; the first live departure paid their preparation cost again. Each live customer still owns private fade uniforms. Repeated surfaces within one customer reuse a private copy.
- Share identical fry bite materials within a single serving, while keeping different servings independent. Render the complete fry bite presentation under the loading still so its first use is prepared.
- Prepare the actual sale-bill material, pooled burger sprites and visible burst-animation poses before gameplay. The warmup also draws the completion light against the kitchen. The initial pose alone had fully transparent flying accents and did not exercise their visible rendering path.
- Preserve earned social reviews if their customer is freed during the deferred completion sequence, passing a valid customer or null to the typed review callback.

## Measurement method

Godot 4.6.3, Vulkan Forward+, RTX 3070, 1920×1080 viewport, 60 FPS cap, dummy audio. Rendered runs execute alone. `HITCH_AUDIT_FOCUSED=1` selects the requested cases. The departure window lasts at least eight seconds and the serving windows at least seven seconds, each retaining a minimum of 300 frame samples. This corrects an earlier harness assumption that 300 frames always covered the whole animation. Wall-frame maxima include deferred work and rendering; action-call timings only measure synchronous initiation.

The earlier shipping capture used fixed frame counts and included additional events before serving. It is a useful historical comparison rather than a perfectly controlled same-sequence benchmark. Success requires each serving completion assertion, not just lower timings.

## Investigation evidence

Retaining prepared fade materials reduced live fade binding from roughly 352 ms for the first departing customer to 3–4 ms for all three. The entire departure window improved from the earlier 392 ms maximum to 149 ms in the fourth focused pass; its remaining large frame occurred immediately when departure began, before fading.

Fry presentation setup fell from roughly 97 ms to 10–11 ms. Two normal-feedback focused runs measured worst frames of 62 and 84 ms, with no frame over 100 ms in their fries windows.

Changing shader reflection/copying alone did not fix the fade stall and was reverted. A diagnostic with feedback text disabled did not remove the burger spike, and recorded eating voice loading took under 1 ms. Disabling the completion light's shadows also did not improve the burger measurement, so shadows were restored. Diagnostic-only feedback suppression is not enabled in the shipping game.

A separate rendered scoring test passed payout, ticket-removal and review assertions with the phone on its home and social screens. Scoring cost about 17 ms, station redraw 0.06–0.07 ms, and review handling 8–9 ms. The first post-score observation window peaked at 96.7 ms, the second at 41.4 ms. It omitted the flying-burger presentation and used a fresh isolated save, so these numbers are diagnostic, not substitutes for the full serving measurement. Its log is `build/multiplayer_release/full_serve_render_profile.log`.

## Final results and validation

Final capture: `build/gameplay_hitch_audit_20261011/serve_departure_final.json` and `.log`. Exit 0; both serving-completion assertions passed. All eleven final regression checks passed: seven focused checks (material isolation, clothing fade, appearance-cache isolation, deferred serving/cache behavior, side-food queue/cleanup, fries interruption and payment pooling) and both host/guest roles on LAN and relay. Evidence: `build/gameplay_hitch_audit_20261011/serve_regressions.json`.

| Event | Earlier shipping worst frame | Final worst frame | Final p95 | Frames over 100 ms |
|---|---:|---:|---:|---:|
| Three customers leaving | 392.4 ms | 137.0 ms | 25.3 ms | 1 |
| Burger serve | 170.4 ms | 181.5 ms | 33.0 ms | 1 |
| Fries serve | 125.4 ms | 68.3 ms | 28.7 ms | 0 |

The departure maximum is about 65% lower and the fries maximum about 45% lower in this capture. Live fade setup took 3.4–3.8 ms per customer. Fries synchronous initiation was 10.9 ms versus 96.8 ms earlier. The departure window still has an immediate 137 ms spike before fading starts.

**Burger serving has no demonstrated overall hitch improvement.** Final initiation was 1.5 ms, scoring 20.4 ms, and review handling 3.9 ms, but frame 43 still reached 181.5 ms. Other focused passes ranged around 162–164 ms with normal feedback. Its precise remaining cause is unresolved; neither audio loading, station redraw, nor disabling the light's shadows explains it. Additional renderer/deferred-work attribution is needed. The warmups are not presented as a solution to that remaining spike.

Early background loading still reached a large spike; this follow-up does not claim to fix startup. Renderer texture/RID warnings remain at shutdown. The broader smoke run also reproduced the existing burger-to-hand alignment failure (about 66 px); it is not fixed by this performance work.

Reproduce the focused capture in PowerShell with `$env:HITCH_AUDIT_FOCUSED='1'; python tools/run_gameplay_hitch_audit.py serve_departure_final`. Run `python tools/run_serve_hitch_checks.py` for the focused behavioral checks and two-peer LAN/relay release scenarios. These network checks use two local processes and do not establish real Internet latency or two-machine GPU performance.

The Windows release export passed its isolated native boot check (exit 0, no script/parse errors) and was installed at `build/BurgerPals.exe`. The previous executable is preserved at `build/gameplay_hitch_audit_20261011/BurgerPals_before_serve_perf.exe`. Native validation covers startup; full serving and multiplayer checks ran from the project. Retaining the bounded warmup materials trades some memory for avoiding first-departure preparation; memory and overall loading duration were not separately benchmarked.
