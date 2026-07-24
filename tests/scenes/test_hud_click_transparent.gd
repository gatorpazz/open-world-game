extends GutTest
## The HUD is display-only and must never eat the mouse (spec 025 fix): a HUD
## control left at the default MOUSE_FILTER_STOP swallows clicks/hover over any
## panel it overlaps — this is what blocked the top of the dialogue panel. Every
## Control in every HUD scene must be MOUSE_FILTER_IGNORE.

const HUD_SCENES: Array[String] = [
	"res://scenes/ui/hud_clock.tscn",
	"res://scenes/ui/hud_bars.tscn",
	"res://scenes/ui/hud_notice.tscn",
	"res://scenes/ui/hud_spell.tscn",
	"res://scenes/ui/hud_prompt.tscn",
]


func _check(node: Node, scene: String) -> void:
	if node is Control:
		assert_eq(
			(node as Control).mouse_filter,
			Control.MOUSE_FILTER_IGNORE,
			"%s: %s must ignore the mouse (display-only HUD)" % [scene, node.name]
		)
	for child: Node in node.get_children():
		_check(child, scene)


func test_every_hud_control_ignores_the_mouse() -> void:
	for path: String in HUD_SCENES:
		var hud := (load(path) as PackedScene).instantiate()
		_check(hud, path)
		hud.free()
