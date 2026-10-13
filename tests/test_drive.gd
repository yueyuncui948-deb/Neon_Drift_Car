extends SceneTree
## Drives all laps using the same public input actions as a player, without teleporting.
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var race = preload("res://scenes/race.tscn").instantiate()
    race.persist_results=false
    root.add_child(race)
    race.start_race()
    var last_lap := 0
    for frame in range(18000):
        await physics_frame
        if race.state==race.State.FINISHED:
            break
        if race.state!=race.State.RACING:
            continue
        var nearest := 0
        var distance := INF
        for i in range(race.track.points.size()):
            var candidate: float = race.track.points[i].distance_squared_to(race.car.position)
            if candidate<distance:
                distance=candidate
                nearest=i
        var target: Vector3 = race.track.points[(nearest+2)%race.track.points.size()]
        var direction: Vector3 = target-race.car.position
        var error := wrapf(atan2(direction.x,direction.z)-race.car.rotation.y,-PI,PI)
        for action in ["steer_left","steer_right","accelerate","brake"]:
            Input.action_release(action)
        if error>.055: Input.action_press("steer_left")
        elif error<-.055: Input.action_press("steer_right")
        if race.car.speed_kmh()<42: Input.action_press("accelerate")
        elif race.car.speed_kmh()>48: Input.action_press("brake")
        if race.lap != last_lap:
            print("DRIVE: lap ",race.lap," time ",race.elapsed)
            last_lap=race.lap
    var success: bool = race.state==race.State.FINISHED and race.lap_times.size()==3
    print("DRIVING TEST: ","PASS: three physical laps" if success else "FAIL", " time=",race.elapsed," gate=",race.next_gate," position=",race.car.position," yaw=",race.car.rotation.y)
    for action in ["steer_left","steer_right","accelerate","brake"]:
        Input.action_release(action)
    race.queue_free()
    await create_timer(.1).timeout
    quit(0 if success else 1)
