-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Made by Ryuu89. Resource rules adapted from Hydroxide, commit 6951b2a.

local placeId, jobId = game.PlaceId, game.JobId
if game.GameId ~= 1087859240 or (placeId ~= 5208655184 and placeId ~= 3541987450) then
	warn("[Rogue World] Rogue Lineage Gaia and Khei only.")
	return
end
local previous = _G.RogueWorldESP
if type(previous) == "table" and type(previous.Stop) == "function" then
	previous.Stop()
end

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local config = {
	ores = false,
	ingredients = false,
	npcs = false,
	mythril = true,
	copper = true,
	iron = true,
	tin = true,
	oreRange = 500,
	ingredientRange = 250,
	npcRange = 1000,
	textSize = 13,
	opacity = 85,
	distanceFade = true,
	outline = true,
}
local limits = {
	oreRange = { 25, 5000 },
	ingredientRange = { 25, 5000 },
	npcRange = { 25, 5000 },
	textSize = { 10, 24 },
	opacity = { 10, 100 },
}
local ingredientNames = {
	["3293218896"] = "Desert Mist",
	["2773353559"] = "Blood Thorn",
	["2960178471"] = "Snowscroom",
	["2577691737"] = "Lava Flower",
	["2618765559"] = "Glow Scroom",
	["2575167210"] = "Moss Plant",
	["2620905234"] = "Scroom",
	["2766925289"] = "Trote",
	["2766925320"] = "Polar Plant",
	["2766802713"] = "Periashroom",
	["2766802766"] = "Strange Tentacle",
	["2766925228"] = "Tellbloom",
	["2766802731"] = "Dire Flower",
	["2573998175"] = "Freeleaf",
	["2766925214"] = "Crown Flower",
	["3215371492"] = "Potato",
	["2766925304"] = "Vile Seed",
	["3049345298"] = "Zombie Scroom",
	["2766802752"] = "Orcher Leaf",
	["2766925267"] = "Creely",
	["2889328388"] = "Ice Jar",
	["3049928758"] = "Canewood",
	["3049556532"] = "Acorn Light",
	["2766925245"] = "Uncanny Tentacle",
	["9858299042"] = "Evoflower",
	["3173538809"] = "Sky Orchid",
}
local oreColors = {
	Mythril = Color3.fromRGB(130, 205, 245),
	Copper = Color3.fromRGB(210, 140, 85),
	Iron = Color3.fromRGB(205, 210, 220),
	Tin = Color3.fromRGB(175, 185, 195),
}
local ingredientColor = Color3.fromRGB(145, 220, 130)
local npcColor = Color3.fromRGB(240, 210, 120)
local POOL_SIZE, TARGET_LIMIT = 96, 2048
local state = {
	running = true,
	ready = false,
	uiReady = false,
	targets = {},
	pool = {},
	slots = {},
	cache = {},
	status = "Disabled",
	ingredientStatus = "Disabled",
	controlAt = -math.huge,
	cursor = 1,
	ores = 0,
	ingredients = 0,
	npcs = 0,
	unknown = 0,
	visible = 0,
	epoch = 0,
}
local hasUI = UI
	and type(UI.AddTab) == "function"
	and type(UI.GetValue) == "function"
	and type(UI.SetValue) == "function"
local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
local function read(o, k)
	if not o then
		return nil
	end
	local ok, v = pcall(function()
		return o[k]
	end)
	return ok and v or nil
end
local function children(o)
	return o and o:GetChildren() or {}
end
local function child(o, n)
	return o and o:FindFirstChild(n) or nil
end
local function address(o)
	local n = read(o, "Address")
	return finite(n) and n >= 65536 and n < 140737488355328 and n % 8 == 0 and n or nil
end
local function point(v)
	return v
		and finite(v.X)
		and finite(v.Y)
		and finite(v.Z)
		and math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z)) < 1000000
end
local function validSession()
	return game.GameId == 1087859240 and game.PlaceId == placeId and game.JobId == jobId
end
local function enabled()
	return config.ores or config.ingredients or config.npcs
