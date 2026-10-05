-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Matcha adaptation by Ryuu89.
-- Spell ranges and bonus rules: zyu/hydroxide, commit 6951b2a5c29e47ebde700f3897e50cc2d863e89c.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local placeId, jobId = game.PlaceId, game.JobId
if game.GameId ~= 1087859240 or (placeId ~= 5208655184 and placeId ~= 3541987450) then
	warn("[Rogue Mana] Rogue Lineage Gaia and Khei only.")
	return
end
if type(Drawing) ~= "table" or type(Vector2) ~= "table" then
	warn("[Rogue Mana] Matcha Drawing and Vector2 are required.")
	return
end
local previous = _G.RogueManaOverlay
if type(previous) == "table" and type(previous.Stop) == "function" then
	previous.Stop()
end
local player = Players.LocalPlayer
local spells = {
	["Armis"] = { { 40, 60 }, { 70, 80 } },
	["Trickstus"] = { { 30, 70 }, { 30, 50 } },
	["Scrupus"] = { { 30, 100 }, { 30, 100 } },
	["Celeritas"] = { { 70, 90 }, { 70, 80 } },
	["Ignis"] = { { 80, 95 }, { 53, 57 } },
	["Gelidus"] = { { 80, 95 }, { 85, 100 } },
	["Viribus"] = { { 23, 35 }, { 60, 70 } },
	["Sagitta Sol"] = { { 50, 65 }, { 40, 60 } },
	["Tenebris"] = { { 90, 100 }, { 40, 60 } },
	["Nocere"] = { { 70, 85 }, { 70, 85 } },
	["Hystericus"] = { { 75, 90 }, { 15, 35 } },
	["Shrieker"] = { { 30, 50 }, { 30, 50 } },
	["Verdien"] = { { 75, 100 }, { 75, 85 } },
	["Contrarium"] = { { 80, 95 }, { 70, 90 } },
	["Floresco"] = { { 90, 100 }, { 80, 95 } },
	["Perflora"] = { { 70, 90 }, { 30, 50 } },
	["Manus Dei"] = { { 90, 95 }, { 50, 60 } },
	["Fons Vitae"] = { { 75, 100 }, { 75, 100 } },
	["Trahere"] = { { 75, 85 }, { 75, 85 } },
	["Furantur"] = { { 60, 80 }, { 60, 80 } },
	["Inferi"] = { { 10, 30 }, { 10, 30 } },
	["Howler"] = { { 60, 80 }, { 60, 80 } },
	["Secare"] = { { 90, 95 }, { 90, 95 } },
	["Ligans"] = { { 63, 80 }, { 63, 80 } },
	["Reditus"] = { { 50, 100 }, { 50, 100 } },
	["Fimbulvetr"] = { { 86, 90 }, { 70, 80 } },
	["Gate"] = { { 75, 83 }, { 75, 83 } },
	["Snarvindur"] = { { 60, 75 }, { 20, 30 } },
	["Hoppa"] = { { 40, 60 }, { 50, 60 } },
	["Percutiens"] = { { 60, 70 }, { 70, 80 } },
	["Dominus"] = { { 50, 100 }, { 50, 100 } },
	["Custos"] = { { 45, 65 }, { 45, 65 } },
	["Claritum"] = { { 90, 100 }, { 90, 100 } },
	["Globus"] = { { 70, 100 }, { 70, 100 } },
	["Intermissum"] = { { 70, 100 }, { 70, 100 } },
	["Sraunus"] = { { 1, 50 }, { 1, 50 } },
	["Nosferatus"] = { { 95, 100 }, { 95, 100 } },
	["Gourdus"] = { { 80, 90 }, { 80, 90 } },
	["Telorum"] = { { 80, 90 }, { 75, 85 } },
	["Velo"] = { { 0, 100 }, { 50, 60 } },
}
local config = {
	enabled = true,
	normal = true,
	snap = true,
	opacity = 45,
	offsetY = 0,
	topInset = 0,
	scalePercent = 100,
	remTrainingOwned = false,
}
local limits = { opacity = { 0, 100 }, offsetY = { -100, 100 }, topInset = { 0, 100 }, scalePercent = { 50, 500 } }
local state =
	{ running = true, status = "Waiting for character", ranges = "", refreshAt = 0, uiReady = false, slots = {} }
local hasUI = UI
	and type(UI.AddTab) == "function"
	and type(UI.GetValue) == "function"
	and type(UI.SetValue) == "function"

