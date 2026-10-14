#!/usr/bin/env python3
"""Read-only glTF/GLB structure inspection; does not import or execute asset code.
Usage: python3 tools/inspect_car_asset.py file.glb [file.gltf ...] --output report.json
Triangle counts include all mesh primitives, including unused/alternate meshes.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct


def inspect(path):
    path=Path(path)
    raw=path.read_bytes()
    if raw[:4]==b'glTF':
        magic,version,length=struct.unpack_from('<4sII',raw)
        if version!=2 or length!=len(raw):
            raise ValueError(f'{path.name}: invalid GLB header')
        offset=12
        document=None
        while offset+8<=len(raw):
            size,kind=struct.unpack_from('<II',raw,offset)
            offset+=8
            if offset+size>len(raw): raise ValueError('Truncated GLB chunk')
            if kind==0x4E4F534A: document=json.loads(raw[offset:offset+size])
            offset+=size
        if document is None: raise ValueError('Missing glTF JSON chunk')
    else:
        document=json.loads(raw)
    accessors=document.get('accessors',[])
    meshes=document.get('meshes',[])
    nodes=document.get('nodes',[])
    triangles=[]
    unsupported=[]
    for mesh in meshes:
        count=0
        for primitive in mesh.get('primitives',[]):
            index=primitive.get('indices',primitive.get('attributes',{}).get('POSITION'))
            if index is None: continue
            entries=accessors[index]['count']
            mode=primitive.get('mode',4)
            if mode==4: count+=entries//3
            elif mode in (5,6): count+=max(0,entries-2)
            else: unsupported.append(mode)
        triangles.append(count)
    parents={child:i for i,n in enumerate(nodes) for child in n.get('children',[])}
    wheel_nodes=[{'index':i,'name':n.get('name',''),'parent':nodes[parents[i]].get('name','') if i in parents else None,'translation':n.get('translation'),'mesh':n.get('mesh')} for i,n in enumerate(nodes) if any(term in n.get('name','').lower() for term in ['wheel','tire','tyre','rim','axle'])]
    skins=document.get('skins',[])
    return {
        'file':path.name,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),
        'generator':document.get('asset',{}).get('generator'),
        'mesh_count':len(meshes),'material_count':len(document.get('materials',[])),
        'triangles_all_meshes':sum(triangles),
        'triangles_mesh_node_instances':sum(triangles[n['mesh']] for n in nodes if 'mesh' in n),
        'skin_count':len(skins),'skin_joint_counts':[len(s.get('joints',[])) for s in skins],
        'skinned_node_count':sum('skin' in n for n in nodes),
        'animations':[{'name':a.get('name',''),'channels':len(a.get('channels',[])),'target_nodes':[nodes[c['target']['node']].get('name','') for c in a.get('channels',[]) if 'node' in c.get('target',{})]} for a in document.get('animations',[])],
        'wheel_named_nodes':wheel_nodes,
        'extensions_used':document.get('extensionsUsed',[]),
        'extensions_required':document.get('extensionsRequired',[]),
        'external_images':[i['uri'] for i in document.get('images',[]) if 'uri' in i and not i['uri'].startswith('data:')],
        'non_triangle_modes':sorted(set(unsupported)),
        'note':'No skin means no glTF skin binding; node names alone do not prove usable wheel pivots. Runtime import and axis tests remain required.'
    }

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('files',nargs='+')
    parser.add_argument('--output',type=Path)
    args=parser.parse_args()
    result=json.dumps([inspect(p) for p in args.files],ensure_ascii=False,indent=2)+'\n'
    if args.output: args.output.write_text(result)
    else: print(result,end='')
