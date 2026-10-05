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
				if world.inRender then
					world.renderReads += 1
				end
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
	local camera =
		world.object("Camera", "Camera", { Position = world.vector(0, 0, 0), ViewportSize = { X = 1920, Y = 1200 } })
	world.camera = camera
	world.workspace = world.object("Workspace", "Workspace", { CurrentCamera = camera })
	local root = world.object("Part", "HumanoidRootPart", { Position = world.vector(0, 0, 0) })
	local hum = world.object("Humanoid", "Humanoid", { Health = 100 })
	world.character = world.object("Model", "Tester", {}, { root, hum })
	world.player = world.object("Player", "Tester", { Character = world.character, UserId = 1 })
	world.playerList = { world.player }
	world.players = {
		LocalPlayer = world.player,
		GetPlayers = function()
			return table.clone(world.playerList)
		end,
	}
	world.collection = {}
	world.storage = world.object("ReplicatedStorage", "ReplicatedStorage")
	world.calls = 0
	world.remote = world.object("RemoteFunction", "ReturnToMenu", {
		InvokeServer = function()
			world.calls += 1
			if world.remoteDelay then
				coroutine.yield(world.remoteDelay)
			end
			if world.remoteThrows then
				error("Simulated transport error")
			end
			return true
		end,
	})
	world.requests = world.object("Folder", "Requests", {}, { world.remote })
	world.add(world.storage, world.requests)
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
			if world.inRender then
				world.renderReads += 1
			end
			if key == "GetService" then
				return function(_, name)
					if name == "GuiService" then
						return {}
					end
					if name == "CollectionService" then
						return world.collection
					end
					if name == "ReplicatedStorage" then
						return world.storage
					end
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
		getscripthash = function(client)
			world.hashReads = (world.hashReads or 0) + 1
			if world.hashThrows then
				error("Hash unavailable")
			end
			return world.scriptHash
		end,
		_G = world.globals,
		UI = ui,
		Color3 = { fromRGB = world.color },
		Vector2 = {
			new = function(x, y)
				return { X = x, Y = y }
			end,
		},
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
						if key == "Visible" then
							world.visibilityWrites += 1
						end
						if key == "Position" then
							world.positionWrites += 1
						end
						if key == "Transparency" then
							world.opacityWrites += 1
						end
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
				if world.spawnHook then
					world.spawnHook()
				end
				resume(entry)
			end,
		},
	}, { __index = getfenv(0) })
	function world.run()
		local fn = assert(loadstring(SOURCE, "Proximity.lua"))
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
		return world.globals.RogueProximity.GetStatus()
	end
	function world.firstVisible()
		for _, drawing in ipairs(world.drawings) do
			if drawing.Visible and not drawing.removed then
				return drawing
			end
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

local function fixture()
	local w = createWorld()
	local root = w.object("Part", "HumanoidRootPart", { Position = w.vector(20, 0, 0) })
	local hum = w.object("Humanoid", "Humanoid", { Health = 100 })
	local char = w.object("Model", "Neighbor", {}, { root, hum })
	local other = w.object("Player", "Neighbor", { UserId = 2, Character = char })
	table.insert(w.playerList, other)
	w.other, w.otherRoot, w.otherChar, w.otherHum = other, root, char, hum
	return w
end
local function arm(w, preview)
	w.values.rpx_enabled = true
	w.values.rpx_autoMenu = true
	w.values.rpx_preview = preview
end
local function stop(w)
	w.globals.RogueProximity.Stop()
	w.step(0.3)
	check(w.visible() == 0 and w.uiCallback == nil, "Stop removes label and UI")
	check(w.writes == 0, "No game-property writes")
end

local w = fixture()
w.run()
w.step(0.5)
check(not w.status().enabled and w.values.rpx_preview and w.calls == 0 and w.visible() == 0, "Defaults never act")
local observation = w.globals.RogueProximity.Preview()
check(
	observation.target.id == 2 and observation.danger == "Unknown" and w.calls == 0,
	"Read-only preview observes target without side effects"
)
w.values.rpx_enabled = true
w.step(0.4)
check(w.visible() == 1 and w.status().status == "Nearby player - alert only", "Alert operates without tag support")
check(w.drawings[1].Position.X == 960 and w.drawings[1].Position.Y == 144, "Alert uses current viewport")
w.data[w.camera].ViewportSize = { X = 800, Y = 600 }
w.step(0.3)
check(w.drawings[1].Position.X == 400 and w.drawings[1].Position.Y == 72, "Alert follows window resize")
w.values.rpx_distance = 10
w.step(0.3)
check(w.visible() == 0 and w.status().nearest == "None in range", "Distance setting changes actual detection")
w.values.rpx_distance = 100
arm(w, false)
w.step(2)
check(
	w.calls == 0 and w.status().status == "Blocked - Danger state unavailable",
	"Missing HasTag blocks real auto menu"
)
w.collection.HasTag = function()
	return nil
