extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
    checks+=1
    if not ok:
        failures+=1
        push_error(message)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var race=preload("res://scenes/race.tscn").instantiate()
    race.persist_results=false
    root.add_child(race)
    race.set_physics_process(false)
    race.car.set_physics_process(false)
    check(race.hud.panel_style(Color.BLACK)==race.hud.panel_style(Color.BLACK),"Repeated panels reuse the same resource")
    check(race.hud.map_desktop.size()==129 and race.hud.map_touch.size()==129,"Both map layouts are cached closed paths")
    race.hud._process(.1)
    var before: int=race.hud.redraw_count
    for i in range(120): race.hud._process(1.0/60)
    check(race.hud.redraw_count==before,"Idle menu does not redraw every frame")
    race.state=race.State.RACING
    race.hud._process(.1)
    before=race.hud.redraw_count
    for i in range(120): race.hud._process(1.0/60)
    check(race.hud.redraw_count-before<=61,"Driving HUD is capped near 30 Hz")
    race.apply_quality(true)
    check(not race.sun.shadow_enabled and root.msaa_3d==Viewport.MSAA_DISABLED,"Power saving turns off costly shadows and MSAA")
    race.apply_quality(false)
    check(race.sun.shadow_enabled and root.msaa_3d==Viewport.MSAA_4X,"Standard quality remains selectable")
    var pose: Transform3D=race.track.gates[1]
    race.car.position=pose.origin
    race.car.velocity=-pose.basis.z*10
    race.update_guidance(1.3)
    check(race.wrong_way_time>=1.2,"Reverse movement triggers guidance")
    race.car.velocity=pose.basis.z*10
    race.update_guidance(.1)
    check(race.wrong_way_time==0,"Correct direction clears warning")
    race.car.velocity=Vector3.ZERO
    race.car.set_virtual_action("accelerate",true)
    race.update_guidance(3.1)
    check(race.stuck_time>=3,"Held throttle without motion gives recovery hint")
    race.hud.recover_button.pressed.emit()
    check(race.recovered==1 and race.elapsed==5,"Recovery is available through a UI button")
    race.hud.recover_button.pressed.emit()
    check(race.recovered==1,"Double tapping recovery does not stack penalties")
    print("RENDER/GUIDANCE: ",checks," checks; ",failures," failures")
    race.queue_free()
    await create_timer(.1).timeout
    quit(0 if failures==0 else 1)
