extends Control
## Fixed design canvas; the root viewport preserves its 16:10 aspect ratio.
const INK := Color("edf6ff")
const MUTED := Color("91a8c5")
const CYAN := Color("2de4ef")
const PINK := Color("ff458b")
var race: Node3D
var font: Font = preload("res://assets/ui/neon-ui.otf")
var primary: Button
var secondary: Button
var mute_button: Button
var pause_button: Button
var touch_toggle: Button
var touch_buttons: Array[Button] = []
var finger_actions: Dictionary = {}
const TOUCH_ACTIONS := ["steer_left","steer_right","handbrake","brake","accelerate","boost"]
var touch_visible := false
var previous_mode := -1
var toast := ""
var toast_time := 0.0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    primary = button("開始挑戰  →", Rect2(64,620,360,66), func():
        if get_tree().paused:
            race.toggle_pause()
        else:
            race.start_race())
    secondary = button("重新挑戰",Rect2(64,704,220,48),func():
        get_tree().paused=false
        race.start_race())
    mute_button = button("音效：開", Rect2(1136,30,126,42),func():
        race.muted = not race.muted
        mute_button.text = "音效：關" if race.muted else "音效：開")
    pause_button = button("暫停  Ⅱ",Rect2(1278,30,120,42),func(): race.toggle_pause())
    touch_toggle = button("觸控", Rect2(1038,30,80,42),func():
        touch_visible = not touch_visible
        update_touch())
    touch_visible = bool(JavaScriptBridge.eval("matchMedia('(pointer: coarse)').matches")) if OS.has_feature("web") else DisplayServer.is_touchscreen_available()
    var definitions := [
        ["◀", "steer_left", Rect2(40,678,104,100)],
        ["▶", "steer_right", Rect2(158,678,104,100)],
        ["甩尾", "handbrake", Rect2(1006,660,104,100)],
        ["煞車", "brake", Rect2(1124,742,104,100)],
        ["加速", "accelerate", Rect2(1242,660,136,182)],
        ["氮氣", "boost", Rect2(1124,624,104,100)],
    ]
    for definition in definitions:
        var control := button(definition[0],definition[2],func(): pass)
        control.button_down.connect(func(): Input.action_press(definition[1]))
        control.button_up.connect(func(): Input.action_release(definition[1]))
        touch_buttons.append(control)
    update_touch()

func button(caption: String, rect: Rect2, callback: Callable) -> Button:
    var control := Button.new()
    control.text = caption
    control.position = rect.position
    control.size = rect.size
    control.focus_mode = Control.FOCUS_NONE
    control.add_theme_font_override("font",font)
    control.add_theme_font_size_override("font_size",20)
    control.add_theme_color_override("font_color",INK)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("101f34")
    normal.border_color = Color("28566b")
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(6)
    control.add_theme_stylebox_override("normal",normal)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color("17465c")
    hover.border_color = CYAN
    control.add_theme_stylebox_override("hover",hover)
    var pressed := hover.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("205c73")
    control.add_theme_stylebox_override("pressed",pressed)
    control.pressed.connect(callback)
    add_child(control)
    return control

func message(value: String) -> void:
    toast = value
    toast_time = 2.5

func update_touch() -> void:
    var active: bool = touch_visible and race.state == race.State.RACING and not get_tree().paused
    for control in touch_buttons:
        control.visible = active
    if not active:
        finger_actions.clear()
        for action in ["accelerate","brake","steer_left","steer_right","handbrake","boost"]:
            Input.action_release(action)

func _process(delta: float) -> void:
    race.publish_qa(delta)
    toast_time = maxf(0,toast_time-delta)
    var mode: int = 4 if get_tree().paused else race.state
    if mode != previous_mode:
        previous_mode = mode
        primary.visible = mode in [0,3,4]
        secondary.visible = mode == 4
        pause_button.visible = mode in [1,2,4]
        primary.text = "繼續比賽  →" if mode == 4 else ("再跑一次  →" if mode == 3 else "開始挑戰  →")
        update_touch()
    queue_redraw()

