extends Node

var bgm_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []

# Preload Audio Streams
var bgm_stream = load("res://Background Sound/menieldm-obsidian-halls-495840.mp3")
var coin_sfx = load("res://Sound Effect/mixkit-winning-a-coin-video-game-2069.wav")
var level_up_sfx = load("res://Sound Effect/mixkit-completion-of-a-level-2063.wav")
var blood_pop_sfx = load("res://Sound Effect/mixkit-game-blood-pop-slide-2363.wav")
var win_sfx = load("res://Sound Effect/mixkit-medieval-show-fanfare-announcement-226.wav")
var lose_sfx = load("res://Sound Effect/mixkit-player-losing-or-failing-2042.wav")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus(AudioServer.bus_count)
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus(AudioServer.bus_count)
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
	
	bgm_player = AudioStreamPlayer.new()
	bgm_player.stream = bgm_stream
	bgm_player.bus = "Music"
	add_child(bgm_player)
	bgm_player.play()
	
	for i in range(16):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)

func play_sfx(stream: AudioStream):
	if stream == null: return
	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	
	var p = sfx_players[0]
	p.stream = stream
	p.play()

func play_coin(): play_sfx(coin_sfx)
func play_level_up():
	# Play level-up louder than other SFX by boosting volume on its player
	if level_up_sfx == null: return
	for p in sfx_players:
		if not p.playing:
			p.stream = level_up_sfx
			p.volume_db = 12.0  # +12dB boost for bigger sound
			p.play()
			# Reset to 0dB after it finishes so other SFX aren't affected
			var timer = get_tree().create_timer(p.stream.get_length() + 0.1)
			timer.timeout.connect(func(): if is_instance_valid(p): p.volume_db = 0.0)
			return
func play_blood_pop(): play_sfx(blood_pop_sfx)
func play_win(): 
	bgm_player.stop()
	play_sfx(win_sfx)
func play_lose(): 
	bgm_player.stop()
	play_sfx(lose_sfx)

func set_music_volume(linear_val: float):
	var db = linear_to_db(max(0.001, linear_val))
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, db)

func set_sfx_volume(linear_val: float):
	var db = linear_to_db(max(0.001, linear_val))
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, db)
