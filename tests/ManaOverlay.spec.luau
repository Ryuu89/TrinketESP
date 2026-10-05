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
	world.guiService = {}
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
					if name == "GuiService" then return world.guiService end
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
		isfile = function(path) return path == "AutoBard.display.cfg" and world.storedDpi ~= nil end,
		readfile = function(path) assert(path == "AutoBard.display.cfg"); return tostring(world.storedDpi) end,
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
				check(kind == "Square", "Mana creates only square overlays")
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
		local fn = assert(loadstring(SOURCE, "ManaOverlay.lua"))
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
		return world.globals.RogueManaOverlay.GetStatus()
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


local function fixture()
 local w=createWorld()
 local bar=w.object("Frame","Mana",{AbsolutePosition={X=20,Y=100},AbsoluteSize={X=10,Y=200}})
 local left=w.object("Frame","LeftContainer",{}, {bar})
 local stat=w.object("ScreenGui","StatGui",{Enabled=true,IgnoreGuiInset=true},{left})
 local gui=w.object("PlayerGui","PlayerGui",{}, {stat})
 w.add(w.player,gui)
 local backpack=w.object("Backpack","Backpack")
 w.add(w.player,backpack)
 local tool=w.object("Tool","Ignis")
 w.add(w.character,tool)
 return w,bar,stat,backpack,tool
end
local w,bar,stat,backpack,tool=fixture()
w.run()
w.step(0.3)
check(w.visible()==2,"Both cast ranges visible")
check(w.drawings[1].Position.X==20 and math.abs(w.drawings[1].Position.Y-110)<1e-9,"Ignis normal range aligned to top")
check(math.abs(w.drawings[1].Size.Y-30)<1e-9,"Ignis normal range height")
check(math.abs(w.drawings[2].Position.Y-186)<1e-9,"Ignis snap range aligned")
check(math.abs(w.drawings[2].Size.Y-8)<1e-9,"Ignis snap range height")
check(w.drawings[1].Color.R==1 and w.drawings[2].Color.B==1,"Hydroxide red and blue colors")
check(w.drawings[1].Transparency==0.45,"Default overlay alpha")

local boon=w.object("NumberValue","ScholarsBoon",{Value=3})
local boosts=w.object("Folder","Boosts",{}, {boon})
w.add(w.character,boosts)
w.add(backpack,w.object("Folder","WiseCasting"))
w.add(backpack,w.object("Folder","RemTraining"))
w.step(0.3)
check(w.status().ranges=="Normal 72-100% | Snap 45-65%","All three Hydroxide bonuses applied and clamped")
w.data[boon].Value=nil
w.step(0.3)
check(w.visible()==0 and w.status().status:find("unreadable"),"Unreadable bonus blocks display")
w.data[boon].Value=0
w.step(0.3)
check(w.visible()==2,"Recovered bonus restores display")
w.values.rmo_opacity=70
w.values.rmo_offsetY=12
w.step(0.15)
check(w.drawings[1].Transparency==0.7 and w.drawings[1].Position.Y==112,"Live opacity and alignment settings")
w.values.rmo_snap=false
w.step(0.1)
check(w.visible()==1,"Snap toggle applies")
w.values.rmo_normal=false
w.step(0.1)
check(w.visible()==0,"Normal toggle applies")
w.values.rmo_normal=true
w.values.rmo_snap=true
w.values.rmo_opacity=0
w.step(0.1)
check(w.visible()==0,"Zero opacity fully hides overlay")
w.values.rmo_opacity=45
w.step(0.1)
w.focused=false
w.step(0.1)
check(w.visible()==0,"Alt-tab hides overlay")
w.focused=true
w.step(0.3)
check(w.visible()==2,"Refocus restores overlay")

w.data[tool].Parent=backpack
w.step(0.05)
check(w.visible()==0,"Unequip invalidates cached ranges before next inspection")
w.data[tool].Parent=w.character
w.data[tool].Name="Unrecognized"
w.step(0.3)
check(w.visible()==0,"Unknown tool has no guessed ranges")
w.data[tool].Name="Ignis"
w.data[stat].Enabled=false
w.step(0.3)
check(w.visible()==0,"Hidden StatGui hides overlay")
w.data[stat].Enabled=true
w.data[bar].AbsoluteSize={X=10,Y=0}
w.step(0.3)
check(w.visible()==0,"Zero geometry rejected")
w.data[bar].AbsoluteSize={X=10,Y=200}
w.step(0.3)
check(w.visible()==2,"Resizing restores geometry")
local nativeHeight=w.drawings[1].Size.Y
w.data[bar].AbsoluteSize={X=0,Y=0}
w.memory["float:"..tostring(w.data[bar].Address+0xFC)]=20
w.memory["float:"..tostring(w.data[bar].Address+0x100)]=100
w.memory["float:"..tostring(w.data[bar].Address+0x104)]=10
w.memory["float:"..tostring(w.data[bar].Address+0x108)]=200
w.step(5.1)
check(w.visible()==2 and math.abs(w.drawings[1].Size.Y-nativeHeight)<1e-9,"Zero native AbsoluteSize recovered from memory after AbsolutePosition")
w.memory["float:"..tostring(w.data[bar].Address+0xFC)]=21
w.step(0.3)
check(w.visible()==0,"Memory size rejected when the stored position no longer matches")
w.memory["float:"..tostring(w.data[bar].Address+0xFC)]=20
w.data[bar].AbsoluteSize={X=10,Y=200}
w.step(0.3)
local reads=w.memoryReads
local writes=w.positionWrites
w.step(0.5)
check(w.positionWrites==writes and w.memoryReads==reads,"Stable overlay avoids redundant geometry writes and memory reads")
w.values.rmo_enabled=false
w.step(0.1)
check(w.visible()==0,"Disable applies immediately")
w.values.rmo_enabled=true
w.step(0.3)
w.data[w.player].Character=nil
w.step(0.05)
check(w.visible()==0,"Respawn clears old character overlay")
w.data[w.player].Character=w.character
w.step(0.3)
check(w.visible()==2,"Character recovery resumes overlay")
w.gameData.JobId="another-server"
w.step(0.1)
check(w.visible()==0 and w.globals.RogueManaOverlay==nil,"Server change unloads overlay")
check(w.writes==0,"Mana does not write game properties")

