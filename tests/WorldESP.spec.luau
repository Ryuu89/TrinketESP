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



local function setup()
 local w=createWorld()
 local ore=w.object("Folder","Ores")
 w.add(w.workspace,ore)
 local npcs=w.object("Folder","NPCs")
 w.add(w.workspace,npcs)
 local junk={}
 for i=1,96 do junk[i]=w.object("Part","Decor"..i) end
 w.add(w.workspace,w.object("Folder","Unrelated",{},junk))
 local ingredients=w.object("Folder","RandomizedContainer")
 w.add(w.workspace,ingredients)
 w.oreFolder,w.npcFolder,w.ingredientFolder=ore,npcs,ingredients
 function w.ore(name,x)
  local o=w.object("Part",name,{Position=w.vector(x or 20,5,10),Transparency=0})
  w.add(ore,o); return o
 end
 function w.ingredient(id,x)
  local o=w.object("UnionOperation","Part",{AssetId=id,Position=w.vector(x or 10,5,10),Transparency=0},{
   w.object("ClickDetector","ClickDetector"),w.object("Folder","Blacklist")})
  w.add(ingredients,o);return o
 end
 function w.npc(name,pants)
  local root=w.object("Part",name=="The Eagle" and "HumanoidRootPart" or "Torso",{Position=w.vector(20,5,10)})
  local list={root,w.object("Humanoid","Humanoid",{Health=100})}
  if pants then list[#list+1]=w.object("Pants","Clothing") end
  local o=w.object("Model",name,{},list);w.add(npcs,o);return o
 end
 function w.status() return w.globals.RogueWorldESP.GetStatus() end
 function w.enable()
  w.values.rwe_ores,w.values.rwe_ingredients,w.values.rwe_npcs=true,true,true
  w.step(3)
 end
 return w
end

local w=setup()
local iron=w.ore("Iron")
local copper=w.ore("Copper")
local tin=w.ore("Tin",200)
local mythril=w.ore("Mythril")
local wrongOre=w.ore("Diamond")
local scroom=w.ingredient("rbxassetid://2620905234")
local unknown=w.ingredient("rbxassetid://999999")
local npc=w.npc("Trainer",true)
w.npc("The Eagle",false)
w.npc("Decor",false)
w.run()
w.step(0.5)
check(w.status().status=="Disabled" and w.visible()==0,"Default disabled; no visuals")
check(w.status().ores==0,"No resource scan while disabled")
w.enable()
check(w.status().ores==4,"Only four Hydroxide ore categories")
check(w.status().ingredients==1 and w.status().unknownIngredients==1,"Known ingredient only; unknown hidden")
check(w.status().npcs==2,"NPC structure and Eagle exception")
check(w.visible()==7,"Four ores, one ingredient, two NPCs")
check(w.status().error==nil,"No runtime errors")
check(w.status().ingredientStatus=="Identified 1 | Unknown (hidden) 1","Useful classification status")
check(#w.drawings==96,"Fixed drawing pool")
w.values.rwe_iron=false
w.step(0.3)
check(w.visible()==6,"Ore category changes affect renderer")
w.values.rwe_oreRange=25
w.step(0.3)
check(w.visible()==5,"Display range updates live")
w.values.rwe_npcs=false
w.step(0.3)
check(w.visible()==3,"NPC toggle independent")
w.values.rwe_ingredients=false
w.step(0.3)
check(w.visible()==2,"Ingredient toggle independent")
w.values.rwe_distanceFade=false
w.values.rwe_opacity=60
w.values.rwe_outline=false
w.values.rwe_textSize=18
w.step(0.3)
for _,d in ipairs(w.drawings) do if d.Visible then
 check(d.Transparency==0.6 and d.Size==18 and d.Outline==false,"Style controls are not visual-only")
end end
local beforeReads=w.renderReads
local first=w.firstVisible()
local oldX=first.Position.X
w.cameraShift=17
w.renderOnly(5)
check(w.renderReads==beforeReads,"No Instance reads in renderer")
check(first.Position.X==oldX+17,"Camera projection updates without collector")
local pw,ow,vw=w.positionWrites,w.opacityWrites,w.visibilityWrites
w.renderOnly(5)
check(w.positionWrites==pw and w.opacityWrites==ow and w.visibilityWrites==vw,"Suppress redundant Drawing writes")
w.focused=false
w.renderOnly(1)
check(w.visible()==0,"Immediate focus-loss hiding")
w.focused=true
w.step(0.3)
check(w.visible()==2,"Focus recovery")
w.data[copper].Transparency=1
w.step(0.3)
check(w.visible()==1,"Depleted ore hidden")
w.data[mythril].Parent=nil
w.step(0.3)
check(w.visible()==0,"Removed ore hidden")
w.data[copper].Transparency=0
w.step(0.3)
check(w.visible()==1,"Replenished ore shown")
w.data[w.player].Character=nil
w.step(0.3)
check(w.visible()==0 and w.status().status=="Waiting for a living character","Menu does not run overlay")
w.data[w.player].Character=w.character
w.step(2)
check(w.visible()==1,"Spawn recovery")
w.renderOnly(80)
check(w.visible()==0,"Stale controls hide labels if worker stalls")
w.step(0.3)
check(w.visible()==1,"Worker resumes")
local old=w.globals.RogueWorldESP
w.run();w.step(0.3)
check(old.GetStatus().running==false,"Rerun unloads old controller")
check(#w.drawings==192 and w.visible()==0,"New instance starts disabled")
w.buttons["Unload World ESP"]()
w.step(0.3)
check(w.globals.RogueWorldESP==nil and w.visible()==0,"Clean unload")
check(w.writes==0 and w.calls==0,"No game writes or remotes")

local all=setup()
local ids={"3293218896","2773353559","2960178471","2577691737","2618765559","2575167210","2620905234","2766925289","2766925320","2766802713","2766802766","2766925228","2766802731","2573998175","2766925214","3215371492","2766925304","3049345298","2766802752","2766925267","2889328388","3049928758","3049556532","2766925245","9858299042","3173538809"}
for _,id in ipairs(ids) do all.ingredient("https://www.roblox.com/asset/?id="..id) end
all.run();all.enable()
check(all.status().ingredients==26 and all.visible()==26,"All 26 Hydroxide ingredient identifiers")
local count=all.status().ingredients
local fake=all.object("Part","Fake",{Position=all.vector(10,5,10),AssetId="2620905234",Transparency=0})
all.add(all.ingredientFolder,fake)
all.step(2)
check(all.status().ingredients==count,"Wrong class cannot masquerade as an ingredient")
all.gameData.JobId="new-server"
all.step(0.3)
check(all.globals.RogueWorldESP==nil and all.visible()==0,"Session change tears down overlay")

local khei=setup()
khei.gameData.PlaceId=3541987450
khei.ingredient("2620905234")
khei.run();khei.enable()
check(khei.status().ingredients==0 and khei.status().ingredientStatus=="Gaia ingredients only","Original Khei exclusion")
khei.globals.RogueWorldESP.Stop()
local other=createWorld(123)
other.run()
check(other.globals.RogueWorldESP==nil and #other.drawings==0,"Game restriction precedes resource creation")

local crowded=setup()
for i=1,120 do crowded.ore("Iron",i) end
crowded.run();crowded.enable()
check(crowded.status().ores==120 and crowded.visible()==96,"Pool limits drawing, not discovery")
check(#crowded.drawings==96,"No allocation per candidate")
crowded.globals.RogueWorldESP.Stop()
check(crowded.visible()==0,"Entire pool removed")

local raw=setup()
raw.ingredient(nil)
raw.globals.RogueTrinketESP={GetUnionAssetId=function() return "2620905234" end}
raw.run();raw.enable()
check(raw.status().ingredients==1,"Shared validated AssetId reader used")
raw.globals.RogueWorldESP.Stop()
local pending=setup()
pending.ore("Iron")
pending.run()
pending.values.rwe_ores=true
pending.step(0.3)
pending.values.rwe_ores=false
pending.step(2)
check(pending.visible()==0 and pending.status().status=="Disabled","Disabled mid-discovery cannot publish labels")
pending.globals.RogueWorldESP.Stop()

local refresh=setup()
local changing=refresh.ingredient("2620905234")
local dead=refresh.npc("Mortal",true)
local alpha=refresh.ore("Copper")
refresh.run();refresh.enable()
check(refresh.status().ingredients==1,"Ingredient initially classified")
refresh.data[changing].AssetId="999999"
refresh.step(13)
check(refresh.status().ingredients==0 and refresh.status().unknownIngredients==1,"Known signatures expire instead of staying mislabeled")
refresh.data[changing].AssetId="2573998175"
refresh.step(2)
check(refresh.status().ingredients==1,"Unknown signatures retry")
refresh.data[dead:FindFirstChild("Humanoid")].Health=0
refresh.data[alpha].Transparency=nil
refresh.step(0.5)
check(refresh.visible()==1,"Dead NPC and unreadable ore availability are hidden")
refresh.values.rwe_opacity=0/0
refresh.step(0.3)
check(refresh.status().error==nil,"Non-finite UI values rejected")
refresh.data[changing].Position=refresh.vector(math.huge,0,10)
refresh.step(0.3)
check(refresh.visible()==0,"Invalid world geometry hidden")
refresh.globals.RogueWorldESP.Stop()

local fairness=setup()
local prefix={}
for i=1,1000 do prefix[i]=fairness.object("Part","Unused") end
table.insert(fairness.data[fairness.workspace].children,1,fairness.object("Folder","Large",{},prefix))
fairness.ingredient("2620905234")
fairness.run();fairness.enable()
check(fairness.status().ingredients==1,"Large unrelated folder cannot starve ingredient discovery")
local late=fairness.ore("Tin")
fairness.step(2)
check(fairness.status().ores==1,"Late resource spawns discovered")
fairness.globals.RogueWorldESP.Stop()
print(string.format("PASS: %d WorldESP assertions; no game or MCP.",passed))





