# Gameplay and hitch follow-up — 2026-10-11

## Gameplay changes

- Mailcat's handoff position moves one foot (0.3048 m) toward screen-right and six inches (0.1524 m) toward the camera. Recalculating the courier's size does not accumulate the offset.
- Automatic selection preserves mobile tickets' queue positions. Explicitly clicking a mobile ticket can bring it forward; the selection intent is replicated to both peers.
- Accepted bacon snacks restore 10% of maximum customer patience, capped at maximum. The host applies the reward once and replicates it. Existing acceptance probabilities and cat behavior remain intact.

## What was happening with cola

Serving was constructing another cup, generating procedural foam texture data, creating shader resources and preparing depth-tested material variants on the main thread. The handoff now copies the prepared cup visual, with private liquid state, and reuses immutable textures, shaders and matching depth materials. A representative cola handoff is prepared beneath the loading still. The original inventory cup and authoritative serving callbacks retain their ownership and timing.

## Other performance changes

Character construction repeatedly created equivalent face, clothing and accessory materials. Gameplay appearances now reuse materials keyed by the complete saved preset and part. Eyes and mouth expression materials remain independent; fading takes private material copies. Geometry caches reuse immutable sphere and mouth meshes. Surface controls skip redundant updates when settings have not changed. Loading prepares a bounded set of up to twelve local saved appearances, one at a time. An additional uncached appearance may still incur a first-use cost.

## Validation and limits

The focused checks passed for courier position and scale, mobile queue order, cup cache identity and independence, thrown-food bacon restoration, clothing compatibility, material isolation and customer fading, background angry-click recycling, snack presentation and mobile side-order completion.

Sixteen host/guest checks passed across LAN and relay: queue selection/bacon replication, chef rewards, deliveries and the broader multiplayer release scenario. These are two processes on this machine and establish synchronization behavior, not real Internet latency or simultaneous GPU performance on two machines.

Rendered measurements use Godot 4.6.3, Vulkan Forward+, RTX 3070, a 1920×1080 viewport, a 60 FPS cap and dummy audio output. Events run serially with fixed observation windows. The table reports the largest wall-frame interval in each window, not pure event CPU time or an average FPS. Driver caches and background work make individual maxima noisy; the synchronous action measurements corroborate the large cola and character-construction improvements. The initial fries baseline did not initiate the intended path, so the first corrected capture is used for that row.

The audit still emits a freed-lambda warning around its forced boss-reset/delivery transition and renderer/resource warnings at shutdown. The earlier burger handoff alignment assertion remains unresolved. Passing this audit does not mean these diagnostics or all visual alignment checks are resolved.

## Rendered results

Final capture: `build/gameplay_hitch_audit_20261011/shipping_final.json` and `.log`. Completed with exit 0 and all serving assertions passed. Earlier baseline: `verified.json`; corrected fries baseline: `improved.json`.

| Event | Earlier worst frame (ms) | Final worst frame (ms) | Final synchronous action (ms) |
|---|---:|---:|---:|
| Settled idle | 260.8 | 36.1 | — |
| Customer arrival 1 | 285.4 | 36.0 | 11.4 |
| Customer arrival 2 | 212.8 | 41.0 | 12.0 |
| Customer arrival 3 | 217.0 | 36.3 | 11.9 |
| Three customers leaving | 399.6 | 392.4 | 12.1 |
| All background walkers restyled | 243.0 | 71.5 | 45.5 |
| Background angry clicks | 34.5 | 47.4 | 2.7 |
| Boss arrival | 164.2 | 185.2 | 87.0 |
| Supply delivery | 214.9 | 78.5 | 1.0 |
| Burger serve | 169.4 | 170.4 | 1.3 |
| Cola serve | 683.6 | 55.5 | 6.6 |
| Fries serve (corrected baseline) | 153.9 | 125.4 | 96.8 |
| Ice cream serve | 268.6 | 54.4 | 7.6 |
| Eight chef rewards | 53.2 | 52.3 | 4.7 |

Cola's synchronous initiation dropped from 671.6 ms to 6.6 ms (about 99%); its worst observed frame dropped about 92%. Customer construction itself measured 9.7–10.2 ms after loading preparation, versus about 186–190 ms earlier. No frame exceeded 100 ms in the final arrival, walker-restyle, angry-click, delivery, cola, ice-cream or chef-reward windows.

This is not a hitch-free result. Early background loading still reached 714.7 ms. Departure, boss, burger and fries windows still exceeded 100 ms. Boss and angry-click maxima were higher in this capture; neither is claimed as a performance improvement. Departure material preparation/disposal, boss setup and first-use fries effects remain priorities. Burger scoring took 18.9 ms and review processing 4.3 ms; a separate payment-effects diagnostic reported 40.4 ms. Those measurements do not fully explain its 170.4 ms maximum, so further attribution is needed.

Reproduce with `python tools/run_gameplay_hitch_audit.py shipping_final` (run alone) and `python tools/run_hitch_audit_checks.py network`. Caches trade a bounded amount of memory and loading preparation time for lower in-game construction costs; loading-duration changes were not separately benchmarked.

The Windows release export passed its isolated native boot check (exit 0, no script/parse errors) and was installed at `build/BurgerPals.exe`. The previous executable is preserved at `build/gameplay_hitch_audit_20261011/BurgerPals_before_queue_perf.exe`. Native validation was a boot check; the full rendered audit and multiplayer scenarios ran from the project.
