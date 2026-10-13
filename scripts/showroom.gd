extends Node3D
## Compatibility / WebGL 2.0 asset showroom, not a driving simulation.

const CYAN := Color(0.05, 0.88, 1.0)
const PINK := Color(1.0, 0.08, 0.42)
var camera: Camera3D
var azimuth := 0.69
var elevation := 0.43
var distance := 8.8
var dragging := false

func surface(color: Color, emissive := false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.65
    if emissive:
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return mat

func box(label_text: String, dimensions: Vector3, location: Vector3, mat: Material) -> void:
    var node := MeshInstance3D.new()
    node.name = label_text
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    node.mesh = mesh
    node.material_override = mat
    node.position = location
    add_child(node)

func text(content: String, pos: Vector2, size: int, color: Color, parent: Node) -> Label:
    var label := Label.new()
    label.text = content
    label.position = pos
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    parent.add_child(label)
    return label

func _ready() -> void:
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color("080e1c")
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color = Color("819cca")
    environment.environment.ambient_light_energy = 0.65
    environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    add_child(environment)
    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-42, -35, 0)
    key.light_color = Color("b9d9ff")
    key.light_energy = 2.1
    key.shadow_enabled = true
    add_child(key)
    var fill := OmniLight3D.new()
    fill.position = Vector3(-3, 3, -1)
    fill.light_color = PINK
    fill.light_energy = 0.8
    fill.omni_range = 9
    add_child(fill)
    box("Infinite floor", Vector3(200, 0.1, 200), Vector3(0, -0.14, 0), surface(Color("0a1020"), true))
    var grid := surface(Color("172a40"), true)
    for i in range(-20, 21):
        box("Grid X", Vector3(40, 0.004, 0.012), Vector3(0, -0.083, i), grid)
        box("Grid Z", Vector3(0.012, 0.004, 40), Vector3(i, -0.083, 0), grid)
    var podium := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 3.15
    cylinder.bottom_radius = 3.25
    cylinder.height = 0.2
    cylinder.radial_segments = 64
    podium.mesh = cylinder
    podium.material_override = surface(Color("141d31"))
    podium.position.y = 0.025
    add_child(podium)
    for i in range(96):
        var angle := i * TAU / 96.0
        var next_angle := (i + 1) * TAU / 96.0
        var a := Vector3(cos(angle)*3.18, 0.08, sin(angle)*3.18)
        var b := Vector3(cos(next_angle)*3.18, 0.08, sin(next_angle)*3.18)
        var segment := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = Vector3(0.025, 0.026, a.distance_to(b) + 0.003)
        segment.mesh = mesh
        segment.material_override = surface(CYAN if i < 48 else PINK, true)
        add_child(segment)
        segment.position = (a+b)/2
        segment.look_at(b, Vector3.UP)
    camera = Camera3D.new()
    camera.fov = 43
    camera.current = true
    add_child(camera)
    update_camera()
    var canvas := CanvasLayer.new()
    add_child(canvas)
    var ui := Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(ui)
    text("N / D     MOTORWORKS", Vector2(56, 35), 19, CYAN, ui)
    text("ASSET LAB     /     001", Vector2(1140, 38), 16, Color("91a1bb"), ui)
    text("NEON DRIFT", Vector2(52, 76), 58, Color("edf4ff"), ui)
    text("ION-01  /  LOW-POLY INTERCEPTOR", Vector2(57, 149), 17, Color("91a1bb"), ui)
    text("01", Vector2(1250, 99), 48, PINK, ui)
    text("PROTOTYPE", Vector2(1230, 158), 13, Color("91a1bb"), ui)
    text("OBSIDIAN ALLOY", Vector2(57, 684), 16, CYAN, ui)
    text("Electric silhouette. Analog attitude.", Vector2(57, 711), 22, Color("edf4ff"), ui)
    text("PIPELINE", Vector2(57, 800), 12, Color("7586a3"), ui)
    text("BLENDER  /  bpy  →  glTF 2.0", Vector2(57, 825), 19, Color("d4e3f6"), ui)
    text("RENDERER", Vector2(540, 800), 12, Color("7586a3"), ui)
    text("GODOT 4  /  COMPATIBILITY", Vector2(540, 825), 19, Color("d4e3f6"), ui)
    text("INSPECT", Vector2(1050, 800), 12, Color("7586a3"), ui)
    text("DRAG TO ORBIT   ·   R TO RESET", Vector2(1050, 825), 17, CYAN, ui)
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--capture="):
            for frame in range(12):
                await get_tree().process_frame
            await RenderingServer.frame_post_draw
            var path := argument.trim_prefix("--capture=")
            var result := get_viewport().get_texture().get_image().save_png(path)
            if result != OK:
                push_error("Screenshot save failed: %s" % result)
                get_tree().quit(1)
            else:
                print("SCREENSHOT_SAVED: ", path)
                get_tree().quit(0)

func update_camera() -> void:
    camera.position = Vector3(sin(azimuth)*cos(elevation), sin(elevation), cos(azimuth)*cos(elevation))*distance
    camera.look_at(Vector3(0, 0.5, 0), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            dragging = event.pressed
        if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            distance = maxf(6.5, distance - 0.4)
        if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            distance = minf(13, distance + 0.4)
    elif event is InputEventMouseMotion and dragging:
        azimuth -= event.relative.x * 0.006
        elevation = clampf(elevation + event.relative.y * 0.004, 0.15, 0.85)
    elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
        azimuth = 0.69
        elevation = 0.43
        distance = 8.8
    update_camera()
