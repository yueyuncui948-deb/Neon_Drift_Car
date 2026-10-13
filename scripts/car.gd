class_name NeonCar
extends CharacterBody3D
## Arcade rear-wheel-drive approximation. The imported model faces local +Z.
## Rigid wheel pivots are authored by our bpy script; no skeleton is involved.

const MODEL = preload("res://assets/cars/neon_drift_car.gltf")
const TOP_SPEED := 34.0
const BOOST_SPEED := 46.0
var enabled := true
var boost := 100.0
var drifting := false
var boosting := false
var steering := 0.0
var drift_score := 0.0
var travel := 0.0
var visual: Node3D
var wheels: Array[Node3D] = []
var spins: Array[Node3D] = []
var front_wheels: Array[Node3D] = []
var last_impact := 0.0

static func configure_inputs() -> void:
    var bindings := {
        "accelerate": [KEY_W, KEY_UP], "brake": [KEY_S, KEY_DOWN],
        "steer_left": [KEY_A, KEY_LEFT], "steer_right": [KEY_D, KEY_RIGHT],
        "handbrake": [KEY_SPACE], "boost": [KEY_SHIFT],
        "reset_car": [KEY_R], "pause_race": [KEY_ESCAPE, KEY_P],
    }
    for action in bindings:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        for code in bindings[action]:
            var event := InputEventKey.new()
            event.physical_keycode = code
            if not InputMap.action_has_event(action, event):
                InputMap.action_add_event(action, event)

func _ready() -> void:
    configure_inputs()
    collision_layer = 2
    collision_mask = 1
    var shape := CollisionShape3D.new()
    var body := BoxShape3D.new()
    body.size = Vector3(2.15, 1.1, 4.35)
    shape.shape = body
    shape.position.y = 0.55
    add_child(shape)
    visual = MODEL.instantiate()
    add_child(visual)
    for wheel_name in ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]:
        var wheel := visual.find_child(wheel_name, true, false) as Node3D
        if wheel == null:
            push_error("Missing generated wheel pivot: " + wheel_name)
            continue
        var parts := wheel.get_children()
        var spin := Node3D.new()
        spin.name = "Roll"
        wheel.add_child(spin)
        for part in parts:
            part.reparent(spin, true)
        wheels.append(wheel)
        spins.append(spin)
        if "_F" in wheel_name:
            front_wheels.append(wheel)

func speed_kmh() -> float:
    return Vector2(velocity.x, velocity.z).length() * 3.6

func reset_to(point: Vector3, heading: float) -> void:
    position = point
    rotation = Vector3(0, heading, 0)
    velocity = Vector3.ZERO
    steering = 0
    drifting = false
    boosting = false

func _physics_process(delta: float) -> void:
    last_impact = maxf(0, last_impact - delta)
    if not enabled:
        velocity = Vector3.ZERO
        drifting = false
        boosting = false
        return
    drive(delta, Input.get_action_strength("accelerate"), Input.get_action_strength("brake"),
        Input.get_axis("steer_left", "steer_right"), Input.is_action_pressed("handbrake"), Input.is_action_pressed("boost"))
    if not is_on_floor():
        velocity.y -= 20.0 * delta
    else:
        velocity.y = -0.5
    var previous_velocity := velocity
    move_and_slide()
    for i in range(get_slide_collision_count()):
        var normal := get_slide_collision(i).get_normal()
        if absf(normal.y) < 0.4 and previous_velocity.length() > 5:
            velocity = previous_velocity.slide(normal) * 0.65
            last_impact = 0.35
    animate_wheels(delta)

func drive(delta: float, throttle: float, brake: float, steer: float, handbrake: bool, wants_boost: bool) -> void:
    var forward := global_basis.z
    var longitudinal := velocity.dot(forward)
    steering = move_toward(steering, steer, delta * 4.0)
    var turn_strength := clampf(absf(longitudinal) / 9.0, 0, 1)
    rotate_y(-steering * turn_strength * signf(longitudinal) * (1.65 if handbrake else 1.18) * delta)
    forward = global_basis.z
    longitudinal = velocity.dot(forward)
    var lateral := velocity - forward * longitudinal
    lateral.y = 0
    boosting = wants_boost and throttle > 0 and boost > 1 and not handbrake
    var top := BOOST_SPEED if boosting else TOP_SPEED
    if boosting:
        boost = maxf(0, boost - 28.0 * delta)
    else:
        boost = minf(100, boost + 12.0 * delta)
    if throttle > 0:
        longitudinal = move_toward(longitudinal, top * throttle, (18.0 if boosting else 10.0) * delta)
    elif brake < 0.01:
        longitudinal = move_toward(longitudinal, 0, 2.0 * delta)
    if brake > 0:
        longitudinal = move_toward(longitudinal, -9.0 * brake, (26.0 if longitudinal > 0 else 7.0) * delta)
    if handbrake:
        longitudinal = move_toward(longitudinal, 0, 3.0 * delta)
    lateral *= exp(-(1.25 if handbrake else 8.0) * delta)
    drifting = handbrake and absf(longitudinal) > 8 and lateral.length() > 1.8
    if drifting:
        drift_score += lateral.length() * delta * 12.0
    var vertical := velocity.y
    velocity = forward * longitudinal + lateral
    velocity.y = vertical
    travel += longitudinal * delta
    visual.rotation.z = lerpf(visual.rotation.z, steering * turn_strength * 0.035, minf(1, delta*5))

func animate_wheels(delta: float) -> void:
    for wheel in front_wheels:
        wheel.rotation.y = -steering * 0.42
    var roll := velocity.dot(global_basis.z) * delta / 0.445
    for spin in spins:
        spin.rotate_x(roll)
