extends GutTest
## Interactable component behavior (spec 003, supports criterion 1).


func _make_interactable(display_name := "Flawed Gem", verb := &"take") -> Interactable:
	var interactable := Interactable.new()
	interactable.display_name = display_name
	interactable.verb = verb
	return interactable


func test_interact_emits_with_actor() -> void:
	var interactable := _make_interactable()
	add_child_autofree(interactable)
	watch_signals(interactable)
	var actor := Node.new()
	autofree(actor)
	interactable.interact(actor)
	assert_signal_emitted_with_parameters(interactable, "interacted", [actor])


func test_prompt_formats_verb_and_display_name() -> void:
	var interactable := _make_interactable("Flawed Gem", &"take")
	autofree(interactable)
	assert_eq(interactable.get_prompt(), "Take Flawed Gem")


func test_prompt_uses_talk_verb() -> void:
	var interactable := _make_interactable("Hunald", &"talk")
	autofree(interactable)
	assert_eq(interactable.get_prompt(), "Talk Hunald")


func test_find_in_returns_child_interactable() -> void:
	var body := StaticBody3D.new()
	var interactable := _make_interactable()
	body.add_child(interactable)
	add_child_autofree(body)
	assert_eq(Interactable.find_in(body), interactable)


func test_find_in_returns_null_when_absent() -> void:
	var body := StaticBody3D.new()
	add_child_autofree(body)
	assert_null(Interactable.find_in(body))
