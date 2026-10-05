-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Matcha adaptation by Ryuu89, 2026-09-05.
-- Identification rules: zyu/hydroxide, commit 6951b2a5c29e47ebde700f3897e50cc2d863e89c.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local placeId = game.PlaceId
if game.GameId ~= 1087859240 or (placeId ~= 5208655184 and placeId ~= 3541987450) then
	warn("[Rogue ESP] This script supports Rogue Lineage Gaia and Khei only.")
	return
end
if type(Drawing) ~= "table" or type(WorldToScreen) ~= "function" then
	warn("[Rogue ESP] Matcha Drawing and WorldToScreen are required.")
	return
end

local previous = _G.RogueTrinketESP
if type(previous) == "table" and type(previous.Stop) == "function" then
	previous.Stop()
end

local POOL_SIZE = 128
local localPlayer = Players.LocalPlayer
local jobId = game.JobId
local config = {
	enabled = true,
	customColor = false,
	range = 1000,
	limitRange = false,
	distanceFade = false,
	fadeStart = 250,
	fadeEnd = 2000,
	fadeMinimum = 25,
	area = true,
	distance = true,
	textSize = 13,
	outline = false,
	common = true,
	rare = true,
	event = true,
	artifact = true,
	mythic = true,
	unknown = true,
	farCommon = false,
	farRare = false,
	farEvent = false,
	farArtifact = true,
	farMythic = true,
}
local numberLimits = {
	range = { 25, 10000 },
	textSize = { 10, 24 },
	fadeStart = { 0, 9999 },
	fadeEnd = { 1, 10000 },
	fadeMinimum = { 0, 100 },
}
local categories = { "common", "rare", "event", "artifact", "mythic", "unknown" }
local categoryLabels = { "Common", "Rare", "Event", "Artifact", "Mythic", "Unclassified" }
local colors = {
	common = Color3.fromRGB(189, 97, 29),
	rare = Color3.fromRGB(60, 150, 150),
	event = Color3.fromRGB(0, 255, 0),
	artifact = Color3.fromRGB(96, 255, 0),
	mythic = Color3.fromRGB(255, 0, 0),
	unknown = Color3.fromRGB(0, 0, 0),
}
colors.custom = Color3.fromRGB(255, 206, 92)
local defaultAlpha = { common = 112 / 255, rare = 144 / 255, unknown = 133 / 255 }
local palette = {}
for key, color in pairs(colors) do
	palette[key] = { color.R, color.G, color.B, defaultAlpha[key] or 1 }
end
local ranks = { unknown = 0, common = 1, rare = 2, event = 3, artifact = 4, mythic = 5 }
local bypassKeys =
	{ common = "farCommon", rare = "farRare", event = "farEvent", artifact = "farArtifact", mythic = "farMythic" }
local meshNames = {
	["5196782997"] = { "Old Ring", "common" },
	["5196776695"] = { "Ring", "common" },
	["5204003946"] = { "Goblet", "common" },
	["5196577540"] = { "Old Amulet", "common" },
	["5196551436"] = { "Amulet", "common" },
	["5204453430"] = { "Scroll", "rare" },
}
local unionNames = {
	["2765613127"] = { "Idol of the Forgotten", "common" },
	["15583017412"] = { "Ornament", "event" },
	["15611175305"] = { "Present", "event" },
	["4117970107"] = { "Pumpkin Centerpiece", "event" },
	["17590006505"] = { "Idol of War", "event" },
	["135210454467508"] = { "Scary Mask", "event" },
	["130937394581985"] = { "Scary Mask", "event" },
	["110718109649132"] = { "Scary Mask", "event" },
	["78990214596147"] = { "Scary Mask", "event" },
	["77406341502228"] = { "Scary Mask", "event" },
	["118090092039844"] = { "Scary Mask", "event" },
}

local state = {
	running = true,
	targets = {},
	cache = {},
	pool = {},
	visible = 0,
	total = 0,
	identified = 0,
	status = "Waiting for character",
	lastError = nil,
	failures = 0,
	refresh = true,
	key = 0x75,
	keyHeld = false,
	uiReady = false,
	uiAt = 0,
	keyAt = 0,
	colorRevision = 0,
	slotsByAddress = {},
	ready = false,
	controlAt = -math.huge,
	positionCursor = 1,
	onScreen = 0,
}
local hasUI = UI ~= nil
	and type(UI.AddTab) == "function"
	and type(UI.GetValue) == "function"
	and type(UI.SetValue) == "function"

local function read(object, property)
	if object == nil then
		return nil
	end
	local ok, value = pcall(function()
		return object[property]
	end)
	if ok then
		return value
	end
	return nil
end

local function finite(n)
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end

