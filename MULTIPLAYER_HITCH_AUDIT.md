Implementation follow-up: see [MULTIPLAYER_FIXES.md](MULTIPLAYER_FIXES.md) for the changes and release validation. The findings and measurements below describe the original audit baseline.

Multiplayer hitch audit - September 12, 2026

The strongest direct match for simultaneous-action freezes is the global patty drag owner. Separate from that input bug, unchanged remote state repeatedly rebuilds visual resources. Network queues and snapshot bursts can amplify those costs. These are 20 prioritized fixes, not 20 fixes already applied. No gameplay code, executable or hosted relay was changed during this audit.

The review covered the current working copy, including existing uncommitted performance changes. It traced 139 game RPCs, periodic replication, receive-side rendering work, ownership, relay routing, bootstrap and regression coverage. Prior improvements already present include patty pose throttling/interpolation, station signatures, social deltas/image reuse, material/audio warmup, and a limited frame-state batcher. Those are not counted as new fixes.

Fresh focused measurements used Godot 4.6.3, headless, isolated user data and real visual helper implementations. They do not measure GPU stalls, WAN conditions, concurrent gameplay, or the shipped EXE. The final expanded probe exited 0 with no script errors.

| Repeated unchanged operation | Samples | Median | p95 | Maximum | Allocation observation |
| --- | ---: | ---: | ---: | ---: | --- |
| Four ready-fries packs | 20 | 7.023 ms | 8.306 ms | 9.221 ms | All four packs replaced; eight roots coexist until deferred deletion |
| Full remote iced cup | 60 | 0.819 ms | 1.270 ms | 1.425 ms | All 48 ice materials replaced |
| Full remote soft-serve cone | 30 | 1.637 ms | 2.468 ms | 2.649 ms | Procedural mesh replaced |

At 60 FPS the entire frame budget is 16.67 ms. These costs can land in addition to normal game/render work; they must not be summed into a claimed measured multiplayer frame time. An earlier cup/fries-only run showed the same allocation behavior (fries median 6.750 ms, maximum 8.500 ms; cup maximum 2.064 ms). The variation is why acceptance should use repeated scenarios and percentiles.

The relay audit executed actual server handlers against fake sockets: valid mode 0 became mode 2, and 100 messages were sent to a recipient reporting 16 MiB already buffered. No production server was contacted.

