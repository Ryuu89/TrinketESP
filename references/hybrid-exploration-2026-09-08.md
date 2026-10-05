# Matcha Hybrid investigation — 2026-09-08

Scope: user authorized independent exploration but explicitly prohibited Play and leaving the server. All remote, item activation, character movement, reset and disconnection tests were excluded. No scheduled unattended job was created.

## Session

- Matcha status: Hybrid enabled, Rogue Gaia PlaceId 5208655184.
- Job ID: d8a5ed5b-72a5-4fcf-a0f2-fc2aff37a15c.
- LocalPlayer.Character was nil; PlayerGui contained StartMenu and ServerStatsGui.
- No character was spawned. The original Hydroxide script and community loaders were not executed.
- Global inventory inspected names/types only, not API keys or unrelated account data.

## Camera probes

1. CameraSubject is readable but absent from the writable binding list; prior same-subject setter test failed. Player.Spectate and Camera.Spectate are nil.
2. Camera.CFrame assignment returned successfully. A temporary 0.25-stud candidate displacement produced **zero observed change** in Camera.Position or CFrame, with a restoration assignment afterward.
3. Camera.Position assignment similarly returned success with **zero observed displacement**; restoration assignment followed.
4. Camera.lookAt with a colon rejected the implicit Instance argument: Vector3Meta expected.
5. Camera.lookAt(origin, target), with a dot, changed orientation in a small controlled test. The original look direction was immediately restored through the same method.
6. Changing the origin supplied to lookAt by 0.25 studs did not move the camera position.

Conclusion: lookAt has a measured local orientation effect. This is not native spectate or proof of arbitrary camera-position control. No persistent camera-follow loop or raw camera-memory write was installed. The brief orientation test is the only observed camera alteration.

## ClickDetector probes

- A live door ClickDetector exposed ClassName, generic FireServer and InvokeServer bindings.
- MaxActivationDistance, MouseClick, Fire and Activate returned nil.
- Global fireclickdetector, firesignal, firetouchinterest and native spectate entry points were absent.
- A bound generic network method does not establish support for that receiver class.
- No FireServer/InvokeServer method was called, on either a detector or a remote.

Hydroxide Auto Trinket (25312–25380) uses fireclickdetector and the actual MaxActivationDistance, and skips Azael Horn. It does not reveal a generic pickup remote. Mouse-free Auto Pickup remains **not implemented**, not a disabled working port.

## Leaderboard source

Read-only decompilation of game.StarterGui.LeaderboardGui.LeaderboardClient confirmed:
- Actual rows are created in MainFrame.ScrollingFrame.
- Formatting uses FirstName, LastName, UberTitle, HouseRank, Gender and Prestige attributes.
- Hover changes a label to the username with an embedded direction mark.
- The game script does not supply a spectate remote or Player.Spectate method.

Hydroxide maps labels to players through hooks/upvalues and inserts transparent GUI buttons, then changes CameraSubject/CameraType. Those native mechanisms are not exposed in this VM. The live PlayerGui has no leaderboard while the user remains in the menu, so clicking a real row was not tested.

## Implemented World Resources

WorldESP.lua is now bundled into Rogue.lua and starts disabled:
- Ore ESP: four source categories with independent filtering, depleted-node hiding and ranges.
- Gaia Ingredient ESP: original container structure and 26 AssetId signatures.
- NPC ESP: original Pants + Humanoid + Torso rule, plus The Eagle exception.
- Opacity, distance fading, text size, outline and per-resource ranges.
- Fixed 96-label pool; separate from the existing 128 trinket labels.
- Independent collector/cache and renderer; no Instance reads during rendering.
- Fair incremental ingredient-folder discovery. Version-validated read-only AssetId recovery is reused from TrinketESP via GetUnionAssetId.
- Periodic signature revalidation; unknown ingredients are hidden, not mislabeled.

No fake Spectate/Auto Pickup controls were added. Trinket classification and mana range logic were preserved.

## Live resource sample

- Workspace.Ores: 40 children.
- Workspace.NPCs: 344 objects before structural filtering (not 344 validated NPC labels).
- Ingredient container: 839 children; 610 matched UnionOperation + ClickDetector + Blacklist.
- 605 ingredient AssetIds readable; 604 recognized by the source table.
- One readable unmapped ID: 2889328423. Five IDs unreadable.
- These counts include replicated/depleted objects and are not a count of available pickups.
- Unified script initialized in the menu without reported startup errors. World and Proximity stayed disabled; Trinkets waited for a character. Mana was paused while Roblox was unfocused.
- Visual placement of the new labels is tested in mocks, not a live spawned session. No forced character proxy or fake successful pickup was used as live validation.

## Validation

- TrinketESP: 2,131 assertions.
- ManaOverlay: 192 assertions.
- Proximity: 66 assertions.
- WorldESP: 913 assertions.
- Unified integration: 472 assertions.
- Total: 3,774 mock assertions; generated bundle compiled with Luau CLI.
- Tests cover all 26 ingredient IDs, category/range changes, transparency, missing properties, invalid geometry, focus, menu/death, stale cache, signature refresh, late spawns, pool pressure, fair discovery, rerun, unload and no game writes/remotes.

## Remaining feature families

| Family | Result / dependency |
| --- | --- |
| Trinket ESP and Mana Overlay | Implemented; final live mana alignment still needs user confirmation |
| Ore, Ingredient, NPC name ESP | Implemented this session; live spawned render check remains |
| Proximity alert | Implemented, off by default |
| Proximity Auto Menu | Conditional implementation; missing Danger tag API still blocks sending |
| Right-click Spectate | Blocked by unverified camera-subject/viewpoint controls |
| Mouse-free Auto Pickup | Blocked by activation API and unreadable activation range |
| Player metadata / Observe / moderator alerts | Partial replicated data possible; tags and static moderator lists are not authoritative safety checks |
| Native NPC chams / player ESP | Existing Matcha native systems can cover presentation; not integrated into this resource-label module |
| Ingredient/ore/weapon/bag collection | No live activation contract verified |
| Route visualization/import | Read-only port possible; not implemented here |
| Autofarm / movement / flight / no-fall / AA | Full Hydroxide behavior depends on hooks, states, collision changes and emergency actions unavailable or not validated here |
| Crafting / dialogue / spell automation | Each needs its own verified interaction/state contract and controlled gameplay testing |
| Serverhop / reset / anti-AFK | Not enabled or tested; server exit explicitly prohibited |
| Environment modifications / combat hooks / silent aim / anti-debuffs | Not ported; APIs and original behavior are not interchangeable |

This remains a partial port. No absence-of-ban guarantee is made. No automatic future progression or monitoring is left running.