local function updateColor(key, r, g, b, a)
	if type(r) ~= "number" then
		local value, callbackAlpha = r, g
		r = read(value, "R") or read(value, "r") or read(value, 1)
		g = read(value, "G") or read(value, "g") or read(value, 2)
		b = read(value, "B") or read(value, "b") or read(value, 3)
		a = callbackAlpha or read(value, "A") or read(value, "a") or read(value, 4)
	end
	if not finite(r) or not finite(g) or not finite(b) then
		return
	end
	if math.min(r, g, b) < 0 or math.max(r, g, b) > 1 then
		return
	end
	a = a == nil and 1 or a
	if not finite(a) or a < 0 or a > 1 then
		return
	end
	local current = palette[key]
	if current and current[1] == r and current[2] == g and current[3] == b and current[4] == a then
		return
	end
	palette[key] = { r, g, b, a }
	colors[key] = Color3.fromRGB(r * 255, g * 255, b * 255)
	state.colorRevision = state.colorRevision + 1
end

local function colorPicker(section, key)
	local c = palette[key]
	section:ColorPicker("rte_color_" .. key, c[1], c[2], c[3], c[4], function(...)
		updateColor(key, ...)
	end)
end

local function position(v)
	return v ~= nil
		and finite(v.X)
		and finite(v.Y)
		and finite(v.Z)
		and math.abs(v.X) < 1000000
		and math.abs(v.Y) < 1000000
		and math.abs(v.Z) < 1000000
end

local function assetId(value)
	if type(value) ~= "string" then
		return nil
	end
	if value == "" then
		return ""
	end
	if not value:match("^rbxassetid://") and not value:match("^https?://") and not value:match("^%d+$") then
		return nil
	end
	return value:gsub("%%20", ""):match("%d+")
end

local memoryVersion = type(getrbxversion) == "function" and getrbxversion() or nil
-- Field shift per validated build. version-02c37bc51a384b8f moved every field by -0x10;
-- it was revalidated against live MeshPart, Union, SpecialMesh, part color and particle data.
local memoryShifts = {
	["version-e7d81637d42c4b23"] = 0,
	["version-02c37bc51a384b8f"] = -0x10,
}
local memoryEnabled = memoryShifts[memoryVersion] ~= nil and type(memory_read) == "function"
local memoryShift = memoryShifts[memoryVersion] or 0
local memoryHits = 0

local function pointer(value)
	return finite(value) and value >= 65536 and value < 140737488355328 and value % 8 == 0
end

local function raw(kind, address)
	if not memoryEnabled or not finite(address) or address < 65536 or address >= 140737488355328 then
		return nil
	end
	local ok, value = pcall(memory_read, kind, address)
	return ok and value or nil
end

local function objectAddress(object)
	if not memoryEnabled then
		return nil
	end
	local address = read(object, "Address")
	if pointer(address) and pointer(raw("uintptr_t", address)) then
		return address
	end
	return nil
end

-- Layout validated against live game objects on the builds listed in memoryShifts.
-- Never scan memory or reuse these offsets on an unlisted version.
local function contentString(object, offset)
	local address = objectAddress(object)
	if not address then
		return nil
	end
	local field = address + offset
	local length, capacity = raw("uintptr_t", field + 16), raw("uintptr_t", field + 24)
	if
		not finite(length)
		or not finite(capacity)
		or length % 1 ~= 0
		or capacity % 1 ~= 0
		or length < 0
		or length > 256
		or capacity < length
		or capacity > 4096
	then
		return nil
	end
	if length == 0 and capacity == 15 then
		return ""
	end
	if length == 0 then
		return nil
	end
	local data = capacity > 15 and raw("uintptr_t", field) or field
	if not pointer(data) then
		return nil
	end
	local text = raw("string", data)
	if type(text) ~= "string" or #text ~= length then
		return nil
	end
	return text
end

local function itemAsset(object, property)
	local native = assetId(read(object, property))
	if native ~= nil then
		return native
	end
	local class = read(object, "ClassName")
	local offset
	if property == "MeshId" then
		offset = class == "MeshPart" and 0x310 or class == "SpecialMesh" and 0xF8 or nil
	elseif property == "AssetId" and class == "UnionOperation" then
		offset = 0x310
	end
	if not offset then
		return nil
	end
	local value = assetId(contentString(object, offset + memoryShift))
	if value ~= nil then
		memoryHits = memoryHits + 1
	end
	return value
end

local function sphereMesh(mesh)
	local native = read(mesh, "MeshType")
	if tostring(native) == "Sphere" or tostring(native) == "Enum.MeshType.Sphere" then
		return true
	end
	local sphereEnum = Enum and Enum.MeshType and Enum.MeshType.Sphere
	if native ~= nil then
		return sphereEnum ~= nil and native == sphereEnum
	end
	if read(mesh, "ClassName") ~= "SpecialMesh" then
		return false
	end
	local address = objectAddress(mesh)
	return address ~= nil and raw("int", address + 0x148 + memoryShift) == 3
end

local function rgb(value)
	if value == nil then
		return nil
	end
	local r, g, b = value.R, value.G, value.B
	if not finite(r) or not finite(g) or not finite(b) then
		return nil
	end
	if math.min(r, g, b) < 0 or math.max(r, g, b) > 1 then
		return nil
	end
	return { r, g, b }
