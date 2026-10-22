extends Node
var clips: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var last_play: Dictionary = {}
var ambient: AudioStreamPlayer
var focused := true
func _ready() -> void:
	for kind in ["hit","guard","swing","step","ui","horn"]: clips[kind] = synthesize(kind)
	for i in 10:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	ambient = AudioStreamPlayer.new()
	ambient.stream = synthesize("wind")
	ambient.volume_db = -26
	add_child(ambient)
	ambient.play()
func _process(_delta: float) -> void:
	AudioServer.set_bus_mute(0,not Campaign.state.settings.sound or not focused)
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: focused = false
	if what == NOTIFICATION_APPLICATION_FOCUS_IN: focused = true
func play(kind: String, volume: float = -14) -> void:
	if not Campaign.state.settings.sound or not focused: return
	var now := Time.get_ticks_msec()
	if now-int(last_play.get(kind,-1000)) < (220 if kind == "step" else 80): return
	last_play[kind] = now
	for voice in voices:
		if voice.playing: continue
		voice.stream = clips[kind]
		voice.volume_db = volume
		voice.play()
		return
func synthesize(kind: String) -> AudioStreamWAV:
	const RATE := 22050
	var duration := 4.0 if kind == "wind" else 1.1 if kind == "horn" else 0.24
	var length := int(RATE*duration)
	var bytes := PackedByteArray()
	bytes.resize(length*2)
	var random := RandomNumberGenerator.new()
	random.seed = hash(kind)
	var low := 0.0
	for i in length:
		var t := float(i)/RATE
		var noise := random.randf_range(-1,1)
		low = lerpf(low,noise,0.035)
		var envelope := minf(1,t*100)*pow(1.0-t/duration,2)
		var sample := 0.0
		match kind:
			"hit": sample = (sin(TAU*(105*t-100*t*t))*0.65+noise*0.35)*envelope
			"guard": sample = (sin(TAU*1720*t)*0.3+sin(TAU*2341*t)*0.2+noise*0.22)*envelope
			"swing": sample = noise*sin(t/duration*PI)*0.3
			"step": sample = (low*3+sin(TAU*72*t)*0.25)*envelope
			"ui": sample = sin(TAU*640*t)*exp(-t*35)*0.25
			"horn": sample = (sin(TAU*147*t)+sin(TAU*294*t)*0.3)*sin(t/duration*PI)*0.4
			"wind": sample = low*(0.7+0.3*sin(t*TAU/duration))*minf(1,minf(t,duration-t)*12)
		bytes.encode_s16(i*2,int(clampf(sample,-1,1)*28000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	if kind == "wind":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = length
	return stream

func stop_all() -> void:
	for voice in voices:
		if is_instance_valid(voice): voice.stop()
	if is_instance_valid(ambient): ambient.stop()
func _exit_tree() -> void:
	stop_all()
