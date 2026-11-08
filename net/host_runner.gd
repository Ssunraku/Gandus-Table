class_name HostRunner
extends Node
## Keeps a hosted game moving on the host's phone: every frame it lets the network deliver
## messages and, when the host says a step is due, waits the right pause (bot thinking, the
## finished trick staying on the table, the deal) and then runs it.
## Tests set pace = 0 and call _process themselves.

var host: SpadesHost
var link: LocalLink
var discovery: LanDiscovery
## Multiplies every pause. 0 = no waiting at all.
var pace: float = 1.0

var _waited: float = 0.0
var _stopped: bool = false


func _init(game_host: SpadesHost, local_link: LocalLink, finder: LanDiscovery = null) -> void:
	host = game_host
	link = local_link
	discovery = finder


func _process(delta: float) -> void:
	if _stopped:
		return
	link.poll()
	if discovery != null:
		discovery.poll()
	var due: float = host.next_delay()
	if due < 0.0:
		_waited = 0.0
		return
	_waited += delta
	if pace <= 0.0 or _waited >= due * pace:
		_waited = 0.0
		host.step()
		link.poll()


## Ends everything: no more polling or steps, the network is closed.
func stop() -> void:
	_stopped = true
	set_process(false)
	if discovery != null:
		discovery.stop_advertising()
	host.close("host_left")
	link.poll()
	link.close()
