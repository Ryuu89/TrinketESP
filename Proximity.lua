-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Made by Ryuu89. Proximity and menu rules adapted from Hydroxide, commit 6951b2a.

local placeId, jobId = game.PlaceId, game.JobId
if game.GameId ~= 1087859240 or (placeId ~= 5208655184 and placeId ~= 3541987450) then
	warn("[Rogue Proximity] Rogue Lineage Gaia and Khei only.")
	return
end
local previous = _G.RogueProximity
if type(previous) == "table" and type(previous.Stop) == "function" then
	previous.Stop()
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local config = { enabled = false, distance = 100, showAlert = true, autoMenu = false, preview = true, holdMs = 1000 }
local state = { running = true, status = "Disabled", danger = "Unknown", nearest = "None", uiReady = false, epoch = 0 }
local hasUI = UI
	and type(UI.AddTab) == "function"
	and type(UI.GetValue) == "function"
	and type(UI.SetValue) == "function"

local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
local function read(object, key)
	if not object then
		return nil
	end
	local ok, value = pcall(function()
		return object[key]
	end)
	if ok then
		return value
	end
	return nil
end
local function child(object, name)
	return object and object:FindFirstChild(name) or nil
end
local function service(name)
	local ok, value = pcall(function()
		return game:GetService(name)
	end)
	if ok then
		return value
	end
	return nil
end
local function sessionValid()
	return game.GameId == 1087859240 and game.PlaceId == placeId and game.JobId == jobId
end
local function point(value)
	return value
		and finite(value.X)
		and finite(value.Y)
		and finite(value.Z)
		and math.abs(value.X) < 1000000
		and math.abs(value.Y) < 1000000
		and math.abs(value.Z) < 1000000
end
local function livingRoot(owner)
	local character = read(owner, "Character")
	local root, humanoid = child(character, "HumanoidRootPart"), child(character, "Humanoid")
	local health, position = read(humanoid, "Health"), read(root, "Position")
	local address = read(character, "Address")
	if not finite(health) or health <= 0 or not point(position) or not finite(address) or address <= 0 then
		return nil
	end
	if read(read(root, "Parent"), "Address") ~= address then
		return nil
	end
	return character, position, address
end
local hud = {}
local function hudDanger(character)
	local gui = child(player, "PlayerGui")
	local panel = child(gui, "DangerGui")
	local label, client = child(panel, "TextLabel"), child(panel, "DangerClient")
	local characterAddress, panelAddress = read(character, "Address"), read(panel, "Address")
	local labelAddress, clientAddress = read(label, "Address"), read(client, "Address")
	if
		read(gui, "ClassName") ~= "PlayerGui"
		or read(panel, "ClassName") ~= "ScreenGui"
		or read(label, "ClassName") ~= "TextLabel"
		or read(client, "ClassName") ~= "LocalScript"
		or not finite(characterAddress)
		or not finite(panelAddress)
		or not finite(labelAddress)
		or not finite(clientAddress)
		or read(read(gui, "Parent"), "Address") ~= read(player, "Address")
		or read(read(panel, "Parent"), "Address") ~= read(gui, "Address")
		or read(read(label, "Parent"), "Address") ~= panelAddress
		or read(read(client, "Parent"), "Address") ~= panelAddress
	then
		hud = {}
		return "Unknown", "Danger HUD unavailable"
	end
	local now = tick()
	local key = characterAddress .. ":" .. panelAddress .. ":" .. labelAddress .. ":" .. clientAddress
	if hud.key ~= key then
		hud = { key = key }
		if type(getscripthash) == "function" then
			local ok, hash = pcall(getscripthash, client)
			-- Pinned to the inspected DangerClient; unknown revisions must not authorize menu.
			hud.verified = ok and type(hash) == "string" and hash == "15563268767215079424"
		end
	end
	if not hud.verified then
		return "Unknown", "DangerClient revision not verified"
	end
	if not hud.lastRead or now - hud.lastRead > 0.75 then
		hud.sawDanger, hud.clearAt = false, nil
	end
	hud.lastRead = now
	local text = read(label, "Text")
	if text == "IN DANGER\nYour life is at risk!" or text == "MORTAL DANGER\nDeath is at your heels!" then
		hud.sawDanger, hud.clearAt = true, nil
		return "Danger", "Verified game HUD"
	end
	if text ~= "Safe" then
		hud.sawDanger, hud.clearAt = false, nil
		return "Unknown", "Danger HUD text unrecognized"
	end
	-- The template also says Safe. Require a live Danger -> Safe transition.
	if not hud.sawDanger then
		return "Unknown", "Waiting for a live Danger-to-Safe transition"
	end
	hud.clearAt = hud.clearAt or now
	if now - hud.clearAt < 2 then
		return "Unknown", "Confirming Safe HUD (2 seconds)"
	end
	return "Clear", "Verified game HUD"
