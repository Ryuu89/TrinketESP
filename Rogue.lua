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

local function startTrinkets(host)
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
		-- The host owns the shared tab.
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
	status:Button("Unload Script", host.Stop)
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
		host.trinketUI = drawUI
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
return controller



end

local function startMana(host)
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
		-- The host owns the shared tab.
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
	local status = tab:Section("Mana Status", "Right")
	status:InputText("rmo_status", "State", state.status)
	status:InputText("rmo_ranges", "Mana Ranges", state.ranges)
	status:Button("Refresh Mana Overlay", function()
		state.refreshAt = 0
	end)
	status:Tip("Unload Script in the Trinket status section stops both overlays.")
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
		host.manaUI = drawUI
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
return controller

end

local function startProximity(host)
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
		-- The host owns the shared tab.
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
	status:Tip("Unload Script stops all modules.")
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
		host.proximityUI = drawUI
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
return controller

end

local function startWorld(host)
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
		-- The host owns the shared tab.
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
	style:Tip("Unload Script stops all modules.")
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
		host.worldUI = drawUI
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
return controller

end

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
