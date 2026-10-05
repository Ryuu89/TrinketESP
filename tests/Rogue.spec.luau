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
	local camera = world.object("Camera", "Camera", { Position = world.vector(0, 0, 0), ViewportSize={X=1920,Y=1200} })
	world.camera=camera
	world.workspace = world.object("Workspace", "Workspace", { CurrentCamera = camera })
	local root = world.object("Part", "HumanoidRootPart", { Position = world.vector(0, 0, 0) })
	local hum = world.object("Humanoid", "Humanoid", { Health = 100 })
	world.character = world.object("Model", "Tester", {}, { root, hum })
	world.player = world.object("Player", "Tester", { Character = world.character, UserId=1 })
	world.playerList = {world.player}
	world.players = { LocalPlayer = world.player, GetPlayers=function() return table.clone(world.playerList) end }
	world.collection={}
	world.storage=world.object("ReplicatedStorage","ReplicatedStorage")
	world.calls=0
	world.remote=world.object("RemoteFunction","ReturnToMenu",{InvokeServer=function()
		world.calls+=1
		if world.remoteDelay then coroutine.yield(world.remoteDelay) end
		if world.remoteThrows then error("Simulated transport error") end
		return true
	end})
	world.requests=world.object("Folder","Requests",{}, {world.remote})
	world.add(world.storage,world.requests)
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
					if name == "GuiService" then return {} end
					if name == "CollectionService" then return world.collection end
					if name == "ReplicatedStorage" then return world.storage end
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
	function section:SliderFloat(id, label, minimum, maximum, default)
		return self:SliderInt(id, label, minimum, maximum, default)
	end
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
		Vector2 = {new=function(x,y) return {X=x,Y=y} end},
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
				check(kind == "Text" or kind == "Square", "Only overlay Drawing objects")
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
				if world.spawnHook then world.spawnHook() end
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


local w=createWorld()
local bar=w.object("Frame","Mana",{AbsolutePosition={X=22,Y=434},AbsoluteSize={X=28,Y=298}})
local left=w.object("Frame","LeftContainer",{}, {bar})
local stat=w.object("ScreenGui","StatGui",{Enabled=true},{left})
local gui=w.object("PlayerGui","PlayerGui",{}, {stat})
w.add(w.player,gui)
w.add(w.player,w.object("Backpack","Backpack"))
w.add(w.character,w.object("Tool","Gate"))
w.item("MeshPart",{MeshId="rbxassetid://5196776695"})
w.run()
w.step(1)
check(w.globals.RogueOverlay~=nil,"Unified controller created")
check(w.globals.RogueOverlay.GetStatus().trinkets.identified==1,"Unified trinket identification preserved")
check(w.globals.RogueOverlay.GetStatus().mana.ranges=="Normal 75-83% | Snap 75-83%","Unified mana ranges preserved")
check(w.visible()==3,"Trinket label and both mana rectangles render")
check(w.values.rte_farArtifact and w.values.rte_farMythic,"Requested range defaults preserved")
check(w.values.rmo_enabled and w.values.rte_enabled,"Both sets of controls initialized")
check(w.values.rpx_enabled==false and w.values.rpx_preview==true and w.calls==0,"Proximity starts disabled in preview mode")
check(w.globals.RogueWorldESP ~= nil and w.values.rwe_ores == false and w.values.rwe_ingredients == false and w.values.rwe_npcs == false, "World resources start disabled")
check(w.globals.RogueTrinketESP.GetUnionAssetId(w.object("UnionOperation","Ingredient",{AssetId="rbxassetid://2620905234"})) == "2620905234", "Unified shared ingredient reader")
check(w.globals.RogueTrinketESP.GetUnionAssetId(w.object("Part","Wrong class",{AssetId="2620905234"})) == nil, "Shared reader rejects wrong class")
w.values.rpx_enabled=true
w.step(0.4)
check(w.globals.RogueOverlay.GetStatus().proximity.status=="Watching replicated players","Integrated proximity runs independently")
w.values.rpx_enabled=false
w.step(0.4)
check(w.buttons["Unload Script"]~=nil and w.buttons["Unload Mana Overlay"]==nil,"One unload control")
w.values.rte_enabled=false
w.step(0.4)
check(w.visible()==2,"Trinket toggle leaves mana running")
w.values.rmo_enabled=false
w.step(0.1)
check(w.visible()==0,"Mana toggle works in shared UI")
w.values.rte_enabled=true
w.values.rmo_enabled=true
w.step(1)
local old=w.globals.RogueOverlay
w.run()
w.step(1)
check(not old.running and w.visible()==3,"Rerun replaces both modules")
w.buttons["Unload Script"]()
w.step(0.3)
check(w.globals.RogueOverlay==nil and w.globals.RogueTrinketESP==nil and w.globals.RogueManaOverlay==nil and w.globals.RogueProximity==nil and w.globals.RogueWorldESP==nil,"Unified unload clears every controller")
check(w.visible()==0 and w.uiCallback==nil,"Unified unload removes all drawings and the tab")
check(w.writes==0,"Unified script never writes game properties")
print(string.format("PASS: %d integration assertions; no game or MCP.",passed))


