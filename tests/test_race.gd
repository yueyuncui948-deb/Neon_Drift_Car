extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var race = preload("res://scenes/race.tscn").instantiate()
    race.persist_results = false
    root.add_child(race)
    race.set_physics_process(false)
    race.car.set_physics_process(false)
    check(race.track.gates.size()==8, "Eight ordered checkpoints")
    race.start_race()
    race.state = race.State.RACING
    var finish: Transform3D = race.track.gates[0]
    race.advance_gates(finish.origin-finish.basis.z, finish.origin+finish.basis.z)
    check(race.lap==1 and race.next_gate==1, "Finish crossing cannot skip checkpoints")
    var gate: Transform3D = race.track.gates[1]
    race.advance_gates(gate.origin+gate.basis.z,gate.origin-gate.basis.z)
    check(race.next_gate==1, "Reverse gate crossing is rejected")
    race.advance_gates(gate*Vector3(20,0,-1),gate*Vector3(20,0,1))
    check(race.next_gate==1, "Off-track gate crossing is rejected")
    for lap_index in range(3):
        for step in range(8):
            var index := (step+1)%8
            var pose: Transform3D = race.track.gates[index]
            race.lap_elapsed += 1
            race.elapsed += 1
            race.advance_gates(pose.origin-pose.basis.z,pose.origin+pose.basis.z)
    check(race.state==race.State.FINISHED, "Three valid laps finish the race")
    check(race.lap_times.size()==3 and race.elapsed==24, "All lap times are recorded")
    race.start_race()
    race.state = race.State.RACING
    race.recover()
    check(race.elapsed==5 and race.recovered==1 and race.next_gate==1, "Recovery adds five seconds without skipping gates")
    # Exercise real physics against a side rail.
    race.car.enabled = true
    var start: Transform3D = race.track.gates[0]
    race.car.reset_to(start.origin+Vector3.UP*.2,0)
    race.car.velocity = start.basis.x*25
    race.car.set_physics_process(true)
    for frame in range(45):
        await physics_frame
    var local: Vector3 = start.affine_inverse()*race.car.position
    check(absf(local.x)<9, "Physical barriers keep car inside the road")
    print("RACE TESTS: ", "PASS (8 checks)" if failures==0 else "FAIL: %d" % failures)
    race.queue_free()
    await create_timer(0.1).timeout
    quit(0 if failures==0 else 1)
