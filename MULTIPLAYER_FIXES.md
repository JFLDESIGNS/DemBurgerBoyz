# Multiplayer smoothing changes

This release implements the twenty audit work items and the requested customer-arrival behavior. The original findings and before measurements remain in MULTIPLAYER_HITCH_AUDIT.md.

1. Drag claims are per patty, granted by the host, with generations rejecting obsolete poses/releases. Another cook grabbing a different patty no longer cancels the local drag.
2. Ready fries retain four pooled packs. Only visible packs have grab targets and receive shelf effects/pushes.
3. Ice cubes share cached meshes/materials, retain nodes, and use the remote cup's own flavor and fill state.
4. Soft-serve geometry uses a bounded 101-step mesh cache; unchanged fill skips mesh work.
5. Phone supply rows and equipment cards update in place, preserving focus/scroll and purchase callbacks.
6. Economy, customer and grill broadcasts coalesce action dirtiness through one service queue.
7. Revisioned sparse state patches replace repeated full economy payloads; unchanged challenge state is suppressed. Clock changes travel as sparse fields; a separate clock protocol was unnecessary for this implementation.
8. Periodic streams start at different phases; construction/application jobs yield after a small time budget instead of replaying missed ticks.
9. Tool/cup/cone/cursor poses use quantized changed-state suppression, a 20 Hz motion ceiling, and periodic keepalives.
10. Remote held tools, cups, cones and baskets interpolate between arrivals. Shared baskets retain visibility and clear interpolation on release.
11. Relay outboxes replace unsent complete motion frames and share a frame-wide byte/packet budget; reliable events retain FIFO order.
12. Relay decode/dispatch, gameplay snapshot application and motion application have bounded work/queues. Overload fails explicitly rather than growing memory without limit.
13. The relay tracks recipient backpressure, queue bytes/age, send errors, and congestion counters; a slow recipient is isolated.
14. Transfer mode zero is preserved. Dependent control/state/bootstrap events share one reliable channel; motion and social data use separate channels; per-object motion sequences reject older updates.
15. Negotiated binary envelopes replace JSON/base64 game payloads when both ends support version 1; legacy JSON fallback remains available. The relay always stamps the authenticated sender.
16. Grill/mess state uses sparse revisioned patches with full recovery; patties and debris use indexed lookup. Complete reconciliations remain responsible for deletions.
17. Remote visual pools for three partners are prepared over loading/setup frames and reused for actual network peer IDs.
18. Guests explicitly request an ordered, paced bootstrap. Completion is acknowledged after pending state applies; missing completion retries. Final state includes station and drag ownership reconciliation, and input waits until ready.
19. Review thumbnails are resized/encoded outside the serve action, then delivered incrementally. Text-only edits retain decoded photos and omit unchanged image bytes; queued rows resolve current text before dispatch.
20. Active two/four-peer tests keep gameplay processing enabled, exercise independent and contested drags, cups/cones, stocked fries, shop reuse and a mid-action state catch-up. Reports include frame percentiles, threshold counts, transport queues/RTT and grab acknowledgment latency. A test-only TCP proxy supplies delay/jitter and bandwidth limits.

Customers now remain at the order spot until the flying burger reaches their mouth. Accepted serving still stops the order clock and commits scoring immediately. Host snapshots and removal messages cannot dispose of a guest's customer during the flight. Completion has a fail-safe for an interrupted animation.

## Validation

The release verification report is generated under build/multiplayer_release. Commands:

- `node tests/relay_protocol.test.cjs`
- `python tools/run_multiplayer_hitch_audit.py`
- `python tools/verify_multiplayer_release.py source`
- `python tools/run_multiplayer_concurrent.py 2 lan`
- `python tools/run_multiplayer_concurrent.py 4 lan`
- `python tools/run_multiplayer_concurrent.py 4 relay`
- `python tools/run_multiplayer_concurrent.py 4 relay impaired`
- `python tools/verify_multiplayer_release.py export`
- `python tools/verify_multiplayer_release.py packaged`
- `node tests/relay_live_protocol.cjs wss://burger-pals-mp-production.up.railway.app`

Focused unchanged-operation timings improved from fries p95 8.306 ms to 0.147 ms, iced cup 1.270 ms to 0.016 ms, and cone 2.468 ms to 0.024 ms. These headless helper measurements demonstrate removal of redundant resource work, not a measured whole-game FPS increase. The relay burst test delivered all 400 ordered 4096-byte payloads with binary negotiation and drained its queue.

Local multi-process frame intervals do not establish real WAN or GPU performance. WebSocket remains TCP and cannot eliminate TCP head-of-line blocking. Individual expensive construction jobs can exceed the scheduling budget; the scheduler bounds how many jobs start, rather than interrupting a scene construction halfway through. Godot's existing full-scene headless shutdown access violation is recorded separately when all gameplay assertions complete; script failures still fail verification. Native rendered startup is checked independently.

Final local active-play checks completed for four LAN peers, four relay peers under delay/jitter and 128 KiB/s link limits, and two clean relay peers. The final two-peer relay run measured phase p99 frame intervals of 16.9-27.7 ms, maxima of 17.1-37.5 ms, guest grab acknowledgment of 16 ms, and empty transport queues at completion. These are local headless measurements. The impaired four-peer run reported 133-150 ms relay RTT and 299-333 ms guest grab acknowledgment; all peers agreed on contested ownership and completed mid-action catch-up. It also exposed first-open shop construction, which was subsequently moved into loading and checked in the final two-peer run.

Additional relay corrections preserve host identity during connection setup, let the relay enforce capacity without rejecting already admitted peers, and remove a selected guest without closing the host socket.

Customer and station snapshots share the reliable gameplay channel with spawn/serve/ownership events, so ENet packet loss cannot let state reconciliation overtake the event it depends on. Motion and social history remain separate.