end
w.step(1.5)
check(w.calls == 0, "Non-boolean tag result stays unknown")
w.collection.HasTag = function()
	error("unreadable")
end
w.step(1.5)
check(w.calls == 0, "Tag read errors block auto menu")
w.collection.HasTag = function()
	return true
end
w.step(1.5)
check(w.calls == 0 and w.status().status == "Blocked - Danger active", "Danger blocks request")
w.collection.HasTag = function()
	return false
end
local danger = w.object("Folder", "Danger")
w.add(w.character, danger)
w.step(1.5)
check(w.calls == 0 and w.status().danger == "Danger", "Positive Danger child overrides a clear tag read")
table.remove(w.data[w.character].children)
w.data[danger].Parent = nil
w.values.rpx_preview = true
w.step(1.8)
check(
	w.calls == 0 and w.status().status == "Preview - would request menu; nothing sent",
	"Preview never calls a supported remote"
)
w.values.rpx_preview = false
w.step(0.3)
check(w.calls == 0, "Switching out of preview restarts the confirmation period")
w.step(1.6)
check(w.calls == 1 and w.status().attempted, "Clear and stable conditions call the menu remote once")
check(
	w.status().status == "Request returned - menu transition not confirmed",
	"Transport return is not reported as successful teleport"
)
w.step(4)
check(w.calls == 1, "No repeated requests while a player stays near")
w.values.rpx_enabled = false
w.step(0.3)
w.values.rpx_enabled = true
w.step(0.3)
check(
	w.calls == 1 and w.status().status == "Request returned - menu transition not confirmed",
	"Disable/re-enable preserves the request result without retrying"
)
w.buttons["Re-arm Auto Menu"]()
w.step(1.8)
check(w.calls == 2, "Manual re-arm permits one new attempt")
stop(w)

local away = fixture()
away.collection.HasTag = function()
	return false
end
away.run()
arm(away, false)
away.step(0.3)
away.data[away.otherRoot].Position = away.vector(500, 0, 0)
away.step(1.5)
check(away.calls == 0 and away.visible() == 0, "Leaving radius cancels confirmation")
away.data[away.otherRoot].Position = away.vector(20, 0, 0)
away.step(0.3)
away.focused = false
away.step(1.5)
check(away.calls == 0 and away.visible() == 0, "Loss of focus cancels confirmation")
away.focused = true
away.step(0.3)
away.values.rpx_enabled = false
away.step(1.5)
check(away.calls == 0, "Disabling monitor cancels confirmation")
stop(away)

local dead = fixture()
dead.collection.HasTag = function()
	return false
end
dead.run()
arm(dead, false)
dead.step(0.3)
dead.data[dead.character.Humanoid].Health = 0
dead.step(1.5)
check(dead.calls == 0 and dead.visible() == 0, "Local death suppresses automation and alert")
dead.data[dead.character.Humanoid].Health = 100
dead.data[dead.otherHum].Health = 0
dead.step(1.5)
check(dead.calls == 0, "Dead target is not a proximity trigger")
dead.data[dead.otherHum].Health = 100
dead.data[dead.otherRoot].Position = dead.vector(0 / 0, 0, 0)
dead.step(1.5)
check(dead.calls == 0, "Invalid positions cannot trigger remote")
stop(dead)

local changed = fixture()
changed.collection.HasTag = function()
	return false
end
changed.run()
arm(changed, false)
changed.step(0.7)
local newRoot = changed.object("Part", "HumanoidRootPart", { Position = changed.vector(20, 0, 0) })
local newHum = changed.object("Humanoid", "Humanoid", { Health = 100 })
changed.data[changed.other].Character = changed.object("Model", "Neighbor", {}, { newRoot, newHum })
changed.step(0.7)
check(changed.calls == 0, "Target respawn restarts confirmation")
changed.values.rpx_holdMs = 5000
changed.step(1)
check(changed.calls == 0, "Confirmation setting invalidates an existing hold")
changed.gameData.JobId = "new-session"
changed.step(0.4)
check(
	changed.globals.RogueProximity == nil and changed.calls == 0 and changed.visible() == 0,
	"Session change stops module"
)
check(changed.writes == 0, "Session handling never writes properties")

local failure = fixture()
failure.collection.HasTag = function()
	return false
