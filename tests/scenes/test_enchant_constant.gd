extends GutTest
## Constant worn-charm hook (spec 023, acceptance criterion 4): a `resist` charm
## raises the effective armor, a `fortify` charm raises the effective skill, and
## unequipping removes both. Standalone stats+inventory (the barter-test shape).

var _stats: StatsComponent
var _ic: InventoryComponent


func before_each() -> void:
	_stats = StatsComponent.new()
	add_child_autofree(_stats)
	_ic = InventoryComponent.new()
	_ic.stats = _stats
	add_child_autofree(_ic)


func _ring_charm(effect: StringName, magnitude: float, subject := &"") -> ArmorDef:
	var working := BoundWorkingDef.new()
	working.id = StringName("test_charm_%s_%s" % [effect, subject])
	working.trigger = &"constant"
	working.effect = effect
	working.magnitude = magnitude
	working.subject = subject
	var ring := ArmorDef.new()
	ring.id = StringName("test_ring_%s_%s" % [effect, subject])
	ring.display_name = "Test Charm Ring"
	ring.slot = &"ring"
	ring.armor_rating = 0
	ring.bound_working = working
	return ring


func _equip(item: ItemDef) -> void:
	_ic.add_item(item)
	assert_true(_ic.equip(item), "equipped %s" % item.id)


func test_a_worn_resist_charm_raises_effective_armor() -> void:
	var base := _ic.get_effective_armor_rating()
	_equip(_ring_charm(&"resist", 12.0))

	assert_eq(_ic.get_effective_armor_rating(), base + 12, "the resist charm adds to armor")

	_ic.unequip(&"ring_1")
	assert_eq(_ic.get_effective_armor_rating(), base, "unequipping removes the bonus")


func test_a_worn_fortify_charm_raises_only_its_subject_skill() -> void:
	var blades_base := _ic.effective_skill(&"blades")
	var security_base := _ic.effective_skill(&"security")
	_equip(_ring_charm(&"fortify", 10.0, &"blades"))

	assert_eq(_ic.effective_skill(&"blades"), blades_base + 10, "fortify lifts blades")
	assert_eq(_ic.effective_skill(&"security"), security_base, "a different skill is untouched")

	_ic.unequip(&"ring_1")
	assert_eq(_ic.effective_skill(&"blades"), blades_base, "unequipping removes the fortify")
