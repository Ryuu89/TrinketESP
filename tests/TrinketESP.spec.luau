local SOURCE = [====[@@SOURCE@@]====]
local passed = 0
local function check(condition, message)
	assert(condition, message)
	passed += 1
end

local function createWorld(place)
	local world = {
		now = 0,
		focused = true,
		down = {},
		tasks = {},
		connections = {},
		drawings = {},
		values = {},
		pickersThisFrame = {},
		buttons = {},
		logs = {},
		writes = 0,
		lookups = 0,
		renderReads = 0,
		visibilityWrites = 0,
		positionWrites = 0,
		opacityWrites = 0,
		inRender = false,
		cameraShift = 0,
		nextAddress = 0x100000,
		memory = {},
		memoryReads = 0,
		globals = {},
		data = {},
	}
	local vectorMeta = {}
	function vectorMeta.__index(v, k)
		if k == "Magnitude" then
			return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		end
	end
	function vectorMeta.__sub(a, b)
		return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z }, vectorMeta)
	end
	function world.vector(x, y, z)
		return setmetatable({ X = x, Y = y, Z = z }, vectorMeta)
	end
	function world.color(r, g, b)
		return { R = r / 255, G = g / 255, B = b / 255 }
	end
	function world.object(class, name, properties, children)
		world.nextAddress += 0x1000
		local data = properties or {}
		data.ClassName, data.Name, data.Address = class, name, world.nextAddress
		local object = {}
		data.children = children or {}
		world.data[object] = data
		local methods = {
			GetChildren = function()
				world.lookups += 1
				return table.clone(data.children)
			end,
			FindFirstChild = function(_, target)
				world.lookups += 1
				for _, child in ipairs(data.children) do
					if child.Name == target then
						return child
					end
				end
			end,
		}
		setmetatable(object, {
			__index = function(_, key)
				if world.inRender then world.renderReads += 1 end
				if methods[key] then
					return methods[key]
				end
				if data[key] ~= nil then
					return data[key]
				end
				for _, child in ipairs(data.children) do
					if child.Name == key then
						return child
					end
				end
			end,
			__newindex = function()
				world.writes += 1
				error("Unexpected game write")
			end,
		})
		for _, child in ipairs(data.children) do
			world.data[child].Parent = object
		end
		return object
	end
	function world.add(parent, child)
		table.insert(world.data[parent].children, child)
		world.data[child].Parent = parent
	end
	local camera = world.object("Camera", "Camera", { Position = world.vector(0, 0, 0) })
	world.workspace = world.object("Workspace", "Workspace", { CurrentCamera = camera })
	local root = world.object("Part", "HumanoidRootPart", { Position = world.vector(0, 0, 0) })
	local hum = world.object("Humanoid", "Humanoid", { Health = 100 })
	world.character = world.object("Model", "Tester", {}, { root, hum })
	world.player = world.object("Player", "Tester", { Character = world.character })
	world.players = { LocalPlayer = world.player }
	local service = { RenderStepped = {} }
	function service.RenderStepped:Connect(callback)
		local connection = { callback = callback, active = true }
		function connection:Disconnect()
			self.active = false
		end
		table.insert(world.connections, connection)
		return connection
	end
	local gameData = { GameId = 1087859240, PlaceId = place or 5208655184, JobId = "session-one" }
	world.gameData = gameData
	local game = setmetatable({}, {
		__index = function(_, key)
			if world.inRender then world.renderReads += 1 end
			if key == "GetService" then
				return function(_, name)
					if name == "Workspace" then
						return world.workspace
					end
					if name == "Players" then
						return world.players
					end
					if name == "RunService" then
						return service
					end
					error("Unexpected service: " .. name)
				end
			end
			return gameData[key]
		end,
		__newindex = function()
			world.writes += 1
			error("Game write")
		end,
	})
	local section = {}
	function section:Toggle(id, _, default, callback)
		if world.values[id] == nil then
			world.values[id] = default
		end
		return { callback = callback }
	end
	function section:SliderInt(id, _, _, _, default)
		if world.values[id] == nil then
			world.values[id] = default
		end
	end
	function section:InputText(id, _, default)
		if world.values[id] == nil then
			world.values[id] = default
		end
	end
	function section:ColorPicker(id, r, g, b, a, callback)
		if world.values[id] == nil then
			world.values[id] = { r, g, b, a }
		end
		world.colorCallbacks = world.colorCallbacks or {}
		world.colorCallbacks[id] = callback
		world.pickersThisFrame[id] = true
	end
	function section:Keybind()
		return {
			GetKey = function()
				return world.hotkey or 0x75
			end,
		}
	end
	function section:Button(name, callback)
		world.buttons[name] = callback
	end
	function section:Tip() end
	function section:Text() end
	local tab = {
		Section = function()
			return section
		end,
	}
	local ui = {
		AddTab = function(_, callback)
			world.uiCallback = callback
			callback(tab)
		end,
		RemoveTab = function()
			world.uiCallback = nil
		end,
		GetValue = function(id)
			return world.values[id]
		end,
		SetValue = function(id, value)
			world.values[id] = value
		end,
	}
	local function resume(entry)
		local ok, delay = coroutine.resume(entry.thread)
		assert(ok, delay)
		entry.at = world.now + (type(delay) == "number" and math.max(delay, 0.01) or 0.01)
	end
	local env = setmetatable({
		game = game,
		_G = world.globals,
		UI = ui,
		Color3 = { fromRGB = world.color },
		getrbxversion = function()
			return world.version
		end,
		memory_read = function(kind, address)
			world.memoryReads += 1
			return world.memory[kind .. ":" .. tostring(address)] or 0
		end,
		Enum = { MeshType = { Sphere = "Sphere" } },
		isrbxactive = function()
			return world.focused
		end,
		iskeypressed = function(key)
			return world.down[key] == true
		end,
		tick = function()
			return world.now
		end,
		print = function(...)
			table.insert(world.logs, table.concat({ ... }, " "))
		end,
		warn = function(...)
			table.insert(world.logs, table.concat({ ... }, " "))
		end,
		Drawing = {
			new = function(kind)
				check(kind == "Text", "Only text overlays should be created")
				local values = { removed = false }
				local drawing = setmetatable({}, {
					__index = values,
					__newindex = function(_, key, value)
						assert(key ~= "FontSize", "Live Matcha uses Text.Size, not FontSize")
						if key == "Visible" then world.visibilityWrites += 1 end
						if key == "Position" then world.positionWrites += 1 end
						if key == "Transparency" then world.opacityWrites += 1 end
						values[key] = value
					end,
				})
				function drawing:Remove()
					self.removed = true
					self.Visible = false
				end
				table.insert(world.drawings, drawing)
				return drawing
			end,
		},
		WorldToScreen = function(v)
			return { X = 960 + v.X + world.cameraShift, Y = 600 - v.Y }, v.Z >= 0 and math.abs(v.X) < 900
		end,
		task = {
			wait = function(delay)
				return coroutine.yield(delay or 0.01)
			end,
			spawn = function(callback)
				local entry = { thread = coroutine.create(callback), at = world.now }
				table.insert(world.tasks, entry)
				resume(entry)
			end,
		},
	}, { __index = getfenv(0) })
	function world.run()
		local fn = assert(loadstring(SOURCE, "TrinketESP.lua"))
		setfenv(fn, env)
		fn()
	end
	function world.step(seconds)
		for _ = 1, math.ceil(seconds / 0.05) do
			world.now += 0.05
			if world.uiCallback then
				world.pickersThisFrame = {}
				world.uiCallback(tab)
			end
			for _, entry in ipairs(world.tasks) do
				if coroutine.status(entry.thread) ~= "dead" and world.now >= entry.at then
					resume(entry)
				end
			end
			for _, connection in ipairs(world.connections) do
				if connection.active then
					world.inRender = true
					connection.callback(0.05)
					world.inRender = false
				end
			end
		end
	end
	function world.renderOnly(frames)
		for _ = 1, frames do
			world.now += 0.01
			for _, connection in ipairs(world.connections) do
				if connection.active then
					world.inRender = true
					connection.callback(0.01)
					world.inRender = false
				end
			end
		end
	end
	function world.item(class, properties, children)
		local list = children or {}
		table.insert(list, world.object("StringValue", "ID", { Value = "intentionally-not-used" }))
		properties = properties or {}
		properties.Position = properties.Position or world.vector(20, 5, 10)
		local item = world.object(class, "Part", properties, list)
		world.add(world.workspace, item)
		return item
	end
	function world.status()
		return world.globals.RogueTrinketESP.GetStatus()
	end
	function world.firstVisible()
		for _, drawing in ipairs(world.drawings) do
			if drawing.Visible and not drawing.removed then return drawing end
		end
		error("No visible test drawing")
	end
	function world.visible()
		local n = 0
		for _, drawing in ipairs(world.drawings) do
			if not drawing.removed and drawing.Visible then
				n += 1
			end
		end
		return n
	end
	return world
