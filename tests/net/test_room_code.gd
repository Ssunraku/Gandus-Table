extends GutTest


func test_generated_codes_are_4_allowed_letters() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(500):
		var c: String = RoomCode.generate(rng)
		assert_eq(c.length(), 4)
		assert_true(RoomCode.is_valid(c), c)
		assert_false(c.contains("I") or c.contains("O"), c)


func test_normalize_accepts_any_case_and_spaces() -> void:
	assert_eq(RoomCode.normalize(" abcd "), "ABCD")
	assert_eq(RoomCode.normalize("wxyz"), "WXYZ")


func test_normalize_rejects_wrong_length_and_bad_letters() -> void:
	for bad in ["ABC", "ABCDE", "AB1D", "ABOD", "ABID", "", "    ", "AB D", "ÄBCD"]:
		assert_eq(RoomCode.normalize(bad), "", bad)
