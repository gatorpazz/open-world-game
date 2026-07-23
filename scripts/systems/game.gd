extends Node
## Autoload "Game" — the only sanctioned global (spec 003). Owns the player's
## persistent identity (CharacterSheet + Inventory, plus the Journal per
## spec 005) and performs spawn-point scene changes; the player NODE is
## instanced fresh per scene and the identity resources are injected into it.
## Save/load (spec 007) serializes what this node holds. No other global
## state goes here without a spec saying so.
##
## Deliberately no class_name: it would collide with the autoload name.
## Tests preload this script by path instead.

## Emitted when the whole bell or the day rolls over (not every frame) — the HUD
## clock and scheduled NPCs listen (spec 020).
signal time_changed(day: int, bell: int)

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const SPAWN_GROUP := &"spawn_points"
const DEFAULT_SAVE_PATH := "user://save.json"
const DEFAULT_SAVES_DIR := "user://saves"
## The new-game starting world (spec 010): the player wakes in the bait
## square. main.tscn survives as the greybox test target.
const MAIN_SCENE_PATH := "res://scenes/world/bait_square.tscn"
const TITLE_SCENE_PATH := "res://scenes/ui/title_screen.tscn"

var character_sheet: CharacterSheet
var inventory: Inventory
var journal: Journal
## The one sanctioned player bank (spec 016): a Game-owned Inventory separate
## from what the player carries, deposited into at the Lastdoor stash chest and
## serialized as its own save section. The world-state-from-journal fence holds
## — this is identity, not world state.
var stash: Inventory
## Per-faction reputation + rank (spec 015), the numeric layer over the
## joined_* journal entries. Reconciled from the journal at every scene entry
## and restored whole on load; SaveCodec serializes it.
var faction_standing: FactionStanding
## Per-jurisdiction bounty (spec 017): the legal debt a witnessed theft accrues,
## cleared by paying a warden's fine. Identity, not world state — SaveCodec
## serializes it (its own section, SAVE_VERSION 4).
var bounty: BountyLedger
## Notice (spec 018): the never-clearing regard an unlicensed working draws;
## past its threshold the caster is overcast. Identity — SaveCodec serializes it
## (its own section, SAVE_VERSION 5).
var notice: NoticeLedger
## The in-game clock (spec 020): circuit-day + bell-of-day, advanced in real time
## by _process and by rest. Identity — SaveCodec serializes it (its own section,
## SAVE_VERSION 6). time_changed fires on each bell/day rollover.
var clock: WorldClock
## Per-NPC disposition modifier (spec 019): the regard a persuasion move shifts,
## one term of the effective disposition (DispositionRules composes it with base,
## faction reputation, and overcast). Identity — SaveCodec serializes it (its own
## section, SAVE_VERSION 7).
var disposition: DispositionLedger
## Total real seconds played (spec 025): ticked in _process during gameplay,
## shown in save-slot metadata. Identity — SaveCodec serializes it (SAVE_VERSION
## 8).
var playtime_seconds: float = 0.0

## The legacy single-save path (pre-025): adopted once as the quicksave slot.
## Tests point this at a scratch file.
var save_path := DEFAULT_SAVE_PATH
## The save-slots directory (spec 025): quicksave + numbered manual slots live
## here. Tests point this at a scratch dir so they never touch a real save.
var saves_dir := DEFAULT_SAVES_DIR

## Parent of world scenes. Tests point this at a sandbox node; scene swaps
## only ever free worlds parented here, so Game can never free the test runner.
var world_parent: Node
var current_world: Node = null
var player: Player = null

## The balance config, loaded once for the real-time clock tick (spec 020).
var _config: BalanceConfig = null
## The last whole bell emitted — the tick only signals on a change.
var _last_bell := -1


func _ready() -> void:
	character_sheet = StatsComponent.build_default_sheet(
		StatsComponent.DEFAULT_MAJOR_SKILLS.duplicate()
	)
	inventory = Inventory.new()
	journal = Journal.new()
	faction_standing = FactionStanding.new()
	stash = Inventory.new()
	bounty = BountyLedger.new()
	notice = NoticeLedger.new()
	clock = WorldClock.new()
	disposition = DispositionLedger.new()
	_config = load(StatsComponent.BALANCE_PATH) as BalanceConfig
	world_parent = get_tree().root
	_adopt_boot_scene.call_deferred()


