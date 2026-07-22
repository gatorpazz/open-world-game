class_name FactionRules
extends RefCounted
## Pure faction rules (spec 015): the fixed logic that combines a FactionDef
## with the player's FactionStanding — membership seeding, advancement
## eligibility, charter, and joining exclusivity. All static, no scene tree,
## resolvers passed in (the SaveCodec pattern). Nothing here reads Game;
## reconcile mutates only the standing it is handed.


## Seeds a record for every faction whose join_journal_entry is held but has
## no record yet. Idempotent (seed_if_absent never touches an existing
## record), so this is safe to run at every identity setup AND is the core of
## the v1->v2 save migration — a v1 save is just a v2 save whose faction
## records have not been seeded yet.
static func reconcile(
	standing: FactionStanding,
	journal_entries: Array[StringName],
	library: Dictionary[StringName, FactionDef]
) -> void:
	for faction_id: StringName in library:
		var def := library[faction_id]
		if def.join_journal_entry == &"":
			continue
		if not journal_entries.has(def.join_journal_entry):
			continue
		var start_reputation := 0
		if not def.ranks.is_empty():
			start_reputation = def.ranks[0].reputation_min
		standing.seed_if_absent(faction_id, 0, start_reputation)


## True when the player is a member with a next rank they now qualify for —
## reputation meets the next rank's floor AND (no skill gate, or the governing
## skill meets its minimum). False at the top rank or for a non-member.
static func can_advance(def: FactionDef, standing: FactionStanding, sheet: CharacterSheet) -> bool:
	if not standing.is_member(def.id):
		return false
	var next_index := standing.get_rank(def.id) + 1
	if next_index >= def.ranks.size():
		return false
	var next_rank := def.ranks[next_index]
	if standing.get_reputation(def.id) < next_rank.reputation_min:
		return false
	if next_rank.skill_id == &"":
		return true
	var skill_level := 0
	if sheet.skills.has(next_rank.skill_id):
		skill_level = sheet.skills[next_rank.skill_id]
	return skill_level >= next_rank.skill_min


## True when the player holds a charter from this faction — a member at or
## above its charter_rank. charter_rank == -1 means the faction never
## charters. 018 gates the 008 casting tiers on this.
static func is_chartered_under(
	faction_id: StringName, standing: FactionStanding, library: Dictionary[StringName, FactionDef]
) -> bool:
	if not library.has(faction_id):
		return false
	var def := library[faction_id]
	if def.charter_rank < 0:
		return false
	if not standing.is_member(faction_id):
		return false
	return standing.get_rank(faction_id) >= def.charter_rank


## True when joining def is barred because the player already belongs to one
## of its rivals. Always false for shipped content (empty rivals) — the
## mechanism the independence ruling keeps dormant.
static func blocks_joining(def: FactionDef, standing: FactionStanding) -> bool:
	for rival: StringName in def.rivals:
		if standing.is_member(rival):
			return true
	return false
