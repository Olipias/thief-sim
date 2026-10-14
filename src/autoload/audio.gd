extends Node
## Tiny SFX player: preloads generated WAVs and round-robins a pool of
## AudioStreamPlayers so overlapping sounds never cut each other off.
## Autoloaded as "Audio".

const SFX := {
	"step": "res://assets/sfx/step.wav",
	"pickup": "res://assets/sfx/pickup.wav",
	"coin": "res://assets/sfx/coin.wav",
	"denied": "res://assets/sfx/denied.wav",
	"alert": "res://assets/sfx/alert.wav",
	"caught": "res://assets/sfx/caught.wav",
	"smoke": "res://assets/sfx/smoke.wav",
	"escape": "res://assets/sfx/escape.wav",
	"ghost": "res://assets/sfx/ghost.wav",
	"blip": "res://assets/sfx/blip.wav",
}
const POOL_SIZE := 10

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for key in SFX:
		_streams[key] = load(SFX[key])
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)


func play(sound: String, volume_db := -6.0, pitch := 1.0) -> void:
	if not _streams.has(sound):
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[sound]
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


func _exit_tree() -> void:
	shutdown()


func play_step() -> void:
	play("step", -16.0, randf_range(0.9, 1.12))


func stop_all() -> void:
	for player in _players:
		player.stop()
		player.stream = null


## Stop audio and destroy the player pool.  Used before quitting (tests,
## clean shutdown) so the audio server cannot keep phantom references.
func shutdown() -> void:
	for player in _players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
			player.free()
	_players.clear()
	_streams.clear()