end
local function dangerState(character)
	local marker = child(character, "MortalDanger") or child(character, "Danger")
	local collection = service("CollectionService")
	local method = read(collection, "HasTag")
	if type(method) == "function" then
		local okDanger, danger = pcall(method, collection, character, "Danger")
		local okMortal, mortal = pcall(method, collection, character, "MortalDanger")
		if marker or (okDanger and danger == true) or (okMortal and mortal == true) then
			hud = {}
			return "Danger", "Character markers / tags"
		end
		if okDanger and okMortal and danger == false and mortal == false then
			hud = {}
			return "Clear", "Character tags"
		end
	end
	local value, source = hudDanger(character)
	if marker then
		hud.clearAt = nil
		return "Danger", "Character marker"
	end
	return value, source
end
local function snapshot()
	local result = { danger = "Unknown", complete = true }
	if not sessionValid() then
		result.reason = "Session changed"
		return result
	end
	local character, origin, address = livingRoot(player)
	if not character then
		hud = {}
		result.reason = "Waiting for a living character"
		return result
	end
	result.characterAddress = address
	result.danger, result.dangerSource = dangerState(character)
	local localId = read(player, "UserId")
	if not finite(localId) or localId <= 0 then
		result.reason = "Local player identity unavailable"
		return result
	end
	local nearest, seen = nil, {}
	for index, other in ipairs(Players:GetPlayers()) do
		if index > 200 then
			result.complete = false
			break
		end
		local id = read(other, "UserId")
		if finite(id) and id > 0 and id ~= localId and not seen[id] then
			seen[id] = true
			local _, target, targetAddress = livingRoot(other)
			if target then
				local dx, dy, dz = target.X - origin.X, target.Y - origin.Y, target.Z - origin.Z
				local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
				if
					distance <= config.distance
					and (
						not nearest
						or distance < nearest.distance
						or (distance == nearest.distance and id < nearest.id)
					)
				then
					nearest = {
						id = id,
						name = tostring(read(other, "Name") or id),
						distance = distance,
						characterAddress = targetAddress,
					}
				end
			end
		end
	end
	result.target = nearest
	return result
end
local function clearHold()
	state.holdAt, state.holdKey = nil, nil
end
local function hide()
	if state.label then
		state.label.Visible = false
	end
end
local function setUI(id, value)
	if hasUI and state.uiReady then
		local ok, current = pcall(UI.GetValue, id)
		if ok and current ~= value then
			pcall(UI.SetValue, id, value)
		end
	end
end
local function syncUI()
	if not hasUI or not state.uiReady then
		return
	end
	local changed = false
	for key, current in pairs(config) do
		local ok, value = pcall(UI.GetValue, "rpx_" .. key)
		if ok and type(value) == type(current) then
			if type(value) == "number" then
				if not finite(value) then
					continue
				end
				value =
					math.floor(math.clamp(value, key == "distance" and 10 or 250, key == "distance" and 2000 or 5000))
			end
			if current ~= value then
				config[key] = value
				changed = true
			end
		end
	end
	if changed then
		state.epoch = state.epoch + 1
		clearHold()
	end
	setUI("rpx_status", state.status)
	setUI("rpx_danger", state.danger)
	setUI("rpx_dangerSource", state.dangerSource or "Not sampled")
	setUI("rpx_nearest", state.nearest)
end