local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
local function savedScale()
	if type(isfile) ~= "function" or type(readfile) ~= "function" then
		return nil
	end
	local ok, value = pcall(function()
		if not isfile("AutoBard.display.cfg") then
			return nil
		end
		return tonumber(readfile("AutoBard.display.cfg"))
	end)
	if ok and finite(value) and value >= 96 and value <= 480 then
		return value / 96 * 100
	end
	return nil
end
config.scalePercent = savedScale() or config.scalePercent

local function read(o, key)
	if not o then
		return nil
	end
	local ok, value = pcall(function()
		return o[key]
	end)
	if ok then
		return value
	end
	return nil
end
-- Matcha can report AbsoluteSize as zero. The engine stores it right after AbsolutePosition,
-- so the offset is found once by matching the native position and is rechecked on every read.
local sizeOffset, sizeScanAt = nil, -math.huge
local function memoryFloat(address)
	if type(memory_read) ~= "function" then
		return nil
	end
	local ok, value = pcall(memory_read, "float", address)
	if ok and finite(value) then
		return value
	end
	return nil
end
local function matchesPosition(address, p)
	local x, y = memoryFloat(address), memoryFloat(address + 4)
	return x ~= nil and y ~= nil and math.abs(x - p.X) < 0.01 and math.abs(y - p.Y) < 0.01
end
local function absoluteSize(o, p)
	local size = read(o, "AbsoluteSize")
	if size and finite(size.X) and finite(size.Y) and size.X > 0 and size.Y > 0 then
		return size
	end
	local address = read(o, "Address")
	if
		not finite(address)
		or address <= 0
		or not p
		or not finite(p.X)
		or not finite(p.Y)
		or (p.X == 0 and p.Y == 0)
	then
		return size
	end
	if sizeOffset == nil then
		local now = tick()
		if now - sizeScanAt < 5 then
			return size
		end
		sizeScanAt = now
		for offset = 0x40, 0x400, 4 do
			if matchesPosition(address + offset, p) then
				sizeOffset = offset + 8
				break
			end
		end
		if sizeOffset == nil then
			return size
		end
	end
	if not matchesPosition(address + sizeOffset - 8, p) then
		sizeOffset = nil
		return size
	end
	local x, y = memoryFloat(address + sizeOffset), memoryFloat(address + sizeOffset + 4)
	if x == nil or y == nil then
		return size
	end
	return Vector2.new(x, y)
end
local function child(o, name)
	return o and o:FindFirstChild(name) or nil
end
local function visible(slot, value)
	if slot.visible ~= value then
		slot.drawing.Visible, slot.visible = value, value
	end
end
local function hide(reason)
	for _, slot in ipairs(state.slots) do
		visible(slot, false)
	end
	state.status = reason
	state.ranges = ""
end
local function setUI(id, value)
	if hasUI and state.uiReady then
		local ok, current = pcall(UI.GetValue, id)
		if ok and current ~= value then
			pcall(UI.SetValue, id, value)
		end
	end
end

local controller = {}
function controller.Stop()
	if not state.running then
		return
	end
	state.running = false
	for _, slot in ipairs(state.slots) do
		pcall(function()
			slot.drawing:Remove()
		end)
	end
	state.slots = {}
	state.context = nil
	if hasUI and type(UI.RemoveTab) == "function" then
		pcall(UI.RemoveTab, "Rogue Mana")
	end
	if _G.RogueManaOverlay == controller then
		_G.RogueManaOverlay = nil
	end
end
function controller.GetStatus()
	local slot = state.slots[1]
	return {
		status = state.status,
		ranges = state.ranges,
		running = state.running,
		error = state.error,
		scalePercent = config.scalePercent,
		remTrainingOwned = config.remTrainingOwned,
		normalBounds = slot and slot.visible and { x = slot.x, y = slot.y, width = slot.width, height = slot.height },
	}
end

local function syncUI()
	if not hasUI or not state.uiReady then
		return
	end
	for key, current in pairs(config) do
		local ok, value = pcall(UI.GetValue, "rmo_" .. key)
		if ok and type(value) == type(current) then
			if type(value) == "boolean" then
				config[key] = value
			elseif finite(value) then
				local range = limits[key]
				local bounded = math.clamp(value, range[1], range[2])
				config[key] = key == "scalePercent" and bounded or math.floor(bounded)
			end
		end
	end
	setUI("rmo_status", state.status)
	setUI("rmo_ranges", state.ranges)
end