## The real-time bell clock (spec 020): advances only during gameplay (a world +
## player), so headless tests without a world never drift. Emits time_changed
## when the whole bell or the day rolls over, not every frame.
func _process(delta: float) -> void:
	if current_world == null or player == null:
		return
	playtime_seconds += delta
	clock.advance(delta / _config.real_seconds_per_bell, _config)
	if clock.get_bell() != _last_bell:
		_last_bell = clock.get_bell()
		time_changed.emit(clock.get_day(), clock.get_bell())


## Advances the clock by `bells` (spec 020 — rest; later fast-travel), emitting
## time_changed so the HUD and scheduled NPCs update. Game owns the tick, so the
## signal stays here and the _process dedup is kept consistent.
func advance_time(bells: float) -> void:
	clock.advance(bells, _config)
	_last_bell = clock.get_bell()
	time_changed.emit(clock.get_day(), clock.get_bell())


## Morrowind-style load-door transition. Deferred: it is triggered from
## interaction signal chains inside the very scene about to be freed.
func change_scene(scene_path: String, spawn_point: StringName) -> void:
	_change_scene_now.call_deferred(scene_path, spawn_point)


## Death reload (spec 004): re-enter the current world at its default
## spawn. World state resets while the persistent identity survives.
## Since spec 007 the death overlay prefers load_game(); this remains
## the fallback when no save exists, and the F6 debug path.
func reload_current_scene() -> void:
	if current_world == null or current_world.scene_file_path.is_empty():
		push_warning("reload_current_scene: no reloadable current world")
		return
	change_scene(current_world.scene_file_path, &"default")


## New-game commit point (spec 009): adopts the sheet character creation
## built, resets the rest of the identity wholesale — a new game is a whole
## new identity — and enters the starting world. The default sheet built in
## _ready remains the F6 debug fallback.
func start_new_game(sheet: CharacterSheet) -> void:
	character_sheet = sheet
	inventory = Inventory.new()
	journal = Journal.new()
	faction_standing = FactionStanding.new()
	stash = Inventory.new()
	bounty = BountyLedger.new()
	notice = NoticeLedger.new()
	clock = WorldClock.new()
	disposition = DispositionLedger.new()
	playtime_seconds = 0.0
	_last_bell = -1  # force a resync time_changed on the next tick
	change_scene(MAIN_SCENE_PATH, &"default")


## Returns to the title screen (spec 025 pause menu → Quit to Title). Clears the
## play refs so the real-time tick stops, then swaps the whole scene to the title
## — a menu, not a world, so it spawns no player. Deferred (a scene swap from an
## input handler must not run mid-frame); the caller unpauses.
func quit_to_title() -> void:
	current_world = null
	player = null
	get_tree().change_scene_to_file.call_deferred(TITLE_SCENE_PATH)


## Whether any save slot exists (spec 025) — Continue is offered when so. Adopts
## a legacy save.json into the quicksave slot first (once).
func has_save() -> bool:
	SaveSlots.adopt_legacy(saves_dir, save_path)
	for slot_id: StringName in SaveSlots.SLOT_IDS:
		if SaveSlots.exists(saves_dir, slot_id):
			return true
	return false


## Whether the player holds a charter from the named faction (spec 015):
## a member at or above its charter_rank. 018 gates the casting tiers on this.
func is_chartered_under(faction_id: StringName) -> bool:
	return FactionRules.is_chartered_under(
		faction_id, faction_standing, FactionLibrary.get_factions()
	)


## Records a witnessed theft (spec 017): the jurisdiction's bounty rises and,
## if the player is one of its members, its reputation is docked. Game mutates
## its own state — the Theft orchestrator computes the amounts (from CrimeRules
## + the balance config) and calls down, the save_game/change_scene precedent.
func report_theft(jurisdiction: StringName, bounty_amount: int, reputation_dock: int) -> void:
	_record_offense(jurisdiction, bounty_amount, reputation_dock)