end

local function itemColor(object)
	local class = read(object, "ClassName")
	local address = (class == "Part" or class == "MeshPart" or class == "UnionOperation") and objectAddress(object)
	if address then
		local r, g, b = raw("byte", address + 0x1A8 + memoryShift), raw("byte", address + 0x1A9 + memoryShift), raw("byte", address + 0x1AA + memoryShift)
		if finite(r) and finite(g) and finite(b) and math.min(r, g, b) >= 0 and math.max(r, g, b) <= 255 then
			memoryHits = memoryHits + 1
			return { r / 255, g / 255, b / 255 }
		end
	end
	return rgb(read(object, "Color"))
end

local function memorySequence(emitter)
	if read(emitter, "ClassName") ~= "ParticleEmitter" then
		return nil
	end
	local address = objectAddress(emitter)
	if not address then
		return nil
	end
	local data = raw("uintptr_t", address + 0x178 + memoryShift)
	local count, capacity = raw("int", address + 0x180 + memoryShift), raw("int", address + 0x184 + memoryShift)
	if
		not pointer(data)
		or not finite(count)
		or not finite(capacity)
		or count < 2
		or count > 20
		or count % 1 ~= 0
		or capacity % 1 ~= 0
		or capacity < count
		or capacity > 64
	then
		return nil
	end
	local out, lastTime = {}, -1
	for index = 0, count - 1 do
		for component = 0, 4 do
			local value = raw("float", data + (index * 5 + component) * 4)
			if not finite(value) or value < 0 or value > 1 then
				return nil
			end
			out[#out + 1] = value
		end
		local time = out[index * 5 + 1]
		if time <= lastTime or (index == 0 and time ~= 0) or (index == count - 1 and time ~= 1) then
			return nil
		end
		lastTime = time
	end
	memoryHits = memoryHits + 1
	return out
end

local function particleRate(emitter)
	if read(emitter, "ClassName") ~= "ParticleEmitter" then
		return nil
	end
	local value = read(emitter, "Rate")
	if finite(value) and value >= 0 and value <= 10000 then
		return value
	end
	local address = objectAddress(emitter)
	if not address then
		return nil
	end
	value = raw("float", address + 0x248 + memoryShift)
	if finite(value) and value >= 0 and value <= 10000 then
		memoryHits = memoryHits + 1
		return value
	end
	return nil
end

local function near(a, b)
	return math.abs(a - b) < 0.002
end

local function sequence(emitter)
	local value = read(emitter, "Color")
	if value == nil then
		return memorySequence(emitter)
	end
	local text = tostring(value)
	if text:find("[^%d%s%.%-+eE]") then
		return memorySequence(emitter)
	end
	local out = {}
	for token in text:gmatch("%S+") do
		local n = tonumber(token)
		if not finite(n) then
			return nil
		end
		out[#out + 1] = n
	end
	if #out < 10 or #out % 5 ~= 0 then
		return nil
	end
	return out
end

local function white(seq)
	if seq == nil then
		return nil
	end
	local expected = { 0, 1, 1, 1, 0, 1, 1, 1, 1, 0 }
	if #seq ~= #expected then
		return false
	end
	for i = 1, #expected do
		if not near(seq[i], expected[i]) then
			return false
		end
	end
	return true
end

local function gem(color)
	if color == nil then
		return nil
	end
	local r, g, b = color[1], color[2], color[3]
	if near(r, 164 / 255) and near(g, 187 / 255) and near(b, 190 / 255) then
		return "Diamond", "rare"
	end
	if near(r, 230 / 255) and near(g, 29 / 255) and near(b, 248 / 255) then
		return "Rift Gem", "mythic"
	end
	if g > r and g > b then
		return "Emerald", "rare"
	end
	if r > g and r > b then
		return "Ruby", "rare"
	end
	if b > r and b > g then
		return "Sapphire", "rare"
	end
	return nil
end

local function identify(object)
	local class = object.ClassName
	if class == "UnionOperation" then
		local id = itemAsset(object, "AssetId")
		local match = id and unionNames[id]
		if match then
			return match[1], match[2], "Union AssetId"
		end
		return "Unclassified", "unknown", id == nil and "AssetId unavailable" or "Unknown union asset"
	end

	local meshId = class == "MeshPart" and itemAsset(object, "MeshId") or nil
	local match = meshId and meshNames[meshId]
	if match then
		return match[1], match[2], "MeshId"
	end

	local children = object:GetChildren()
	local byName, special = {}, nil
	for _, child in ipairs(children) do
		byName[child.Name] = child
		if child.ClassName == "SpecialMesh" then
			special = child
		end
	end
	local emitter = byName.ParticleEmitter
	local emitterSeq = sequence(emitter)
	local emitterWhite = white(emitterSeq)
	if class == "Part" then
		if special and byName.OrbParticle then
			return "???", "rare", "OrbParticle + SpecialMesh"
		end
		local specialId = itemAsset(special, "MeshId")
		local sphere = sphereMesh(special)
		if special and emitter and specialId == "" and sphere then
			return "Opal", "common", "Sphere mesh + ParticleEmitter"
		end
		local namedMeshId = itemAsset(byName.Mesh, "MeshId")
		if namedMeshId == "2877143560" and emitterWhite == true then
			local name, category = gem(itemColor(object))
			if name then
				return name, category, "Gem mesh + color + particles"
			end
		end
		if emitterWhite == false then
			return "Rift Gem", "mythic", "Non-white particle sequence"
		end
	end

	local pairedId, pairedName
	if meshId == "5197099782" then
		pairedId, pairedName = "5197111525", "Amulet of the White King"
	elseif meshId == "5196963069" then
		pairedId, pairedName = "5196975152", "Lannis Amulet"
	end
	if pairedId then
		for _, child in ipairs(children) do
			if
				child.ClassName == "MeshPart"
				and child.Name == "MeshPart"
				and itemAsset(child, "MeshId") == pairedId
			then
				return pairedName, "artifact", "Paired meshes"
			end
		end
	end

	local attachmentEmitter = nil
	if byName.Attachment then
		for _, child in ipairs(byName.Attachment:GetChildren()) do
			if child.ClassName == "ParticleEmitter" then
				attachmentEmitter = child
				break
			end
		end
	end
	local rate = particleRate(attachmentEmitter)
	if rate == 3 then
		return "Mysterious Artifact", "mythic", "Attachment particle rate"
	end
	if meshId == "4103271893" then
		return "Candy", "event", "MeshId"
	end
	if rate == 5 then
		local seq = sequence(attachmentEmitter)
		if seq then
			if near(seq[3], 0.8) then
				return "Phoenix Down", "artifact", "Attachment particles"
			end
			return placeId == 3541987450 and "Phoenix Flower" or "Azael Horn", "mythic", "Attachment particles"
		end
	end
	local brickColor = read(object, "BrickColor")
	if class == "MeshPart" and read(brickColor, "Name") == "Black" then
		return "Night Stone", "artifact", "Black BrickColor"
	end
	if meshId == "2520762076" then
		return "Howler Friend", "artifact", "MeshId"
	end
	local orbSeq = sequence(byName.OrbParticle)
	if
		class == "Part"
		and orbSeq
		and near(orbSeq[2], 0.105882)
		and near(orbSeq[3], 0.596078)
		and near(orbSeq[4], 0.596078)
		and near(orbSeq[7], 0.105882)
		and near(orbSeq[8], 0.596078)
		and near(orbSeq[9], 0.596078)
	then
		return "Ice Essence", "rare", "OrbParticle color"
	end
	if placeId == 3541987450 and class == "MeshPart" then
		if meshId == "4027112893" and byName.Part then
			return "Bound Book", "rare", "MeshId + Part"
		end
		if meshId == "2877143560" then
			local name, category = gem(itemColor(object))
			if name then
				return name, category, "Khei gem mesh + color"
			end
		end
	end
	if attachmentEmitter and rate == nil then
		return "Unclassified", "unknown", "Attachment particle rate unavailable"
	end
	if rate == 5 and sequence(attachmentEmitter) == nil then
		return "Unclassified", "unknown", "Attachment particle color unavailable"
	end
	return "Unclassified",
		"unknown",
		class == "MeshPart" and meshId == nil and "MeshId unavailable" or "No readable Hydroxide signature"
end

local function setVisible(slot, visible)
	if slot.visible ~= visible then
		slot.label.Visible = visible
		slot.visible = visible
	end
end

local function hideAll()
	for _, slot in ipairs(state.pool) do
		setVisible(slot, false)
	end
	state.visible = 0
end

local controller = {}
function controller.Stop()
	if not state.running then
		return
	end
	state.running = false
	if state.connection then
		pcall(function()
			state.connection:Disconnect()
		end)
	end
	for _, slot in ipairs(state.pool) do
		pcall(function()
			slot.label:Remove()
		end)
	end
	state.targets, state.cache, state.pool, state.slotsByAddress = {}, {}, {}, {}
	if hasUI and type(UI.RemoveTab) == "function" then
		pcall(UI.RemoveTab, "Rogue ESP")
	end
	if _G.RogueTrinketESP == controller then
		_G.RogueTrinketESP = nil
	end
end

function controller.GetUnionAssetId(object)
	if not state.running or read(object, "ClassName") ~= "UnionOperation" then return nil end
	if game.PlaceId ~= placeId or game.JobId ~= jobId then return nil end
	return itemAsset(object, "AssetId")
end

function controller.GetStatus()
	local items = {}
	for _, target in ipairs(state.targets) do
		items[#items + 1] = { name = target.name, category = target.category, reason = target.reason }
	end
	return {
		status = state.status,
		candidates = state.total,
		identified = state.identified,
		visible = state.visible,
		onScreen = state.onScreen,
		labelLimit = POOL_SIZE,
		error = state.lastError,
		items = items,
		memoryReader = memoryEnabled,
		memoryVersion = memoryVersion,
		memoryHits = memoryHits,
	}
end
_G.RogueTrinketESP = controller

local characterCache = { refreshAt = 0 }
local function characterReady()
	local character = localPlayer and localPlayer.Character
	if character == nil then
		characterCache = { refreshAt = 0 }
		return false
	end
	local address = read(character, "Address")
	local now = tick()
	if address ~= characterCache.address or now >= characterCache.refreshAt then
		characterCache = {
			address = address,
			refreshAt = now + 0.3,
			root = character:FindFirstChild("HumanoidRootPart"),
			humanoid = character:FindFirstChild("Humanoid"),
		}
	end
	if not position(read(characterCache.root, "Position")) then
		return false
	end
	local health = read(characterCache.humanoid, "Health")
	return health == nil or (finite(health) and health > 0)
end

local function sessionValid()
	return game.GameId == 1087859240 and game.PlaceId == placeId and game.JobId == jobId
end

local areas, areasAt = {}, 0
local function updateAreas(now)
	if now < areasAt then
		return
	end
	areasAt = now + 10
	local folder = Workspace:FindFirstChild("AreaMarkers")
	local updated = {}
	if folder then
		for _, marker in ipairs(folder:GetChildren()) do
			local p = read(marker, "Position")
			if position(p) then
				updated[#updated + 1] = { name = marker.Name, position = p }
			end
		end
	end
	areas = updated
end

local function nearestArea(p)
	local name, best = nil, math.huge
	for _, area in ipairs(areas) do
		local d = (p - area.position).Magnitude
		if d < best then
			name, best = area.name, d
		end
	end
	return name
end

local function collect()
	if not sessionValid() then
		state.status = "Session changed - run the script again"
		hideAll()
		return
	end
	if not config.enabled then
		state.status = "Disabled"
		hideAll()
		return
	end
	if not characterReady() then
		state.status = "Waiting for character"
		state.targets, state.cache, state.total, state.identified = {}, {}, 0, 0
		hideAll()
		return
	end
	local now = tick()
	updateAreas(now)
	local targets, cache, identified = {}, {}, 0
	local classifications = 0
	for index, object in ipairs(Workspace:GetChildren()) do
		if not state.running or not config.enabled then
			return
		end
		local class = object.ClassName
		if
			object.Name == "Part"
			and (class == "Part" or class == "MeshPart" or class == "UnionOperation")
			and object:FindFirstChild("ID")
		then
			local address, p = read(object, "Address"), read(object, "Position")
			if finite(address) and address > 0 and position(p) and not cache[address] then
				local target = state.cache[address]
				if target == nil or target.class ~= class or now >= target.classifyAt then
					local ok, name, category, reason = pcall(identify, object)
					if not ok then
						name, category, reason = "Unclassified", "unknown", "Item read failed"
					end
					target = {
						name = name,
						category = category,
						reason = reason,
						class = class,
						classifyAt = tick() + (category == "unknown" and 2 or 5) + (address % 997) / 997,
					}
					classifications = classifications + 1
					if classifications % 8 == 0 then
						task.wait()
						if not state.running or not config.enabled then
							return
						end
					end
				end
				target.object, target.address = object, address
				target.position, target.positionAt, target.alive = p, tick(), true
				if target.areaAt == nil or now >= target.areaAt then
					target.area, target.areaAt = nearestArea(p), now + 10
				end
				cache[address] = target
				targets[#targets + 1] = target
				if target.category ~= "unknown" then
					identified = identified + 1
				end
			end
		end
		if index % 32 == 0 then
			task.wait()
		end
	end
	if not state.running or not config.enabled or not sessionValid() then
		return
	end
	state.targets, state.cache = targets, cache
	state.total, state.identified = #targets, identified
	state.status = #targets == 0 and "No trinkets replicated"
		or identified == #targets and "Tracking trinkets"
		or identified == 0 and "Identification blocked - MeshId / AssetId unavailable"
		or "Tracking - some signatures unavailable"
end

local function setUI(id, value)
	if not hasUI or not state.uiReady then
		return
	end
	local ok, current = pcall(UI.GetValue, id)
	if ok and current ~= value then
		pcall(UI.SetValue, id, value)
	end
end

local function syncUI()
	if not hasUI or not state.uiReady then
		return
	end
	for key, current in pairs(config) do
		local ok, value = pcall(UI.GetValue, "rte_" .. key)
		if ok and type(value) == type(current) then
			if type(value) == "boolean" then
				config[key] = value
			elseif finite(value) and numberLimits[key] then
				local bounds = numberLimits[key]
				config[key] = math.floor(math.clamp(value, bounds[1], bounds[2]))
			end
		end
	end
	if config.fadeEnd <= config.fadeStart then
		config.fadeEnd = config.fadeStart + 1
		setUI("rte_fadeEnd", config.fadeEnd)
	end
	for key in pairs(palette) do
		local ok, r, g, b, a = pcall(UI.GetValue, "rte_color_" .. key)
		if ok then
			updateColor(key, r, g, b, a)
		end
	end
	setUI("rte_status", state.status)
	setUI(
		"rte_counts",
		string.format("%d candidates | %d identified | %d on screen", state.total, state.identified, state.visible)
	)
end

local function describeColor(value)
	if value == nil then
		return "unavailable"
	end
	return string.format(
		"R=%s G=%s B=%s",
		tostring(read(value, "R")),
		tostring(read(value, "G")),
		tostring(read(value, "B"))
	)
end

local function diagnostics()
	print(
		"[Rogue ESP] Memory reader: " .. (memoryEnabled and "validated build" or "disabled - unsupported build or API")
	)
	print(
		"[Rogue ESP] Roblox build: " .. tostring(memoryVersion) .. " | recovered properties: " .. tostring(memoryHits)
	)
	syncUI()
	print("[Rogue ESP] Color mode: " .. (config.customColor and "Global override" or "Per category"))
	for _, key in ipairs({ "custom", "unknown" }) do
		local c = palette[key]
		print(string.format("[Rogue ESP] %s configured RGBA: %.3f %.3f %.3f %.3f", key, c[1], c[2], c[3], c[4]))
		print("[Rogue ESP] " .. key .. " Color3: " .. describeColor(colors[key]))
		if hasUI then
			local ok, r, g, b, a = pcall(UI.GetValue, "rte_color_" .. key)
			print(
				string.format(
					"[Rogue ESP] %s picker raw: %s | %s | %s | %s",
					key,
					tostring(r),
					tostring(g),
					tostring(b),
					tostring(a)
				)
			)
			if ok and type(r) ~= "number" then
				print("[Rogue ESP] picker components: " .. describeColor(r))
			end
		end
	end
	for _, slot in ipairs(state.pool) do
		if slot.styleKey then
			local sent = palette[slot.styleKey]
			print(
				string.format("[Rogue ESP] Drawing RGB (%s): %.3f %.3f %.3f", slot.styleKey, sent[1], sent[2], sent[3])
			)
			print("[Rogue ESP] Text opacity: 1 = opaque, 0 = invisible. Color readback unsupported.")
			print("[Rogue ESP] Drawing transparency: " .. tostring(read(slot.label, "Transparency")))
			break
		end
	end
	print("[Rogue ESP] " .. state.status)
	print(
		string.format(
			"[Rogue ESP] Candidates: %d | Identified: %d | Visible: %d",
			state.total,
			state.identified,
			state.visible
		)
	)
	local reasons = {}
	for _, target in ipairs(state.targets) do
		reasons[target.reason] = (reasons[target.reason] or 0) + 1
	end
	for reason, count in pairs(reasons) do
		print(string.format("[Rogue ESP] %s: %d", reason, count))
	end
	if state.lastError then
		print("[Rogue ESP] Last error: " .. state.lastError)
	end
end

local function toggle(section, key, label)
	section:Toggle("rte_" .. key, label, config[key], function(value)
		config[key] = value == true
		if key == "enabled" then
			state.refresh = true
		end
		if key == "enabled" and not config.enabled then
			hideAll()
		end
	end)
end

local function drawUI(tab)
	local main = tab:Section("Trinket ESP", "Left")
	toggle(main, "enabled", "Trinket ESP")
	local keybind = main:Keybind("rte_hotkey", 0x75, "toggle")
	if tick() >= state.keyAt then
		state.keyAt = tick() + 0.2
		local ok, key = pcall(function()
			return keybind:GetKey()
		end)
		if ok and finite(key) and key >= 0 and key <= 255 and key ~= state.key then
			state.keyHeld = type(iskeypressed) == "function" and iskeypressed(key) or false
			state.key = key
		end
	end
	main:Tip("Toggle while Roblox is focused. Default: F6.")
	toggle(main, "limitRange", "Limit Display Range")
	main:SliderInt("rte_range", "Display Range (studs)", 25, 10000, config.range)
	main:Tip(
		"OFF: show all replicated candidates within the camera view. ON: apply the display range. Does not change replication."
	)
	toggle(main, "area", "Show Region")
	toggle(main, "distance", "Show Distance")
	main:SliderInt("rte_textSize", "Text Size", 10, 24, config.textSize)
	toggle(main, "outline", "Text Outline")
	toggle(main, "customColor", "Override All Category Colors")
	colorPicker(main, "custom")
	main:Tip("ON: use the adjacent color for every label. OFF: use colors in Categories.")

	local fading = tab:Section("Distance Fade", "Left")
	toggle(fading, "distanceFade", "Fade Distant Trinkets")
	fading:SliderInt("rte_fadeStart", "Start Fading (studs)", 0, 9999, config.fadeStart)
	fading:SliderInt("rte_fadeEnd", "Minimum Opacity At (studs)", 1, 10000, config.fadeEnd)
	fading:SliderInt("rte_fadeMinimum", "Minimum Opacity (%)", 0, 100, config.fadeMinimum)
	fading:Tip(
		"Measured from the camera. Opacity decreases gradually between the two distances; 0% hides distant labels. Multiplies the color picker's opacity and never changes identification."
	)
	fading:Tip("The end distance must exceed the start; invalid values are corrected automatically.")

	local filters = tab:Section("Categories", "Right")
	for i, key in ipairs(categories) do
		toggle(filters, key, categoryLabels[i])
		if not config.customColor then
			colorPicker(filters, key)
		end
	end
	if config.customColor then
		filters:Text("Category colors overridden. Change the color beside Override All Category Colors.")
	end
	filters:Tip("All replicated candidates are tracked. Up to 128 labels on screen; rare items have priority if full.")

	local range = tab:Section("Ignore Display Range", "Left")
	for i = 1, 5 do
		toggle(range, bypassKeys[categories[i]], categoryLabels[i])
	end
	range:Tip("Applies only to items already replicated to your client.")

	local status = tab:Section("Status", "Right")
	status:InputText("rte_status", "State", state.status)
	status:InputText("rte_counts", "Trinkets", "Waiting for scan")
	status:Button("Rescan Trinkets", function()
		state.cache = {}
		areasAt = 0
		state.refresh = true
	end)
	status:Button("Print Diagnostics", diagnostics)
	status:Button("Unload ESP", controller.Stop)
	status:Text("Made by Ryuu89")
	status:Text("Identification based on Hydroxide")
	if not state.uiReady then
		state.uiReady = true
		for key, value in pairs(config) do
			pcall(UI.SetValue, "rte_" .. key, value)
		end
	end
end

local function updateCache()
	local now = tick()
	if now >= state.uiAt then
		state.uiAt = now + 0.2
		syncUI()
	end
	if now - state.controlAt >= 0.1 then
		state.controlAt = now
		local valid = sessionValid()
		state.ready = valid and config.enabled and characterReady()
		if state.ready then
			local camera = Workspace.CurrentCamera
			local origin = read(camera, "Position") or read(read(camera, "CFrame"), "Position")
			state.origin = position(origin) and origin or nil
		else
			state.origin = nil
			hideAll()
			if not valid then
				state.status = "Session changed - run the script again"
			end
		end
	end
	if not state.ready then
		return
	end
	local list = state.targets
	local count = #list
	if count == 0 then
		return
	end
	local visited, reads = 0, 0
	while visited < count and reads < 8 do
		if state.positionCursor > count then
			state.positionCursor = 1
		end
		local target = list[state.positionCursor]
		state.positionCursor = state.positionCursor + 1
		visited = visited + 1
		if now - (target.positionAt or 0) >= 0.1 then
			reads = reads + 1
			local parentValid = target.alive
			if now >= (target.parentAt or 0) then
				target.parentAt = now + 0.25
				parentValid = read(target.object, "Parent") ~= nil
			end
			local p = parentValid and read(target.object, "Position") or nil
			target.positionAt = now
			target.alive = position(p) == true
			target.position = target.alive and p or nil
		end
	end
end

local frameTargets, selected = {}, {}
local function priority(a, b)
	local ra, rb = ranks[a.target.category], ranks[b.target.category]
	if ra ~= rb then
		return ra > rb
	end
	if a.distance ~= b.distance then
		return a.distance < b.distance
	end
	return a.target.address < b.target.address
end

local function labelOpacity(distance, styleKey)
	local factor = 1
	if config.distanceFade then
		local progress = math.clamp((distance - config.fadeStart) / (config.fadeEnd - config.fadeStart), 0, 1)
		factor = 1 - progress * (1 - config.fadeMinimum / 100)
		-- One-percent steps avoid redundant Drawing writes for subpixel distance changes.
		factor = math.floor(factor * 100 + 0.5) / 100
	end
	return palette[styleKey][4] * factor
end

local function render()
	if not state.running then
		return
	end
	local now = tick()
	local focused = type(isrbxactive) == "function" and isrbxactive()
	local pressed = state.key > 0 and type(iskeypressed) == "function" and iskeypressed(state.key)
	if pressed and not state.keyHeld and focused then
		config.enabled = not config.enabled
		state.refresh = true
		setUI("rte_enabled", config.enabled)
	end
	state.keyHeld = pressed
	if not config.enabled or not focused or not state.ready or now - state.controlAt > 0.75 or not state.origin then
		hideAll()
		return
	end
	local count = 0
	for _, target in ipairs(state.targets) do
		local p = target.position
		if config[target.category] and target.alive and p and now - target.positionAt <= 2 then
			local distance = (p - state.origin).Magnitude
			local bypass = bypassKeys[target.category]
			if
				finite(distance) and (not config.limitRange or distance < config.range or (bypass and config[bypass]))
			then
				local point, onScreen = WorldToScreen(p)
				if onScreen and finite(point.X) and finite(point.Y) then
					count = count + 1
					local entry = frameTargets[count] or {}
					frameTargets[count] = entry
					entry.target, entry.point, entry.distance = target, point, distance
				end
			end
		end
	end
	for i = #frameTargets, count + 1, -1 do
		frameTargets[i] = nil
	end
	if count > POOL_SIZE then
		table.sort(frameTargets, priority)
	end
	local visible = math.min(count, POOL_SIZE)
	table.clear(selected)
	for i = 1, visible do
		selected[frameTargets[i].target.address] = true
	end
	for _, slot in ipairs(state.pool) do
		if slot.owner and not selected[slot.owner] then
			state.slotsByAddress[slot.owner] = nil
			slot.owner = nil
			setVisible(slot, false)
		end
	end
	local freeIndex, drawn = 1, 0
	for i = 1, visible do
		local entry = frameTargets[i]
		local target = entry.target
		local slot = state.slotsByAddress[target.address]
		if not slot then
			while state.pool[freeIndex].owner do
				freeIndex = freeIndex + 1
			end
			slot = state.pool[freeIndex]
			slot.owner = target.address
			state.slotsByAddress[target.address] = slot
			freeIndex = freeIndex + 1
		end
		local label = slot.label
		if slot.address ~= target.address or now >= slot.textAt then
			local text = target.name
			if config.distance then
				text = text .. string.format("\n[%d]", math.floor(entry.distance))
			end
			if config.area and target.area then
				text = text .. " (" .. target.area .. ")"
			end
			if slot.text ~= text then
				label.Text, slot.text = text, text
			end
			slot.address, slot.textAt = target.address, now + 0.2
		end
		local styleKey = config.customColor and "custom" or target.category
		if slot.styleKey ~= styleKey or slot.colorRevision ~= state.colorRevision then
			label.Color = colors[styleKey]
			slot.styleKey, slot.colorRevision = styleKey, state.colorRevision
		end
		local opacity = labelOpacity(entry.distance, styleKey)
		if slot.opacity ~= opacity then
			label.Transparency, slot.opacity = opacity, opacity
		end
		if slot.category ~= target.category then
			label.ZIndex, slot.category = 10 + ranks[target.category], target.category
		end
		if slot.size ~= config.textSize then
			label.Size, slot.size = config.textSize, config.textSize
		end
		if slot.outline ~= config.outline then
			label.Outline, slot.outline = config.outline, config.outline
		end
		if slot.x ~= entry.point.X or slot.y ~= entry.point.Y then
			label.Position = entry.point
			slot.x, slot.y = entry.point.X, entry.point.Y
		end
		setVisible(slot, opacity > 0)
		if opacity > 0 then
			drawn = drawn + 1
		end
	end
	state.visible, state.onScreen = drawn, count
end

local ok, err = pcall(function()
	for i = 1, POOL_SIZE do
		local label = Drawing.new("Text")
		state.pool[i] = { label = label, textAt = 0, visible = false }
		label.Visible, label.Center, label.Outline = false, true, config.outline
		label.Font, label.Size, label.Transparency = 2, config.textSize, 1
	end
	if hasUI then
		UI.AddTab("Rogue ESP", drawUI)
	end
	state.connection = RunService.RenderStepped:Connect(function()
		local success, message = pcall(render)
		if not success then
			state.lastError = tostring(message)
			warn("[Rogue ESP] Stopped after a render error: " .. state.lastError)
			controller.Stop()
		end
	end)
	task.spawn(function()
		while state.running do
			local success, message = pcall(updateCache)
			if not success then
				state.lastError = tostring(message)
				warn("[Rogue ESP] Stopped after a cache error: " .. state.lastError)
				controller.Stop()
				return
			end
			task.wait(0.02)
		end
	end)
	task.spawn(function()
		local nextScan = 0
		while state.running do
			if state.refresh or tick() >= nextScan then
				state.refresh = false
				local success, message = pcall(collect)
				if not success then
					state.lastError = tostring(message)
					state.status = "Scan failed - see diagnostics"
					state.targets, state.cache = {}, {}
					hideAll()
					state.failures = state.failures + 1
					if state.failures >= 3 then
						warn("[Rogue ESP] Stopped after repeated scan errors: " .. state.lastError)
						controller.Stop()
					end
				else
					state.failures = 0
				end
				nextScan = tick() + 0.75
			end
			task.wait(0.1)
		end
	end)
end)
if not ok then
	controller.Stop()
	warn("[Rogue ESP] Startup failed: " .. tostring(err))
	return
end
print("[Rogue ESP] Loaded. Open Rogue ESP in Matcha. F6 toggles the overlay. Read-only: no input or game writes.")


