extends Node3D
signal race_changed
const TOTAL_LAPS := 3
const TrackScript = preload("res://scripts/track.gd")
const CAR_SCENE = preload("res://scenes/car.tscn")
enum State { READY, COUNTDOWN, RACING, FINISHED }
var state := State.READY
var track: NeonTrack
var car: NeonCar
var camera: Camera3D
var next_gate := 1
var lap := 1
var elapsed := 0.0
var lap_elapsed := 0.0
var lap_times: Array[float] = []
var countdown := 3.0
var previous_position := Vector3.ZERO
var camera_heading := 0.0
var recovered := 0
var hud: Control
var muted := false
var best_time := 0.0
var best_drift := 0
var persist_results := true
var records_path := "user://records.cfg"
var motor: AudioStreamPlayer
var skid: AudioStreamPlayer
var skid_mesh: MultiMesh
var skid_index := 0
var skid_anchor := Vector3.ZERO

func _ready() -> void:
    track = TrackScript.new()
    add_child(track)
    car = CAR_SCENE.instantiate()
    add_child(car)
    car.enabled = false
    reset_position()
    var world := WorldEnvironment.new()
    world.environment = Environment.new()
    world.environment.background_mode = Environment.BG_COLOR
    world.environment.background_color = Color("080e21")
    world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    world.environment.ambient_light_color = Color("acc5ed")
    world.environment.ambient_light_energy = 0.75
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48,-32,0)
    sun.light_color = Color("b1d1ff")
    sun.light_energy = 1.15
    sun.shadow_enabled = true
    add_child(sun)
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 65
    camera.far = 500
    add_child(camera)
    update_camera(1, true)
    var layer := CanvasLayer.new()
    add_child(layer)
    hud = preload("res://scripts/hud.gd").new()
    hud.race = self
    layer.add_child(hud)
    load_records()
    setup_audio()
    setup_skidmarks()
    capture_if_requested()

func setup_audio() -> void:
    motor = loop_player(preload("res://assets/audio/motor.wav"))
    skid = loop_player(preload("res://assets/audio/skid.wav"))

func loop_player(source: AudioStreamWAV) -> AudioStreamPlayer:
    var player := AudioStreamPlayer.new()
    var stream := source.duplicate() as AudioStreamWAV
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = 22050
    player.stream = stream
    player.volume_db = -80
    add_child(player)
    return player

func load_records() -> void:
    var records := ConfigFile.new()
    if records.load(records_path) == OK:
        best_time = float(records.get_value("record","time",0.0))
        best_drift = int(records.get_value("record","drift",0))

func save_records() -> void:
    if not persist_results:
        return
    if best_time <= 0 or elapsed < best_time:
        best_time = elapsed
    best_drift = maxi(best_drift,int(car.drift_score))
    var records := ConfigFile.new()
    records.set_value("record","time",best_time)
    records.set_value("record","drift",best_drift)
    if records.save(records_path) != OK:
        hud.message("無法儲存紀錄；本次仍可正常遊玩")

static func format_time(value: float) -> String:
    var milliseconds := maxi(0,int(value*1000))
    return "%02d:%02d.%03d" % [milliseconds/60000,(milliseconds/1000)%60,milliseconds%1000]

func toggle_pause() -> void:
    if state not in [State.COUNTDOWN,State.RACING]:
        return
    get_tree().paused = not get_tree().paused
    hud.update_touch()
    if get_tree().paused:
        motor.volume_db = -80
        skid.volume_db = -80

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree():
        if state in [State.COUNTDOWN,State.RACING] and not get_tree().paused:
            toggle_pause()

func setup_skidmarks() -> void:
    skid_mesh = MultiMesh.new()
    skid_mesh.transform_format = MultiMesh.TRANSFORM_3D
    var mark := BoxMesh.new()
    mark.size = Vector3(.18,.012,.75)
    skid_mesh.mesh = mark
    skid_mesh.instance_count = 180
    for i in range(skid_mesh.instance_count):
        skid_mesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(0,-20,0)))
    var node := MultiMeshInstance3D.new()
    node.multimesh = skid_mesh
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color("65325e")
    node.material_override = mat
    add_child(node)

