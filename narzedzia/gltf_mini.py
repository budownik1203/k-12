"""Minimalny zapis modeli low poly do glTF 2.0 (.glb) bez zewnętrznych zależności poza numpy.

Model = lista węzłów, każdy węzeł ma siatkę złożoną z prymitywów (po jednym na materiał).
Normalne są płaskie (wierzchołki nie są współdzielone między ścianami), co daje twardy,
fasetowany wygląd typowy dla low poly.

Konwencje nazw węzłów (rozumiane przez importer glTF w Godot):
  nazwa-col       siatka widoczna + kolizja trimesh
  nazwa-colonly   tylko kolizja, bez siatki widocznej
Konwencje nazw materiałów (rozumiane przez psx_materialy.gd):
  nazwa_emit      materiał świecący (tekstura używana też jako emisja)
"""
import json
import struct
from pathlib import Path

import numpy as np

UP = np.array([0.0, 1.0, 0.0])


def _v(p):
    return np.asarray(p, dtype=float)


class Mesh:
    def __init__(self):
        self.prims = {}  # nazwa materiału -> dict(pos, nrm, uv, idx)

    def _prim(self, mat):
        if mat not in self.prims:
            self.prims[mat] = {"pos": [], "nrm": [], "uv": [], "idx": []}
        return self.prims[mat]

    def empty(self):
        return not any(p["idx"] for p in self.prims.values())

    # -------------------------------------------------------------- podstawy

    def quad(self, mat, p0, p1, p2, p3, uv0, uv1, uv2, uv3, facing=None):
        """Czworokąt p0-p1-p2-p3 (przeciwnie do ruchu wskazówek zegara patrząc z przodu).
        facing: opcjonalny wektor, w którą stronę ma patrzeć przód (kolejność jest wtedy poprawiana)."""
        ps = [_v(p0), _v(p1), _v(p2), _v(p3)]
        uvs = [uv0, uv1, uv2, uv3]
        n = np.cross(ps[1] - ps[0], ps[2] - ps[0])
        if np.linalg.norm(n) < 1e-12:
            n = np.cross(ps[2] - ps[0], ps[3] - ps[0])
        if facing is not None and np.dot(n, facing) < 0:
            ps = ps[::-1]
            uvs = uvs[::-1]
            n = -n
        ln = np.linalg.norm(n)
        if ln < 1e-12:
            return
        n = n / ln
        pr = self._prim(mat)
        base = len(pr["pos"])
        for p, uv in zip(ps, uvs):
            pr["pos"].append(p)
            pr["nrm"].append(n)
            pr["uv"].append(uv)
        pr["idx"] += [base, base + 1, base + 2, base, base + 2, base + 3]

    def tri(self, mat, p0, p1, p2, uv0, uv1, uv2, facing=None):
        ps = [_v(p0), _v(p1), _v(p2)]
        uvs = [uv0, uv1, uv2]
        n = np.cross(ps[1] - ps[0], ps[2] - ps[0])
        if facing is not None and np.dot(n, facing) < 0:
            ps = ps[::-1]
            uvs = uvs[::-1]
            n = -n
        ln = np.linalg.norm(n)
        if ln < 1e-12:
            return
        n = n / ln
        pr = self._prim(mat)
        base = len(pr["pos"])
        for p, uv in zip(ps, uvs):
            pr["pos"].append(p)
            pr["nrm"].append(n)
            pr["uv"].append(uv)
        pr["idx"] += [base, base + 1, base + 2]

    # -------------------------------------------------------------- bryły

    def box(self, mat, mn, mx, uv="world", tiles=1.0, faces="+x-x+y-y+z-z", mats=None):
        """Prostopadłościan wyrównany do osi.
        uv: 'world' (planarnie w metrach * tiles) albo 'fit' (każda ściana 0..1).
        mats: opcjonalny słownik ściana -> materiał (np. {'+z': 'drzwi'})."""
        x0, y0, z0 = mn
        x1, y1, z1 = mx
        F = {
            "+x": ([(x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1)], (1, 0, 0), lambda p: (-p[2], p[1])),
            "-x": ([(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)], (-1, 0, 0), lambda p: (p[2], p[1])),
            "+z": ([(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], (0, 0, 1), lambda p: (p[0], p[1])),
            "-z": ([(x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0)], (0, 0, -1), lambda p: (-p[0], p[1])),
            "+y": ([(x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0)], (0, 1, 0), lambda p: (p[0], -p[2])),
            "-y": ([(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], (0, -1, 0), lambda p: (p[0], p[2])),
        }
        for key in ("+x", "-x", "+y", "-y", "+z", "-z"):
            if key not in faces:
                continue
            ps, nrm, proj = F[key]
            m = (mats or {}).get(key, mat)
            if uv == "fit":
                uvs = [(0, 1), (1, 1), (1, 0), (0, 0)]
            else:
                uvs = [(proj(p)[0] * tiles, -proj(p)[1] * tiles) for p in ps]
            self.quad(m, *ps, *uvs, facing=np.array(nrm, dtype=float))

    def beam(self, mat, a, b, w, h, tiles=1.0):
        """Belka o przekroju w x h między punktami a i b (poręcze, tralki)."""
        a, b = _v(a), _v(b)
        d = b - a
        L = np.linalg.norm(d)
        d = d / L
        ref = UP if abs(np.dot(d, UP)) < 0.95 else np.array([1.0, 0, 0])
        s = np.cross(d, ref)
        s /= np.linalg.norm(s)
        u = np.cross(s, d)
        hw, hh = w / 2, h / 2
        c = []
        for p in (a, b):
            c.append([p - s * hw - u * hh, p + s * hw - u * hh, p + s * hw + u * hh, p - s * hw + u * hh])
        A, B = c
        for i in range(4):
            j = (i + 1) % 4
            mid = (A[i] + A[j] + B[i] + B[j]) / 4 - (a + b) / 2
            self.quad(mat, A[i], A[j], B[j], B[i], (0, 0), (1, 0), (1, L * tiles), (0, L * tiles), facing=mid)
        self.quad(mat, *A, (0, 0), (1, 0), (1, 1), (0, 1), facing=-d)
        self.quad(mat, *B, (0, 0), (1, 0), (1, 1), (0, 1), facing=d)

    def cylinder(self, mat_side, mat_cap, center, r, h, seg=10, u_tiles=1.0, cap_top=True, cap_bottom=True):
        cx, cy, cz = center
        angs = np.linspace(0, 2 * np.pi, seg + 1)
        for i in range(seg):
            a0, a1 = angs[i], angs[i + 1]
            p0 = (cx + r * np.cos(a0), cy, cz + r * np.sin(a0))
            p1 = (cx + r * np.cos(a1), cy, cz + r * np.sin(a1))
            p2 = (p1[0], cy + h, p1[2])
            p3 = (p0[0], cy + h, p0[2])
            out = np.array([np.cos((a0 + a1) / 2), 0, np.sin((a0 + a1) / 2)])
            u0, u1 = i / seg * u_tiles, (i + 1) / seg * u_tiles
            self.quad(mat_side, p0, p1, p2, p3, (u0, 1), (u1, 1), (u1, 0), (u0, 0), facing=out)
            for top, flag in ((True, cap_top), (False, cap_bottom)):
                if not flag:
                    continue
                y = cy + h if top else cy
                c = (cx, y, cz)
                q0 = (p0[0], y, p0[2])
                q1 = (p1[0], y, p1[2])
                uvc = (0.5, 0.5)
                uv0 = (0.5 + 0.5 * np.cos(a0), 0.5 + 0.5 * np.sin(a0))
                uv1 = (0.5 + 0.5 * np.cos(a1), 0.5 + 0.5 * np.sin(a1))
                self.tri(mat_cap, c, q0, q1, uvc, uv0, uv1, facing=np.array([0, 1 if top else -1, 0.0]))


# ------------------------------------------------------------------ zapis

def write_glb(path, nodes, materials, texture_dir_rel="../textures"):
    """nodes: lista (nazwa, Mesh, [x, y, z]).
    materials: dict nazwa -> dict(texture='plik.png', double_sided=False)."""
    path = Path(path)
    used = []
    for _, mesh, _ in nodes:
        for m in mesh.prims:
            if m not in used:
                used.append(m)
    images, textures, mats = [], [], []
    tex_index = {}
    for m in used:
        spec = materials[m]
        t = spec["texture"]
        if t not in tex_index:
            images.append({"uri": f"{texture_dir_rel}/{t}"})
            textures.append({"source": len(images) - 1, "sampler": 0})
            tex_index[t] = len(textures) - 1
        mat = {
            "name": m,
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": tex_index[t]},
                "metallicFactor": 0.0,
                "roughnessFactor": 1.0,
            },
            "doubleSided": bool(spec.get("double_sided", False)),
        }
        if m.endswith("_emit"):
            mat["emissiveTexture"] = {"index": tex_index[t]}
            mat["emissiveFactor"] = [1.0, 1.0, 1.0]
        mats.append(mat)

    blob = bytearray()
    views, accessors, meshes, gnodes = [], [], [], []

    def add(data, target, ctype, typ, minmax=False):
        nonlocal blob
        while len(blob) % 4:
            blob.append(0)
        off = len(blob)
        raw = data.tobytes()
        blob += raw
        views.append({"buffer": 0, "byteOffset": off, "byteLength": len(raw), "target": target})
        acc = {"bufferView": len(views) - 1, "componentType": ctype, "count": int(data.shape[0]), "type": typ}
        if minmax:
            acc["min"] = data.min(axis=0).tolist()
            acc["max"] = data.max(axis=0).tolist()
        accessors.append(acc)
        return len(accessors) - 1

    for name, mesh, tr in nodes:
        prims = []
        for m, pr in mesh.prims.items():
            if not pr["idx"]:
                continue
            pos = np.array(pr["pos"], dtype=np.float32)
            nrm = np.array(pr["nrm"], dtype=np.float32)
            uv = np.array(pr["uv"], dtype=np.float32)
            idx = np.array(pr["idx"], dtype=np.uint32)
            a_pos = add(pos, 34962, 5126, "VEC3", True)
            a_nrm = add(nrm, 34962, 5126, "VEC3")
            a_uv = add(uv, 34962, 5126, "VEC2")
            a_idx = add(idx, 34963, 5125, "SCALAR")
            prims.append({"attributes": {"POSITION": a_pos, "NORMAL": a_nrm, "TEXCOORD_0": a_uv},
                          "indices": a_idx, "material": used.index(m)})
        if not prims:
            continue
        meshes.append({"name": name, "primitives": prims})
        gnodes.append({"name": name, "mesh": len(meshes) - 1, "translation": [float(v) for v in tr]})

    while len(blob) % 4:
        blob.append(0)
    gltf = {
        "asset": {"version": "2.0", "generator": "strefa-k12 gltf_mini"},
        "scene": 0,
        "scenes": [{"nodes": list(range(len(gnodes)))}],
        "nodes": gnodes,
        "meshes": meshes,
        "materials": mats,
        "textures": textures,
        "images": images,
        # 9728 = NEAREST: piksele bez rozmycia
        "samplers": [{"magFilter": 9728, "minFilter": 9728, "wrapS": 10497, "wrapT": 10497}],
        "accessors": accessors,
        "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
    }
    js = json.dumps(gltf, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    total = 12 + 8 + len(js) + 8 + len(blob)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A))
        f.write(js)
        f.write(struct.pack("<II", len(blob), 0x004E4942))
        f.write(blob)
    tris = sum(len(p["idx"]) // 3 for _, m, _ in nodes for p in m.prims.values())
    print(f"zapisano {path.name}: {tris} trójkątów")
    return tris
