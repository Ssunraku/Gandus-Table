extends GutTest

var link: LocalLink
var at_host: Array = []     # [peer, text]
var at_client: Array = []   # [peer, text]
var client_t: Transport


func _make(network: Transport = null) -> void:
	link = LocalLink.new(network)
	link.message_received.connect(func(p: int, t: String) -> void: at_host.append([p, t]))
	client_t = link.local_client()
	client_t.message_received.connect(func(p: int, t: String) -> void: at_client.append([p, t]))


func before_each() -> void:
	at_host = []
	at_client = []


func test_local_client_reaches_the_host_as_peer_0() -> void:
	_make()
	client_t.send_to(Transport.HOST_ID, "hi")
	link.poll()
	assert_eq(at_host, [[0, "hi"]])


func test_host_message_to_peer_0_reaches_the_local_client() -> void:
	_make()
	link.send_to(LocalLink.LOCAL_PEER, "yo")
	link.poll()
	assert_eq(at_client, [[1, "yo"]])


func test_broadcast_reaches_the_local_client_and_the_inner_transport() -> void:
	var net: FakeNetwork = FakeNetwork.new()
	_make(net.host_transport())
	var remote: FakeTransport = net.connect_client()
	var remote_got: Array = []
	remote.message_received.connect(func(_p: int, t: String) -> void: remote_got.append(t))
	net.pump()
	link.broadcast("all")
	link.poll()
	net.pump()
	assert_eq(at_client, [[1, "all"]])
	assert_eq(remote_got, ["all"])


func test_inner_peers_appear_with_their_own_ids() -> void:
	var net: FakeNetwork = FakeNetwork.new()
	_make(net.host_transport())
	var remote: FakeTransport = net.connect_client()
	net.pump()
	remote.send_to(1, "from remote")
	net.pump()
	assert_eq(at_host, [[remote.my_id, "from remote"]])
	link.send_to(remote.my_id, "reply")
	net.pump()


func test_nothing_is_delivered_until_poll() -> void:
	_make()
	client_t.send_to(1, "x")
	assert_eq(at_host.size(), 0)
	link.poll()
	assert_eq(at_host.size(), 1)


func test_is_local_peer_only_for_the_local_client() -> void:
	_make()
	assert_true(link.is_local_peer(0))
	assert_false(link.is_local_peer(2))
	assert_false(link.is_local_peer(1))


func test_messages_sent_while_delivering_arrive_in_the_same_poll_in_order() -> void:
	_make()
	link.message_received.connect(func(_p: int, t: String) -> void:
		if t == "ping":
			link.send_to(LocalLink.LOCAL_PEER, "pong"))
	client_t.send_to(1, "ping")
	link.poll()
	assert_eq(at_client, [[1, "pong"]])


func test_a_whole_lobby_and_game_start_works_with_only_a_local_client() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.blind_nil_enabled = false
	_make()
	var host: SpadesHost = SpadesHost.new(link, s, 8)
	var me: SpadesClient = SpadesClient.new(client_t)
	me.join("Me", true)
	link.poll()
	me.request_seat(0)
	link.poll()
	assert_eq(me.my_seat, 0)
	assert_true(me.is_host)
	me.add_bots()
	me.start_game()
	link.poll()
	assert_false(me.view.is_empty(), "the host's own player gets a snapshot")
	var guard: int = 0
	while not me.view["must_bid"] and guard < 50:
		guard += 1
		host.step()
		link.poll()
	assert_true(me.view["must_bid"])
