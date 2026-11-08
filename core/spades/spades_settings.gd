class_name SpadesSettings
extends RefCounted
## The host's choices for a Spades game, set before the game starts.
## Defaults come from docs/SPADES_RULES.md.

var blind_nil_enabled: bool = true
var nil_enabled: bool = true
var redeal_enabled: bool = true
var bags_penalty_enabled: bool = true
var play_higher_enabled: bool = false
var win_score: int = 500
var lose_score: int = -200


## Points for a made Nil (or lost for a failed one).
func nil_value() -> int:
	return 100


## Blind Nil is worth double, unless normal Nil is switched off: then it is worth the same as Nil.
func blind_nil_value() -> int:
	return 200 if nil_enabled else 100
