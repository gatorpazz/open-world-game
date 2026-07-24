extends GutTest
## HudPrompt (spec 025 fix): the interaction prompt shows with a target during
## free gameplay, hides while a panel pauses the tree, and returns when it
## unpauses (the raycast detector that feeds it is frozen while paused).

const PROMPT_SCENE := preload("res://scenes/ui/hud_prompt.tscn")

var _prompt: HudPrompt
var _target: Interactable


func before_each() -> void:
	_prompt = PROMPT_SCENE.instantiate() as HudPrompt
	add_child_autofree(_prompt)
	_target = Interactable.new()
	_target.display_name = "Wren"
	_target.verb = &"talk"
	add_child_autofree(_target)


func after_each() -> void:
	get_tree().paused = false


func test_shows_with_a_target_hides_while_paused_and_returns() -> void:
	_prompt.set_target(_target)
	assert_true(_prompt.visible, "shown with a target during gameplay")
	assert_eq(_prompt.label.text, "Talk Wren", "the prompt reads the verb + name")

	get_tree().paused = true
	await get_tree().process_frame  # process_mode ALWAYS sees the transition
	assert_false(_prompt.visible, "hidden while a panel pauses the tree")

	get_tree().paused = false
	await get_tree().process_frame
	assert_true(_prompt.visible, "restored when the panel closes")


func test_no_target_stays_hidden() -> void:
	_prompt.set_target(null)
	assert_false(_prompt.visible, "no target, no prompt")