local function inspect()
	state.context = nil
	local character = read(player, "Character")
	if not character then
		hide("Waiting for character")
		return
	end
	local humanoid = child(character, "Humanoid")
	local health = read(humanoid, "Health")
	if not finite(health) or health <= 0 then
		hide("Waiting for a living character")
		return
	end
	local gui = child(player, "PlayerGui")
	local stat = child(gui, "StatGui")
	local bar = child(child(stat, "LeftContainer"), "Mana")
	if not bar then
		hide("Waiting for StatGui mana bar")
		return
	end
	if read(stat, "Enabled") == false or read(bar, "Visible") == false then
		hide("Mana bar hidden")
		return
	end
	local tool
	for _, object in ipairs(character:GetChildren()) do
		if object.ClassName == "Tool" then
			if tool then
				hide("Multiple equipped tools - ranges unavailable")
				return
			end
			tool = object
		end
	end
	local name = read(tool, "Name")
	local spell = name and spells[name]
	if not spell then
		hide(tool and "No Hydroxide range for equipped tool" or "Equip a spell to show its ranges")
		return
	end
	local boon = child(child(character, "Boosts"), "ScholarsBoon")
	local bonus = 0
	if boon then
		bonus = read(boon, "Value")
		if not finite(bonus) or bonus < 0 or bonus > 100 then
			hide("ScholarsBoon unreadable - ranges unavailable")
			return
		end
	end
	local backpack = child(player, "Backpack")
	if not backpack then
		hide("Waiting for Backpack")
		return
	end
	if child(backpack, "WiseCasting") then
		bonus = bonus + 2
	end
	if config.remTrainingOwned or child(backpack, "RemTraining") then
		bonus = bonus + 3
	end
	local ranges = {}
	for i, range in ipairs(spell) do
		ranges[i] = { math.max(0, range[1] - bonus), math.min(100, range[2] + bonus) }
	end
	state.context = { character = character, tool = tool, bar = bar, stat = stat, name = name, ranges = ranges }
end

local function guiInset(stat)
	if read(stat, "IgnoreGuiInset") == true then
		return 0
	end
	local service = game:GetService("GuiService")
	local method = read(service, "GetGuiInset")
	if type(method) == "function" then
		local ok, inset = pcall(method, service)
		if ok and inset and finite(inset.Y) and inset.Y >= 0 and inset.Y <= 200 then
			return inset.Y
		end
	end
	return config.topInset
end

local function drawRange(slot, lower, upper, p, size, enabled, inset)
	if not enabled or config.opacity == 0 then
		visible(slot, false)
		return
	end
	local scale = config.scalePercent / 100
	local x = p.X * scale
	local y = (p.Y + inset + size.Y * (1 - upper / 100)) * scale + config.offsetY
	local width, height = size.X * scale, size.Y * (upper - lower) / 100 * scale
	if height <= 0 then
		visible(slot, false)
		return
	end
	if slot.x ~= x or slot.y ~= y then
		slot.drawing.Position = Vector2.new(x, y)
		slot.x, slot.y = x, y
	end
	if slot.width ~= width or slot.height ~= height then
		slot.drawing.Size = Vector2.new(width, height)
		slot.width, slot.height = width, height
	end
	if slot.opacity ~= config.opacity then
		slot.drawing.Transparency = config.opacity / 100
		slot.opacity = config.opacity
	end
	visible(slot, true)
end

local function update()
	if game.GameId ~= 1087859240 or game.PlaceId ~= placeId or game.JobId ~= jobId then
		hide("Session changed - run the script again")
		syncUI()
		controller.Stop()
		return
	end
	syncUI()
	if not config.enabled then
		hide("Disabled")
		return
	end
	if type(isrbxactive) ~= "function" or not isrbxactive() then
		hide("Paused - Roblox not focused")
		return
	end
	local now = tick()
	if now >= state.refreshAt then
		state.refreshAt = now + 0.2
		inspect()
	end
	local context = state.context
	if not context then
		return
	end
	-- Recheck ownership before showing cached ranges after an unequip or respawn.
	local current = read(player, "Character")
	local parent = read(context.tool, "Parent")
	local health = read(child(current, "Humanoid"), "Health")
	if
		not current
		or read(current, "Address") ~= read(context.character, "Address")
		or not parent
		or read(parent, "Address") ~= read(current, "Address")
		or not finite(health)
		or health <= 0
	then
		state.context = nil
		state.refreshAt = 0
		hide("Character or equipped spell changed")
		return
	end
	if
		read(context.stat, "Enabled") == false
		or read(context.bar, "Visible") == false
		or not read(context.bar, "Parent")
	then
		hide("Mana bar hidden")
		return
	end
	local p = read(context.bar, "AbsolutePosition")
	local size = absoluteSize(context.bar, p)
	if
		not p
		or not size
		or not finite(p.X)
		or not finite(p.Y)
		or not finite(size.X)
		or not finite(size.Y)
		or size.X <= 0
		or size.X > 300
		or size.Y <= 0
		or size.Y > 5000
		or math.abs(p.X) > 20000
		or math.abs(p.Y) > 20000
	then
		hide("Mana bar bounds unavailable")
		return
	end
	local normal, snap = context.ranges[1], context.ranges[2]
	local inset = guiInset(context.stat)
	drawRange(state.slots[1], normal[1], normal[2], p, size, config.normal, inset)
	if snap then
		drawRange(state.slots[2], snap[1], snap[2], p, size, config.snap, inset)
	else
		visible(state.slots[2], false)
	end
	state.status = context.name .. " - Hydroxide cast ranges"
	state.ranges = string.format("Normal %g-%g%%", normal[1], normal[2])
	if snap then
		state.ranges = state.ranges .. string.format(" | Snap %g-%g%%", snap[1], snap[2])
	end