func label(value: String, x: float, y: float, size: int, color := INK) -> void:
    draw_string(font,Vector2(x,y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func panel(rect: Rect2, color := Color(0.025,0.055,0.10,0.88)) -> void:
    draw_style_box(panel_style(color),rect)

func panel_style(color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color=color
    style.set_corner_radius_all(8)
    return style

func _draw() -> void:
    if race == null:
        return
    var menu: bool = race.state in [race.State.READY,race.State.FINISHED] or get_tree().paused
    if menu:
        draw_rect(Rect2(0,0,730,900),Color(0.018,0.033,0.066,0.95))
        draw_rect(Rect2(730,0,2,900),Color(0.16,0.8,0.9,0.35))
        label("N / D     MOTORWORKS",64,74,22,CYAN)
        label("霓虹甩尾",60,184,64)
        label("NEON DRIFT  /  MIDNIGHT CIRCUIT",64,225,18,MUTED)
        draw_line(Vector2(64,258),Vector2(658,258),Color("23445d"),1)
        if race.state == race.State.FINISHED and not get_tree().paused:
            label("挑戰完成",64,314,28,CYAN)
            label(race.format_time(race.elapsed),60,387,60)
            label("三圈總時間    ·    甩尾積分  %d" % race.car.drift_score,66,429,22,MUTED)
            for i in range(race.lap_times.size()):
                label("第 %d 圈     %s" % [i+1,race.format_time(race.lap_times[i])],66,473+i*36,21)
            label("回正 %d 次  ·  罰秒已計入成績" % race.recovered,66,592,18,MUTED)
        elif get_tree().paused:
            label("比賽已暫停",64,325,34,CYAN)
            label("喘口氣，下一個彎等你。",64,379,24)
            label("按 P / Esc 或下方按鈕繼續",64,440,21,MUTED)
        else:
            label("夜色之中，留下你的路線。",64,317,26)
            label("駕駛 ION-01 完成三圈，挑戰最快時間。",64,364,21,MUTED)
            label("依序穿過 8 個檢查點；甩尾累積風格積分。",64,399,21,MUTED)
            label("WASD / 方向鍵",64,471,23,CYAN)
            label("加速、轉向、煞車與倒車",310,471,20)
            label("空白鍵  /  Shift",64,517,23,CYAN)
            label("手煞車甩尾  /  氮氣加速",310,517,20)
            label("R  /  P 或 Esc",64,563,23,CYAN)
            label("回正（+5 秒） /  暫停",310,563,20)
        label("個人最佳   " + (race.format_time(race.best_time) if race.best_time>0 else "等待你的第一筆紀錄"),64,806,18,MUTED)
        label("原創低多邊形賽車  ·  三圈計時挑戰",64,851,16,MUTED)
        label("ION—01",1080,746,40,CYAN)
        label("OBSIDIAN / ELECTRIC",1050,781,17,MUTED)
        return
    label("N / D",42,61,28,CYAN)
    label("NEON DRIFT",146,61,24)
    panel(Rect2(36,94,408,96))
    label("LAP",58,120,14,MUTED)
    label("%d / 3" % race.lap,56,164,36)
    label("總時間",216,120,14,MUTED)
    label(race.format_time(race.elapsed),212,161,32,CYAN)
    panel(Rect2(36,202,408,55))
    label("本圈  "+race.format_time(race.lap_elapsed),56,236,18)
    label("檢查點 %d / 8" % (8 if race.next_gate==0 else race.next_gate),276,236,17,MUTED)
    if not touch_visible:
        panel(Rect2(36,665,310,196))
        label("%03d" % race.car.speed_kmh(),54,752,76)
        label("KM/H",232,746,18,MUTED)
        label("氮氣",58,790,16,CYAN)
        draw_rect(Rect2(112,778,208,9),Color("253b50"))
        draw_rect(Rect2(112,778,208*race.car.boost/100,9),CYAN)
        label("SPACE 甩尾   SHIFT 加速",58,831,16,MUTED)
    else:
        label("%03d KM/H  ·  氮氣 %d%%" % [race.car.speed_kmh(),race.car.boost],580,841,22,CYAN)
    label("DRIFT",624,118,14,PINK)
    label("%06d" % race.car.drift_score,619,155,34)
    if race.car.drifting:
        label("甩尾中  +",610,202,28,PINK)
    if race.car.boosting:
        label("N I T R O",615,730,28,CYAN)
    if race.state == race.State.COUNTDOWN:
        panel(Rect2(605,315,230,190))
        label(str(maxi(1,ceili(race.countdown))),668,452,108,CYAN)
    if toast_time>0:
        panel(Rect2(500,270,450,56))
        label(toast,521,307,22,PINK)
    label("P 暫停  ·  R 回正 (+5 秒)",54,873,15,MUTED)
    mini_map()

func mini_map() -> void:
    var rect := Rect2(1150,110,250,200) if touch_visible else Rect2(1140,650,260,210)
    panel(rect)
    var origin := rect.position+rect.size/2+Vector2(0,8)
    var scale := 1.2
    label("MIDNIGHT CIRCUIT",rect.position.x+18,rect.position.y+28,13,MUTED)
    var line := PackedVector2Array()
    for point in race.track.points:
        line.append(origin+Vector2(point.x,point.z)*scale)
    line.append(line[0])
    draw_polyline(line,Color("416078"),8,true)
    draw_polyline(line,Color("10253a"),4,true)
    var gate: Vector3 = race.track.gates[race.next_gate].origin
    draw_circle(origin+Vector2(gate.x,gate.z)*scale,5,PINK)
    var car_pos := origin+Vector2(race.car.position.x,race.car.position.z)*scale
    draw_circle(car_pos,5,CYAN)
    var direction: Vector3 = race.car.global_basis.z
    draw_line(car_pos,car_pos+Vector2(direction.x,direction.z)*13,CYAN,3,true)

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("pause_race"):
        race.toggle_pause()
        get_viewport().set_input_as_handled()
    elif event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ENTER:
        if get_tree().paused:
            race.toggle_pause()
        elif race.state in [race.State.READY,race.State.FINISHED]:
            race.start_race()
        get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
    if not touch_visible or race.state != race.State.RACING or get_tree().paused:
        return
    if event is InputEventScreenTouch:
        set_finger_action(event.index,action_at(event.position) if event.pressed else "")
        if action_at(event.position) != "":
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        set_finger_action(event.index,action_at(event.position))
        if finger_actions.has(event.index):
            get_viewport().set_input_as_handled()

func action_at(point: Vector2) -> String:
    for i in range(touch_buttons.size()):
        if touch_buttons[i].visible and touch_buttons[i].get_global_rect().has_point(point):
            return TOUCH_ACTIONS[i]
    return ""

func set_finger_action(index: int, action: String) -> void:
    var previous: String = finger_actions.get(index,"")
    finger_actions.erase(index)
    if previous != "" and not finger_actions.values().has(previous):
        Input.action_release(previous)
    if action != "":
        finger_actions[index] = action
        Input.action_press(action)