Online and LAN need separate validation. The online transport is a WebSocket/TCP stream: an `unreliable` RPC annotation does not turn it into lossy low-latency datagrams. Reducing queued work should help, but metadata/channel changes alone cannot remove TCP delivery stalls. This interpretation follows [Godot WebSocket documentation](https://docs.godotengine.org/en/stable/tutorials/networking/websocket.html). For ENet, channel and unreliable-ordered semantics are described in [Godot multiplayer documentation](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html); server queue monitoring is documented in the [ws API](https://github.com/websockets/ws/blob/master/doc/ws.md#websocketbufferedamount).

1. **Fix drag ownership per patty.** Immediate / small-to-medium / input correctness.

   Evidence: [game.gd:73013](C:/Users/joe/Desktop/burgergame/scripts/game.gd:73013) writes one global `drag_owner_id` for every remote claim, even when the remote player grabs a different patty. [game.gd:15422](C:/Users/joe/Desktop/burgergame/scripts/game.gd:15422) then stops local drag updates when that ID belongs to someone else. This directly fits simultaneous host/guest actions: host drags A, guest claims B, host A stops following input. This path is verified in source; it has not been reproduced in a live two-player run here.

   Fix: Track ownership by patty network ID, let the host grant contested claims, and attach a claim generation to poses/releases. A remote claim for B must never alter local control of A. Preserve immediate local feedback while resolving a same-patty conflict.

   Check: Two cooks drag separate patties continuously without pauses; competing for one patty yields exactly one owner; late poses/releases from a previous owner have no effect.

2. **Reuse ready-fries objects when the count is unchanged.** Immediate / small / measured CPU and allocation cost.

   Evidence: Every economy packet calls `_refresh_ready_fries_visuals` at [game.gd:74291](C:/Users/joe/Desktop/burgergame/scripts/game.gd:74291). That function queues every pack for deletion and reconstructs the authored model, materials, effects, and grab shapes at [game.gd:35224](C:/Users/joe/Desktop/burgergame/scripts/game.gd:35224). The final probe measured 7.023 ms median, 8.306 ms p95, 9.221 ms maximum for four unchanged packs.

   Fix: Compare old/new servings before refreshing. Keep four reusable packs, update only count transitions, and separately invalidate their layout when tuning changes. Four old and four new roots briefly coexist today until queued deletion runs.

   Check: Repeated identical economy packets preserve pack instance IDs and create zero new packs; buying, grabbing and serving fries still adjust stock and hit targets.

3. **Cache remote ice materials and update cups only when their appearance changes.** Immediate / medium / measured CPU and allocation cost.

   Evidence: [game.gd:72269](C:/Users/joe/Desktop/burgergame/scripts/game.gd:72269) calls `_refresh_cup_ice_stack` on each received cup pose; [game.gd:43321](C:/Users/joe/Desktop/burgergame/scripts/game.gd:43321) replaces all ice materials even when count/fill are identical. The probe confirmed 48 replacements per unchanged full cup, with 0.819 ms median and 1.270 ms p95 for the full cup helper.

   Fix: Retain ice nodes/meshes/materials and update only changed tint, count or fill. A fully iced cup at the 20 Hz send ceiling currently implies up to 960 new materials per second per remote cup. Pass each cup's flavor/fill explicitly: the helper currently restores local `cup_flavor` before creating ice materials, and ice layout reads local `cup_soda_fill`. A guest cup should not change its tint/height when the observer pours their own drink.

   Check: Identical poses preserve all ice resource IDs; increasing ice adds only needed cubes; two differently flavored cups keep independent color and ice height while both players pour.

4. **Stop rebuilding an unchanged soft-serve mesh.** Immediate / small-to-medium / measured CPU and allocation cost.

   Evidence: [game.gd:72259](C:/Users/joe/Desktop/burgergame/scripts/game.gd:72259) calls [game.gd:36966](C:/Users/joe/Desktop/burgergame/scripts/game.gd:36966), which regenerates the corkscrew using the nested vertex/index loops at [game.gd:36776](C:/Users/joe/Desktop/burgergame/scripts/game.gd:36776). The full-cone probe confirmed replacement despite unchanged fill: 1.637 ms median, 2.468 ms p95, 2.649 ms maximum.

   Fix: Skip generation when fill and shape settings match. Reuse a bounded cache of quantized fill meshes or update a persistent mesh while pouring, invalidating it when cone geometry settings change.

   Check: Holding a full cone generates no additional meshes; filling remains visually continuous and follows the authoritative amount.

5. **Keep the phone shop rows alive.** High / small-to-medium / source-confirmed allocation path.

   Evidence: Economy receipt invokes `_refresh_phone_ui` at [game.gd:74296](C:/Users/joe/Desktop/burgergame/scripts/game.gd:74296). With the shop selected, [game.gd:48898](C:/Users/joe/Desktop/burgergame/scripts/game.gd:48898) clears and rebuilds equipment cards, ingredient rows, styles and buttons. The social-feed cache does not cover this shop path.

   Fix: Build rows once and update existing text, bar values and button state using `_phone_supply_row_refs`. Rebuild only when shop structure changes; defer hidden UI updates until needed.

   Check: Several identical economy updates create zero shop rows; focus/scroll remain stable; purchase buttons and delivery status update correctly.

6. **Use the existing state batcher for all action-driven broadcasts.** High / medium / source-confirmed scheduling gap.

   Evidence: The batcher at [game.gd:73462](C:/Users/joe/Desktop/burgergame/scripts/game.gd:73462) currently has one call site, at [game.gd:68612](C:/Users/joe/Desktop/burgergame/scripts/game.gd:68612). Many other actions call economy/customer/grill senders immediately, while periodic sends can run during the same frame.

   Fix: Route action dirtiness and periodic due flags through one end-of-frame scheduler. Build at most one latest snapshot for each subsystem per frame. Keep ordered interaction events immediate; targeted join state needs a separate destination-aware path.

   Check: Multiple independent actions in one frame produce one snapshot per dirty subsystem, while all authoritative actions are applied exactly once.

7. **Send economy and challenge changes instead of repeating all state.** High / medium / source-confirmed recurring traffic.

   Evidence: [game.gd:5572](C:/Users/joe/Desktop/burgergame/scripts/game.gd:5572) sends the complete reliable economy every 0.5 seconds; [game.gd:74201](C:/Users/joe/Desktop/burgergame/scripts/game.gd:74201) serializes inventory, freshness, tanks, machines and counters. Challenge state is also sent reliably every 0.5 seconds, including inactive/unchanged state.

   Fix: Use revisions and changed fields for durable stock/money/machine state. Synchronize a clock anchor separately so a changing timer does not dirty the whole economy. Keep a full initial state and explicit recovery path. Only dirty UI components for changed fields.

   Check: An idle kitchen has little economy/challenge traffic; purchases, refills, payouts and late joins converge exactly with no missed stock changes.

8. **Spread periodic snapshots across frames.** High / medium / likely burst amplifier.

   Evidence: The accumulators at [game.gd:5533](C:/Users/joe/Desktop/burgergame/scripts/game.gd:5533) and [game.gd:5572](C:/Users/joe/Desktop/burgergame/scripts/game.gd:5572) start together. Customer/background updates share a 0.2-second interval; economy/challenge share 0.5 seconds; other repair passes may coincide. The frame batcher deduplicates requested state but does not distribute its construction cost.

   Fix: Stagger periodic deadlines and schedule low-priority repair work under a measured time/byte budget. Prioritize accepted interactions and active held objects. Do not run a catch-up loop that emits every missed snapshot after a slow frame.

   Check: A busy kitchen has lower p99 serialization time with bounded snapshot age; a 200 ms simulated pause does not trigger a replay burst.

9. **Suppress stationary cursor and held-tool packets.** High / small-to-medium / source-confirmed recurring traffic.

   Evidence: Cursor packets go out at up to roughly 30 Hz at [game.gd:72626](C:/Users/joe/Desktop/burgergame/scripts/game.gd:72626). Tools, cups and cones go out at up to 20 Hz without changed-state checks at [game.gd:71756](C:/Users/joe/Desktop/burgergame/scripts/game.gd:71756) and [game.gd:71921](C:/Users/joe/Desktop/burgergame/scripts/game.gd:71921). Patty poses already have suppression, so this extends an existing approach.

   Fix: Track per-peer/per-object last-sent pose and appearance. Quantize motion thresholds, send short periodic keepalives, and immediately send active/tool/pour state transitions. Suppressing position must not suppress changing liquid fill.

   Check: A stationary held tool produces only keepalives; stop-pouring and put-down transitions arrive promptly; active movement retains the intended update rate.

10. **Interpolate every remote held object.** High / medium / visible smoothness.

   Evidence: Only the spatula branch uses a target proxy at [game.gd:72498](C:/Users/joe/Desktop/burgergame/scripts/game.gd:72498). Cups/cones and most other tools directly assign transforms at [game.gd:72329](C:/Users/joe/Desktop/burgergame/scripts/game.gd:72329) and [game.gd:72435](C:/Users/joe/Desktop/burgergame/scripts/game.gd:72435). Fryer basket poses also step at network cadence.

   Fix: Use per-object timestamped samples and render between them, with a small measured jitter buffer and a capped extrapolation window. Preserve immediate local control, explicit teleports and ownership transitions. Reuse the existing spatula/patty interpolation machinery where appropriate.

   Check: With jitter injected, remote tools move between packets instead of stepping; after packet silence they stop extrapolating; taking ownership never adds local input latency.

11. **Make outgoing motion replaceable and enforce a real per-frame send budget.** High / medium-to-large / source-confirmed queue behavior.

   Evidence: [relay_multiplayer_peer.gd:130](C:/Users/joe/Desktop/burgergame/scripts/relay_multiplayer_peer.gd:130) encodes packets into an opaque FIFO. No mode or freshness policy removes obsolete poses. `_flush_outbox` limits 32 messages per invocation, but `_send_json` invokes it for every send, so 32 is not a shared per-frame limit.

   Fix: Represent disposable motion separately before opaque RPC serialization, keyed by peer/object/stream, so unsent older poses can be replaced. Maintain a frame-wide byte/time budget and separate reliable control ordering. Bound queued age as well as bytes and report send failures accurately.

   Check: After temporary congestion the latest pose arrives without replaying seconds of obsolete motion; spawn/claim/release/serve messages remain ordered and lossless. Never discard unknown SceneMultiplayer control packets.

12. **Bound receive/decode and presentation work.** High / large / likely burst amplifier.

   Evidence: [relay_multiplayer_peer.gd:113](C:/Users/joe/Desktop/burgergame/scripts/relay_multiplayer_peer.gd:113) drains every available WebSocket message in one poll; [relay_multiplayer_peer.gd:209](C:/Users/joe/Desktop/burgergame/scripts/relay_multiplayer_peer.gd:209) parses/decodes and queues each RPC. Receive handlers synchronously build visuals, so a network burst can put several rebuilds into one frame.

   Fix: Budget decode and application work, bound inbox size/age, and coalesce only explicitly disposable pose streams. Apply authoritative transitions promptly and queue expensive presentation separately. Keep a full-state recovery strategy so bounded processing does not merely turn CPU stalls into ever-growing latency.

   Check: A burst while cooking leaves bounded frame time and queue age; no reliable interaction disappears; oversized or persistently overloaded input fails explicitly rather than growing memory indefinitely.

13. **Add relay backpressure per recipient.** High for online / medium / handler behavior reproduced.

   Evidence: [server.js:56](C:/Users/joe/Desktop/burgergame/mp_server/server.js:56) sends whenever a socket is open and never examines `bufferedAmount`. The fake-socket probe ran the actual relay handler with a recipient reporting 16 MiB buffered: all 100 further messages were still sent. This proves missing gating, not real-world latency magnitude.

   Fix: Add per-recipient byte/age limits, send completion/error handling, and congestion counters. Coalesce explicitly typed transient state before sending it into the socket; retain reliable control ordering and isolate a slow recipient from healthy peers.

   Check: A throttled guest cannot create unbounded buffered data; other guests continue receiving promptly. Reliable-overflow handling is explicit and observable.

14. **Preserve transfer modes and separate unrelated ordered streams.** High correctness / medium / mode bug reproduced.

   Evidence: [server.js:314](C:/Users/joe/Desktop/burgergame/mp_server/server.js:314) uses `Number(msg.mode || 2)`, converting valid mode 0 into 2; the relay probe reproduced 0 -> 2. All 139 game RPC declarations use the default channel. Mixed-size motion and full-world snapshots share the unreliable-ordered stream on transports that implement it.

   Fix: Default modes only when missing, validate supported values, and allocate deliberate channels for control, motion and bulky state on ENet. Use per-object sequence numbers where several objects share a channel. On the WebSocket relay, retain correct metadata but recognize that channels alone do not remove TCP ordering delays.

   Check: Mode 0/1/2 round-trip unchanged; delayed bulky state does not cause unrelated current motion to be discarded on ENet; old poses cannot reverse newer transitions.

15. **Replace JSON/base64 game payloads with a tested binary protocol.** Medium / large / measurable encoding overhead, WAN gain unmeasured.

   Evidence: [relay_multiplayer_peer.gd:274](C:/Users/joe/Desktop/burgergame/scripts/relay_multiplayer_peer.gd:274) base64-encodes every RPC, then JSON-encodes it; receipt reverses both. Base64 alone expands three source bytes into four characters, before the JSON wrapper. Existing comments explicitly record an earlier binary delivery failure.

   Fix: Define a versioned binary envelope, validate payload sizes and authoritative sender identity, negotiate compatibility, and prove it through the real hosted route before switching. Do not simply enable the legacy branch: its sender/target/header layout needs review. Retain a tested fallback during rollout.

   Check: Byte-for-byte payload tests, peer routing, all modes/channels, reconnect and four-player tests pass through the deployed route. Measure encode/decode cost and wire bytes before claiming an improvement.

16. **Make grill/mess replication incremental with indexed lookup.** Medium-to-high under load / large / source-confirmed scaling path.

   Evidence: [game.gd:73510](C:/Users/joe/Desktop/burgergame/scripts/game.gd:73510) emits all patty fields and a complete mess snapshot every 0.33 seconds. [game.gd:73662](C:/Users/joe/Desktop/burgergame/scripts/game.gd:73662) walks all residue slots; debris reconciliation performs a nested ID search at [game.gd:73761](C:/Users/joe/Desktop/burgergame/scripts/game.gd:73761). `_patty_by_net_id` also scans collections at [game.gd:72774](C:/Users/joe/Desktop/burgergame/scripts/game.gd:72774).

   Fix: Keep ID-to-object registries and revisions, send changed entities plus explicit removals, and run infrequent complete recovery snapshots. Quantize visual cook/fill values separately from authoritative scoring. Add/remove registry entries on spawn, pooling and deletion; do not interpret omission from a partial update as deletion.

   Check: Packed-grill/scrape tests show bounded lookup cost and reduced payload size; dropped deltas recover; no ghost fry, patty or debris survives a valid full reconciliation.

17. **Prepare remote tool proxies before first interaction.** Medium / medium / first-use allocation risk.

   Evidence: [game.gd:71984](C:/Users/joe/Desktop/burgergame/scripts/game.gd:71984) duplicates a live tool tree on its first received pose; cup/cone/fries proxies are also built lazily. Local resource caching does not prove those remote variants have been constructed or drawn.

   Fix: Prepare a bounded pool of remote visual proxies during loading or paced peer setup. Cache child references and strip gameplay/collision processing. Render representative remote materials/effects during warmup if GPU profiling shows first-use pipeline compilation.

   Check: The first remote tool use performs no large scene duplication; later uses reuse proxies. Rendered first-use frame times improve without exceeding the chosen memory budget.

18. **Replace repeated bootstrap pushes with an acknowledged join transaction.** Medium-to-high on join / large / source-confirmed burst path.

   Evidence: [game.gd:71354](C:/Users/joe/Desktop/burgergame/scripts/game.gd:71354) pushes state twice; guests request again after 0.35 seconds, and live-join handling pushes after 0.4 seconds. [game.gd:71415](C:/Users/joe/Desktop/burgergame/scripts/game.gd:71415) performs large loops without pacing and calls several broadcast helpers, affecting existing peers as well as the joiner. The second `call_deferred` is not a dependable frame boundary.

   Fix: Wait for guest-ready, send one versioned snapshot in bounded chunks to that peer, acknowledge completion, and retry only missing/stale chunks. Track changes during the snapshot and reconcile them before enabling guest interaction.

   Check: A late join while two cooks work produces one completed bootstrap, no redundant full-world bursts to established peers, and identical final inventory/ownership state.

19. **Move review photo encoding and history delivery off the action path.** Medium / medium / synchronous bulk-work risk.

   Evidence: [social_feed_replication.gd:10](C:/Users/joe/Desktop/burgergame/scripts/social_feed_replication.gd:10) reads image data and PNG-encodes a new picture synchronously. [game.gd:71656](C:/Users/joe/Desktop/burgergame/scripts/game.gd:71656) sends the complete history as individual reliable posts in one loop during a join. Deltas and decoded-image reuse already exist.

   Fix: Prepare bounded thumbnails when the picture is created, cache encoded bytes, and trickle history under a bulk-data budget after essential kitchen state. Split text updates from unchanged image bytes. If using a worker, keep scene/render resource operations on their required thread and move only safe image processing.

   Check: Serving a photo review adds no synchronous image encoding spike; a late join with many photos does not delay grabs/releases; text-only edits do not resend the image.

20. **Add a simultaneous-play frame-time and latency regression harness.** Start alongside fixes / medium-to-large / confirmed coverage gap.

   Evidence: [multiplayer_release_smoke.gd:26](C:/Users/joe/Desktop/burgergame/tests/multiplayer_release_smoke.gd:26) disables process and physics before its multiplayer fixture; it verifies serving correctness, not ongoing simultaneous play. Existing metrics time game `_process`, not all receive/deferred work, and relay stats omit RTT and packet age.

   Fix: Run two and four active peers with normal gameplay loops. Script different-object drag, same-object contention, both players pouring, stocked ready fries, scraping, serving, open shop and late join. Collect monotonic frame intervals, p50/p95/p99/max, >33/50/100 ms counts, encode/decode/apply time, allocation counters, bytes, queue age, and action acknowledgment latency.

   Check: Test ENet and relay under clean, delayed/jittered and bandwidth-limited conditions. Capture both players; use separate machines for representative GPU/WAN results. Assert state correctness alongside performance so smoothing cannot hide desync.

Implementation order: start the baseline/telemetry work in 20, then fix ownership and measured redundant allocations in 1-5. Next address repeated scheduling/traffic and movement in 6-10, then bounded queues and protocol correctness in 11-14. Take binary, incremental state and join/bulk changes in 15-19 behind compatibility tests. Start with low-risk changes that remove unchanged work; do not merely increase update rates or buffers.

Suggested performance target, to calibrate against actual hardware: zero >100 ms action-induced stalls after warmup and substantially fewer >33 ms frames than the unchanged baseline at the same settings. Treat p99 frame time, queue age and action latency as separate success measures. A fixed 60 FPS guarantee is not established by this audit.

Audit artifacts: [visual measurements](C:/Users/joe/Desktop/burgergame/build/multiplayer_hitch_audit/visual_probe.json), [relay measurements](C:/Users/joe/Desktop/burgergame/build/multiplayer_hitch_audit/relay_probe.json), [visual log](C:/Users/joe/Desktop/burgergame/build/multiplayer_hitch_audit/visual_probe.log), [source hashes](C:/Users/joe/Desktop/burgergame/build/multiplayer_hitch_audit/source_manifest.json). The build folder is ignored by Git. The focused probes and runner are separate source additions so the investigation can be repeated.

Reproduce the focused probes from the repository with `python tools/run_multiplayer_hitch_audit.py`. The runner redirects APPDATA/LOCALAPPDATA into the audit folder, uses the existing local Godot binary, and never exports or deploys. [Runner](C:/Users/joe/Desktop/burgergame/tools/run_multiplayer_hitch_audit.py), [Godot probe](C:/Users/joe/Desktop/burgergame/tests/multiplayer_hitch_audit_probe.gd), [Relay probe](C:/Users/joe/Desktop/burgergame/tools/multiplayer_relay_audit_probe.cjs).