end

local defaults = createWorld()
defaults.run()
defaults.step(0.3)
for key, rgba in pairs({
 common={189/255,97/255,29/255,112/255}, rare={60/255,150/255,150/255,144/255},
 event={0,1,0,1}, artifact={96/255,1,0,1}, mythic={1,0,0,1}, unknown={0,0,0,133/255}
}) do
 for i,value in ipairs(rgba) do
  check(math.abs(defaults.values["rte_color_"..key][i]-value)<1e-9, "Requested default "..key.." channel "..i)
 end
end
check(defaults.values.rte_farArtifact and defaults.values.rte_farMythic, "Artifacts and mythics bypass range by default")
defaults.globals.RogueTrinketESP.Stop()

local w = createWorld()
local expectations = {}
local function expect(item, name, category)
	table.insert(expectations, { name = name, category = category })
	return item
end
for id, name in pairs({
	["5196782997"] = "Old Ring",
	["5196776695"] = "Ring",
	["5204003946"] = "Goblet",
	["5196577540"] = "Old Amulet",
	["5196551436"] = "Amulet",
	["5204453430"] = "Scroll",
}) do
	expect(w.item("MeshPart", { MeshId = "rbxassetid://" .. id }), name, name == "Scroll" and "rare" or "common")
end
for id, name in pairs({
	["2765613127"] = "Idol of the Forgotten",
	["15583017412"] = "Ornament",
	["15611175305"] = "Present",
	["4117970107"] = "Pumpkin Centerpiece",
	["17590006505"] = "Idol of War",
	["135210454467508"] = "Scary Mask",
}) do
	expect(
		w.item("UnionOperation", { AssetId = "rbxassetid://%20" .. id .. "%20" }),
		name,
		name == "Idol of the Forgotten" and "common" or "event"
	)
