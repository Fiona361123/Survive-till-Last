extends SceneTree

func _init():
    print("Testing collision...")
    var err = change_scene_to_file("res://main.tscn")
    if err != OK:
        print("Failed to load main.tscn")
    
    var timer = Timer.new()
    timer.wait_time = 3.0
    timer.autostart = true
    timer.one_shot = true
    timer.timeout.connect(func(): quit())
    root.add_child(timer)
