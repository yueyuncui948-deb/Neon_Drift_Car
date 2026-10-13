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
var status: Label
var summary: Label

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
    status = Label.new()
    status.position = Vector2(40,35)
    status.add_theme_font_size_override("font_size",28)
    layer.add_child(status)
    summary = Label.new()
    summary.position = Vector2(40,90)
    summary.add_theme_font_size_override("font_size",20)
    layer.add_child(summary)
    capture_if_requested()

func start_race() -> void:
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
    if Input.is_action_just_pressed("reset_car"):
        recover()

func _process(delta: float) -> void:
    update_camera(delta)
    status.text = "NEON DRIFT    |    LAP %d / %d    |    %03d KM/H" % [lap,TOTAL_LAPS,car.speed_kmh()]
    match state:
        State.READY: summary.text = "ENTER TO START   ·   WASD / ARROWS   ·   SPACE DRIFT   ·   SHIFT BOOST   ·   R RECOVER (+5s)"
        State.COUNTDOWN: summary.text = "START IN %d" % ceili(countdown)
        State.RACING: summary.text = "TIME %.2f    ·    NEXT GATE %d    ·    DRIFT %d" % [elapsed,next_gate,car.drift_score]
        State.FINISHED: summary.text = "FINISHED — %.2f sec    ·    DRIFT %d    ·    ENTER TO RETRY" % [elapsed,car.drift_score]

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
        if state == State.READY or state == State.FINISHED:
            start_race()

func update_camera(delta: float, snap := false) -> void:
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
