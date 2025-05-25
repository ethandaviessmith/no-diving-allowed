extends Node

@export var master_volume : float = 1.0 # 0.0 = mute, 1.0 = 100%
@export var background_volume : float = 1.0
@export var effects_volume : float = 1.0

var _bg_music: AudioStreamPlayer = null
var _bg_music_base_db: float = -10.0

# Usage:
# - Add as Autoload singleton (`SFX`)
# - SFX.play("dive_splash")
# - SFX.play("walk")
# - Supports multiple, layered, interchangeable, random-pitch-per-play.

var sfx_samples := {}
var sfx_volumes := {}
var sfx_pitch_ranges := {}


var sfx_timers := {} # For ambient/interval effects
var activity_channels := {} # activity_id : AudioStreamPlayer

func _ready():
	play_bg_music(preload("res://assets/audio/bg_music.wav"), -30)
	
	sfx_samples["dive_splash"] = [
		preload("res://assets/audio/dive_splash.mp3"),
		preload("res://assets/audio/dive_splash2.mp3"),
		preload("res://assets/audio/dive_splash3.mp3"),
		preload("res://assets/audio/dive_splash4.mp3")]
	sfx_volumes["dive_splash"] = -24

	sfx_samples["puddle"] = [
		preload("res://assets/audio/wet_walk.mp3")
	]
	sfx_volumes["puddle"] = -23
	sfx_pitch_ranges["puddle"] = Vector2(0.94, 1.08)

	sfx_samples["walk"] = [
		preload("res://assets/audio/walk.wav"),
		preload("res://assets/audio/walk2.wav")
	]
	sfx_volumes["walk"] = -23
	sfx_pitch_ranges["walk"] = Vector2(0.94, 1.08)
	
	sfx_samples["splash"] = [
		preload("res://assets/audio/water_swirl.mp3"),
		preload("res://assets/audio/small_splash.mp3"),
		preload("res://assets/audio/small_splash2.mp3"),
		preload("res://assets/audio/small_splash3.mp3")
	]
	sfx_volumes["splash"] = -18
	sfx_pitch_ranges["splash"] = Vector2(0.97, 1.06)

	sfx_samples["shower"] = [
		preload("res://assets/audio/shower.mp3"),
	]
	sfx_volumes["shower"] = -30
	sfx_pitch_ranges["shower"] = Vector2(0.97, 1.06)


func play_activity_sfx(
		owner: Node,    # Who owns the sound / gets it as child
		activity_id: String,  # Unique ID: e.g. "shower", "hairdryer", "resting"
		samples: Array, # [AudioStream, ...]
		max_duration := 4.0,
		pitch_min := 0.97, pitch_max := 1.03
	):
	stop_activity_sfx(owner, activity_id) # Clean whatever was active for these
	if samples.is_empty():
		return
	var stream: AudioStream = samples.pick_random()
	var snd := AudioStreamPlayer.new()
	snd.stream = stream
	snd.volume_db = sfx_volumes[activity_id]
	snd.pitch_scale = randf_range(pitch_min, pitch_max)
	snd.bus = "SFX"
	snd.name = "activity_sfx_%s" % activity_id
	owner.add_child(snd)
	snd.play()

	var tm = Timer.new()
	tm.one_shot = true
	tm.wait_time = min(max_duration, stream.get_length())
	snd.add_child(tm)
	tm.timeout.connect(func():
		if is_instance_valid(snd):
			snd.stop()
			snd.queue_free()
		var key = _activity_channel_key(owner, activity_id)
		if activity_channels.has(key):
			activity_channels.erase(key)
	)
	tm.start()
	snd.finished.connect(func():
		var key = _activity_channel_key(owner, activity_id)
		if activity_channels.has(key):
			activity_channels.erase(key)
		snd.queue_free()
	)
	activity_channels[_activity_channel_key(owner, activity_id)] = snd

func stop_activity_sfx(owner: Node, activity_id: String):
	var key = _activity_channel_key(owner, activity_id)
	if activity_channels.has(key):
		var sfx = activity_channels[key]
		if is_instance_valid(sfx):
			sfx.stop()
			sfx.queue_free()
		activity_channels.erase(key)

func _activity_channel_key(owner: Node, activity_id: String) -> String:
	return "%s#%s" % [str(owner.get_instance_id()), activity_id]

func play_interval_sfx(event: String, interval_min := 0.2, interval_max := 0.35, parent := get_tree().current_scene):
	stop_interval_sfx(event)
	var t := Timer.new()
	t.one_shot = true
	add_child(t)
	sfx_timers[event] = t
	t.timeout.connect(func():
		play(event, parent)
		play_interval_sfx(event, interval_min, interval_max, parent)
	)
	t.start(randf_range(interval_min, interval_max))
	play(event, parent)

func stop_interval_sfx(event: String):
	if sfx_timers.has(event):
		var t: Timer = sfx_timers[event]
		if is_instance_valid(t):
			t.stop()
			t.queue_free()
		sfx_timers.erase(event)



# Optional for fine control!
func stop_all():
	for c in get_children(): if c is AudioStreamPlayer: c.stop()
	for t: Timer in sfx_timers.values():
		t.stop()

func _on_bg_music_finished():
	if is_instance_valid(_bg_music):
		_bg_music.play() # Loops

func stop_bg_music():
	if is_instance_valid(_bg_music):
		_bg_music.stop()
		_bg_music.queue_free()
		_bg_music = null

func _apply_volumes():
	# Called whenever a exported volume slider changes (editor or runtime)
	# Updates all active sound/musics
	for c in get_children():
		if c is AudioStreamPlayer:
			if c.bus == "Music":
				c.volume_db = _mix_db(_bg_music_base_db, background_volume * master_volume)
			elif c.bus == "SFX":
				c.volume_db = _mix_db(sfx_volumes.get(c.name.replace("activity_sfx_", ""), 0), effects_volume * master_volume)
	# BG music (singleton)
	if is_instance_valid(_bg_music):
		_bg_music.volume_db = _mix_db(_bg_music_base_db, background_volume * master_volume)

func _mix_db(base_db: float, volume_scale: float) -> float:
	# Combine dB with a linear scale (0.0 is silent, 1.0 is unchanged)
	if volume_scale <= 0.0:
		return -80.0 # practically mute
	return base_db + linear_to_db(volume_scale)

# Play a one-shot effect (or many at once)
func play(event: String, parent := get_tree().current_scene):
	if not sfx_samples.has(event): return
	var arr = sfx_samples[event]
	if arr.is_empty(): return
	var sfx = AudioStreamPlayer.new()
	sfx.stream = arr.pick_random()
	sfx.volume_db = _mix_db(sfx_volumes.get(event, 0), effects_volume * master_volume)
	var r = sfx_pitch_ranges.get(event, Vector2.ONE)
	sfx.pitch_scale = randf_range(r.x, r.y)
	sfx.bus = "SFX"
	parent.add_child(sfx)
	sfx.play()
	sfx.finished.connect( sfx.queue_free )

func play_bg_music(stream: AudioStream, vol_db := -10):
	if is_instance_valid(_bg_music): return
	_bg_music = AudioStreamPlayer.new()
	_bg_music.stream = stream
	_bg_music.bus = "Music"
	_bg_music.volume_db = _mix_db(vol_db, background_volume * master_volume)
	_bg_music_base_db = vol_db
	get_tree().current_scene.add_child(_bg_music)
	_bg_music.play()
	_bg_music.finished.connect(_on_bg_music_finished)
