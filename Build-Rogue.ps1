$ErrorActionPreference = 'Stop'
$esp = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'TrinketESP.lua') -Raw
$proximity = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Proximity.lua') -Raw
$world = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'WorldESP.lua') -Raw
$mana = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ManaOverlay.lua') -Raw
$esp = $esp.Replace('pcall(UI.RemoveTab, "Rogue ESP")', '-- The host owns the shared tab.').Replace('UI.AddTab("Rogue ESP", drawUI)', 'host.trinketUI = drawUI').Replace('status:Button("Unload ESP", controller.Stop)', 'status:Button("Unload Script", host.Stop)').Replace('print("[Rogue ESP] Loaded. Open Rogue ESP in Matcha. F6 toggles the overlay. Read-only: no input or game writes.")', 'return controller')
$mana = $mana.Replace('pcall(UI.RemoveTab, "Rogue Mana")', '-- The host owns the shared tab.').Replace('UI.AddTab("Rogue Mana", drawUI)', 'host.manaUI = drawUI').Replace('status:Button("Unload Mana Overlay", controller.Stop)', 'status:Tip("Unload Script in the Trinket status section stops both overlays.")').Replace('tab:Section("Status", "Right")', 'tab:Section("Mana Status", "Right")').Replace('print("[Rogue Mana] Loaded. Open Rogue Mana in Matcha. Visual only: no input, camera or game writes.")', 'return controller')
$proximity = $proximity.Replace('pcall(UI.RemoveTab, "Rogue Proximity")', '-- The host owns the shared tab.').Replace('UI.AddTab("Rogue Proximity", drawUI)', 'host.proximityUI = drawUI').Replace('status:Button("Unload Proximity", controller.Stop)', 'status:Tip("Unload Script stops all modules.")').Replace('print("[Rogue Proximity] Loaded disabled. Preview is on. Auto Menu needs Hybrid and verified Danger checks.")', 'return controller')
$world = $world.Replace('pcall(UI.RemoveTab, "Rogue World")', '-- The host owns the shared tab.').Replace('UI.AddTab("Rogue World", drawUI)', 'host.worldUI = drawUI').Replace('style:Button("Unload World ESP", controller.Stop)', 'style:Tip("Unload Script stops all modules.")').Replace('print("[Rogue World] Loaded disabled. Ore, ingredient and NPC labels only; no gameplay actions.")', 'return controller')
if (!$world.Contains('host.worldUI = drawUI') -or !$world.Contains('return controller')) { throw 'World module entry point changed.' }
if (!$proximity.Contains('host.proximityUI = drawUI') -or !$proximity.Contains('return controller')) { throw 'Proximity module entry point changed.' }
if (!$esp.Contains('host.trinketUI = drawUI') -or !$mana.Contains('host.manaUI = drawUI')) { throw 'Module UI entry point changed; review bundle integration.' }
$header = @'
-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Made by Ryuu89. Rogue Lineage overlays for Matcha.
-- Identification and spell ranges adapted from Hydroxide, commit 6951b2a5c29e47ebde700f3897e50cc2d863e89c.

if game.GameId ~= 1087859240 or (game.PlaceId ~= 5208655184 and game.PlaceId ~= 3541987450) then
	warn("[Rogue] Rogue Lineage Gaia and Khei only.")
	return
end
local previous = _G.RogueOverlay
if type(previous) == "table" and type(previous.Stop) == "function" then previous.Stop() end
local host = { running = true }
function host.Stop()
	if not host.running then return end
	host.running = false
	if host.trinkets then host.trinkets.Stop() end
	if host.mana then host.mana.Stop() end
	if host.proximity then host.proximity.Stop() end
	if host.world then host.world.Stop() end
	if UI and type(UI.RemoveTab) == "function" then
		pcall(UI.RemoveTab, "Rogue ESP")
		pcall(UI.RemoveTab, "Rogue Mana")
	end
	if _G.RogueOverlay == host then _G.RogueOverlay = nil end
end
function host.GetStatus()
	return {
		running = host.running,
		trinkets = host.trinkets and host.trinkets.GetStatus(),
		mana = host.mana and host.mana.GetStatus(),
		proximity = host.proximity and host.proximity.GetStatus(),
		world = host.world and host.world.GetStatus(),
	}
end

'@
$footer = @'

_G.RogueOverlay = host
local ok, err = pcall(function()
	host.trinkets = startTrinkets(host)
	host.mana = startMana(host)
	host.proximity = startProximity(host)
	host.world = startWorld(host)
	if not host.trinkets or not host.mana or not host.proximity or not host.world then
		host.Stop()
		warn("[Rogue] An overlay could not start.")
		return
	end
	if UI and type(UI.AddTab) == "function" then
		UI.AddTab("Rogue ESP", function(tab)
			if not host.running then return end
			if host.trinketUI then host.trinketUI(tab) end
			if host.manaUI then host.manaUI(tab) end
			if host.proximityUI then host.proximityUI(tab) end
			if host.worldUI then host.worldUI(tab) end
		end)
	end
end)
if not ok then host.Stop(); warn("[Rogue] Startup failed: " .. tostring(err)); return end
if host.running then print("[Rogue] Trinket ESP, Mana Overlay, World Resources and Proximity loaded (automation disabled). Open Rogue ESP. F6 toggles trinkets only.") end

'@
$bundle = $header + "`nlocal function startTrinkets(host)`n" + $esp + "`nend`n`nlocal function startMana(host)`n" + $mana + "`nend`n`nlocal function startProximity(host)`n" + $proximity + "`nend`n`nlocal function startWorld(host)`n" + $world + "`nend`n" + $footer
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'Rogue.lua'), $bundle, [Text.UTF8Encoding]::new($false))




