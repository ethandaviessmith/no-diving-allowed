extends Node

# Usage:
# - Add this script as an Autoload singleton (`SFX`)
# - SFX.play("dive_splash")
# - SFX.play("walk")
# - Supports multiple, layered, interchangeable, random-pitch-per-play.

var sfx_samples := {}
var sfx_volumes := {}
var sfx_pitch_ranges := {}


var sfx_timers := {} # For ambient/interval effects
var activity_channels := {} # activity_id : AudioStreamPlayer

func _ready():
	play_bg_music(preload("res://assets/audio/bg_music.wav"), -20)
	
	sfx_samples["dive_splash"] = [
		preload("res://assets/audio/dive_splash.mp3"),
		preload("res://assets/audio/dive_splash2.mp3"),
		preload("res://assets/audio/dive_splash3.mp3"),
		preload("res://assets/audio/dive_splash4.mp3")]
	sfx_volumes["dive_splash"] = -4

	sfx_samples["puddle"] = [
		preload("res://assets/audio/wet_walk.mp3")
	]
	sfx_volumes["puddle"] = -8
	sfx_pitch_ranges["puddle"] = Vector2(0.94, 1.08)

	sfx_samples["walk"] = [
		preload("res://assets/audio/walk.wav"),
		preload("res://assets/audio/walk2.wav")
	]
	sfx_volumes["walk"] = -8
	sfx_pitch_ranges["walk"] = Vector2(0.94, 1.08)
	
	sfx_samples["splash"] = [
		preload("res://assets/audio/water_swirl.mp3"),
		preload("res://assets/audio/small_splash.mp3"),
		preload("res://assets/audio/small_splash2.mp3"),
		preload("res://assets/audio/small_splash3.mp3")
	]
	sfx_volumes["splash"] = -14
	sfx_pitch_ranges["splash"] = Vector2(0.97, 1.06)

	sfx_samples["shower"] = [
		preload("res://assets/audio/shower.mp3"),
	]
	sfx_volumes["shower"] = -14
	sfx_pitch_ranges["shower"] = Vector2(0.97, 1.06)


func play_activity_sfx(
		owner: Node,    # Who owns the sound / gets it as child
		activity_id: String,  # Unique ID: e.g. "shower", "hairdryer", "resting"
		samples: Array, # [AudioStream, ...]
		max_duration := 4.0,
		vol_db := 0.0,
		pitch_min := 0.97, pitch_max := 1.03
	):
	stop_activity_sfx(owner, activity_id) # Clean whatever was active for these
	if samples.is_empty():
		return
	var stream: AudioStream = samples.pick_random()
	var snd := AudioStreamPlayer.new()
	snd.stream = stream
	snd.volume_db = vol_db
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


# Play a one-shot effect (or many at once)
func play(event: String, parent := get_tree().current_scene):
	if not sfx_samples.has(event): return
	var arr = sfx_samples[event]
	if arr.is_empty(): return
	var sfx = AudioStreamPlayer.new()
	sfx.stream = arr.pick_random()
	sfx.volume_db = sfx_volumes.get(event, 0)
	var r = sfx_pitch_ranges.get(event, Vector2.ONE)
	sfx.pitch_scale = randf_range(r.x, r.y)
	sfx.bus = "SFX"
	parent.add_child(sfx)
	sfx.play()
	sfx.finished.connect( sfx.queue_free )

# Optional for fine control!
func stop_all():
	for c in get_children(): if c is AudioStreamPlayer: c.stop()
	for t: Timer in sfx_timers.values():
		t.stop()

var _bg_music: AudioStreamPlayer = null

func play_bg_music(stream: AudioStream, vol_db := -10):
	if is_instance_valid(_bg_music): return
	_bg_music = AudioStreamPlayer.new()
	_bg_music.stream = stream
	_bg_music.bus = "Music"
	_bg_music.volume_db = vol_db
	get_tree().current_scene.add_child(_bg_music)
	_bg_music.play()
	# If looping isn't specified in Export, fake it:
	_bg_music.finished.connect(_on_bg_music_finished)

func _on_bg_music_finished():
	if is_instance_valid(_bg_music):
		_bg_music.play() # Loops

func stop_bg_music():
	if is_instance_valid(_bg_music):
		_bg_music.stop()
		_bg_music.queue_free()
		_bg_music = null
