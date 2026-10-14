extends SceneTree
var failures:=0
var checks:=0
func check(ok: bool, message: String) -> void:
    checks+=1
    if not ok:
        failures+=1
        push_error(message)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var race=preload("res://scenes/race.tscn").instantiate()
    race.records_path="user://optimization_records.cfg"
    race.settings_path="user://optimization_settings.cfg"
    for path in [race.records_path,race.settings_path]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    root.add_child(race)
    race.set_physics_process(false)
    race.car.set_physics_process(false)
    race.state=race.State.RACING
    race.skid_index=24
    race.skid_mesh.visible_instance_count=24
    race.skid_mesh.set_instance_transform(0,Transform3D.IDENTITY)
    race.car.boost_locked=true
    race.car.visual.rotation.z=.2
    race.car.last_impact=.2
    race.wrong_way_time=5
    race.stuck_time=5
    race.recovery_cooldown=1
    race.hud.set_finger_action(9,"accelerate")
    race.camera.position=Vector3(500,500,500)
    race.start_race()
    check(race.skid_index==0 and race.skid_mesh.visible_instance_count==0,"Restart removes old skidmarks")
    check(race.car.boost==100 and not race.car.boost_locked,"Restart refills and unlocks boost")
    check(race.car.visual.rotation.z==0 and race.car.last_impact==0,"Restart resets visual lean and collision cooldown")
    check(race.wrong_way_time==0 and race.stuck_time==0 and race.recovery_cooldown==0,"Restart clears old warnings and recovery cooldown")
    check(race.car.input_strength("accelerate")==0,"Restart clears stale touch owners")
    check(race.camera.position.distance_to(race.car.position)<13,"Restart snaps follow camera")
    race.state=race.State.RACING
    race.car.position+=Vector3(50,0,50)
    race.recover()
    check(race.camera.position.distance_to(race.car.position)<13 and race.elapsed==5,"Recovery snaps camera and counts one penalty")
    check(race.format_time(84.399999999)=="01:24.400" and race.format_time(59.9999)=="01:00.000","Milliseconds round correctly across minute boundary")
    race.state=race.State.FINISHED
    race.update_goal_marker()
    check(not race.goal_marker.visible,"Finished race hides goal stripe")
    race.start_race()
    check(race.goal_marker.visible and race.next_gate==1,"New race restores first goal stripe")
    race.set_muted(true)
    race.set_quality(true)
    race.muted=false
    race.apply_quality(false)
    race.load_settings()
    check(race.muted and race.quality_low and not race.sun.shadow_enabled,"Mute and quality survive settings reload")
    var cfg:=ConfigFile.new()
    cfg.set_value("settings","muted","false")
    cfg.set_value("settings","quality_low",42)
    cfg.save(race.settings_path)
    race.load_settings()
    check(not race.muted and not race.quality_low,"Invalid setting types use native defaults")
    cfg=ConfigFile.new()
    cfg.set_value("record","time","invalid")
    cfg.set_value("record","drift",-20)
    cfg.set_value("record","lap",INF)
    cfg.set_value("extension","keep","custom")
    cfg.save(race.records_path)
    race.load_records()
    check(race.best_time==0 and race.best_drift==0 and race.best_lap==0,"Corrupt record values are ignored")
    race.elapsed=90
    race.car.drift_score=200
    race.lap_times.assign([31.0,29.0,30.0])
    race.save_records()
    race.load_records()
    check(race.best_time==90 and race.best_drift==200 and race.best_lap==29,"Total, drift and best lap persist")
    cfg.load(race.records_path)
    check(cfg.get_value("extension","keep","")=="custom","Saving records preserves unrelated keys")
    race.elapsed=NAN
    race.car.drift_score=INF
    race.lap_times.assign([NAN,-2.0,40.0])
    race.save_records()
    check(race.best_time==90 and race.best_drift==200 and race.best_lap==29,"Invalid or worse scores cannot overwrite valid records")
    for path in [race.records_path,race.settings_path]:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    print("RESTART / SETTINGS TESTS: ","PASS" if failures==0 else "FAIL", " (",checks," checks)")
    race.queue_free()
    await create_timer(.1).timeout
    quit(0 if failures==0 else 1)
