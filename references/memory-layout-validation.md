# Read-only property recovery validation

Roblox build: `version-e7d81637d42c4b23`. Validated through the local Matcha MCP on 2026-09-05.

The classification rules remain those adapted from Hydroxide commit `6951b2a5c29e47ebde700f3897e50cc2d863e89c`. Offsets below are independent observations of this Roblox build; they are not claimed to come from Hydroxide.

## Verified fields

| Object | Field | Relative layout |
| --- | --- | --- |
| MeshPart | MeshId string | +0x310 |
| UnionOperation | AssetId string | +0x310 |
| SpecialMesh | MeshId string | +0xF8 |
| SpecialMesh | MeshType integer | +0x148; Sphere = 3 |
| BasePart | RGB bytes | +0x1A8, +0x1A9, +0x1AA |
| ParticleEmitter | Rate (float) | +0x248 |
| ParticleEmitter | Color sequence | data pointer +0x178, count +0x180, capacity +0x184 |

Strings: data/inline storage at the field, length at +16, capacity at +24. Long strings use a data pointer; the validated empty Opal MeshId has length 0 and capacity 15. Particle keypoints contain five floats (time, RGB, envelope), 20 bytes per keypoint.

## Independent references

- Backpack Old Ring: `rbxassetid://5196782997`.
- Backpack Amulet: `rbxassetid://5196551436`.
- Backpack Idol of the Forgotten: `https://www.roblox.com//asset/?id=2765613127`.
- Backpack Opal: empty SpecialMesh MeshId, MeshType 3; RGB 248/248/248.
- Named inventory gem references: Ruby 255/0/0, Emerald 0/184/49, Sapphire 16/42/220, Diamond 164/187/190.
- Opal and four named gem references: particle color sequence `0 1 1 1 0 1 1 1 1 0`.
- Map gem: SpecialMesh asset 2877143560, white sequence, red part color; classifier returned Ruby.
- Live classifier result: 25 identified / 25 candidates during the test. Candidate counts change as items spawn and disappear.

## Boundaries

Only bounded reads of item objects and their relevant child objects were performed. No input, movement, remote calls, memory writes, collection or server changes were made. The exploratory scans are not part of the production script.

Production checks the exact version before any memory read, validates object headers, pointers, string length/capacity and sequence metadata, and rejects malformed data. Unknown builds use native bindings only. Simulation tests cover successful recovery and rejection of malformed strings, pointers, object headers, mesh types and color-sequence counts.

This fixes missing property access for the tested signatures. The Rate field was subsequently validated at +0x248 against four named Phoenix Down references, each returning 5. Their first keypoint green component was 0.800000011920929. The production classifier recognized all four as Phoenix Down; a concurrent map sample identified 40/40 candidates. Raw Rate paths for Azael Horn, Phoenix Flower and Mysterious Artifact were tested in simulation, not against named live references. BrickColor.Name remains native-only. The test does not establish universal identification, authenticity of every candidate, pickup safety or immunity to anti-cheat detection.

## 2026-10-05: `version-02c37bc51a384b8f`

Every field above moved by exactly **-0x10** on this build. Revalidated through the local Matcha MCP against live objects in Rogue Khei:

| Field | New offset | Evidence |
| --- | --- | --- |
| MeshPart MeshId | +0x300 | 22/22 sampled MeshParts returned an asset string |
| UnionOperation AssetId | +0x300 | 25/25 sampled Unions returned an asset string |
| SpecialMesh MeshId | +0xE8 | asset strings on file meshes; empty strings keep length 0 / capacity 15 |
| SpecialMesh MeshType | +0x138 | 5 (FileMesh) on meshes with ids, 3 (Sphere) and 0 (Head) elsewhere |
| BasePart RGB | +0x198..+0x19A | bytes equal the native `Color` on six parts |
| ParticleEmitter sequence / Rate | +0x168 / +0x170 / +0x174, +0x238 | 8/8 emitters: 2-3 keypoints from time 0 to 1, plausible rates |

`TrinketESP.lua` now keeps a per-build shift table (`memoryShifts`). Unlisted builds still never read memory. No trinkets were replicated during this session, so named-item classification on the new build is covered by the offset evidence and simulated tests, not by a live trinket sample.

### GuiObject AbsoluteSize

On this Matcha/Roblox build the native `AbsoluteSize` binding returns `(0, 0)` for every GuiObject, while `AbsolutePosition` still works. The engine stores AbsoluteSize directly after AbsolutePosition (mana bar: position at +0xFC, size at +0x104). `ManaOverlay.lua` finds that offset once by matching the native position, rechecks the position on every read, and only then uses the following two floats. Live result: mana bar (22, 434.89), recovered size (28, 298.45), identical to the earlier native reading.
