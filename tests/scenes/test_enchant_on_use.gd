extends GutTest
## On-use bound-working charge (spec 023, acceptance criterion 5): using a heal
## bead restores health scaled by the mending skill (the ratified give-back) and
## consumes the single-use charge; a charge not held is a no-op.

var _stats: StatsComponent
var _ic: InventoryComponent


func before_each() -> void:
	_stats = StatsComponent.new()
	add_child_autofree(_stats)
	_ic = InventoryComponent.new()
	_ic.stats = _stats
	add_child_autofree(_ic)


func _heal_bead(magnitude: float) -> MiscDef:
	var working := BoundWorkingDef.new()
	working.id = &"test_tide_charge"
	working.trigger = &"on_use"
	working.effect = &"heal"
	working.skill_id = &"mending"
	working.magnitude = magnitude
	var bead := MiscDef.new()
	bead.id = &"test_tide_bead"
	bead.display_name = "Test Tide Bead"
	bead.bound_working = working
	return bead


func test_using_a_heal_bead_restores_health_and_consumes_it() -> void:
	var bead := _heal_bead(20.0)
	_ic.add_item(bead)
	_stats.set_current_health(1.0)
	var skill: int = _stats.sheet.skills.get(&"mending", 0)
	var expected := EnchantRules.magnitude(bead.bound_working, skill, _stats.sheet.config)
	var before := _stats.current_health

	assert_true(_ic.use_bound_working(bead), "the charge triggers")

	assert_almost_eq(
		_stats.current_health, before + expected, 0.01, "healed by the mending-scaled magnitude"
	)
	assert_eq(_ic.inventory.count_of(bead), 0, "the single-use charge is consumed")


func test_using_a_charge_not_held_is_a_noop() -> void:
	var bead := _heal_bead(20.0)  # never added to the inventory
	assert_false(_ic.use_bound_working(bead), "no charge to use")


func test_a_plain_item_has_no_on_use_working() -> void:
	assert_false(_ic.use_bound_working(MiscDef.new()), "a plain item triggers nothing")
