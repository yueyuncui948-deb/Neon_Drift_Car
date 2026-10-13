extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, description: String) -> void:
    checks+=1
    if not ok:
        failures+=1
        push_error(description)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    var race = preload("res://scenes/race.tscn").instantiate()
    race.persist_results=false
    root.add_child(race)
    race.set_physics_process(false)
    race.car.set_physics_process(false)
    var car: NeonCar = race.car
    check(car.steering_rate(46,false)<car.steering_rate(15,false)*.8,"Boost-speed steering should be less twitchy")
    check(car.steering_rate(30,true)>car.steering_rate(30,false),"Handbrake retains sharper rotation")
    car.boost=1.2
    var previous := false
    var switches := 0
    for i in range(180):
        car.drive(1.0/60,1,0,0,false,true)
        if car.boosting!=previous:
            switches+=1
            previous=car.boosting
    check(switches<=4,"Near-empty boost must not rapidly toggle")
    car.boost=100
    car.drive(1.0/60,1,1,0,false,true)
    check(not car.boosting,"Braking must not consume boost")
    car.velocity=Vector3(1,0,20)
    car.apply_wall_response(car.velocity,Vector3.LEFT)
    check(car.velocity.z>19,"Gentle wall scrape preserves forward motion")
    car.last_impact=0
    car.apply_wall_response(Vector3(12,0,20),Vector3.LEFT)
    var first: float=car.velocity.z
    check(first<20 and car.last_impact>0,"Hard impact still loses speed")
    car.apply_wall_response(Vector3(12,0,20),Vector3.LEFT)
    check(car.velocity.z>first,"Repeated contact does not repeatedly multiply damage")
    Input.action_press("accelerate")
    race.hud.touch_visible=false
    race.hud.update_touch()
    check(Input.is_action_pressed("accelerate"),"Touch visibility change cannot clear keyboard state")
    race.hud.set_finger_action(1,"accelerate")
    race.hud.set_finger_action(1,"")
    check(car.input_strength("accelerate")==1,"Releasing a finger cannot cancel held keyboard acceleration")
    Input.action_release("accelerate")
    race.hud.set_finger_action(1,"accelerate")
    race.hud.set_finger_action(2,"accelerate")
    race.hud.set_mouse_action("accelerate",true)
    race.hud.set_finger_action(1,"")
    race.hud.set_finger_action(2,"")
    check(car.input_strength("accelerate")==1,"Mouse input survives release of both fingers")
    race.hud.set_mouse_action("accelerate",false)
    check(car.input_strength("accelerate")==0,"All owners released means no stuck throttle")
    race.hud.set_finger_action(3,"steer_right")
    race.hud.release_virtual_controls()
    check(car.input_strength("steer_right")==0,"Resetting virtual input clears all touch owners")
    print("HANDLING: ",checks," checks; ",failures," failures; boost transitions=",switches)
    race.queue_free()
    await create_timer(.1).timeout
    quit(0 if failures==0 else 1)