end
local function setUI(key, value)
	if hasUI and state.uiReady then
		local ok, old = pcall(UI.GetValue, "rwe_" .. key)
		if ok and old ~= value then
			pcall(UI.SetValue, "rwe_" .. key, value)
		end
	end
end
local function visible(slot, value)
	if slot.visible ~= value then
		slot.label.Visible, slot.visible = value, value
	end
end
local function hide()
	for _, slot in ipairs(state.pool) do
		visible(slot, false)
	end
	state.visible = 0
end
local controller = {}
function controller.Stop()
	if not state.running then
		return
	end
	state.running, state.ready = false, false
	state.epoch += 1
	if state.connection then
		state.connection:Disconnect()
	end
	for _, slot in ipairs(state.pool) do
		pcall(function()
			slot.label:Remove()
		end)
	end
	state.pool, state.slots, state.targets, state.cache = {}, {}, {}, {}
	if hasUI and type(UI.RemoveTab) == "function" then
		pcall(UI.RemoveTab, "Rogue World")
	end
	if _G.RogueWorldESP == controller then
		_G.RogueWorldESP = nil
	end
end
function controller.GetStatus()
	return {
		running = state.running,
		status = state.status,
		ores = state.ores,
		ingredients = state.ingredients,
		npcs = state.npcs,
		unknownIngredients = state.unknown,
		visible = state.visible,
		ingredientStatus = state.ingredientStatus,
		error = state.error,
		labelLimit = POOL_SIZE,
		truncated = state.truncated == true,
	}
end
_G.RogueWorldESP = controller

local function control()
	if not validSession() then
		controller.Stop()
		return
	end
	if hasUI and state.uiReady then
		for key, old in pairs(config) do
			local ok, v = pcall(UI.GetValue, "rwe_" .. key)
			if ok and type(v) == type(old) then
				if type(v) == "number" then
					if not finite(v) then
						continue
					end
					v = math.floor(math.clamp(v, limits[key][1], limits[key][2]))
				end
				if v ~= old then
					config[key] = v
					state.epoch += 1
				end
			end
		end
	end
	local char = read(player, "Character")
	local health = read(child(char, "Humanoid"), "Health")
	local root = child(char, "HumanoidRootPart")
	local ready = address(char) ~= nil
		and address(read(root, "Parent")) == address(char)
		and finite(health)
		and health > 0
	local charAddress = address(char)
	if state.characterAddress ~= charAddress then
		state.characterAddress = charAddress
		state.epoch += 1
		state.targets, state.cache = {}, {}
	end
	state.ready = ready and enabled()
	state.origin = read(read(Workspace, "CurrentCamera"), "Position")
	state.controlAt = tick()
	state.status = not enabled() and "Disabled"
		or not ready and "Waiting for a living character"
		or "Tracking replicated resources"
	if not state.ready then
		hide()
	end
	setUI("status", state.status)
	setUI("counts", string.format("Ores %d | Ingredients %d | NPCs %d", state.ores, state.ingredients, state.npcs))
	setUI("ingredientStatus", state.ingredientStatus)
end

local function ingredientId(object)
	local reader = _G.RogueTrinketESP
	if type(reader) == "table" and type(reader.GetUnionAssetId) == "function" then
		return reader.GetUnionAssetId(object)
	end
	local id = read(object, "AssetId")
	if type(id) == "string" and (id:match("^rbxassetid://") or id:match("^https?://") or id:match("^%d+$")) then
		return id:gsub("%%20", ""):match("%d+")
	end
end
local function ingredientShape(o)
	return read(o, "ClassName") == "UnionOperation"
		and child(o, "ClickDetector") ~= nil
		and child(o, "Blacklist") ~= nil
