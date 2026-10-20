# torso_patches (20 Oct, owner's prompt 15 "upper traps texture and back shape")

Python tools (numpy, scipy, pillow) that made two data patches for `UpperTorso__Unified`:

- `cap.py` (`remesh`, `apply_cap`): re-meshes the torso's top cap (the generator closed the neck hole with a fan of long
  thin triangles). Same 51 interior vertex ids, same 300 triangle slots. Its result is `MuscleData.UpperTorso__Unified__cap`
  (read by `MuscleMeshes` `applyCapPatch`). Input: a dump of the raw data (`load.py` format), made in Studio.
- `torso_uv_patch.py` (+ `uvfix2.py`, `uvfix.py`, `unroll.py`, `lscm.py`): the new texture map
  (`MuscleData.UpperTorso__Unified__uvfix` + parts `_1`.. `_5`, read by `applyUVPatch`). Input: a dump of the final torso
  (base, nbase, uv, tris, positions P0 / P1 / P2, cap ids).
  Usage: `python torso_uv_patch.py <dump> <out main .luau> <check image .png>`.

These are the session's working scripts, kept so the patches can be remade; the generated modules in `src/` are the
source of truth. Stage meshes: `tools/torso_back_stage_corrections.luau` + `tools/torso_back_lowpoly.py`.
