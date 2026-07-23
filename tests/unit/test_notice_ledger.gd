extends GutTest
## The NoticeLedger pure helpers (spec 018): monotonic accrual and the overcast
## threshold boundary. Notice never clears.

var _ledger: NoticeLedger


func before_each() -> void:
	_ledger = NoticeLedger.new()


func test_starts_clean() -> void:
	assert_eq(_ledger.get_notice(), 0, "a fresh ledger holds no notice")
	assert_false(_ledger.is_overcast(100), "and is not overcast")


func test_add_accumulates_monotonically() -> void:
	_ledger.add(10)
	_ledger.add(15)
	assert_eq(_ledger.get_notice(), 25, "notice sums; there is no way down")


func test_overcast_at_the_threshold_boundary() -> void:
	_ledger.add(99)
	assert_false(_ledger.is_overcast(100), "just under the threshold is not overcast")
	_ledger.add(1)  # exactly 100
	assert_true(_ledger.is_overcast(100), "at the threshold is overcast (>=)")
	_ledger.add(50)
	assert_true(_ledger.is_overcast(100), "and it stays overcast — notice never falls")