local twice=fixture()
twice.run()
twice.step(0.3)
local old=twice.globals.RogueManaOverlay
twice.run()
twice.step(0.3)
check(old.GetStatus().running==false and twice.visible()==2,"Rerun replaces rather than duplicates")
twice.globals.RogueManaOverlay.Stop()
twice.step(0.3)
check(twice.visible()==0 and twice.uiCallback==nil,"Unload cleans all drawings and UI")

local rejected=createWorld(123)
rejected.run()
check(#rejected.drawings==0 and rejected.globals.RogueManaOverlay==nil,"Other games rejected")
local menu=createWorld()
menu.data[menu.player].Character=nil
menu.run()
menu.step(0.3)
check(menu.visible()==0 and menu.status().status=="Waiting for character","Menu safely waits")
menu.globals.RogueManaOverlay.Stop()

local all,_,_,_,equipped=fixture()
all.run()
local expected={
            ["Armis"] = {{40, 60}, {70, 80}},
            ["Trickstus"] = {{30, 70}, {30, 50}},
            ["Scrupus"] = {{30, 100}, {30, 100}},
            ["Celeritas"] = {{70, 90}, {70, 80}},
            ["Ignis"] = {{80, 95}, {53, 57}},
            ["Gelidus"] = {{80, 95}, {85, 100}},
            ["Viribus"] = {{23, 35}, {60, 70}},
            ["Sagitta Sol"] = {{50, 65}, {40, 60}},
            ["Tenebris"] = {{90, 100}, {40, 60}},
            ["Nocere"] = {{70, 85}, {70, 85}},
            ["Hystericus"] = {{75, 90}, {15, 35}},
            ["Shrieker"] = {{30, 50}, {30, 50}},
            ["Verdien"] = {{75, 100}, {75, 85}},
            ["Contrarium"] = {{80, 95}, {70, 90}},
            ["Floresco"] = {{90, 100}, {80, 95}},
            ["Perflora"] = {{70, 90}, {30, 50}},
            ["Manus Dei"] = {{90, 95}, {50, 60}},
            ["Fons Vitae"] = {{75, 100}, {75, 100}},
            ["Trahere"] = {{75, 85}, {75, 85}},
            ["Furantur"] = {{60, 80}, {60, 80}},
            ["Inferi"] = {{10, 30}, {10, 30}},
            ["Howler"] = {{60, 80}, {60, 80}},
            ["Secare"] = {{90, 95}, {90, 95}},
            ["Ligans"] = {{63, 80}, {63, 80}},
            ["Reditus"] = {{50, 100}, {50, 100}},
            ["Fimbulvetr"] = {{86, 90}, {70, 80}},
            ["Gate"] = {{75, 83}, {75, 83}},
            ["Snarvindur"] = {{60, 75}, {20, 30}},
            ["Hoppa"] = {{40, 60}, {50, 60}},
            ["Percutiens"] = {{60, 70}, {70, 80}},
            ["Dominus"] = {{50, 100}, {50, 100}},
            ["Custos"] = {{45, 65}, {45, 65}},
            ["Claritum"] = {{90, 100}, {90, 100}},
            ["Globus"] = {{70, 100}, {70, 100}},
            ["Intermissum"] = {{70, 100}, {70, 100}},
            ["Sraunus"] = {{1, 50}, {1, 50}},
            ["Nosferatus"] = {{95, 100}, {95, 100}},
            ["Gourdus"] = {{80, 90}, {80, 90}},
            ["Telorum"] = {{80, 90}, {75, 85}},
            ["Velo"] = {{0, 100}, {50, 60}}
}
for name,ranges in pairs(expected) do
 all.data[equipped].Name=name
 all.step(0.3)
 check(all.visible()==2,"Ranges supported for "..name)
 check(math.abs(all.drawings[1].Size.Y-(ranges[1][2]-ranges[1][1])*2)<1e-9,"Normal range matches Hydroxide: "..name)
 check(math.abs(all.drawings[2].Size.Y-(ranges[2][2]-ranges[2][1])*2)<1e-9,"Snap range matches Hydroxide: "..name)
end
check(all.writes==0,"All spell checks read-only")
all.globals.RogueManaOverlay.Stop()

local aligned,_,screen=fixture()
aligned.data[screen].IgnoreGuiInset=nil
aligned.run()
aligned.step(0.3)
check(math.abs(aligned.drawings[1].Position.Y-110)<1e-9,"Unknown inset does not inject an unverified top margin")
aligned.values.rmo_topInset=58
aligned.step(0.1)
check(math.abs(aligned.drawings[1].Position.Y-168)<1e-9,"Fallback inset setting affects geometry")
aligned.guiService.GetGuiInset=function() return {X=0,Y=64} end
aligned.step(0.1)
check(math.abs(aligned.drawings[1].Position.Y-174)<1e-9,"Native inset takes priority over fallback")
aligned.data[screen].IgnoreGuiInset=true
aligned.step(0.1)
check(math.abs(aligned.drawings[1].Position.Y-110)<1e-9,"IgnoreGuiInset avoids double offset")
aligned.globals.RogueManaOverlay.Stop()


local scaled,_,scaledScreen=fixture()
scaled.storedDpi=130
scaled.data[scaledScreen].IgnoreGuiInset=false
scaled.run()
scaled.step(0.3)
local factor=130/96
check(math.abs(scaled.status().scalePercent-135.4166666667)<1e-6,"Saved DPI becomes the correct percentage")
check(math.abs(scaled.drawings[1].Position.X-20*factor)<1e-6,"DPI scales horizontal origin")
check(math.abs(scaled.drawings[1].Position.Y-110*factor)<1e-6,"DPI scales vertical position including inset")
check(math.abs(scaled.drawings[1].Size.X-10*factor)<1e-6 and math.abs(scaled.drawings[1].Size.Y-30*factor)<1e-6,"DPI scales range width and height")
scaled.values.rmo_offsetY=7
scaled.step(0.1)
check(math.abs(scaled.drawings[1].Position.Y-(110*factor+7))<1e-6,"Manual alignment is applied in final pixels")
scaled.values.rmo_scalePercent=150
scaled.step(0.1)
check(math.abs(scaled.drawings[1].Position.X-30)<1e-6 and math.abs(scaled.drawings[1].Size.Y-45)<1e-6,"Live scale updates origin and dimensions")
scaled.values.rmo_scalePercent=0/0
scaled.step(0.1)
check(scaled.status().scalePercent==150,"Invalid GUI scale is ignored")
scaled.globals.RogueManaOverlay.Stop()
local invalid=fixture()
invalid.storedDpi="not-a-DPI"
invalid.run()
invalid.step(0.3)
check(invalid.status().scalePercent==100,"Invalid saved profile falls back without guessing")
invalid.globals.RogueManaOverlay.Stop()


local owned,ownedBar,ownedScreen,ownedBackpack=fixture()
owned.storedDpi=130
owned.data[ownedScreen].IgnoreGuiInset=nil
owned.add(ownedBackpack,owned.object("Folder","WiseCasting"))
owned.run()
owned.step(0.3)
check(owned.status().ranges=="Normal 78-97% | Snap 51-59%","Only detected WiseCasting counted by default")
owned.values.rmo_remTrainingOwned=true
owned.step(0.3)
check(owned.status().ranges=="Normal 75-100% | Snap 48-62%","Confirmed RemTraining expands both ranges")
check(math.abs(owned.drawings[1].Position.Y-100*factor)<1e-6,"100 percent touches mapped bar top without a guessed inset")
check(math.abs(owned.drawings[1].Size.Y-50*factor)<1e-6,"Normal range spans exactly one quarter of the current bar")
owned.add(ownedBackpack,owned.object("Folder","RemTraining"))
owned.step(0.3)
check(owned.status().ranges=="Normal 75-100% | Snap 48-62%","Detected plus confirmed RemTraining is not double counted")
owned.data[ownedBar].AbsolutePosition={X=30,Y=180}
owned.data[ownedBar].AbsoluteSize={X=14,Y=320}
owned.step(0.1)
check(math.abs(owned.drawings[1].Position.Y-180*factor)<1e-6,"Moving the bar updates the range origin")
check(math.abs(owned.drawings[1].Size.Y-80*factor)<1e-6,"Resizing the bar updates range height without recalibration")
check(math.abs(owned.drawings[2].Position.Y-(180+320*0.38)*factor)<1e-6,"Snap range follows the same resized coordinate mapping")
owned.values.rmo_remTrainingOwned=false
owned.step(0.3)
check(owned.status().ranges=="Normal 75-100% | Snap 48-62%","Automatic detection still works with override disabled")
check(owned.writes==0,"Confirmation and resizing never write game properties")
owned.globals.RogueManaOverlay.Stop()

print(string.format("PASS: %d mana assertions; no Roblox or MCP.",passed))
