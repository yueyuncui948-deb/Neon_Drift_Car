"""Rebuild the original Neon Drift car: blender --background --python tools/build_car.py.
All geometry is authored procedurally with bpy; no third-party assets are used.
Blender coordinates: X width, -Y front, Z up. Dimensions are in meters.
"""
import bpy
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets' / 'cars'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def material(name, color, metallic=0.0, roughness=0.4, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    p = mat.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = roughness
    if emission:
        p.inputs['Emission Color'].default_value = (*color, 1)
        p.inputs['Emission Strength'].default_value = emission
    mat.diffuse_color = (*color, 1)
    return mat

body = material('Obsidian violet | painted alloy', (0.065, 0.047, 0.14), 0.65, 0.3)
edge = material('Graphite | aero carbon', (0.018, 0.024, 0.04), 0.3, 0.5)
glass = material('Midnight blue | opaque stylized glass', (0.018, 0.095, 0.15), 0.65, 0.18)
rubber = material('Tire rubber', (0.011, 0.014, 0.022), 0.0, 0.85)
cyan = material('Ion cyan | emissive', (0.02, 0.85, 1.0), 0.25, 0.25, 2.5)
pink = material('Hot magenta | emissive', (1.0, 0.025, 0.33), 0.3, 0.28, 2)
white = material('Ice white | headlamps', (0.65, 0.92, 1.0), 0, 0.22, 3)
metal = material('Brushed titanium', (0.28, 0.32, 0.4), 0.8, 0.32)


def cube(name, loc, size, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    ob = bpy.context.object
    ob.name = name
    ob.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(mat)
    if bevel:
        mod = ob.modifiers.new('Single facet edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        ob.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')
    return ob


def hull(name, rings, mat):
    # Each longitudinal ring: y, half-width at base, half-width at top, bottom, top.
    verts = []
    for y, wb, wt, zb, zt in rings:
        verts.extend([(-wb,y,zb), (wb,y,zb), (wt,y,zt), (-wt,y,zt)])
    faces = [(3,2,1,0)]
    for i in range(len(rings)-1):
        for j in range(4):
            a = 4*i+j
            b = 4*i+(j+1)%4
            faces.append((a,b,b+4,a+4))
    n = 4*(len(rings)-1)
    faces.append((n,n+1,n+2,n+3))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    # Recalculate winding consistently for glTF's backface culling.
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    ob.select_set(False)
    return ob


hull('01 | wedge chassis', [(-2.35,.85,.83,.35,.62),(-1.6,1.02,.98,.3,.82),(.8,1.02,.96,.3,.88),(2.15,.91,.9,.4,.79)], body)
cube('Front splitter', (0,-2.26,.33), (1.95,.43,.1), edge, .045)
cube('Front cyan blade', (0,-2.485,.405), (1.78,.035,.035), cyan)
cube('Intake', (0,-2.361,.515), (.73,.035,.135), edge)
for x in [-.58,.58]:
    cube('Headlamp housing', (x,-2.365,.6), (.48,.055,.125), edge, .02)
    cube('LED headlight', (x,-2.4,.625), (.4,.022,.037), white)
    cube('LED lower line', (x,-2.4,.573), (.4,.022,.019), cyan)
# Faceted canopy. Opaque glass avoids web transparency sorting artifacts.
hull('02 | panoramic canopy', [(-.86,.78,.68,.8,.91),(-.21,.78,.59,.82,1.39),(.76,.78,.59,.85,1.39),(1.32,.77,.7,.84,.9)], glass)
cube('Roof panel', (0,.29,1.405), (1.21,1.0,.045), body, .025)
for x in [-.625,.625]:
    cube('Roof cyan rail', (x,.28,1.414), (.035,1.02,.022), cyan)
for x in [-.18,.18]:
    ob = cube('Hood signal stripe', (x,-1.60,.788), (.055,1.02,.025), cyan)
    ob.rotation_euler.x = math.radians(8)
for x in [-1.025,1.025]:
    cube('Sculpted side skirt', (x,.04,.39), (.15,3.50,.19), edge, .04)
    cube('Cyan sill light', (x*1.05,.04,.47), (.035,3.25,.028), cyan)
    cube('Door accent', (x*.975,.2,.82), (.03,.92,.025), pink)
    cube('Rear intake', (x*.995,1.02,.68), (.035,.43,.19), edge)
    mirror = cube('Side mirror', (x*1.1,-.6,1.02), (.22,.26,.10), body, .03)
    cube('Mirror light', (x*1.19,-.68,1.025), (.022,.12,.023), cyan)
# 12-sided tires and 6-spoke emissive rims. Cylinder axes run along X.
for x in [-1.0,1.0]:
    side = -1 if x < 0 else 1
    for y in [-1.42,1.4]:
        for label, radius, depth, xx, mat in [
            ('Tire',.445,.28,x,rubber),
            ('Magenta rim',.325,.025,x+side*.151,pink),
            ('Rim inset',.257,.028,x+side*.169,edge),
            ('Hub',.095,.035,x+side*.194,metal),
        ]:
            bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=depth, location=(xx,y,.46), rotation=(0,math.pi/2,0))
            ob=bpy.context.object
            ob.name=f'{label} {x:+.0f} {y:+.2f}'
            ob.data.materials.append(mat)
        for i in range(6):
            a=i*math.tau/6
            spoke=cube('Six spoke alloy', (x+side*.189,y+math.sin(a)*.16,.46+math.cos(a)*.16), (.026,.042,.24), metal)
            spoke.rotation_euler.x=-a
# Rear wing, louvers, diffuser and rear signature.
for x in [-.67,.67]:
    cube('Wing pylon', (x,1.85,1.03), (.065,.14,.49), edge)
cube('Rear aero wing', (0,1.87,1.3), (2.18,.4,.085), body, .035)
cube('Wing trailing light', (0,2.075,1.3), (2.12,.025,.035), pink)
for x in [-1.08,1.08]:
    cube('Wing endplate', (x,1.88,1.33), (.045,.48,.23), edge, .025)
for y in [1.38,1.51,1.64]:
    cube('Deck louver', (0,y,.883), (1.25,.052,.035), edge)
cube('Rear light bar', (0,2.161,.7), (1.65,.028,.055), pink)
cube('Rear diffuser', (0,2.08,.36), (1.75,.36,.16), edge, .03)
for x in [-.6,-.3,0,.3,.6]:
    cube('Diffuser fin', (x,2.15,.35), (.035,.4,.21), edge)
# Apply transforms/modifiers in exporter, keeping the source editable.
bpy.ops.object.select_all(action='SELECT')
source = ROOT / 'art'
source.mkdir(exist_ok=True)
(source / '.gdignore').touch()
bpy.ops.wm.save_as_mainfile(filepath=str(source/'neon_drift_car.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'neon_drift_car.gltf'), export_format='GLTF_SEPARATE', use_selection=True, export_apply=True, export_yup=True, export_cameras=False, export_lights=False)
triangles = sum(len(ob.data.polygons) for ob in bpy.context.scene.objects if ob.type=='MESH')
print(f'CAR EXPORT COMPLETE: {len(bpy.context.scene.objects)} objects; {triangles} source polygons; {OUT}')
