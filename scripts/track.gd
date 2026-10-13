class_name NeonTrack
extends Node3D
## Original procedural circuit. Repeated scenery uses MultiMesh draw batching.
const STEPS := 128
const WIDTH := 17.0
const GATES := 8
var points := PackedVector3Array()
var batches: Dictionary = {}
var gates: Array[Transform3D] = []
var materials: Dictionary = {}

func material(color: Color, unlit := false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.9
    if unlit:
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return mat

func cube(group: String, point: Vector3, size: Vector3, heading := 0.0, solid := false) -> void:
    var basis := Basis(Vector3.UP, heading)
    var pose := Transform3D(basis.scaled_local(size), point)
    if not batches.has(group):
        batches[group] = []
    batches[group].append(pose)
    if solid:
        var shape := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = size
        shape.shape = box
        shape.transform = Transform3D(basis, point)
        $Boundaries.add_child(shape)

func point_at(t: float) -> Vector3:
    return Vector3(72*cos(t) + 7*cos(3*t), 0, 51*sin(t) + 5*sin(2*t))

func _ready() -> void:
    materials = {
        "road": material(Color("172235")), "curb": material(Color("25334c")),
        "cyan": material(Color("14dbed"), true), "pink": material(Color("ec297f"), true),
        "lane": material(Color("657b97"), true), "dark": material(Color("0b1222")),
        "tower": material(Color("101b32")), "window": material(Color("266675"), true),
        "white": material(Color("c6ebed"), true),
    }
    var boundaries := StaticBody3D.new()
    boundaries.name = "Boundaries"
    add_child(boundaries)
    cube("dark", Vector3(0,-0.25,0), Vector3(500,.5,500), 0, true)
    for i in range(STEPS):
        points.append(point_at(-PI/2 + TAU*i/STEPS))
    build_road_surface()
    for i in range(STEPS):
        var a := points[i]
        var b := points[(i+1)%STEPS]
        var direction := (b-a).normalized()
        var heading := atan2(direction.x, direction.z)
        var right := Vector3(direction.z, 0, -direction.x)
        var middle := (a+b)/2
        for side in [-1,1]:
            var edge: Vector3 = middle+right*side*(WIDTH/2+.3)
            cube("curb", edge+Vector3(0,.22,0), Vector3(.6,.7,a.distance_to(b)+.3), heading, true)
            cube("cyan" if side==1 else "pink", edge+Vector3(0,.59,0), Vector3(.15,.06,a.distance_to(b)+.3), heading)
        if i%2==0:
            cube("lane", middle+Vector3(0,.019,0), Vector3(.16,.008,1.7), heading)
    for i in range(GATES):
        var index := i*STEPS/GATES
        var forward := (points[(index+1)%STEPS]-points[index]).normalized()
        var heading := atan2(forward.x, forward.z)
        var gate := Transform3D(Basis(Vector3.UP,heading),points[index])
        gates.append(gate)
        var color := "cyan" if i==0 else "pink"
        for side in [-1,1]:
            cube("dark", gate*Vector3(side*9,2.8,0), Vector3(.8,5.6,.8), heading)
            cube(color, gate*Vector3(side*8.55,2.8,0), Vector3(.1,5.6,.18), heading)
        cube("dark", gate*Vector3(0,5.5,0), Vector3(18.8,.65,.8), heading)
        cube(color, gate*Vector3(0,5.85,0), Vector3(18.8,.08,.85), heading)
        var label := Label3D.new()
        label.text = "NEON DRIFT  /  FINISH" if i==0 else "SECTOR  0%d  >>>" % i
        label.font_size = 64
        label.pixel_size = .012
        label.modulate = Color("c6f6ff")
        label.no_depth_test = false
        add_child(label)
        label.transform = gate
        label.position += Vector3(0,5.5,0)-forward*.48
        label.rotation.y += PI
    # Start stripe: two rows of alternating squares.
    for row in range(2):
        for x in range(16):
            cube("white" if (x+row)%2==0 else "dark", gates[0]*Vector3(x-7.5,.022,row*.8), Vector3(1,.015,.8), gates[0].basis.get_euler().y)
    var rng := RandomNumberGenerator.new()
    rng.seed = 3107
    for i in range(64):
        var angle := TAU*i/64
        var radius := rng.randf_range(1.55,2.05)
        var point := Vector3(82*cos(angle)*radius,0,62*sin(angle)*radius)
        var height := rng.randf_range(8,40)
        var width := rng.randf_range(4,10)
        cube("tower", point+Vector3(0,height/2,0), Vector3(width,height,width))
        for floor_index in range(2,int(height),4):
            cube("window", point+Vector3(0,floor_index,0), Vector3(width+.03,.15,width+.03))
        cube("pink" if i%3==0 else "cyan", point+Vector3(0,height,0), Vector3(width+.06,.09,width+.06))
    # Low center structures keep sightlines open.
    for i in range(12):
        var a := TAU*i/12
        cube("dark",Vector3(25*cos(a),1.5,18*sin(a)),Vector3(3,3,3))
        cube("cyan",Vector3(25*cos(a),3.05,18*sin(a)),Vector3(3.1,.1,3.1))
    for group in batches:
        var mesh := BoxMesh.new()
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = mesh
        multi.instance_count = batches[group].size()
        for i in range(multi.instance_count):
            multi.set_instance_transform(i,batches[group][i])
        var instance := MultiMeshInstance3D.new()
        instance.multimesh = multi
        instance.material_override = materials[group]
        add_child(instance)

func crossed_gate(index: int, previous: Vector3, current: Vector3) -> bool:
    var gate := gates[index]
    var before := gate.affine_inverse()*previous
    var after := gate.affine_inverse()*current
    if before.z >= 0 or after.z < 0:
        return false
    var fraction := -before.z/(after.z-before.z)
    var crossing := before.lerp(after,fraction)
    return absf(crossing.x) < WIDTH/2 and absf(crossing.y) < 3

func recovery_gate(next_gate: int) -> Transform3D:
    var previous := (next_gate-1+GATES)%GATES
    var result := gates[previous]
    result.origin += result.basis.z * 12 + Vector3.UP*.25
    return result

func build_road_surface() -> void:
    # Shared edge positions avoid coplanar overlapping boxes flickering in WebGL.
    var left := PackedVector3Array()
    var right := PackedVector3Array()
    for i in range(STEPS):
        var tangent := (points[(i+1)%STEPS]-points[(i-1+STEPS)%STEPS]).normalized()
        var side := Vector3(tangent.z,0,-tangent.x)*WIDTH/2
        left.append(points[i]-side+Vector3.UP*.02)
        right.append(points[i]+side+Vector3.UP*.02)
    var builder := SurfaceTool.new()
    builder.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(STEPS):
        var next := (i+1)%STEPS
        for vertex in [left[i],right[next],right[i],left[i],left[next],right[next]]:
            builder.set_normal(Vector3.UP)
            builder.add_vertex(vertex)
    var node := MeshInstance3D.new()
    node.mesh = builder.commit()
    var mat: StandardMaterial3D = materials["road"]
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    node.material_override = mat
    add_child(node)

func nearest_sample(position_on_track: Vector3) -> int:
    var nearest:=0
    var distance:=INF
    for i in range(points.size()):
        var candidate:=points[i].distance_squared_to(position_on_track)
        if candidate<distance:
            distance=candidate
            nearest=i
    return nearest
