# Gameplay hitch audit — 11 October 2026

## Changes

- Customer social dialogue uses the regular shared Wawa player, preserving male/female voice selection without spatial attenuation.
- Patty transfers to the build station play a cached whoosh at launch and a cached board impact at landing. A guest whose station snapshot arrives before its local flight ends still gets exactly one landing sound.
- Chef-point totals and the latest reward appear in the award frame. Rapid awards reuse the popup rather than queueing seconds of delayed feedback or allocating a new sparkle burst for every award.
- Review cleanup checks tween validity before stopping it. Customer clearing checks instance validity before passing customers to typed ticket-removal code.
- Order tickets remain 95% opaque (5% transparent).

## Method and limits

Windows, Godot 4.6.3, RTX 3070, Vulkan Forward+, actual viewport 1920×1080, 60 FPS cap. The renderer overrides the command-line 1280×720 request. Audio uses the Dummy driver for repeatability; audible balance was not judged by listening.

The rendered harness measures wall-clock frame gaps and synchronous action duration separately. Each phase contains subsequent animation/rendering work, so a phase maximum is not proof that its initiating function caused the entire stall. One preset is repeated; this is not exhaustive coverage of every appearance, recipe, hardware configuration, or network condition. The background-walker phase restyles all walkers at once, which is a stress case.

Initial captures exposed harness problems: forced departure bypassed queue bookkeeping, and automatic serving could start before a measured action. Those captures are retained as diagnostics, not clean release evidence. The corrected harness calls normal departure bookkeeping and disables automatic serving only in its test fixture.

## Functional verification

- LAN and local WebSocket relay: all 12 host/guest checks passed across chef-points/transfer sounds, deliveries, and the broader multiplayer release suite. Checks include duplicate/forged reward rejection and exactly one launch/landing sound per peer.
- Two simultaneous headless LAN processes also passed the existing concurrency test. Sampled drag/cup/cone action maxima were 23.6/45.0/31.1 ms on the host and 17.7/33.4/34.3 ms on the guest. These measure simulation scheduling, not GPU rendering, and are not a claim that the full session never hitched.
- Ten of twelve broader smoke tests passed: chef points, regular Wawa/ticket opacity/customer motion, cooking controls, arrival-ticket pooling, serving completion caching, departure clothing fade, machine delivery, boss delivery shake, recent multiplayer features, and serving shortcuts.
- Latest chef-point popup reuse and already-freed-customer cleanup passed a separate focused rerun.
- Burger handoff alignment test failed at approximately 62 px versus a 4 px threshold. The test samples animation alignment even when the burger is invisible, so visual confirmation is still needed; do not treat this as resolved.
- Mobile auto-serving test failed. Its fixture mocks an older drink-consumption path and expects immediate sealing before the current side-item flight completes. Update that test against current side-pack behavior before calling the feature verified.

These network tests ran locally. They do not establish Internet latency/loss tolerance. Multiplayer scripts were exercised in the editor; the exported application's boot check is separate.

The release export and native Vulkan boot check passed. `build/BurgerPals.exe` was replaced with the checked export; the prior executable is backed up at `build/gameplay_hitch_audit_20261011/BurgerPals_before_audit.exe`. The short native boot check reported an ObjectDB leak warning at shutdown and does not constitute a packaged full-gameplay or packaged multiplayer run.

## Measured results

The corrected capture completed with exit 0 and all serving-completion assertions passed. It still logged a freed lambda capture after forced boss cleanup and texture-resource warnings at shutdown. Those warnings remain unresolved; the runner's success flag only checks completion, exit status, and script errors.

| Phase | Action call (ms) | Worst frame (ms) |
|---|---:|---:|
| Customer arrivals, three trials | 186–190 | 213–285 |
| Three customers leaving | 10.7 | 399.6 |
| All background walkers restyled | 214.0 | 243.0 |
| Background angry clicks | 3.6 | 34.5 |
| Boss arrival | 86.5 | 164.2 |
| Supply delivery | 1.0 | 214.9 |
| Burger serve | 1.3 | 169.4 |
| Cola serve | 671.6 | 683.6 |
| Fries serve window* | not valid | 55.0 |
| Ice cream serve | 2.7 | 268.6 |
| Eight chef rewards | 4.5 | 53.2 |

*A separate fries auto-serve path started before the explicit measurement. Completion passed, but the initiation timing is invalid. The fixture now disables that path for future captures; no additional full rendered rerun was made for that test-only change.

Settled idle had a 260.8 ms maximum. Early background loading reached 861.4 ms. Therefore startup/background activity and occasional frame stalls remain even between explicit events. Burger scoring commit took 20.0 ms and review handling 4.4 ms; its larger frame maximum cannot be attributed entirely to scoring. Cola's synchronous first-serve path is a particularly high-priority investigation.

## Follow-up priorities

1. Customer construction and background restyling perform substantial synchronous work. Pool prepared character instances or stage their construction; preserve animation cache correctness and outfit materials.
2. Departure and first-use rendering need further investigation. Measure shader/material preparation and disposal separately before changing lifetime behavior.
3. Reconcile the two failing smoke tests above, then rerun their visual and multiplayer cases.

Reproduction: `python tools/run_gameplay_hitch_audit.py verified`, `python tools/run_hitch_audit_checks.py smoke`, and `python tools/run_hitch_audit_checks.py network`. Logs and JSON are in `build/gameplay_hitch_audit_20261011`; detailed smoke/network logs are in `build/multiplayer_release`.
