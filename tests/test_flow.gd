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
    race.records_path = "user://test_records.cfg"
    race.settings_path="user://test_flow_settings.cfg"
    race.persist_settings=false
    root.add_child(race)
    race.set_physics_process(false)
    race.car.set_physics_process(false)
    check(not race.car.enabled, "Menu must not accept driving")
    race.hud.primary.pressed.emit()
    check(race.state==race.State.COUNTDOWN and not race.car.enabled, "Start button begins countdown")
    race._physics_process(3.1)
    check(race.state==race.State.RACING and race.car.enabled, "Countdown enables driving")
    race.toggle_pause()
    check(paused, "Pause freezes the scene tree")
    race.hud.primary.pressed.emit()
    check(not paused and race.state==race.State.RACING, "Resume continues the same race")
    race.hud.mute_button.pressed.emit()
    check(race.muted, "Mute toggle is functional")
    race.elapsed=65.123
    race.car.drift_score=432
    race.save_records()
    race.best_time=0
    race.best_drift=0
    race.load_records()
    check(is_equal_approx(race.best_time,65.123) and race.best_drift==432, "Records survive save and reload")
    race.elapsed=70
    race.save_records()
    check(is_equal_approx(race.best_time,65.123), "Slower run cannot replace best time")
    race.hud.touch_visible=true
    race.hud.update_touch()
    race.hud.touch_buttons[4].button_down.emit()
    check((race.car.input_strength("accelerate")>0), "Touch accelerate presses action")
    race.toggle_pause()
    check(not (race.car.input_strength("accelerate")>0), "Pausing releases held touch controls")
    race.toggle_pause()
    race.hud.set_finger_action(10,"accelerate")
    race.hud.set_finger_action(11,"steer_right")
    check((race.car.input_strength("accelerate")>0) and (race.car.input_strength("steer_right")>0), "Two fingers hold acceleration and steering together")
    race.hud.set_finger_action(11,"")
    check((race.car.input_strength("accelerate")>0) and not (race.car.input_strength("steer_right")>0), "Releasing steering keeps accelerator held")
    race.hud.set_finger_action(10,"")
    check(not (race.car.input_strength("accelerate")>0), "Releasing final finger clears acceleration")
    check(race.format_time(65.123)=="01:05.123", "Lap time formatting")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(race.records_path))
    print("FLOW TESTS: ", "PASS (14 checks)" if failures==0 else "FAIL: %d" % failures)
    race.queue_free()
    await create_timer(0.1).timeout
    quit(0 if failures==0 else 1)
