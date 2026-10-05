# Hydroxide to Matcha Pro: verified port status

Audit date: 2026-09-08. Source: Hydroxide commit `6951b2a5c29e47ebde700f3897e50cc2d863e89c`, saved in `references/hydroxide-6951b2a.lua.txt`.

This supplements the historical `ASSESSMENT.md`; its earlier identification blockers have since been resolved by the validated read-only memory reader. It is not a claim of feature parity or immunity from enforcement.

## Matcha Pro session evidence

- MCP `matcha_status` reported `hybrid_mode: true`, in Rogue Gaia (`5208655184`). The instance index was refreshed before inspection.
- The current global environment still does not expose `fireclickdetector`, `firesignal`, `firetouchinterest`, `Instance`, `hookfunction` or `hookmetamethod`.
- `CollectionService.HasTag`, `CollectionService.GetTags` and `GuiService.GetGuiInset` returned nil. In this VM, nil can mean an unsupported property; it does not prove the corresponding game state is absent.
- `ReturnToMenu` is a RemoteFunction with an `InvokeServer` method binding. The remote was not invoked. A bound method is not an end-to-end transport test; Hybrid activation was confirmed separately by MCP.
- Eight sampled trinket candidates had ClickDetectors; zero of those detectors exposed a readable positive `MaxActivationDistance`. This is a bounded sample, not a map-wide availability guarantee.
- `CameraSubject` is readable. The current MCP reference still excludes it from writable properties. No camera setter was attempted in this Pro audit.
- No RemoteSpy scripting API appeared in the global inventory or current MCP reference. This does not establish whether the Pro application has a working RemoteSpy UI.
- The unified overlay was not running in this VM at inspection time. It was not automatically loaded, so this audit did not reset the user's overlay settings.

## Existing and requested features

| Feature | Current result | Remaining dependency |
| --- | --- | --- |
| Trinket ESP | Existing implementation retained; classification, category colors and distance fading remain intact | Visual/runtime regression check after the user's Pro restart; only replicated objects are observable |
| Mana Overlay | Existing implementation retained, including dynamic bar geometry and manual RemTraining confirmation | Final visual alignment confirmation; native inset and marker availability remain limited |
| Mouse-free Auto Pickup | Not implemented | Hydroxide requires a real ClickDetector activation API and readable activation range |
| Right-click leaderboard Spectate | Not implemented | CameraSubject setter unavailable; lookAt rotates only, and Camera.Position/CFrame writes had no observed movement |
| Proximity Auto Menu | Conditional flow with verified game-HUD fallback | Requires observed Danger-to-Safe transition when tags unavailable; no live menu request tested |
| Ore, Ingredient and NPC ESP | Implemented in WorldESP.lua; starts disabled | Live spawned render validation remains; unknown ingredient signatures hidden |
| Autofarm, flight and route recovery | Not ported | Original depends on movement, collision/state changes, object creation, hooks and emergency actions that are not equivalent in this VM |

### Why a remote is not a substitute for every missing API

Hydroxide's Auto Trinket routine (lines 25312 onward) finds the detector, reads its activation distance, excludes Azael Horn and calls `fireclickdetector`. It does not provide a generic pickup `FireServer` call that can simply replace this operation. Remote names and arguments must not be guessed or replayed without confirming their purpose.

The leaderboard handler (lines 23839 onward) creates a GUI button and changes the camera subject on right-click. It does not use a server remote for Spectate. Hybrid remote transport alone therefore does not resolve that missing local capability.

The original bot also uses CollectionService tags, Humanoid state changes, temporary Parts, hooks, and emergency actions including leaving/resetting. The presence of network methods does not establish that the other mechanisms or checks have become available. Missing Danger/tag information must not be interpreted as a safe state.

## Reproducing the capability audit

Run `HybridAudit.lua` once in the Matcha editor. It prints a bounded read-only report and exits; no cleanup is needed. It does not invoke remotes or probe writable properties. Confirm Hybrid activation separately through MCP `matcha_status`.

The existing automated suites passed: 2,131 TrinketESP assertions, 192 ManaOverlay assertions and 273 unified integration assertions. These are mock-runtime tests, not live gameplay or anti-cheat tests.