func update_skidmarks() -> void:
    if not car.drifting or car.position.distance_to(skid_anchor)<.5:
        return
    skid_anchor = car.position
    var forward := Vector3(car.velocity.x,0,car.velocity.z).normalized()
    var basis := Basis(Vector3.UP,atan2(forward.x,forward.z))
    for side in [-.85,.85]:
        var point: Vector3 = car.global_transform*Vector3(side,0,-1.4)
        point.y = .025
        skid_mesh.set_instance_transform(skid_index,Transform3D(basis,point))
        skid_index = (skid_index+1)%skid_mesh.instance_count

func start_race() -> void:
    get_tree().paused = false
    motor.play()
    skid.play()
    next_gate = 1
    lap = 1
    elapsed = 0
    lap_elapsed = 0
    lap_times.clear()
    recovered = 0
    countdown = 3.0
    car.boost = 100
    car.drift_score = 0
    car.enabled = false
    reset_position()
    state = State.COUNTDOWN
    race_changed.emit()

func reset_position() -> void:
    var pose := track.recovery_gate(next_gate)
    car.reset_to(pose.origin,pose.basis.get_euler().y)
    previous_position = car.position
    camera_heading = car.rotation.y

func recover() -> void:
    if state != State.RACING:
        return
    elapsed += 5.0
    lap_elapsed += 5.0
    recovered += 1
    hud.message("已回正車輛  ·  加罰 5 秒")
    reset_position()

func advance_gates(previous: Vector3, current: Vector3) -> void:
    if not track.crossed_gate(next_gate, previous, current):
        return
    if next_gate == 0:
        lap_times.append(lap_elapsed)
        lap_elapsed = 0
        if lap == TOTAL_LAPS:
            state = State.FINISHED
            car.enabled = false
            save_records()
            race_changed.emit()
            return
        lap += 1
    next_gate = (next_gate+1)%NeonTrack.GATES
    race_changed.emit()

func _physics_process(delta: float) -> void:
    if state == State.COUNTDOWN:
        countdown -= delta
        if countdown <= 0:
            state = State.RACING
            car.enabled = true
            previous_position = car.position
            race_changed.emit()
    elif state == State.RACING:
        elapsed += delta
        lap_elapsed += delta
        advance_gates(previous_position,car.position)
        previous_position = car.position
        if car.position.y < -3:
            recover()
    update_skidmarks()
    if Input.is_action_just_pressed("reset_car"):
        recover()

func _process(delta: float) -> void:
    update_camera(delta)
    var active := state == State.RACING and not muted
    motor.volume_db = -24 if active else -80
    motor.pitch_scale = 0.65+car.speed_kmh()/75.0
    skid.volume_db = -23 if active and car.drifting else -80

func update_camera(delta: float, snap := false) -> void:
    if state in [State.READY,State.FINISHED]:
        var front := car.global_basis.z
        var side := car.global_basis.x
        camera.position = car.position+front*7+side*6+Vector3.UP*3.3
        var target := car.position+Vector3.UP*.65
        camera.look_at(target,Vector3.UP)
        camera.position -= camera.basis.x*2.5
        camera.fov = 48
        return
    camera_heading = lerp_angle(camera_heading,car.rotation.y,1.0 if snap else minf(1,delta*4))
    var direction := Vector3(sin(camera_heading),0,cos(camera_heading))
    var target := car.position-direction*10.5+Vector3.UP*5
    camera.position = target if snap else camera.position.lerp(target,minf(1,delta*8))
    camera.look_at(car.position+direction*4+Vector3.UP*.8,Vector3.UP)
    camera.fov = lerpf(camera.fov,75.0 if car.boosting else 65.0,minf(1,delta*3))

func capture_if_requested() -> void:
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture="):
            for frame in range(20):
                await get_tree().process_frame
            await RenderingServer.frame_post_draw
            var result := get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--capture="))
            print("RACE_SCREENSHOT: ", result)
            get_tree().quit(0 if result == OK else 1)

func _exit_tree() -> void:
    if is_instance_valid(motor):
        motor.stop()
    if is_instance_valid(skid):
        skid.stop()
