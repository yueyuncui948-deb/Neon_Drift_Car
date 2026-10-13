extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var car := preload("res://scenes/car.tscn").instantiate()
    root.add_child(car)
    car.set_physics_process(false)
    check(car.wheels.size() == 4, "Four procedural wheel pivots must import")
    check(car.front_wheels.size() == 2, "Only front wheels should steer")
    for i in range(180):
        car.drive(1.0/60, 1, 0, 0, false, false)
    check(car.speed_kmh() > 90, "Throttle must accelerate")
    var previous_speed: float = car.speed_kmh()
    for i in range(30):
        car.drive(1.0/60, 0, 1, 0, false, false)
    check(car.speed_kmh() < previous_speed, "Brake must reduce speed")
    car.velocity = Vector3(0, 0, 25)
    for i in range(45):
        car.drive(1.0/60, 1, 0, 1, true, false)
    check(car.rotation.y < -0.2, "Right input must turn right")
    check(car.drift_score > 0, "Handbrake corner must generate drift score")
    car.animate_wheels(0.1)
    check(absf(car.front_wheels[0].rotation.y) > 0.1, "Front pivot must steer")
    check(absf(car.spins[0].rotation.x) > 0.01, "Wheel must roll")
    car.reset_to(Vector3.ZERO, 0)
    for i in range(180):
        car.drive(1.0/60, 1, 0, 0, false, true)
    check(car.boost < 30 and car.speed_kmh() > 122, "Boost consumes energy and exceeds normal speed")
    car.reset_to(Vector3(2, 0, 3), 1)
    check(car.velocity == Vector3.ZERO and car.position == Vector3(2, 0, 3), "Recovery clears motion")
    print("CAR TESTS: ", "PASS (10 checks)" if failures == 0 else "FAIL: %d" % failures)
    car.queue_free()
    quit(0 if failures == 0 else 1)