end
expect(
	w.item("Part", {}, {
		w.object("SpecialMesh", "Mesh", { MeshId = "", MeshType = "Sphere" }),
		w.object("ParticleEmitter", "ParticleEmitter"),
	}),
	"Opal",
	"common"
)
expect(
	w.item("Part", {}, { w.object("SpecialMesh", "Mesh"), w.object("ParticleEmitter", "OrbParticle") }),
	"???",
	"rare"
)
for _, entry in ipairs({
	{ "Diamond", 164, 187, 190, "rare" },
	{ "Ruby", 255, 0, 0, "rare" },
	{ "Emerald", 0, 255, 0, "rare" },
	{ "Sapphire", 0, 0, 255, "rare" },
	{ "Rift Gem", 230, 29, 248, "mythic" },
}) do
	expect(
		w.item("Part", { Color = w.color(entry[2], entry[3], entry[4]) }, {
			w.object("SpecialMesh", "Mesh", { MeshId = "rbxassetid://%202877143560%20" }),
			w.object("ParticleEmitter", "ParticleEmitter", { Color = "0 1 1 1 0 1 1 1 1 0" }),
		}),
		entry[1],
		entry[5]
	)
end
for _, entry in ipairs({
	{ "5197099782", "5197111525", "Amulet of the White King" },
	{ "5196963069", "5196975152", "Lannis Amulet" },
}) do
	expect(
		w.item("MeshPart", { MeshId = "rbxassetid://" .. entry[1] }, {
			w.object("MeshPart", "MeshPart", { MeshId = "rbxassetid://" .. entry[2] }),
		}),
		entry[3],
		"artifact"
	)
end
for _, entry in ipairs({
	{ 3, "0 1 1 1 0 1 1 1 1 0", "Mysterious Artifact", "mythic" },
	{ 5, "0 1 0.8 1 0 1 1 0.8 1 0", "Phoenix Down", "artifact" },
	{ 5, "0 1 1 1 0 1 1 1 1 0", "Azael Horn", "mythic" },
}) do
	expect(
		w.item("Part", {}, {
			w.object("Attachment", "Attachment", {}, {
				w.object("ParticleEmitter", "ParticleEmitter", { Rate = entry[1], Color = entry[2] }),
			}),
		}),
		entry[3],
		entry[4]
	)
