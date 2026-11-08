extends GutTest


func test_make_adds_version_type_and_seq() -> void:
	var m: Dictionary = Protocol.make("bid", {"x": 1}, 7)
	assert_eq(m["v"], Protocol.VERSION)
	assert_eq(m["type"], "bid")
	assert_eq(m["seq"], 7)
	assert_eq(m["x"], 1)


func test_encode_decode_round_trip() -> void:
	var m: Dictionary = Protocol.decode(Protocol.encode(Protocol.make("play_card", {"card": {"s": 3, "r": 14}}, 4)))
	assert_eq(m["type"], "play_card")
	assert_eq(int(m["card"]["r"]), 14)


func test_decode_rejects_garbage_text() -> void:
	for t in ["hello", "", "[1,2]", "{", "null", "42"]:
		assert_true(Protocol.decode(t).is_empty(), t)


func test_decode_rejects_unknown_type() -> void:
	assert_true(Protocol.decode('{"v":1,"type":"hack","seq":0}').is_empty())
	assert_true(Protocol.decode('{"v":1,"seq":0}').is_empty())


func test_decode_rejects_wrong_version() -> void:
	assert_true(Protocol.decode('{"v":2,"type":"bid","seq":0}').is_empty())
	assert_true(Protocol.decode('{"type":"bid","seq":0}').is_empty())


func test_decode_rejects_oversized_text() -> void:
	var big: String = '{"v":1,"type":"leave","seq":0,"pad":"%s"}' % "x".repeat(17000)
	assert_true(Protocol.decode(big).is_empty())


func test_decoded_numbers_are_ints() -> void:
	var m: Dictionary = Protocol.decode('{"v":1,"type":"leave","seq":5}')
	assert_eq(typeof(m["seq"]), TYPE_INT)
	assert_eq(typeof(m["v"]), TYPE_INT)