## What is needed next

Obtain Pro-specific scripting documentation or an official working Hybrid example. In particular: ClickDetector activation, a supported camera-subject setter/native spectate API, tag reads, and RemoteSpy access/export. If the user's own Rogue-derived Studio project is available, its client/server interaction handlers can establish the actual contracts rather than assuming compatibility with a third-party source snapshot.

Public documentation checked: [Matcha LuaVM](https://doc.wabisabi.mom/matcha/llms-full.txt) and [Matcha UI Binding](https://github.com/cconstellation/MatchaScripts). The currently retrieved public LuaVM text did not document Hybrid or FireServer; the local MCP reference documented the Hybrid requirement instead.

No full Hydroxide script was executed. No remote, pickup, cast, camera motion, character motion, teleport, reset, disconnection or server change was performed. Existing overlay source and bundle were left unchanged during this audit.


## Implemented partial port after the initial audit

`Proximity.lua` is now bundled into `Rogue.lua`. It adapts Hydroxide's nearby-player notifier and guarded ReturnToMenu call. The monitor is disabled and Preview is enabled on startup. Alerts are independent of tag availability. The Auto Menu flow has a dwell period, fresh pre-dispatch checks, single-attempt latch, no automatic retries, and explicit Unknown/Danger blocking. The current VM still reports Danger as Unknown, so live automatic menu calls remain blocked. This replaces the earlier 'not implemented' status for the proximity/menu row with 'implemented conditional flow; current live guard unavailable'.

Validation: 2,131 TrinketESP assertions, 192 ManaOverlay assertions, 66 Proximity assertions, and 277 integration assertions passed. The bundle compiled. A temporary disabled standalone instance was loaded through MCP, observed a living local character and Danger Unknown, then unloaded. No menu remote was requested. Alert geometry is covered by mock viewport-resize tests; a live visible alert was not exercised because no player was inside the default radius during the read-only probe. Other outstanding ports (pickup, Spectate and bot motion) are unchanged.



## Independent exploration follow-up

See [the measured session report](references/hybrid-exploration-2026-09-08.md). WorldESP.lua now adds three source-based resource overlays and shares the validated ingredient AssetId reader. The unified bundle passed 3,774 mock assertions and initialized in the user's menu. Camera probes demonstrated that lookAt changes orientation but not viewpoint position; no working Spectate or pickup API was discovered. No Play, remote call, pickup, character movement, reset or server exit occurred. This is not full Hydroxide parity.



## 2026-09-09 correction: Danger HUD fallback

The live DangerClient was read through MCP. It checks both Danger and MortalDanger children/tags and writes the exact states to DangerGui.TextLabel. Its bytecode hash was returned as the string `15563268767215079424`. The StarterGui template already says Safe, so simply accepting that text on startup would be unsound.

Proximity.lua now checks both markers/tags. When native tags are unavailable it validates the current PlayerGui hierarchy, character and script identity, and pinned hash. The fallback requires an observed Danger-to-Safe transition, two uninterrupted seconds of Safe, and the existing proximity hold plus fresh pre-dispatch checks. Unknown revisions/text, replacement GUI/character and sampling gaps block requests. Safety Check Source explains readiness in the interface, including when no player is nearby.

The standalone module was loaded disabled through MCP, read **Danger / Character marker**, confirmed defaults enabled=false, autoMenu=false, preview=true, attempted=false, error=nil, then unloaded. This validates the live block, not a successful menu transition. The full fallback transition was tested in mocks, not by inducing combat or editing the live HUD.

No Play, remote invocation, item activation, camera or character write, or server exit was performed in this follow-up. The character was already spawned when inspected and was intermittently in Danger. A bounded read-only camera inspection found three matching transform copies; matching bytes alone were not accepted as evidence for a writable camera field. Spectate and mouse-free pickup remain unimplemented.

Validation after this correction: 2,131 TrinketESP + 192 ManaOverlay + 107 Proximity + 913 WorldESP + 472 unified assertions = 3,815, plus bundle compilation. This is still a partial Hydroxide port, with no immunity or combat-logging guarantee.