end
failure.remoteThrows = true
failure.run()
arm(failure, false)
failure.step(2)
check(
	failure.calls == 1 and failure.status().status == "Request failed - check Hybrid Mode; no retry",
	"Transport failure is reported"
)
failure.step(10)
check(failure.calls == 1, "Failure has no automatic retry")
stop(failure)

local pending = fixture()
pending.collection.HasTag = function()
	return false
end
pending.remoteDelay = 5
pending.run()
arm(pending, false)
pending.step(2)
check(pending.calls == 1 and pending.status().inFlight, "Yielding InvokeServer is marked in flight")
pending.buttons["Re-arm Auto Menu"]()
pending.step(1)
check(pending.calls == 1, "Re-arm cannot overlap an in-flight request")
pending.globals.RogueProximity.Stop()
pending.step(8)
check(pending.calls == 1 and pending.visible() == 0 and pending.writes == 0, "Unload does not retry a pending request")

local cancelled = fixture()
cancelled.collection.HasTag = function()
	return false
end
cancelled.run()
arm(cancelled, false)
cancelled.spawnHook = function()
	cancelled.focused = false
end
cancelled.step(2)
check(cancelled.calls == 0, "Fresh focus check cancels immediately before dispatch")
stop(cancelled)

local stale = fixture()
stale.collection.HasTag = function()
	return false
end
stale.run()
arm(stale, false)
stale.spawnHook = function()
	stale.data[stale.otherRoot].Position = stale.vector(500, 0, 0)
end
stale.step(2)
check(stale.calls == 0, "Fresh geometry check cancels immediately before dispatch")
stop(stale)

local missing = fixture()
missing.collection.HasTag = function()
	return false
end
missing.data[missing.remote].ClassName = "Folder"
missing.run()
arm(missing, false)
missing.step(2)
check(
	missing.calls == 0 and missing.status().status == "Blocked - ReturnToMenu unavailable; re-arm manually",
	"Remote class must match"
)
stop(missing)

