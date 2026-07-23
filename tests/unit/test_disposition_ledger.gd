extends GutTest
## DispositionLedger (spec 019): the per-NPC modifier map — get defaults to 0,
## adjust accumulates and can go negative (a failed intimidate docks it).


func test_unknown_npc_reads_zero() -> void:
	var ledger := DispositionLedger.new()
	assert_eq(ledger.get_modifier(&"suddel"), 0, "no record reads 0")


func test_adjust_accumulates() -> void:
	var ledger := DispositionLedger.new()
	ledger.adjust(&"suddel", 6)
	ledger.adjust(&"suddel", 8)
	assert_eq(ledger.get_modifier(&"suddel"), 14, "moves accumulate")


func test_adjust_can_go_negative() -> void:
	var ledger := DispositionLedger.new()
	ledger.adjust(&"tansy", -10)
	assert_eq(ledger.get_modifier(&"tansy"), -10, "a failed intimidate docks below zero")


func test_ledgers_are_per_npc() -> void:
	var ledger := DispositionLedger.new()
	ledger.adjust(&"suddel", 5)
	assert_eq(ledger.get_modifier(&"tansy"), 0, "one NPC's regard does not leak to another")
