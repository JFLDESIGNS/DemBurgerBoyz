# Burger serving: photo and review investigation

Requested ten-minute investigation, October 11, 2026. Rendered Godot 4.6.3 Forward+ on RTX 3070. Two sequential fresh-process runs, each with four burger serves: normal, sales photo disabled, review disabled, normal repeat. These are diagnostic comparisons, not statistically stable benchmarks.

## Findings

The photo hypothesis uncovered real extra work. Photo composition used a separate cache key from prewarmed CPU ingredient images and evaluated texture.get_image() before checking the composite cache. The first photo build cost 175.458 ms during burger preparation, before the measured serving action. Repeated builds cost 33.829–35.324 ms.

Serving then read the thumbnail back from the GPU, resized it to 160 square, and encoded a PNG for sales history. Online reviews also encoded a 192-square copy. Those bytes can be prepared directly from the original CPU canvas.

The large first-serve frame is a separate unresolved problem. The baseline spike occurred at global frame 3370; its review ran at 3548. With the fix, the spike occurred at 3362 and the review ran at 3538. Review publication cannot explain those earlier spikes. A later normal serve was faster than either disabled-feature serve, so the ablations do not establish that removing photos or reviews fixes the first-use spike.

## Changes

- Use the prewarmed ingredient CPU cache before requesting a texture readback. Return private image copies so thumbnail resizing cannot damage shared art.
- Encode sales and review PNGs during thumbnail preparation from the CPU canvas, retaining them with that texture.
- Serving copies cached sales bytes; online review and full social-feed serialization reuse cached review bytes. Older textures retain the existing network encoding fallback.
- Add opt-in diagnostic variants, frame markers, photo-build timing, and PNG validation to the rendered audit.

## Measurements

| Measurement | Before | After |
|---|---:|---:|
| First photo preparation | 175.458 ms | 57.566 ms |
| Repeated photo preparation | 33.829–35.324 ms | approximately 45 ms |
| First synchronous serve commit | 18.926 ms | 11.859 ms |
| Four-serve average commit | 19.721 ms | 13.010 ms |
| First normal serve worst frame | 169.987 ms | 164.246 ms |
| First normal serve p95 | 32.658 ms | 32.314 ms |
| Repeat normal serve worst frame | 46.855 ms | 41.405 ms |
| Sales-photo assignment after fix | — | 0.003 ms average |

Repeated preparation became slower because PNG work moved there. This change reduces first photo preparation and serving CPU work; it does not eliminate image-preparation stalls or the first-serve hitch. Remaining investigation should distinguish first-use rendering/resource setup from delayed callbacks around the burger launch. The present evidence does not identify that root cause.

## Validation and evidence

Both rendered runs completed all serving assertions without script errors. Known texture RID shutdown warnings remain. The targeted burger_photo_cache_smoke test passed: sales PNG dimensions/transparency/color, review PNG dimensions, full-feed cached bytes, guest delta image decoding, and isolation of cached ingredient images when callers resize them. This is serialization coverage, not a new live two-player session.

Raw results: build/gameplay_hitch_audit_20261011/burger_photo_probe.json and burger_photo_fixed.json, with matching logs. Targeted test log: build/multiplayer_release/burger_photo_cache_smoke.log.


## Follow-up: fresh-process first-use controls

The earlier same-session ablations did not rule out first-use initialization. This follow-up launches a fresh process for each mode, applies exclusions before the first burger is prepared, and traces global frame numbers. Source changes retain all normal gameplay feedback.

| Fresh-process condition | Burger worst frame | p95 | Frames over 100 ms |
|---|---:|---:|---:|
| No photos, reviews, or history from startup | 166.436 ms | 32.561 ms | 1 |
| Normal, inactive sales-page rebuild fixed | 167.188 ms | 24.899 ms | 1 |
| Completion light disabled | 157.035 ms | 31.504 ms | 1 |
| Profit/flash/fresh-reward feedback disabled | 46.755 ms | 31.940 ms | 0 |
| Static reward font warmup, all features enabled | 80.688 ms | 32.107 ms | 0 |
| Animated reward font warmup, all features enabled | 82.954 ms | 32.615 ms | 0 |
| Reward font plus total digits, all features enabled | 78.151 ms | 31.304 ms | 0 |

The first-use feedback path is a demonstrated contributor. Disabling all photo composition, review commits, and history recording before the first serve still left a 166 ms spike. In the normal instrumented run, scoring ended at global frame 3466 and the 167 ms interval ended at frame 3467. Review publication was much later. Graphics specialization counters advanced four frames later; this alone does not establish graphics compilation as the stall cause.

Removing profit/flash/fresh-reward feedback reduced the whole serving window maximum to 46.755 ms. Warming the reward/profit font, outlines, sparkle labels, animated scale, and large points-total digits during loading reduced the fully enabled run to 78.151 ms (53.3% below 167.188 ms). Intermediate warmup variants measured 80.688 and 82.954 ms. These are progressively refined variants, not three identical statistical repetitions. The evidence does not yet distinguish every glyph or label contribution, and a roughly 78 ms first-serve stall remains.

Also fixed: inactive sales pages no longer rebuild their full ledger or decode images on every sale/review. Opening the page rebuilds current rows. Visible refreshes reuse decoded textures until photo bytes change; removed orders release cached images on the next visible rebuild. Authoritative order recording measured about 0.02 ms afterward.

Validation: all seven rendered diagnostic runs completed serving assertions without script errors. Known shutdown texture RID warnings remain. order_insights_cache_smoke passed hidden-page, image reuse, image replacement, and removal checks. Final run fries maximum: 57.905 ms; chef reward burst: 44.936 ms. No new two-process multiplayer session was run in this follow-up; packet formats and authoritative gameplay logic are unchanged.

Raw paired JSON/log artifacts are under build/gameplay_hitch_audit_20261011 with the seven first_serve_* names in the table order above. The final shipped candidate is first_serve_reward_digits.
