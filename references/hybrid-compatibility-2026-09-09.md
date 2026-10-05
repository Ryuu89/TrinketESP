# Hybrid compatibility tests — 2026-09-09

This follow-up responds to the request to implement Spectate and mouse-free Auto Pickup and to test syntax. It does not claim either feature works.

## Live environment

MCP reported Hybrid enabled in Rogue Gaia, job d8a5ed5b-72a5-4fcf-a0f2-fc2aff37a15c. A living character was already present. The existing unified overlay was running and was preserved.

Explicit global lookups returned nil for fireclickdetector, firesignal, getconnections, getsenv, getgenv, getrenv and Instance. The current MCP tool inventory contained the same nine inspection/execution tools and no separate Hybrid/native execution endpoint.

A same-subject camera assignment, without selecting another player, returned:
`Unknown property: CameraSubject`.
The original CameraSubject address remained unchanged. MCP marked the probe as an error because of this rejected operation, despite pcall capturing the error and later prints completing. No actual camera movement was requested.

A bounded direct-workspace trinket sample found zero matching detectors in this snapshot. This is not evidence that no detectors exist elsewhere or that their range became readable. No detector activation or remote invocation was attempted.

## Protected execution investigation

The live environment exposed create_run_secure. A self-authored arithmetic/typeof probe supplied as its single argument was rejected for a missing second string argument. Supplying a local test string as the second argument returned a 12-character string, which run_secure rejected as invalid Base64. No alternative execution environment was established; no downloaded payload was executed.

## Community examples

The three user-supplied community scripts were fetched and inspected as text, never executed.

- Leox385 AutoFarmm uses the game's RoadmapJob RemoteFunction (offer/getNPC). Its attempted GUI signal firing uses getconnections inside nested pcalls; that source does not prove that the absent function works in Matcha.
- The kokomelo213 gist uses game-specific PurchaseWorldBuyableItem, SellSmuggledGoods and LaunderBriefcase remotes.
- The slithergoh gist uses game-specific RemoteEvents; no fireclickdetector or working camera-subject adapter was found.

Those interaction contracts do not substitute for Rogue's ClickDetector events. The local Hydroxide snapshot was re-read: auto trinket calls fireclickdetector after reading MaxActivationDistance and excludes Azael Horn; leaderboard spectate sets CameraType and CameraSubject.

## Syntax and regression results

All five modules compiled separately with Luau 0.737: TrinketESP, ManaOverlay, Proximity, WorldESP and the generated Rogue bundle.

Existing regression suites passed 2,131 + 192 + 107 + 913 + 472 = 3,815 assertions. These validate existing code, not the missing pickup/Spectate runtime operations.

## Outcome

No functional pickup or Spectate implementation was added. Source modules and active settings were preserved. No Play, item collection, character motion, server exit or remote request occurred. Needed next: a verified ClickDetector activation mechanism plus readable activation range, and a verified camera subject or viewpoint setter. Further syntax-only variations cannot supply missing runtime bindings.

