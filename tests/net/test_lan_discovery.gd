extends GutTest
## Host and finder talking over this computer's loopback (127.0.0.1), on test ports.

const PORT: int = 24790

var host_side: LanDiscovery
var finder: LanDiscovery
var info: Dictionary = {"code": "ABCD", "name": "Sam", "game_port": 24680, "free_seats": 3, "exact": 0}


func before_each() -> void:
	host_side = LanDiscovery.new()
	host_side.port = PORT
	finder = LanDiscovery.new()
	finder.port = PORT
	finder.query_address = "127.0.0.1"
	finder.query_interval_ms = 100


func after_each() -> void:
	host_side.stop_advertising()
	finder.stop_searching()


func _wait_until(cond: Callable, seconds: float = 3.0) -> bool:
	var end: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		host_side.poll()
		finder.poll()
		if cond.call():
			return true
		OS.delay_msec(5)
	return cond.call()


func test_a_search_finds_the_advertising_host() -> void:
	assert_eq(host_side.advertise(info), OK)
	assert_eq(finder.search(), OK)
	assert_true(_wait_until(func() -> bool: return finder.found.size() == 1))
	var g: Dictionary = finder.found[0]
	assert_eq(g["code"], "ABCD")
	assert_eq(g["name"], "Sam")
	assert_eq(g["port"], 24680)
	assert_eq(g["free_seats"], 3)
	assert_eq(g["address"], "127.0.0.1")


func test_a_search_with_the_right_code_finds_it_and_a_wrong_code_finds_nothing() -> void:
	host_side.advertise(info)
	finder.search("ABCD")
	assert_true(_wait_until(func() -> bool: return finder.found.size() == 1))
	finder.stop_searching()
	finder.search("WXYZ")
	assert_false(_wait_until(func() -> bool: return finder.found.size() > 0, 0.6))


func test_an_updated_free_seat_count_is_seen() -> void:
	host_side.advertise(info)
	finder.search()
	assert_true(_wait_until(func() -> bool: return finder.found.size() == 1))
	var updated: Dictionary = info.duplicate()
	updated["free_seats"] = 1
	host_side.update_info(updated)
	assert_true(_wait_until(func() -> bool: return finder.found.size() == 1 and finder.found[0]["free_seats"] == 1))
	assert_eq(finder.found.size(), 1, "no duplicates")


func test_stopping_the_advertiser_makes_the_game_expire_from_the_list() -> void:
	finder.expire_ms = 400
	host_side.advertise(info)
	finder.search()
	assert_true(_wait_until(func() -> bool: return finder.found.size() == 1))
	host_side.stop_advertising()
	assert_true(_wait_until(func() -> bool: return finder.found.is_empty(), 3.0))


func test_garbage_and_oversized_packets_are_ignored() -> void:
	host_side.advertise(info)
	var noisy: PacketPeerUDP = PacketPeerUDP.new()
	noisy.set_dest_address("127.0.0.1", PORT)
	noisy.put_packet("hello".to_utf8_buffer())
	noisy.put_packet("{}".to_utf8_buffer())
	noisy.put_packet('{"gt":2,"q":"find"}'.to_utf8_buffer())
	noisy.put_packet(("x".repeat(2000)).to_utf8_buffer())
	noisy.put_packet(PackedByteArray())
	_wait_until(func() -> bool: return false, 0.3)
	finder.search()
	assert_true(_wait_until(func() -> bool: return finder.found.size() == 1), "the host still answers a real query")
	noisy.close()


func test_a_finder_ignores_bad_replies() -> void:
	finder.search()
	var fake_host: PacketPeerUDP = PacketPeerUDP.new()
	fake_host.bind(PORT)
	var guard: int = 0
	var replies: Array[String] = [
		'{"gt":1,"r":"here","code":"ZZZ","name":"x","port":24680,"free":1}',
		'{"gt":1,"r":"here","code":"ABCD","name":"x","port":99999,"free":1}',
		'{"gt":1,"r":"here","code":"ABCD","name":5,"port":24680,"free":"many"}',
		'not json',
	]
	while guard < 60:
		guard += 1
		finder.poll()
		if fake_host.get_available_packet_count() > 0:
			fake_host.get_packet()
			fake_host.set_dest_address(fake_host.get_packet_ip(), fake_host.get_packet_port())
			for r in replies:
				fake_host.put_packet(r.to_utf8_buffer())
		OS.delay_msec(10)
	for g in finder.found:
		assert_true(RoomCode.is_valid(g["code"]))
		assert_true(g["port"] >= 1 and g["port"] <= 65535)
	assert_lte(finder.found.size(), 1, "only the one reply that was acceptable at all")
	fake_host.close()


func test_local_addresses_are_private_ipv4_only() -> void:
	for a in LanDiscovery.local_addresses():
		var p: PackedStringArray = a.split(".")
		assert_eq(p.size(), 4, a)
		var first: int = int(p[0])
		var second: int = int(p[1])
		assert_true(first == 10 or (first == 192 and second == 168) or (first == 172 and second >= 16 and second <= 31), a)
