extends SceneTree
func _initialize():call_deferred("run")
func run():
 var cards=load("res://scripts/card_table.gd")
 assert(cards.total([12,25,7])==21)
 assert(cards.rank_hand([8,9,10,11,12])>cards.rank_hand([0,13,26,39,1]))
 for file in ["phone_party","phone_gnop","phone_snak","phone_smush","playing_card","game"]:
  assert(load("res://scripts/"+file+".gd").can_instantiate())
 var snake=load("res://scripts/phone_snak.gd").new();root.add_child(snake);snake.set_active(true)
 assert(snake._foods.size()==3 and snake._snake2.is_empty())
 snake.partner=true;snake.join_second();assert(snake._snake2.size()==3)
 snake.handle_key(_key(KEY_UP));snake.second_key(KEY_DOWN,true);snake._process(.16)
 assert(snake._snake[0].y==7 and snake._snake2[0].y==3)
 var session=cards.new();root.add_child(session);session.set_process(false)
 session.players=[1,2];session.mode="draw";session.deal()
 var first=session.view_for(1);var second=session.view_for(2)
 assert(first.hand.size()==5 and second.hand.size()==5)
 for card in first.hand:assert(card not in second.hand)
 assert(not first.has("deck") and not first.has("hands"))
 print("PARTY_RULES_OK");quit()
func _key(code):
 var event=InputEventKey.new();event.keycode=code;event.pressed=true;return event