local controller = {}
function controller.Stop()
	if not state.running then
		return
	end
	state.running = false
	state.epoch = state.epoch + 1
	clearHold()
	if state.label then
		state.label:Remove()
		state.label = nil
	end
	if hasUI and type(UI.RemoveTab) == "function" then
		pcall(UI.RemoveTab, "Rogue Proximity")
	end
	if _G.RogueProximity == controller then
		_G.RogueProximity = nil
	end
end
function controller.GetStatus()
	return {
		running = state.running,
		enabled = config.enabled,
		status = state.status,
		danger = state.danger,
		dangerSource = state.dangerSource,
		nearest = state.nearest,
		autoMenu = config.autoMenu,
		preview = config.preview,
		attempted = state.attempted == true,
		inFlight = state.inFlight == true,
		error = state.error,
	}
end
function controller.Preview()
	-- Read-only observation: never arms, schedules or invokes a remote.
	return snapshot()
end
local function showTarget(target)
	if not target or not config.showAlert then
		hide()
		return
	end
	local viewport = read(read(Workspace, "CurrentCamera"), "ViewportSize")
	if not viewport or not finite(viewport.X) or not finite(viewport.Y) or viewport.X <= 0 or viewport.Y <= 0 then
		hide()
		return
	end
	local text = string.format("%s nearby [%d studs]", target.name, math.floor(target.distance))
	if state.text ~= text then
		state.label.Text, state.text = text, text
	end
	local x, y = viewport.X / 2, math.max(20, viewport.Y * 0.12)
	if x ~= state.x or y ~= state.y then
		state.label.Position = Vector2.new(x, y)
		state.x, state.y = x, y
	end
	state.label.Visible = true
end
local function blocked(observation)
	if observation.reason then
		return observation.reason
	end
	if not observation.complete then
		return "Blocked - player list incomplete"
	end
	if observation.danger == "Danger" then
		return "Blocked - Danger active"
	end
	if observation.danger ~= "Clear" then
		return "Blocked - Danger state unavailable"
	end
	return nil
end
local function requestMenu(observation)
	local epoch, target = state.epoch, observation.target
	state.inFlight, state.attempted = true, true
	state.status = "Request pending - no automatic retry"
	task.spawn(function()
		syncUI()
		if
			not state.running
			or epoch ~= state.epoch
			or not config.enabled
			or not config.autoMenu
			or config.preview
			or type(isrbxactive) ~= "function"
			or not isrbxactive()
		then
			state.inFlight = false
			state.result = "Cancelled before dispatch; re-arm manually"
			return
		end
		local ok, fresh = pcall(snapshot)
		if
			not ok
			or blocked(fresh)
			or not fresh.target
			or fresh.characterAddress ~= observation.characterAddress
			or fresh.target.id ~= target.id
			or fresh.target.characterAddress ~= target.characterAddress
		then
			state.inFlight = false
			state.status = "Cancelled - conditions changed; re-arm manually"
			state.result = state.status
			return
		end
		local remote = child(child(service("ReplicatedStorage"), "Requests"), "ReturnToMenu")
		local method = read(remote, "InvokeServer")
		if read(remote, "ClassName") ~= "RemoteFunction" or type(method) ~= "function" then
			state.inFlight = false
			state.status = "Blocked - ReturnToMenu unavailable; re-arm manually"
			state.result = state.status
			return
		end
		local success = pcall(method, remote)
		state.inFlight = false
		state.result = success and "Request returned - menu transition not confirmed"
			or "Request failed - check Hybrid Mode; no retry"
		if state.running and epoch == state.epoch then
			state.status = state.result
		end
	end)
