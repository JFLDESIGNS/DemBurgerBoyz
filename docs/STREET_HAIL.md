# Sidewalk customer invitations

Click a visible background walker to call "Burger Pals". The host rolls once per sidewalk pass: 50% keep walking, 10% face the truck, point, answer with wawa and walk away angrily, and 40% approach the line as the same custom character and order a burger. Repeated clicks repeat the greeting without rerolling the result.

Accepted invitations wait for a free lane (four customer maximum) or for a closed window, tutorial, boss encounter or scripted entrance to finish. Normal customer serving and co-op replication then take over. Hidden pooled pedestrians cannot intercept clicks.

"Perfect" and "Great job" burger-flip voice clips use half their previous linear gain (approximately -6 dB). Other announcement levels are unchanged.

Validation: tests/street_hail_smoke.gd checks exact probability intervals, repeat clicks, greeting playback, pointing and angry walking, deferred invitations, preserved appearance and movement from the street to the queue. A real kitchen check also exercises the physics click path. Live two-machine co-op has not been exercised.