## Records a witnessed unlicensed working (spec 018): the same legal path as a
## theft — the jurisdiction's bounty rises and, for a member, its reputation is
## docked. Notice (the magical mark) accrues separately, on Game.notice. The
## Working orchestrator computes the amounts.
func report_working(jurisdiction: StringName, bounty_amount: int, reputation_dock: int) -> void:
	_record_offense(jurisdiction, bounty_amount, reputation_dock)


## Records crossing into overcast (spec 018): a one-time reputation dock with
## the jurisdiction — being permanently remarkable is a standing mark. No bounty
## (that is the witnessed-working path) and the notice is already on the ledger.
## Game mutates its own state.
func report_overcast(jurisdiction: StringName, reputation_dock: int) -> void:
	faction_standing.adjust_reputation(jurisdiction, -reputation_dock)


## The shared legal consequence of a witnessed offense (theft or working): a
## jurisdiction bounty plus a reputation dock. Game mutates only its own state.
func _record_offense(jurisdiction: StringName, bounty_amount: int, reputation_dock: int) -> void:
	bounty.add_bounty(jurisdiction, bounty_amount)
	faction_standing.adjust_reputation(jurisdiction, -reputation_dock)


## Records the outcome of a persuasion move (spec 019): shifts the NPC's standing
## disposition modifier. The Persuasion orchestrator computes the delta (a move's
## gain, or an intimidate backfire). Game mutates only its own state.
func report_persuasion(npc_id: StringName, delta: int) -> void:
	disposition.adjust(npc_id, delta)


## An NPC's effective disposition (spec 019): composes base + faction reputation
## + the per-NPC modifier − overcast through the pure DispositionRules from the
## three Game ledgers it owns. The one place the composition's Game reads live —
## the dialogue gate and the barter price nudge both call here.
func disposition_of(npc_def: NPCDef, config: BalanceConfig) -> int:
	var faction_rep := 0
	if npc_def.faction != &"":
		faction_rep = faction_standing.get_reputation(npc_def.faction)
	return (
		DispositionRules
		. disposition(
			DispositionRules.base_of(npc_def, config),
			faction_rep,
			disposition.get_modifier(npc_def.id),
			notice.is_overcast(config.overcast_threshold),
			config,
		)
	)


## Saves to a slot (spec 007 + 025): snapshots the identity resources, the
## current scene, and the player's transform and pools into the slot, wrapped
## under a metadata header. Defaults to the quicksave slot (F5). The caller shows
## any notice — Game stays UI-free.
func save_game(slot_id := SaveSlots.QUICKSAVE) -> bool:
	if current_world == null or current_world.scene_file_path.is_empty() or player == null:
		push_warning("save_game: nothing saveable (no current world or player)")
		return false
	SaveSlots.adopt_legacy(saves_dir, save_path)  # consume an orphaned legacy save first
	var state := SaveCodec.SaveState.new()
	state.scene_path = current_world.scene_file_path
	state.player_transform = player.global_transform
	state.head_pitch = player.head.rotation.x
	state.current_health = player.stats.current_health
	state.current_mana = player.stats.current_mana
	state.current_stamina = player.stats.current_stamina
	state.sheet = character_sheet
	state.inventory = inventory
	state.journal = journal
	state.faction_standing = faction_standing
	state.stash = stash
	state.bounty = bounty
	state.notice = notice
	state.clock = clock
	state.disposition = disposition
	state.playtime = playtime_seconds
	return SaveSlots.write(saves_dir, slot_id, _build_save_meta(), SaveCodec.encode_save(state))


## The save-slot metadata header (spec 025): a display-only summary read cheaply
## by the save/load menu, built fresh each save.
func _build_save_meta() -> Dictionary:
	return {
		"saved": Time.get_datetime_string_from_system(),
		"day": clock.get_day(),
		"bell": clock.get_bell(),
		"scene": current_world.scene_file_path,
		"level": character_sheet.level,
		"playtime": playtime_seconds,
	}


