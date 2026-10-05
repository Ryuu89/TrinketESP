# Rogue Overlays for Matcha

Trinket ESP, Mana Overlay, World Resource ESP and optional Proximity monitoring for Rogue Lineage Gaia and Khei. The overlays are read-only; the optional Auto Menu can send one menu request only when explicitly enabled with Preview off and all guards satisfied. Made by Ryuu89; identification rules adapted from [Hydroxide](https://git.fable.bz/zyu/hydroxide), commit `6951b2a5c29e47ebde700f3897e50cc2d863e89c`.

## Run

Quick start: paste this into the Matcha script editor.

```lua
-- Rogue Lineage Trinket ESP Script by Ryuu89

loadstring(game:HttpGet("https://raw.githubusercontent.com/Ryuu89/TrinketESP/main/Rogue.lua"))()
```

1. Open **`Rogue.lua`** in the Matcha script editor and run the complete file once. It includes the overlays and Proximity module; no loader or second file is needed.
2. Open the **Rogue ESP** tab in the Matcha interface. Trinket, Mana, World Resources and Proximity controls share this tab. **Unload Script** stops all modules.
3. **Trinket ESP** is enabled initially. **F6** toggles it while Roblox is focused; change the binding next to the toggle if desired.
4. While in the character menu, **Waiting for character** is expected. The overlay starts scanning after a character becomes available. Entering the map is not required to load the script or configure its interface.

The overlays never press Play, collect items, move the cursor/camera, teleport or modify game properties. Hybrid Mode is not required for overlays. The only optional remote path is Proximity Auto Menu, described below; it starts disabled and blocked when Danger cannot be read. On the validated Roblox build, property recovery uses Matcha's `memory_read` and requires **Allow Unsafe LuaU**. No memory writes, downloaded loader or external account are used.

## Interface

- **Limit Display Range**: off by default. All replicated candidates are tracked regardless of distance. Enable this to apply **Display Range (studs)**, measured from the camera as in Hydroxide. These controls affect labels only; they do not extend replication or pickup range.
- **Distance Fade**: optional camera-distance fading, disabled by default. **Start Fading (studs)** defaults to 250; **Minimum Opacity At (studs)** defaults to 2000; **Minimum Opacity (%)** defaults to 25. Between these distances, opacity decreases linearly; beyond the end it stays at the minimum. This percentage multiplies the color picker's alpha, rather than replacing it. RGB and identification are unchanged. Zero percent hides the whole distant label, including its outline. The end distance is automatically corrected to exceed the start if necessary. Fading is independent of Display Range and applies to all categories.
- **Default category palette** (alpha 0–255): Common `#BD611D / 112`, Rare `#3C9696 / 144`, Event `#00FF00 / 255`, Artifact `#60FF00 / 255`, Mythic `#FF0000 / 255`, Unclassified `#000000 / 133`. Existing Matcha color-picker values may persist; these are the defaults for fresh controls.
- **Categories**: Common, Rare, Event, Artifact, Mythic and Unclassified. Each category has a color picker next to its toggle when the global color override is off.
- **Override All Category Colors**: apply one color to every label using the adjacent picker. Disable it to restore per-category colors; their pickers are hidden while the override is active. Color and opacity changes also update labels already on screen. For Text drawings, picker alpha is passed directly: 1 is opaque and 0 is invisible (confirmed by an in-game A/B test).
- **Ignore Display Range**: independently bypass the visual range limit for each recognized category when **Limit Display Range** is enabled, as in Hydroxide. Artifact and Mythic bypasses are enabled by default.
- **Show Region / Show Distance / Text Size / Text Outline**: label formatting. Region is the nearest AreaMarker, as in the original.
- **Rescan Trinkets**: refresh classification and area data.
- **Print Diagnostics**: a short console report of classification results, unavailable signatures, active color mode, configured RGBA, picker output and the RGB values sent to Drawing. Color readback is unsupported. It performs no interaction with the items.
- **Unload Script**: disconnect the renderer, stop both overlay workers and remove all Drawing objects and the shared tab.

Re-running the file unloads its previous instance. It does not stop or modify AutoBard. The UI uses `rte_` IDs, independent from AutoBard's controls. On a server change the overlay hides stale targets; run it again in the new server. Runtime settings are managed through Matcha UI; this version does not add a separate settings file.

## Identification coverage

The collector uses Hydroxide's direct Workspace children named `Part` with an `ID` child. Classification includes mesh mappings for rings, amulets, goblets, scrolls, candy and Howler Friend; Union AssetIds for idols and event items; paired amulet meshes; sphere-mesh Opal; gem color/particle rules; attachment-particle artifacts; Ice Essence; and Khei-specific items.

Each rule is conditional on its inputs being readable. Native Matcha reads returned `failed to fetch text` for MeshId and no AssetId. A bounded, read-only fallback now recovers MeshPart.MeshId, UnionOperation.AssetId, SpecialMesh.MeshId/MeshType, part colors, particle emission rates and particle color sequences on the validated builds **`version-e7d81637d42c4b23`** and **`version-02c37bc51a384b8f`** (the latter shifts every field by -0x10). It uses fixed validated fields, not runtime memory scans. Invalid pointers, lengths and sequence metadata are rejected.

Other builds retain native identification but never reuse these offsets. Missing or unmatched data remains **Unclassified**. BrickColor.Name still depends on native bindings (including the Night Stone rule); this is not a claim of complete artifact coverage. The original's unconditional Opal fallback is not used. See [memory layout validation](references/memory-layout-validation.md).

The overlay can only use objects already present in the client's data model. Discovery is not restricted to your character's proximity: if another player's approach causes an item to replicate to your client, the next scan can pick it up. Another player seeing an item does not guarantee that your client received it. Hydroxide likewise checks local Workspace children and newly added objects; neither collector creates data the server has not sent. A label is not evidence of server-side availability, interaction range or protection against detection. There is no working pickup or bot module in this version.

## Performance and validation

Discovery is scheduled 750 ms after each scan completes, with yields after every 32 Workspace children and every 8 classifications. All eligible candidates are collected, including those beyond the display range. Classification rules are unchanged: results are cached for 2 seconds for unknown items or 5 seconds for recognized items, plus a per-address spread of less than 1 second to reduce synchronized reclassification. Region data refreshes every 10 seconds.

A separate worker refreshes up to 8 cached item positions per pass, with a 20 ms wait between passes and a minimum age of 100 ms per item. Parent validity is checked at most every 250 ms per item. These are scheduling targets, not guaranteed frequencies: large candidate lists and Matcha's scheduler can increase refresh latency. Collected or moved items therefore have a bounded-cache delay rather than being read every frame; positions older than 2 seconds are hidden until refreshed.

The render callback reads no Instance properties. It projects cached world positions with the current camera on every callback. Labels remain assigned to the same item while selected, and Drawing properties are written only when needed. Distance fade uses already-cached camera distances, quantized to one-percent factor steps; unchanged opacity is not rewritten. Text and UI polling run at 5 Hz; position projection is not throttled to that rate. Sorting occurs only when more than 128 eligible items are on screen, prioritizing rarer categories, then nearer items. The fixed pool limits simultaneous labels, not discovery or classification. Disabling categories still hides their labels.

Regression tests verify camera movement with the cache worker paused, zero Instance reads during rendering, stable label ownership, redundant-write suppression, distant spawns, range toggling and removal. These checks establish behavior, not a live FPS guarantee. Matcha callback frequency and the game itself can still affect smoothness.

Local Luau tests cover known signatures, unreadable properties, category/range controls, custom and per-category colors, opacity, label settings, focus and hotkeys, menu/spawn transitions, server changes, removal, pool limits, rerun and unloading. These are simulated compatibility tests, not proof that every asset is readable in the live game. Read-only live classification tests recovered 25 of 25 candidates in the initial sample (including Ruby and Opal), then 40 of 40 in the artifact-reader follow-up. The updated classifier also recognized four independently named Phoenix Down inventory handles. Azael Horn, Phoenix Flower and Mysterious Artifact raw-rate paths passed simulated tests; those variants were not present as named references in the live sample. Named inventory references independently checked mesh IDs, Opal geometry and gem/particle colors. This is sample-specific validation, not a guarantee for all spawns or future builds.

To run the local tests with the official Luau CLI installed under `.tools/luau-0.737`:

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\Run-Tests.ps1
```

The test runner embeds the current production source into a mock Matcha/Roblox environment. It does not connect to Roblox or the MCP.

## Mana overlay

The **Mana Overlay** section is included in `Rogue.lua` under the shared **Rogue ESP** tab. Do not run a second script. Older standalone instances are stopped during startup. Enable **Mana Overlay**, equip a supported spell, and keep Roblox focused. Normal cast ranges are red, snap ranges are blue. **Overlay Opacity (%)** adjusts both; **Vertical Alignment (px)** shifts the overlay if the game's GUI inset differs. The script uses the bar's actual AbsolutePosition and AbsoluteSize (when Matcha reports AbsoluteSize as zero, the size is recovered from memory right after the validated AbsolutePosition; requires **Allow Unsafe LuaU**), then adds the GUI top inset as Hydroxide does. Native GetGuiInset is used when available, and a readable IgnoreGuiInset=true prevents a double offset. The current Matcha binding exposes neither in this session: **Fallback GUI Inset (px)** defaults to 0 px (no unverified margin) and remains adjustable; **Vertical Alignment (px)** is an additional offset. Coordinates and rectangle dimensions are now multiplied by **GUI Scale (%)**; the extra Vertical Alignment is applied afterward in final pixels. At startup, a valid existing `AutoBard.display.cfg` DPI is converted using DPI / 96; no AutoBard settings are modified. Without that calibration, the default is 100% and can be set manually. The user\'s current saved 130 DPI corresponds to 135.4167%. Arithmetic and lifecycle are tested; final visual alignment still requires confirmation.

All 40 spell ranges are transcribed from the Hydroxide snapshot. The same corrections for ScholarsBoon, WiseCasting (+2), and RemTraining (+3) expand the ranges. Unknown spells or unreadable bonus values hide the overlay rather than guessing. The overlay does not charge mana, cast spells, move the cursor, change the camera, call remotes or write game memory. It hides on loss of focus, unequip, death, missing geometry and explicit GUI hiding when those flags are readable. Matcha does not expose every visibility flag; this cannot guarantee detection of all other menus drawn over the bar.

Two Drawing squares are reused, with changed-property-only updates. One worker runs at a target interval of 50 ms; equipment/bonus discovery runs every 200 ms. Use **Unload Script** to stop both modules. Re-running `Rogue.lua` replaces the previous unified instance and any legacy standalone instances.

Local tests cover all 40 spells, bonuses, missing data, live settings, lifecycle, geometry and no game writes. Live initialization succeeded with no reported errors. A follow-up read found the character and the real mana bar at (22, 434.89), size (28, 298.45) pixels. No spell was equipped, so the overlay correctly waited; actual equipped-spell alignment and screenshots remain unverified. Testing did not equip a tool or enter the map.

## Development

`TrinketESP.lua`, `ManaOverlay.lua`, `Proximity.lua` and `WorldESP.lua` are source modules with isolated regression tests. After edits, run `Build-Rogue.ps1` to rebuild `Rogue.lua`, then `tests/Run-Tests.ps1` to test the modules and combined lifecycle. Users only need `Rogue.lua`.

## Spectate and pickup investigation

In the 2026-09-08 Hybrid session, CameraSubject remains unavailable for writing. A one-shot camera test found that assignments to Camera.CFrame and Camera.Position return successfully but do not move the camera. Camera.lookAt(origin, target), called with a dot rather than a colon, does change orientation; it does not move the viewpoint. Turning toward a player from the current location is not spectator mode, so no misleading Spectate control was added.

ClickDetector.MouseClick and MaxActivationDistance returned nil. FireServer and InvokeServer are exposed as generic method bindings, which is not evidence that a ClickDetector can be activated through either. No invocation on a detector, remote replay or collection test was attempted. These two ports remain blocked, not completed. See HYBRID-PORT.md for the measured capabilities.

## License

AGPL-3.0-or-later; see [LICENSE](LICENSE). This is a modified implementation dated 2026-09-05, not the original Hydroxide release. The complete editable source accompanies the script. No warranty is provided.


### Mana alignment and skill confirmation

`RemTraining Owned (manual confirmation)` can be enabled when the character owns the skill but Matcha cannot read its Backpack marker. It adds the Hydroxide +3 bonus once, never twice if the marker is also detected. With WiseCasting, Ignis becomes Normal 75–100% and Snap 48–62% (before any ScholarsBoon bonus). The default remains automatic detection for other characters. The manual confirmation is session-only; check it after reloading the script. Range origin and height use the current mana Frame bounds every update, including window resizing. The unknown-inset fallback no longer adds 36 GUI pixels (48.75 drawing pixels at 130 DPI). This addresses the suspected displacement seen in the supplied crop; the updated overlay still needs visual confirmation, and the screenshot does not validate spell success.


## Proximity and Hybrid Auto Menu

The **Proximity** section adapts Hydroxide's nearest-player notifier and its guarded ReturnToMenu call. This is a partial port, not full Hydroxide parity. It is disabled on startup and does not change the existing Trinket ESP or Mana controls.

- **Proximity Monitor:** enable detection of living replicated players within **Detection Radius (studs)**. All players are considered; there are no implicit friend/team exemptions. Identification uses UserId, not unstable wrapper equality.
- **Show Nearby Player Alert:** a single reusable Drawing label near the top of the viewport; it follows viewport resizing. Monitoring polls at 5 Hz, does not traverse descendants, and does not move the camera or mouse.
- **Auto Menu (requires Hybrid):** opt-in. **Preview Only - Never Send** defaults on. Keep Preview on to observe the decision without invoking anything.
- **Proximity Confirmation (ms):** the same nearby player and both character identities must remain valid for this period. Leaving range, death, focus loss, configuration changes and session changes invalidate the pending decision.
- **Danger Readout / Safety Check Source:** either Danger or MortalDanger blocks. Native HasTag must return false for both tags. Without readable tags, the module validates the actual DangerClient bytecode and observes the game HUD. It requires a live Danger-to-Safe transition followed by two seconds of Safe; the template text alone never authorizes a request. Unknown text, changed source/GUI/character, and interrupted sampling invalidate the fallback. There is deliberately no Ignore Danger option.
- **Request behavior:** once Preview is off and conditions pass, a fresh pre-dispatch check resolves ReplicatedStorage.Requests.ReturnToMenu as a RemoteFunction and calls InvokeServer without arguments, as Hydroxide does. Only one attempt is allowed until **Re-arm Auto Menu** is clicked. A pending call cannot be re-armed. Failures are not retried. A returned request is not treated as proof of a completed menu transition.

**Current live limitation:** this VM still lacks HasTag. The verified-HUD fallback is now available, but starting while the HUD already says Safe remains Unknown until a naturally occurring Danger-to-Safe transition is observed. Do not deliberately enter combat to initialize it. Keep Preview enabled until the Safety Check Source and decision are confirmed. Enabling Auto Menu does not bypass Unknown, and the UI reports this block even when nobody is nearby. The remote path and cancellation logic are tested with mocks only; no live menu request was sent. Network state can change between a read and a request, so these checks are not a guarantee against combat logging, death or enforcement. Unloading prevents future requests but cannot retract a remote already sent.

For development, Proximity.lua is the standalone source module. The unified Build-Rogue.ps1 bundles it; community users should run only Rogue.lua. The script remains restricted to the original Gaia/Khei place IDs, not arbitrary private copies.


## World Resources

The shared tab now includes **World Resources** and **Resource Display**. Ore ESP, Ingredient ESP and NPC ESP all start **disabled**. They require a living local character before discovery/rendering; loading the script never leaves the character menu.

- **Ore ESP:** reads direct children of Workspace.Ores and preserves Hydroxide's Mythril/Copper/Iron/Tin filters. Depleted/fully transparent nodes are hidden. Each ore type has its own toggle.
- **Ingredient ESP (Gaia):** discovers the container by Hydroxide's UnionOperation + ClickDetector + Blacklist structure. Uses the same 26 AssetId signatures. Unknown/unreadable signatures are hidden and counted, not guessed. Khei is excluded as in the original. The existing validated Trinket ESP reader supplies missing Union AssetId properties without duplicating raw offsets. Standalone WorldESP uses native AssetId only if that reader is unavailable.
- **NPC ESP:** recognizes a Model with Humanoid, Torso and Pants, plus Hydroxide's The Eagle exception using HumanoidRootPart. Dead NPCs are hidden. These are name labels, not native chams or a replacement for all player/NPC metadata.
- Separate ranges default to 500 studs (ores), 250 (ingredients), and 1000 (NPCs). Resource label opacity defaults to 85%; distance fading reduces it linearly to 25% of that opacity at the selected range. Text size and outline are independent of Trinket ESP.
- One fixed 96-label pool is shared by these three resource overlays; nearest visible resources win when full. This does not reduce the separate 128-label trinket pool. Resource discovery has a 2,048-target storage cap.
- Discovery yields every 16 examined objects, and waits one second after completion. Ingredient-folder search rotates between folders in 32-item batches instead of restarting at a large first folder. Positions/availability refresh in batches of at most 16 every 20 ms. GUI/control reads run at 5 Hz. Rates depend on the scheduler, not guarantees. Unknown ingredient IDs retry on discovery; identified signatures revalidate after 10 seconds.
- The renderer reads no Instances: it only projects cached positions and updates changed Drawing properties. Position data older than two seconds and control state older than 750 ms are hidden. Menu, death, focus loss, session changes and unloading suppress rendering.

Live menu checks identified an ingredient container with 839 children: 610 met the structural filter, 605 had readable IDs, 604 matched the Hydroxide table, one ID (2889328423) was not in that table and five were unreadable. Counts describe that snapshot, not collectible/visible objects. No item was collected. The source's complete 26-signature table and rendering/lifecycle behavior are tested in mocks; live render alignment still needs a spawned-character test.

Latest local validation: 2,131 Trinket ESP + 192 Mana + 107 Proximity + 913 World ESP + 472 integration assertions (3,815 total), plus bundle compilation. No gameplay actions occur in the test runner.