end
expect(w.item("MeshPart", { MeshId = "rbxassetid://4103271893" }), "Candy", "event")
expect(w.item("MeshPart", { MeshId = "rbxassetid://%202520762076%20" }), "Howler Friend", "artifact")
expect(w.item("MeshPart", { BrickColor = { Name = "Black" } }), "Night Stone", "artifact")
expect(
	w.item("Part", {}, {
		w.object("ParticleEmitter", "OrbParticle", {
			Color = "0 0.105882 0.596078 0.596078 0 1 0.105882 0.596078 0.596078 0",
		}),
	}),
	"Ice Essence",
	"rare"
)
expect(w.item("MeshPart", { MeshId = "failed to fetch text" }), "Unclassified", "unknown")
expect(w.item("UnionOperation"), "Unclassified", "unknown")
expect(w.item("Part", {}, { w.object("ParticleEmitter", "ParticleEmitter") }), "Unclassified", "unknown")
expect(
	w.item("Part", { Color = { R = 176, G = 27, B = 185 } }, {
		w.object("SpecialMesh", "Mesh", { MeshId = "rbxassetid://2877143560" }),
		w.object("ParticleEmitter", "ParticleEmitter", { Color = "0 1 1 1 0 1 1 1 1 0" }),
	}),
	"Unclassified",
	"unknown"
)
local areas = w.object("Folder", "AreaMarkers", {}, {
	w.object("Part", "Oresfall", { Position = w.vector(10, 5, 10) }),
})
w.add(w.workspace, areas)
w.run()
w.step(1.5)
local status = w.status()
check(#status.items == #expectations, "All fixtures discovered")
for i, expected in ipairs(expectations) do
	check(
		status.items[i].name == expected.name,
		string.format("Fixture %d: expected %s, got %s", i, expected.name, status.items[i].name)
	)
	check(status.items[i].category == expected.category, "Category " .. expected.name)
end
check(w.visible() == #expectations, "All fixture labels visible")
for _, drawing in ipairs(w.drawings) do
	if drawing.Visible then
		check(
			type(drawing.Color) == "table" and type(drawing.Color.R) == "number",
			"Drawing receives Color3 components"
		)
		check(drawing.Outline == false, "Outline disabled by default")
		check(drawing.Transparency > 0 and drawing.Transparency <= 1, "Default text fill uses category opacity")
	end
end
w.values.rte_outline = true
w.step(0.3)
check(w.firstVisible().Outline == true, "Outline option applies to existing labels")
w.values.rte_outline = false
w.step(0.3)
check(w.firstVisible().Outline == false, "Outline can be disabled again")
check(w.firstVisible().Text:find("Oresfall", 1, true) ~= nil, "Area displayed")
w.values.rte_common = false
w.step(0.3)
check(w.visible() < #expectations, "UI category setting changes rendering")
w.values.rte_unknown = false
w.step(0.3)
local commonCount = 0
for _, item in ipairs(status.items) do
	if item.category == "common" then
		commonCount += 1
	end
end
check(w.visible() == status.identified - commonCount, "Unknown filter hides only unclassified items")
w.values.rte_area = false
w.values.rte_distance = false
w.values.rte_textSize = 20
w.step(0.6)
for _, drawing in ipairs(w.drawings) do
	if drawing.Visible then
		check(
			not drawing.Text:find("Oresfall", 1, true) and not drawing.Text:find("\n", 1, true) and drawing.Size == 20,
			"Label settings applied"
		)
	end
end
w.focused = false
w.down[0x75] = true
w.step(0.3)
check(w.visible() == 0 and w.values.rte_enabled, "Background hotkey does not toggle")
w.focused = true
w.step(0.2)
check(w.values.rte_enabled, "Held background key does not toggle on refocus")
w.down[0x75] = false
w.step(0.1)
w.down[0x75] = true
w.step(0.1)
check(not w.values.rte_enabled and w.visible() == 0, "Focused hotkey disables")
w.down[0x75] = false
w.values.rte_enabled = true
w.step(1)
check(w.visible() > 0, "UI reenables collector and rendering")
w.values.rte_customColor = true
w.values.rte_color_custom = { 0.2, 0.4, 0.6, 0.75 }
w.step(0.3)
for _, drawing in ipairs(w.drawings) do
	if drawing.Visible then
		check(
			math.abs(drawing.Color.R - 0.2) < 0.001
				and math.abs(drawing.Color.B - 0.6) < 0.001
				and drawing.Transparency == 0.75,
			"Custom color and opacity update existing labels"
		)
	end
end
check(not w.pickersThisFrame.rte_color_unknown, "Inactive category picker hidden in global color mode")
w.values.rte_color_unknown = { 0, 1, 0, 1 }
w.step(0.3)
check(math.abs(w.firstVisible().Color.R - 0.2) < 0.001, "Category changes cannot override the active global color")
local transparentLabel = w.firstVisible()
w.values.rte_color_custom = { 0.2, 0.4, 0.6, 0 }
w.step(0.3)
check(transparentLabel.Transparency == 0 and not transparentLabel.Visible, "Zero picker alpha hides fill and outline")
w.values.rte_color_custom = { 0.2, 0.4, 0.6, 1 }
w.step(0.3)
check(w.firstVisible().Transparency == 1, "Full picker alpha restores the text fill")
local callback = w.colorCallbacks.rte_color_custom
callback(w.color(255, 0, 0), 0.5)
w.values.rte_color_custom = nil
w.step(0.05)
for _, drawing in ipairs(w.drawings) do
	if drawing.Visible then
		check(
			drawing.Color.R == 1 and drawing.Color.G == 0 and drawing.Transparency == 0.5,
			"Color picker callback applies immediately"
		)
	end
end
w.values.rte_customColor = false
w.values.rte_unknown = true
w.values.rte_color_unknown = { r = 0, g = 1, b = 0, a = 1 }
w.step(0.3)
local unknownVisible = false
for _, drawing in ipairs(w.drawings) do
	if drawing.Visible and drawing.Text:find("Unclassified", 1, true) then
		unknownVisible = true
		check(
			drawing.Color.G == 1 and drawing.Color.R == 0 and drawing.Transparency == 1,
			"Category color restored after disabling custom color"
		)
	end
end
check(unknownVisible, "Unclassified labels included in color tests")
check(w.pickersThisFrame.rte_color_unknown, "Category picker visible in category mode")
w.buttons["Print Diagnostics"]()
check(table.concat(w.logs, "\n"):find("Drawing RGB", 1, true) ~= nil, "Diagnostics report RGB submitted to renderer")
w.values.rte_color_unknown = { r = 0 / 0, g = 1, b = 0, a = 1 }
w.step(0.3)
check(w.globals.RogueTrinketESP ~= nil, "Invalid color does not stop the ESP")
local before = #w.drawings
w.run()
w.step(1)
local active = 0
for _, connection in ipairs(w.connections) do
	if connection.active then
		active += 1
	end
end
check(active == 1, "Rerun disconnects previous renderer")
for i = 1, before do
	check(w.drawings[i].removed, "Rerun removes old drawing")
end
check(#w.drawings == before + 128, "Fixed-size drawing pool")
check(w.writes == 0, "No game object writes")
w.globals.RogueTrinketESP.Stop()
w.step(1)
check(w.visible() == 0 and w.globals.RogueTrinketESP == nil, "Unload clears overlay and controller")
for _, entry in ipairs(w.tasks) do
	check(coroutine.status(entry.thread) == "dead", "Unload ends collector")
end

local menu = createWorld()
menu.data[menu.player].Character = nil
menu.item("MeshPart", { MeshId = "rbxassetid://5196776695" })
menu.run()
menu.step(1)
check(menu.status().status == "Waiting for character" and menu.visible() == 0, "No menu overlay")
menu.data[menu.player].Character = menu.character
menu.step(1)
check(menu.visible() == 1, "Spawn automatically starts ESP")
menu.gameData.JobId = "session-two"
menu.step(1)
check(menu.visible() == 0, "Session change hides stale targets")

local limits = createWorld()
for i = 1, 140 do
	limits.item("MeshPart", { MeshId = "rbxassetid://5196776695", Position = limits.vector(i, 0, 10) })
end
limits.run()
limits.step(2)
check(limits.visible() == 128 and #limits.drawings == 128, "More targets do not grow the pool")
limits.values.rte_limitRange = true
limits.values.rte_range = 25
limits.step(0.4)
check(limits.visible() < 25, "Display range enforced")
limits.values.rte_farCommon = true
limits.step(0.4)
check(limits.visible() == 128, "Category-specific range override works")
for _, item in ipairs(limits.data[limits.workspace].children) do
	limits.data[item].Position = limits.vector(0, 0, -10)
end
limits.step(1)
check(limits.visible() == 0, "Behind-camera items hidden after bounded cache refresh")
limits.data[limits.workspace].children = {}
limits.step(1)
check(limits.status().candidates == 0, "Removed objects leave the cache")

local khei = createWorld(3541987450)
khei.item("MeshPart", { MeshId = "rbxassetid://4027112893" }, { khei.object("Part", "Part") })
khei.item("Part", {}, {
	khei.object("Attachment", "Attachment", {}, {
		khei.object("ParticleEmitter", "ParticleEmitter", { Rate = 5, Color = "0 1 1 1 0 1 1 1 1 0" }),
	}),
})
khei.run()
khei.step(1)
check(khei.status().items[1].name == "Bound Book", "Khei Bound Book")
check(khei.status().items[2].name == "Phoenix Flower", "Khei Phoenix Flower")
local other = createWorld(1234)
other.run()
check(#other.drawings == 0 and other.globals.RogueTrinketESP == nil, "Wrong game creates no overlay")

local rawWorld = createWorld()
rawWorld.version = "version-e7d81637d42c4b23"
local function put(kind, address, value)
	rawWorld.memory[kind .. ":" .. tostring(address)] = value
end
local function readable(object)
	put("uintptr_t", object.Address, 0x700000)
end
local nextData = 0x800000
local function content(object, offset, text)
	readable(object)
	local field = object.Address + offset
	nextData += 0x1000
	put("uintptr_t", field, nextData)
	put("uintptr_t", field + 16, #text)
	put("uintptr_t", field + 24, #text == 0 and 15 or 255)
	put("string", nextData, text)
end
local ring = rawWorld.item("MeshPart", { MeshId = "failed to fetch text" })
content(ring, 0x310, "rbxassetid://5196782997")
local idol = rawWorld.item("UnionOperation")
content(idol, 0x310, "https://www.roblox.com//asset/?id=2765613127")
local opalMesh = rawWorld.object("SpecialMesh", "Mesh")
content(opalMesh, 0xF8, "")
put("int", opalMesh.Address + 0x148, 3)
rawWorld.item("Part", {}, { opalMesh, rawWorld.object("ParticleEmitter", "ParticleEmitter") })
local rubyMesh = rawWorld.object("SpecialMesh", "Mesh")
content(rubyMesh, 0xF8, "rbxassetid://%202877143560%20")
local particles = rawWorld.object("ParticleEmitter", "ParticleEmitter")
readable(particles)
put("uintptr_t", particles.Address + 0x178, 0x900000)
put("int", particles.Address + 0x180, 2)
put("int", particles.Address + 0x184, 2)
for i, value in ipairs({ 0, 1, 1, 1, 0, 1, 1, 1, 1, 0 }) do
	put("float", 0x900000 + (i - 1) * 4, value)
end
local ruby = rawWorld.item("Part", { Color = rawWorld.color(0, 0, 0) }, { rubyMesh, particles })
readable(ruby)
put("byte", ruby.Address + 0x1A8, 255)
put("byte", ruby.Address + 0x1A9, 0)
put("byte", ruby.Address + 0x1AA, 0)
rawWorld.run()
rawWorld.step(1)
local recovered = rawWorld.status()
for i, name in ipairs({ "Old Ring", "Idol of the Forgotten", "Opal", "Ruby" }) do
	check(recovered.items[i].name == name, "Raw property recovery: " .. name)
end
check(recovered.memoryReader and recovered.memoryHits > 0, "Memory reader status reports recovered properties")
check(rawWorld.writes == 0, "Memory fallback performs no game writes")
put("uintptr_t", ring.Address + 0x320, 999999)
put("uintptr_t", idol.Address + 0x310, 7)
put("int", opalMesh.Address + 0x148, 5)
put("int", particles.Address + 0x180, 999)
rawWorld.buttons["Rescan Trinkets"]()
rawWorld.step(1)
check(rawWorld.status().identified == 0, "Malformed strings, pointers, sphere type and sequence fail closed")
content(ring, 0x310, "rbxassetid://5196782997")
put("uintptr_t", ring.Address, 0)
rawWorld.buttons["Rescan Trinkets"]()
rawWorld.step(1)
check(rawWorld.status().items[1].name == "Unclassified", "Unreadable object header blocks stale raw reads")
rawWorld.globals.RogueTrinketESP.Stop()

local shiftedBuild = createWorld()
shiftedBuild.version = "version-02c37bc51a384b8f"
local function shiftedPut(kind, address, value)
	shiftedBuild.memory[kind .. ":" .. tostring(address)] = value
end
local shiftedRing = shiftedBuild.item("MeshPart", { MeshId = "failed to fetch text" })
shiftedPut("uintptr_t", shiftedRing.Address, 0x700000)
shiftedPut("uintptr_t", shiftedRing.Address + 0x300, 0x880000)
shiftedPut("uintptr_t", shiftedRing.Address + 0x310, 23)
shiftedPut("uintptr_t", shiftedRing.Address + 0x318, 255)
shiftedPut("string", 0x880000, "rbxassetid://5196782997")
local shiftedRuby = shiftedBuild.item("Part", { Color = shiftedBuild.color(0, 0, 0) })
shiftedPut("uintptr_t", shiftedRuby.Address, 0x700000)
shiftedPut("byte", shiftedRuby.Address + 0x198, 255)
shiftedBuild.run()
shiftedBuild.step(1)
check(shiftedBuild.status().memoryReader, "Shifted build enables the memory reader")
check(shiftedBuild.status().items[1].name == "Old Ring", "Shifted build reads MeshId 0x10 earlier")
shiftedBuild.globals.RogueTrinketESP.Stop()

local unknownBuild = createWorld()
unknownBuild.version = "version-unvalidated"
unknownBuild.item("MeshPart", { MeshId = "failed to fetch text" })
unknownBuild.run()
unknownBuild.step(1)
check(
	unknownBuild.memoryReads == 0 and not unknownBuild.status().memoryReader,
	"Unknown Roblox build never reads offsets"
)
check(unknownBuild.status().items[1].name == "Unclassified", "Unknown build does not guess item names")

local artifactWorld = createWorld()
artifactWorld.version = "version-e7d81637d42c4b23"
local function artifactMemory(kind, address, value)
	artifactWorld.memory[kind .. ":" .. tostring(address)] = value
end
local emitters = {}
for index, entry in ipairs({
	{ "Phoenix Down", 5, 0.8 },
	{ "Azael Horn", 5, 1 },
	{ "Mysterious Artifact", 3, 1 },
}) do
	local emitter = artifactWorld.object("ParticleEmitter", "ParticleEmitter")
	emitters[index] = emitter
	local attachment = artifactWorld.object("Attachment", "Attachment", {}, { emitter })
	artifactWorld.item("Part", {}, { attachment })
	artifactMemory("uintptr_t", emitter.Address, 0x700000)
	artifactMemory("float", emitter.Address + 0x248, entry[2])
	local data = 0xA00000 + index * 0x1000
	artifactMemory("uintptr_t", emitter.Address + 0x178, data)
	artifactMemory("int", emitter.Address + 0x180, 2)
	artifactMemory("int", emitter.Address + 0x184, 2)
	for i, component in ipairs({ 0, 1, entry[3], 0, 0, 1, 1, 0.5, 0, 0 }) do
		artifactMemory("float", data + (i - 1) * 4, component)
	end
end
artifactWorld.run()
artifactWorld.step(1)
for i, name in ipairs({ "Phoenix Down", "Azael Horn", "Mysterious Artifact" }) do
	check(artifactWorld.status().items[i].name == name, "Raw particle rate and colors identify " .. name)
end
artifactMemory("float", emitters[1].Address + 0x248, 0 / 0)
artifactMemory("int", emitters[2].Address + 0x180, 999)
artifactWorld.buttons["Rescan Trinkets"]()
artifactWorld.step(1)
check(artifactWorld.status().items[1].name == "Unclassified", "Invalid particle rate never identifies Phoenix Down")
check(artifactWorld.status().items[2].name == "Unclassified", "Rate 5 without valid color never identifies a horn")
check(
	artifactWorld.status().items[1].reason == "Attachment particle rate unavailable",
	"Missing rate has actionable diagnostics"
)
check(
	artifactWorld.status().items[2].reason == "Attachment particle color unavailable",
	"Missing color has actionable diagnostics"
)
artifactWorld.globals.RogueTrinketESP.Stop()
artifactWorld.gameData.PlaceId = 3541987450
artifactMemory("float", emitters[1].Address + 0x248, 5)
artifactMemory("int", emitters[2].Address + 0x180, 2)
artifactWorld.run()
artifactWorld.step(1)
check(artifactWorld.status().items[1].name == "Phoenix Down", "Phoenix Down stays Phoenix Down in Khei")
check(artifactWorld.status().items[2].name == "Phoenix Flower", "Khei artifact uses Phoenix Flower rule")
check(artifactWorld.writes == 0, "Artifact recovery remains read-only")
artifactWorld.globals.RogueTrinketESP.Stop()

local pairedWorld = createWorld()
for _, order in ipairs({ true, false }) do
	local matching = pairedWorld.object("MeshPart", "MeshPart", { MeshId = "rbxassetid://5197111525" })
	local other = pairedWorld.object("MeshPart", "MeshPart", { MeshId = "rbxassetid://999" })
	pairedWorld.item(
		"MeshPart",
		{ MeshId = "rbxassetid://5197099782" },
		order and { matching, other } or { other, matching }
	)
end
pairedWorld.run()
pairedWorld.step(1)
check(pairedWorld.status().identified == 2, "Paired amulet recognition is independent of duplicate child-name order")
pairedWorld.globals.RogueTrinketESP.Stop()


local perf = createWorld()
local first = perf.item("MeshPart", {MeshId="rbxassetid://5196776695",Position=perf.vector(20,0,20)})
local second = perf.item("MeshPart", {MeshId="rbxassetid://5204003946",Position=perf.vector(200,0,20)})
perf.run()
perf.step(1)
local originalLabel
for _,d in ipairs(perf.drawings) do
	if d.Visible and d.Text:sub(1,4) == "Ring" then originalLabel=d end
end
check(originalLabel ~= nil, "Performance fixture rendered")
local x = originalLabel.Position.X
perf.renderReads = 0
local visibleWrites = perf.visibilityWrites
perf.cameraShift = 30
perf.renderOnly(10)
check(originalLabel.Position.X == x + 30, "Camera projection updates without waiting for object cache")
check(perf.renderReads == 0, "Renderer performs no Instance property or tree reads")
check(perf.visibilityWrites == visibleWrites, "Unchanged visibility is not rewritten per frame")
local positionWrites = perf.positionWrites
perf.renderOnly(10)
check(perf.positionWrites == positionWrites, "Stationary screen positions are not rewritten")
perf.data[first].Position = perf.vector(300,0,20)
perf.data[second].Position = perf.vector(10,0,20)
perf.step(0.6)
check(originalLabel.Text:sub(1,4) == "Ring", "Same item keeps its label after distance order changes")
local farItem = perf.item("MeshPart",{MeshId="rbxassetid://5204453430",Position=perf.vector(20,0,5000)})
perf.step(1.5)
check(perf.status().candidates == 3 and perf.visible() == 3, "New distant replicated item discovered with unlimited display range")
perf.values.rte_limitRange = true
perf.values.rte_range = 1000
perf.step(0.4)
check(perf.visible() == 2 and perf.status().candidates == 3, "Range filters display, not detection")
perf.values.rte_limitRange = false
perf.step(0.4)
check(perf.visible() == 3, "Unlimited range restores distant replicated labels")
perf.data[farItem].Parent = nil
perf.step(0.4)
check(perf.visible() == 2, "Removed item hidden by cache before discovery rescan")
perf.globals.RogueTrinketESP.Stop()
perf.step(1)
check(perf.visible() == 0 and perf.writes == 0, "Both worker loops stop without game writes")


local fade = createWorld()
local fadeItem = fade.item("MeshPart", {MeshId="rbxassetid://5196776695", Position=fade.vector(0,0,200)})
fade.run()
fade.step(1)
fade.values.rte_color_common = {189/255,97/255,29/255,1}
fade.step(0.3)
local fadeLabel = fade.firstVisible()
check(fadeLabel.Transparency == 1, "Fade is opt-in; existing appearance unchanged")
fade.values.rte_distanceFade = true
fade.values.rte_fadeStart = 100
fade.values.rte_fadeEnd = 300
fade.values.rte_fadeMinimum = 20
fade.step(0.4)
check(math.abs(fadeLabel.Transparency - 0.6) < 1e-9, "Midpoint has interpolated opacity")
local baseColor = fadeLabel.Color
fade.data[fadeItem].Position = fade.vector(0,0,100)
fade.step(0.4)
check(fadeLabel.Transparency == 1, "Start boundary retains base opacity")
fade.data[fadeItem].Position = fade.vector(0,0,400)
fade.step(0.4)
check(fadeLabel.Transparency == 0.2, "Beyond end clamps at minimum opacity")
check(fadeLabel.Color == baseColor, "Fade preserves category RGB")
fade.values.rte_customColor = true
fade.values.rte_color_custom = {0.2,0.4,0.6,0.5}
fade.step(0.4)
check(fadeLabel.Transparency == 0.1 and fadeLabel.Color.R == 0.2, "Fade multiplies global picker alpha")
fade.values.rte_fadeMinimum = 50
fade.step(0.4)
check(fadeLabel.Transparency == 0.25, "UI minimum updates existing labels")
local opacityWrites = fade.opacityWrites
fade.renderReads = 0
fade.renderOnly(10)
check(fade.opacityWrites == opacityWrites, "Stationary fade does not rewrite opacity")
check(fade.renderReads == 0, "Fade adds no Instance reads to renderer")
fade.values.rte_fadeStart = 500
fade.values.rte_fadeEnd = 100
fade.step(0.4)
check(fade.values.rte_fadeEnd == 501 and fadeLabel.Transparency == 0.5, "Reversed bounds corrected in UI")
fade.values.rte_fadeStart = 100
fade.values.rte_fadeEnd = 100
fade.step(0.4)
check(fade.values.rte_fadeEnd == 101 and fadeLabel.Transparency == 0.25, "Equal bounds cannot divide by zero")
fade.values.rte_fadeMinimum = 0
fade.values.rte_outline = true
fade.step(0.4)
check(not fadeLabel.Visible and fade.status().visible == 0, "Zero fade hides entire Drawing including outline")
check(fade.status().identified == 1, "Invisible fade does not remove identification")
fade.values.rte_distanceFade = false
fade.step(0.4)
check(fadeLabel.Visible and fadeLabel.Transparency == 0.5, "Disabling fade restores picker opacity")
fade.values.rte_distanceFade = true
fade.values.rte_fadeStart = 0/0
fade.values.rte_fadeEnd = math.huge
fade.values.rte_fadeMinimum = -50
fade.step(0.4)
check(fadeLabel.Transparency == 0, "Invalid nonfinite settings ignored; minimum clamped")
fade.values.rte_fadeMinimum = 500
fade.step(0.4)
check(fadeLabel.Transparency == 0.5, "Out-of-range minimum clamps to 100 percent")
fade.globals.RogueTrinketESP.Stop()
fade.step(0.4)
check(fade.writes == 0 and fade.visible() == 0, "Fade cleanup leaves game untouched")

print(string.format("PASS: %d assertions; no Roblox process or MCP used.", passed))