end

local function toggle(section, key, label)
	section:Toggle("rmo_" .. key, label, config[key], function(value)
		config[key] = value == true
		state.refreshAt = 0
		if not config.enabled then
			hide("Disabled")
		end
	end)
end
local function drawUI(tab)
	local main = tab:Section("Mana Overlay", "Left")
	toggle(main, "enabled", "Mana Overlay")
	toggle(main, "normal", "Normal Cast Range (red)")
	toggle(main, "snap", "Snap Cast Range (blue)")
	toggle(main, "remTrainingOwned", "RemTraining Owned (manual confirmation)")
	main:Tip(
		"Enable only if you own RemTraining and automatic detection misses it. Adds its +3 range bonus once, even when detected."
	)
	main:SliderInt("rmo_opacity", "Overlay Opacity (%)", 0, 100, config.opacity)
	main:SliderFloat("rmo_scalePercent", "GUI Scale (%)", 50, 500, config.scalePercent, "%.2f")
	main:Tip(
		"Loaded from the existing AutoBard display calibration when available; otherwise 100%. Scales position and size together. Does not change Windows or game settings."
	)
	main:SliderInt("rmo_topInset", "Fallback GUI Inset (px)", 0, 100, config.topInset)
	main:SliderInt("rmo_offsetY", "Vertical Alignment (px)", -100, 100, config.offsetY)
	main:Tip(
		"Shows Hydroxide's ranges for the equipped spell, including ScholarsBoon, WiseCasting and RemTraining. Does not charge or cast."
	)
	main:Tip(
		"Native GUI inset is used when readable. Otherwise no top margin is assumed (0 px); external coordinates may already include it. Vertical Alignment is an additional adjustment in drawing pixels."
	)
	local status = tab:Section("Status", "Right")
	status:InputText("rmo_status", "State", state.status)
	status:InputText("rmo_ranges", "Mana Ranges", state.ranges)
	status:Button("Refresh Mana Overlay", function()
		state.refreshAt = 0
	end)
	status:Button("Unload Mana Overlay", controller.Stop)
	status:Text("Made by Ryuu89")
	status:Text("Spell ranges based on Hydroxide")
	if not state.uiReady then
		state.uiReady = true
		for key, value in pairs(config) do
			pcall(UI.SetValue, "rmo_" .. key, value)
		end
	end
end

_G.RogueManaOverlay = controller
local ok, message = pcall(function()
	for index, color in ipairs({ Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 0, 255) }) do
		local drawing = Drawing.new("Square")
		state.slots[index] = { drawing = drawing, visible = false }
		drawing.Visible = false
		drawing.Filled = true
		drawing.Color = color
		drawing.Transparency = config.opacity / 100
		drawing.ZIndex = 100 + index
	end
	if hasUI then
		UI.AddTab("Rogue Mana", drawUI)
	end
	task.spawn(function()
		while state.running do
			local success, err = pcall(update)
			if not success then
				state.error = tostring(err)
				warn("[Rogue Mana] Stopped: " .. state.error)
				controller.Stop()
				return
			end
			task.wait(0.05)
		end
	end)
end)
if not ok then
	controller.Stop()
	warn("[Rogue Mana] Startup failed: " .. tostring(message))
	return
end
print("[Rogue Mana] Loaded. Open Rogue Mana in Matcha. Visual only: no input, camera or game writes.")