end
local folderSearch
local function findIngredients()
	if placeId == 3541987450 then
		state.ingredientStatus = "Gaia ingredients only"
		return
	end
	if state.ingredientFolder and address(read(state.ingredientFolder, "Parent")) == address(Workspace) then
		return
	end
	state.ingredientFolder = nil
	if not folderSearch then
		if tick() < (state.nextSearch or 0) then
			return
		end
		folderSearch = { folders = {}, index = 1 }
		for _, o in ipairs(children(Workspace)) do
			if read(o, "ClassName") == "Folder" then
				folderSearch.folders[#folderSearch.folders + 1] = { object = o, cursor = 1 }
			end
		end
	end
	state.ingredientStatus = "Locating ingredient container"
	local folders = folderSearch.folders
	if #folders == 0 then
		folderSearch = nil
		state.nextSearch = tick() + 15
		return
	end
	if folderSearch.index > #folders then
		folderSearch.index = 1
	end
	local entry = folders[folderSearch.index]
	entry.items = entry.items or children(entry.object)
	for _ = 1, 32 do
		local o = entry.items[entry.cursor]
		if not o then
			table.remove(folders, folderSearch.index)
			return
		end
		entry.cursor += 1
		if ingredientShape(o) then
			state.ingredientFolder = entry.object
			folderSearch = nil
			state.ingredientStatus = "Ingredient container found"
			return
		end
	end
	folderSearch.index += 1
end

local function collect()
	local epoch, now = state.epoch, tick()
	local out, cache, seen = {}, {}, {}
	local counts = { ores = 0, ingredients = 0, npcs = 0, unknown = 0 }
	local visits, truncated = 0, false
	local function keepGoing()
		visits += 1
		if visits % 16 == 0 then
			task.wait()
		end
		return state.running and state.ready and state.epoch == epoch and validSession()
	end
	local function add(object, part, kind, name, color, owner)
		local id = address(object)
		if not id or seen[id] then
			return
		end
		seen[id] = true
		if #out >= TARGET_LIMIT then
			truncated = true
			return
		end
		local previousTarget = state.cache[id]
		local target = {
			object = object,
			part = part,
			id = id,
			kind = kind,
			name = name,
			color = color,
			parent = address(owner),
			positionAt = -math.huge,
			signatureAt = now,
			alive = false,
		}
		if
			previousTarget
			and previousTarget.parent == target.parent
			and address(previousTarget.part) == address(part)
		then
			target.position, target.positionAt, target.alive =
				previousTarget.position, previousTarget.positionAt, previousTarget.alive
		end
		out[#out + 1], cache[id] = target, target
		counts[kind] += 1
	end
	if config.ores then
		local folder = child(Workspace, "Ores")
		for _, o in ipairs(children(folder)) do
			if not keepGoing() then
				return
			end
			local name, class = read(o, "Name"), read(o, "ClassName")
			if oreColors[name] and (class == "Part" or class == "MeshPart" or class == "UnionOperation") then
				add(o, o, "ores", name, oreColors[name], folder)
			end
		end
	end
	if config.ingredients and state.ingredientFolder then
		for _, o in ipairs(children(state.ingredientFolder)) do
			if not keepGoing() then
				return
			end
			if ingredientShape(o) then
				local id = address(o)
				local old = id and state.cache[id]
				local name = old and old.kind == "ingredients" and now - old.signatureAt < 10 and old.name
				if not name then
					name = ingredientNames[ingredientId(o)]
				end
				if name then
					add(o, o, "ingredients", name, ingredientColor, state.ingredientFolder)
					if cache[id] and old and now - old.signatureAt < 10 then
						cache[id].signatureAt = old.signatureAt
					end
				else
					counts.unknown += 1
				end
			end
		end
	end
	if config.npcs then
		local folder = child(Workspace, "NPCs")
		for _, o in ipairs(children(folder)) do
			if not keepGoing() then
				return
			end
			if read(o, "ClassName") == "Model" and child(o, "Humanoid") then
				local torso, pants = child(o, "Torso"), false
				for _, c in ipairs(children(o)) do
					if read(c, "ClassName") == "Pants" then
						pants = true
						break
					end
				end
				local part = pants and torso or read(o, "Name") == "The Eagle" and child(o, "HumanoidRootPart")
				if part then
					add(o, part, "npcs", tostring(read(o, "Name")), npcColor, folder)
				end
			end
		end
	end
	if not state.running or not state.ready or epoch ~= state.epoch or not validSession() then
		return
	end
	state.targets, state.cache = out, cache
	state.ores, state.ingredients, state.npcs, state.unknown =
		counts.ores, counts.ingredients, counts.npcs, counts.unknown
	state.truncated = truncated
	if state.ingredientFolder then
		state.ingredientStatus =
			string.format("Identified %d | Unknown (hidden) %d", counts.ingredients, counts.unknown)
	end
	state.collectedAt = now
end

local function updatePositions()
	local list = state.targets
	for _ = 1, math.min(16, #list) do
		if state.cursor > #list then
			state.cursor = 1
		end
		local target = list[state.cursor]
		state.cursor += 1
		local p = read(target.part, "Position")
		local valid = point(p) and address(read(target.object, "Parent")) == target.parent
		if target.kind == "npcs" then
			local health = read(child(target.object, "Humanoid"), "Health")
			valid = valid and address(read(target.part, "Parent")) == target.id and finite(health) and health > 0
		else
			local alpha = read(target.part, "Transparency")
			valid = valid and finite(alpha) and alpha >= 0 and alpha < 1
		end
		target.alive, target.position, target.positionAt = valid, valid and p or nil, tick()
	end
end

local function render()
	if not state.running then
		return
	end
	local now = tick()
	if
		not enabled()
		or not state.ready
		or now - state.controlAt > 0.75
		or not point(state.origin)
		or type(isrbxactive) ~= "function"
		or not isrbxactive()
	then
		hide()
		return
	end
	local candidates = {}
	for _, t in ipairs(state.targets) do
		if not config[t.kind] or (t.kind == "ores" and not config[t.name:lower()]) then
			continue
		end
		if not t.alive or not t.position or now - t.positionAt > 2 then
			continue
		end
		local p, origin = t.position, state.origin
		local dx, dy, dz = p.X - origin.X, p.Y - origin.Y, p.Z - origin.Z
		local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
		local range = t.kind == "ores" and config.oreRange
			or t.kind == "ingredients" and config.ingredientRange
			or config.npcRange
		if distance >= range then
			continue
		end
		local screen, onScreen = WorldToScreen(p)
		if onScreen and screen and finite(screen.X) and finite(screen.Y) then
			candidates[#candidates + 1] = { target = t, screen = screen, distance = distance, range = range }
		end
	end
	if #candidates > POOL_SIZE then
		table.sort(candidates, function(a, b)
			return a.distance == b.distance and a.target.id < b.target.id or a.distance < b.distance
		end)
	end
	local selected = {}
	for i = 1, math.min(#candidates, POOL_SIZE) do
		selected[candidates[i].target.id] = true
	end
	for id, slot in pairs(state.slots) do
		if not selected[id] then
			visible(slot, false)
			slot.id = nil
			state.slots[id] = nil
		end
	end
	local free = 1
	for i = 1, math.min(#candidates, POOL_SIZE) do
		local item = candidates[i]
		local t = item.target
		local slot = state.slots[t.id]
		if not slot then
			while state.pool[free].id do
				free += 1
			end
			slot = state.pool[free]
			slot.id = t.id
			state.slots[t.id] = slot
		end
		local text = string.format("%s [%d]", t.name, math.floor(item.distance))
		local alpha = config.opacity / 100
		if config.distanceFade then
			alpha *= 1 - 0.75 * math.clamp(item.distance / item.range, 0, 1)
		end
		alpha = math.floor(alpha * 100 + 0.5) / 100
		local label = slot.label
		if slot.text ~= text then
			label.Text, slot.text = text, text
		end
		if slot.color ~= t.color then
			label.Color, slot.color = t.color, t.color
		end
		if slot.alpha ~= alpha then
			label.Transparency, slot.alpha = alpha, alpha
		end
		if slot.size ~= config.textSize then
			label.Size, slot.size = config.textSize, config.textSize
		end
		if slot.outline ~= config.outline then
			label.Outline, slot.outline = config.outline, config.outline
		end
		local x, y = math.floor(item.screen.X + 0.5), math.floor(item.screen.Y + 0.5)
		if x ~= slot.x or y ~= slot.y then
			label.Position = Vector2.new(x, y)
			slot.x, slot.y = x, y
		end
		visible(slot, true)
	end
	state.visible = math.min(#candidates, POOL_SIZE)
end

local function drawUI(tab)
	local section = tab:Section("World Resources", "Left")
	for _, entry in ipairs({ { "ores", "Ore ESP" }, { "ingredients", "Ingredient ESP (Gaia)" }, { "npcs", "NPC ESP" } }) do
		section:Toggle("rwe_" .. entry[1], entry[2], config[entry[1]], function(v)
			config[entry[1]] = v == true
			state.epoch += 1
			setUI(entry[1], config[entry[1]])
		end)
	end
	section:SliderInt("rwe_oreRange", "Ore Range (studs)", 25, 5000, config.oreRange)
	section:SliderInt("rwe_ingredientRange", "Ingredient Range (studs)", 25, 5000, config.ingredientRange)
	section:SliderInt("rwe_npcRange", "NPC Range (studs)", 25, 5000, config.npcRange)
	section:Tip("Read-only. No mining, pickup, movement or remotes. Hidden while in the menu.")
	local style = tab:Section("Resource Display", "Right")
	for _, name in ipairs({ "Mythril", "Copper", "Iron", "Tin" }) do
		style:Toggle("rwe_" .. name:lower(), name, config[name:lower()])
	end
	style:Toggle("rwe_distanceFade", "Fade With Distance", config.distanceFade)
	style:Toggle("rwe_outline", "Text Outline", config.outline)
	style:SliderInt("rwe_opacity", "Opacity (%)", 10, 100, config.opacity)
	style:SliderInt("rwe_textSize", "Text Size", 10, 24, config.textSize)
	style:InputText("rwe_status", "Resource Status", state.status)
	style:InputText("rwe_counts", "Tracked Resources", "Ores 0 | Ingredients 0 | NPCs 0")
	style:InputText("rwe_ingredientStatus", "Ingredient Identification", state.ingredientStatus)
	style:Tip("96 visible labels maximum. Unknown ingredient signatures stay hidden.")
	style:Button("Unload World ESP", controller.Stop)
	if not state.uiReady then
		state.uiReady = true
		for k, v in pairs(config) do
			setUI(k, v)
		end
	end
end

local ok, err = pcall(function()
	for _ = 1, POOL_SIZE do
		local label = Drawing.new("Text")
		local slot = { label = label, visible = false }
		state.pool[#state.pool + 1] = slot
		label.Visible, label.Center, label.Font, label.Size, label.Transparency = false, true, 2, 13, 1
	end
	if hasUI then
		UI.AddTab("Rogue World", drawUI)
	end
	state.connection = RunService.RenderStepped:Connect(function()
		local success, message = pcall(render)
		if not success then
			state.error = tostring(message)
			controller.Stop()
			warn("[Rogue World] " .. tostring(message))
		end
	end)
	task.spawn(function()
		local controlAt, searchAt = -math.huge, -math.huge
		while state.running do
			local success, message = pcall(function()
				local now = tick()
				if now - controlAt >= 0.2 then
					controlAt = now
					control()
				end
				if not state.running then
					return
				end
				if state.ready then
					if config.ingredients and now - searchAt >= 0.05 then
						searchAt = now
						findIngredients()
					end
					updatePositions()
				end
			end)
			if not success then
				state.error = tostring(message)
				controller.Stop()
				warn("[Rogue World] " .. tostring(message))
				break
			end
			task.wait(0.02)
		end
	end)
	task.spawn(function()
		while state.running do
			if state.ready then
				local success, message = pcall(collect)
				if not success then
					state.error = tostring(message)
					controller.Stop()
					warn("[Rogue World] " .. tostring(message))
					break
				end
			end
			task.wait(1)
		end
	end)
end)
if not ok then
	controller.Stop()
	warn("[Rogue World] Startup failed: " .. tostring(err))
	return
end
print("[Rogue World] Loaded disabled. Ore, ingredient and NPC labels only; no gameplay actions.")
