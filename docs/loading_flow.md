# Loading and truck opening

The complete twenty-second night-street walking clip plays. During it, five small shader resources load asynchronously, one at a time with 150 ms spacing. No scene construction or GPU warmup runs during playback. There is no minimum preparation hold. Essential kitchen geometry, food, interactions and first-use effects finish before opening.

Only representative legacy/custom customer rigs are warmed during preparation. Exhaustively constructing all saved appearances is no longer a background job, avoiding large scene-construction stalls during play.

The six-second truck opening locks input, raises the shutter, restores sunlight, drops the bunting and flips the sign. The opening jingle ends with Burger Pals. Optional jobs do not hold this sequence open.

Procedural audio uses worker threads with 80 ms gaps between cache entries. Spare patties are generated off-thread, then added one at a time at least 250 ms apart during gameplay, waiting while a burger handoff is active. A refill guard prevents overlapping producers. Initial cooking stock and core rendering warmups remain upfront.

Validation: tests/full_loading_flow_smoke.gd and tests/truck_opening_smoke.gd.