end
local function update()
	syncUI()
	if not sessionValid() then
		controller.Stop()
		return
	end
	if not config.enabled then
		clearHold()
		hide()
		state.status = "Disabled"
		state.nearest, state.danger, state.dangerSource = "None", "Unknown", "Not sampled"
		hud = {}
		return
	end
	if type(isrbxactive) ~= "function" or not isrbxactive() then
		clearHold()
		hide()
		state.status = "Paused - Roblox not focused"
		return
	end
	local observation = snapshot()
	local target = observation.target
	state.danger, state.dangerSource = observation.danger, observation.dangerSource
	state.nearest = target and string.format("%s [%d studs]", target.name, math.floor(target.distance))
		or "None in range"
	showTarget(target)
	if state.inFlight then
		state.status = "Request pending - no automatic retry"
		return
	end
	if state.attempted then
		clearHold()
		state.status = state.result or "Auto Menu used - re-arm manually"
		return
	end
	if observation.reason then
		clearHold()
		state.status = observation.reason
		return
	end
	if not target then
		clearHold()
		state.status = config.autoMenu and blocked(observation) or "Watching replicated players"
		return
	end
	if not config.autoMenu then
		clearHold()
		state.status = "Nearby player - alert only"
		return
	end
	local reason = blocked(observation)
	if reason then
		clearHold()
		state.status = reason
		return
	end
	local key = tostring(observation.characterAddress) .. ":" .. target.id .. ":" .. target.characterAddress
	if state.holdKey ~= key then
		state.holdAt, state.holdKey = tick(), key
	end
	if tick() - state.holdAt < config.holdMs / 1000 then
		state.status = "Nearby player - confirming proximity"
		return
	end
	if config.preview then
		state.status = "Preview - would request menu; nothing sent"
		return
	end
	requestMenu(observation)
end
local function drawUI(tab)
	local section = tab:Section("Proximity", "Left")
	section:Toggle("rpx_enabled", "Proximity Monitor", config.enabled)
	section:Toggle("rpx_showAlert", "Show Nearby Player Alert", config.showAlert)
	section:SliderInt("rpx_distance", "Detection Radius (studs)", 10, 2000, config.distance)
	section:Toggle("rpx_autoMenu", "Auto Menu (requires Hybrid)", config.autoMenu)
	section:Toggle("rpx_preview", "Preview Only - Never Send", config.preview)
	section:SliderInt("rpx_holdMs", "Proximity Confirmation (ms)", 250, 5000, config.holdMs)
	section:Tip(
		"Auto Menu checks Danger and MortalDanger. Without tag support, a verified game HUD must show Danger then Safe for 2 seconds. Unknown always blocks."
	)
	section:Tip(
		"All replicated players are considered; no friend or team exemptions. Hidden or unreplicated players cannot be detected. Preview is on initially."
	)
	local status = tab:Section("Proximity Status", "Right")
	status:InputText("rpx_status", "State", state.status)
	status:InputText("rpx_nearest", "Nearest Player", state.nearest)
	status:InputText("rpx_danger", "Danger Readout", state.danger)
	status:InputText("rpx_dangerSource", "Safety Check Source", state.dangerSource or "Not sampled")
	status:Button("Re-arm Auto Menu", function()
		if state.inFlight then
			return
		end
		state.epoch = state.epoch + 1
		state.attempted = false
		state.result = nil
		state.status = "Re-armed - waiting for conditions"
		clearHold()
	end)
	status:Button("Unload Proximity", controller.Stop)
	if not state.uiReady then
		state.uiReady = true
		for key, value in pairs(config) do
			pcall(UI.SetValue, "rpx_" .. key, value)
		end
	end
end

_G.RogueProximity = controller
local ok, err = pcall(function()
	state.label = Drawing.new("Text")
	state.label.Text, state.label.Size, state.label.Font = "", 20, 2
	state.label.Center, state.label.Outline, state.label.Visible = true, true, false
	state.label.Color, state.label.Transparency = Color3.fromRGB(255, 190, 80), 1
	state.label.ZIndex = 150
	if hasUI then
		UI.AddTab("Rogue Proximity", drawUI)
	end
	task.spawn(function()
		while state.running do
			local success, message = pcall(update)
			if not success then
				state.error = tostring(message)
				warn("[Rogue Proximity] Stopped: " .. state.error)
				controller.Stop()
				return
			end
			task.wait(0.2)
		end
	end)
end)
if not ok then
	controller.Stop()
	warn("[Rogue Proximity] Startup failed: " .. tostring(err))
	return
end
print("[Rogue Proximity] Loaded disabled. Preview is on. Auto Menu needs Hybrid and verified Danger checks.")
