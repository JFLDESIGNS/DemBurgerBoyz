Armed hostile / terrorist wave code — shelved for now.

Files:
  terrorist_customer.gd — gunmen, bombers, ragdolls, hand-mounted pistols

To re-enable:
  1. Copy terrorist_customer.gd back to scripts/terrorist_customer.gd
  2. In scripts/game.gd set TERRORISTS_ENABLED := true
  3. Uncomment TerroristCustomerScript preload and spawn hooks in game.gd
  4. Uncomment bodies in _spawn_terrorist_wave / _spawn_opening_terrorist / _spawn_terrorist_unit