local repeatRun = fixture()
repeatRun.run()
repeatRun.values.rpx_enabled = true
repeatRun.step(0.4)
local old = repeatRun.globals.RogueProximity
repeatRun.run()
repeatRun.step(0.5)
check(not old.GetStatus().running and repeatRun.visible() == 0, "Rerun unloads old label and resets to disabled")
check(repeatRun.values.rpx_preview and repeatRun.calls == 0, "Rerun defaults to preview without calls")
stop(repeatRun)
local wrong = createWorld(1)
wrong.run()
check(wrong.globals.RogueProximity == nil and #wrong.drawings == 0, "Other games are rejected")

local function dangerHUD(w, text)
	local label = w.object("TextLabel", "TextLabel", { Text = text or "Safe" })
	local client = w.object("LocalScript", "DangerClient")
	local panel = w.object("ScreenGui", "DangerGui", {}, { label, client })
	local gui = w.object("PlayerGui", "PlayerGui", {}, { panel })
	w.add(w.player, gui)
	w.scriptHash = "15563268767215079424"
	w.hudLabel, w.hudClient, w.hudPanel, w.playerGui = label, client, panel, gui
	return label
end
local dangerText = "IN DANGER\nYour life is at risk!"
local mortalText = "MORTAL DANGER\nDeath is at your heels!"
local fallback = fixture()
local label = dangerHUD(fallback)
fallback.run()
arm(fallback, false)
fallback.step(4)
check(fallback.calls == 0 and fallback.status().danger == "Unknown", "Template Safe is not proof of an initialized HUD")
check(
	fallback.status().dangerSource == "Waiting for a live Danger-to-Safe transition",
	"UI explains HUD initialization guard"
)
fallback.data[label].Text = dangerText
fallback.step(0.4)
check(fallback.status().danger == "Danger" and fallback.calls == 0, "Verified Danger HUD blocks without HasTag")
fallback.data[label].Text = "Safe"
fallback.step(1.8)
check(fallback.calls == 0 and fallback.status().danger == "Unknown", "HUD clear requires two full seconds")
fallback.step(0.8)
check(
	fallback.calls == 0 and fallback.status().danger == "Clear",
	"Proximity hold starts only after HUD clear confirmation: "
		.. tostring(fallback.calls)
		.. "/"
		.. tostring(fallback.status().danger)
		.. "/"
		.. tostring(fallback.status().dangerSource)
		.. "/"
		.. tostring(fallback.status().error)
)
fallback.step(1.3)
check(fallback.calls == 1, "Verified live transition permits one mocked menu request")
check(fallback.hashReads == 1, "Bytecode hash cached for stable HUD identity")
stop(fallback)

local hudPreview = fixture()
dangerHUD(hudPreview, dangerText)
hudPreview.run()
arm(hudPreview, true)
hudPreview.step(0.4)
hudPreview.data[hudPreview.hudLabel].Text = "Safe"
hudPreview.step(4)
check(
	hudPreview.calls == 0 and hudPreview.status().status == "Preview - would request menu; nothing sent",
	"HUD fallback respects Preview"
)
check(hudPreview.values.rpx_dangerSource == "Verified game HUD", "Safety source is published to UI")
hudPreview.data[hudPreview.hudLabel].Text = mortalText
hudPreview.step(0.3)
check(hudPreview.status().danger == "Danger", "Mortal Danger HUD immediately blocks a previously clear state")
hudPreview.data[hudPreview.hudLabel].Text = "Safe"
hudPreview.step(0.4)
hudPreview.focused = false
hudPreview.step(1)
hudPreview.focused = true
hudPreview.step(4)
check(
	hudPreview.calls == 0 and hudPreview.status().danger == "Unknown",
	"Sampling gap invalidates HUD transition witness"
)
stop(hudPreview)

local unknownHash = fixture()
dangerHUD(unknownHash, dangerText)
unknownHash.scriptHash = "new-unreviewed-bytecode"
unknownHash.run()
arm(unknownHash, false)
unknownHash.step(0.4)
unknownHash.data[unknownHash.hudLabel].Text = "Safe"
unknownHash.step(4)
check(
	unknownHash.calls == 0 and unknownHash.status().dangerSource == "DangerClient revision not verified",
	"Changed script revision cannot authorize menu"
)
local marker = unknownHash.object("Accessory", "MortalDanger")
unknownHash.add(unknownHash.character, marker)
unknownHash.step(0.3)
check(unknownHash.status().danger == "Danger", "MortalDanger marker blocks even with unknown HUD revision")
stop(unknownHash)

local badHUD = fixture()
dangerHUD(badHUD, dangerText)
badHUD.data[badHUD.hudLabel].Parent = nil
badHUD.run()
arm(badHUD, false)
badHUD.step(0.4)
badHUD.data[badHUD.hudLabel].Text = "Safe"
badHUD.step(4)
check(badHUD.calls == 0 and badHUD.status().danger == "Unknown", "Detached label cannot authorize menu")
stop(badHUD)

local respawnHUD = fixture()
dangerHUD(respawnHUD, dangerText)
respawnHUD.run()
arm(respawnHUD, false)
respawnHUD.step(0.3)
respawnHUD.data[respawnHUD.hudLabel].Text = "Safe"
respawnHUD.step(1)
local replacementRoot = respawnHUD.object("Part", "HumanoidRootPart", { Position = respawnHUD.vector(0, 0, 0) })
local replacementHum = respawnHUD.object("Humanoid", "Humanoid", { Health = 100 })
respawnHUD.data[respawnHUD.player].Character = respawnHUD.object(
	"Model",
	"Tester",
	{},
	{ replacementRoot, replacementHum }
)
respawnHUD.step(4)
check(
	respawnHUD.calls == 0 and respawnHUD.status().danger == "Unknown",
	"Respawn cannot inherit old HUD's safety witness"
)
check(respawnHUD.hashReads == 2, "New character requires renewed source validation")
stop(respawnHUD)

local unreadable = fixture()
dangerHUD(unreadable, dangerText)
unreadable.run()
arm(unreadable, false)
unreadable.step(0.3)
unreadable.data[unreadable.hudLabel].Text = "???"
unreadable.step(0.3)
unreadable.data[unreadable.hudLabel].Text = "Safe"
unreadable.step(4)
check(
	unreadable.calls == 0 and unreadable.status().danger == "Unknown",
	"Unrecognized text invalidates transition witness"
)
stop(unreadable)

local mortal = fixture()
mortal.collection.HasTag = function(_, _, tag)
	return tag == "MortalDanger"
end
mortal.run()
arm(mortal, false)
mortal.step(3)
check(mortal.calls == 0 and mortal.status().danger == "Danger", "Native MortalDanger tag overrides clear Danger tag")
mortal.collection.HasTag = function(_, _, tag)
	if tag == "Danger" then
		return false
	end
	return nil
end
mortal.step(3)
check(mortal.calls == 0 and mortal.status().danger == "Unknown", "Both native tags must be readable and clear")
mortal.data[mortal.otherRoot].Position = mortal.vector(500, 0, 0)
mortal.step(0.3)
check(
	mortal.status().status == "Blocked - Danger state unavailable",
	"Unavailable safety check is visible even with nobody nearby"
)
stop(mortal)

print(string.format("PASS: %d proximity assertions; mock remotes only.", passed))