## Loads a slot (spec 007 + 025). Decodes the whole payload before touching any
## state — a missing, corrupt, or tampered save returns false with Game exactly
## as it was. Defaults to the quicksave slot (F9). The apply is deferred: callers
## fire from input handlers inside the very scene about to be freed.
func load_game(slot_id := SaveSlots.QUICKSAVE) -> bool:
	SaveSlots.adopt_legacy(saves_dir, save_path)
	var payload := SaveSlots.read_payload(saves_dir, slot_id)
	if payload.is_empty():
		push_warning("load_game: no readable save in slot '%s'" % slot_id)
		return false
	var balance := load(StatsComponent.BALANCE_PATH) as BalanceConfig
	var state := SaveCodec.decode_save(
		payload, balance, ItemLibrary.get_items(), FactionLibrary.get_factions()
	)
	if state == null:
		return false
	_apply_load.call_deferred(state)
	return true


## Instances a fresh player at the named spawn marker and injects the
## persistent identity — before add_child, so the player's components skip
## building defaults in _ready.
func spawn_player(world: Node, spawn_point: StringName) -> Player:
	_reconcile_factions()
	var new_player: Player = PLAYER_SCENE.instantiate()
	new_player.setup_identity(character_sheet, inventory, journal)
	world.add_child(new_player)
	var marker := find_spawn_point(world, spawn_point)
	if marker != null:
		new_player.global_transform = marker.global_transform
	else:
		push_error("No spawn point '%s' in '%s'; spawning at origin." % [spawn_point, world.name])
	player = new_player
	return new_player


## The Marker3D in group "spawn_points" whose node name matches, or null.
## Searches the subtree, so it works on worlds not yet in the scene tree.
static func find_spawn_point(world: Node, spawn_point: StringName) -> Marker3D:
	for node: Node in world.find_children("*", "Marker3D", true, false):
		if node.is_in_group(SPAWN_GROUP) and node.name == spawn_point:
			return node as Marker3D
	return null


## F6 convention: every playable scene has a "default" spawn marker. If the
## scene we booted into has one, spawn the player there through the same
## injection path as a real transition. Scenes without one (2D debug scenes,
## the test runner) leave Game inert.
func _adopt_boot_scene() -> void:
	current_world = get_tree().current_scene
	if current_world == null:
		return
	if find_spawn_point(current_world, &"default") == null:
		return
	spawn_player(current_world, &"default")


## The commit point of a load: the decoded resources replace the identity,
## the saved world is re-entered (its JournalGates _ready against the
## restored journal — the 006 cell-reload model), and the exact transform
## and pools are applied in the same call stack, so the spawn-marker
## positioning in spawn_player cannot win over them.
func _apply_load(state: SaveCodec.SaveState) -> void:
	character_sheet = state.sheet
	inventory = state.inventory
	journal = state.journal
	faction_standing = state.faction_standing
	stash = state.stash
	bounty = state.bounty
	notice = state.notice
	clock = state.clock
	disposition = state.disposition
	playtime_seconds = state.playtime
	_last_bell = -1  # force a resync time_changed to the loaded time on the next tick
	_change_scene_now(state.scene_path, &"default")
	player.global_transform = state.player_transform
	player.head.rotation.x = state.head_pitch
	player.stats.set_current_health(state.current_health)
	player.stats.set_current_mana(state.current_mana)
	player.stats.set_current_stamina(state.current_stamina)


func _change_scene_now(scene_path: String, spawn_point: StringName) -> void:
	var next: Node = (load(scene_path) as PackedScene).instantiate()
	if current_world != null and current_world.get_parent() == world_parent:
		world_parent.remove_child(current_world)
		current_world.queue_free()
	world_parent.add_child(next)
	if world_parent == get_tree().root:
		get_tree().current_scene = next
	current_world = next
	spawn_player(next, spawn_point)


## Seeds a faction record for every joined_* entry the journal holds (spec
## 015), at every scene entry — the 006 cell-reload cadence. Idempotent, so a
## reputation dock or rank-up is never reset. Guarded for the debug/test paths
## that drive spawn_player before identity is built.
func _reconcile_factions() -> void:
	if faction_standing == null or journal == null:
		return
	FactionRules.reconcile(faction_standing, journal.entries, FactionLibrary.get_factions())
