-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Made by Ryuu89. One-shot, read-only Matcha capability report.

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
	if not object then
		return nil
	end
	local ok, value = pcall(function()
		return object:FindFirstChild(name)
	end)
	if ok then
		return value
	end
	return nil
end

local function report(name, value)
	print("[Hybrid Audit] " .. name .. ": " .. tostring(value))
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

if game.GameId ~= 1087859240 or (game.PlaceId ~= 5208655184 and game.PlaceId ~= 3541987450) then
	report("Stopped", "Rogue Lineage Gaia and Khei only")
	return
end

local players, workspace = service("Players"), service("Workspace")
local player = read(players, "LocalPlayer")
local camera = read(workspace, "CurrentCamera")
local character = read(player, "Character")
local environment = getfenv(0)
for _, name in ipairs({
	"fireclickdetector",
	"firesignal",
	"firetouchinterest",
	"hookfunction",
	"hookmetamethod",
	"Instance",
}) do
	report(name, type(environment[name]))
end
report("CameraSubject readable", read(camera, "CameraSubject") ~= nil)
report("Camera.lookAt binding (dot call)", type(read(camera, "lookAt")))
report(
	"Camera position writes",
	"Not tested by this audit; previous session probe accepted assignments with no observed movement"
)
report("Native Player.Spectate", type(read(player, "Spectate")))
report("CameraSubject writable", "not tested; requires a documented setter")
report("CollectionService.HasTag", type(read(service("CollectionService"), "HasTag")))
report("CollectionService.GetTags", type(read(service("CollectionService"), "GetTags")))
report("GuiService.GetGuiInset", type(read(service("GuiService"), "GetGuiInset")))

local requests = child(service("ReplicatedStorage"), "Requests")
local menu = child(requests, "ReturnToMenu")
report("ReturnToMenu class", read(menu, "ClassName"))
report("InvokeServer binding", type(read(menu, "InvokeServer")))
report("Hybrid activation", "verify with MCP matcha_status; a method binding alone does not prove activation")
report("Remote execution", "not tested; no remote invoked")

local backpack = child(player, "Backpack")
report("WiseCasting marker", child(backpack, "WiseCasting") ~= nil)
report("RemTraining marker", child(backpack, "RemTraining") ~= nil)
local stat = child(child(player, "PlayerGui"), "StatGui")
local mana = child(child(stat, "LeftContainer"), "Mana")
report("Mana position", read(mana, "AbsolutePosition"))
report("Mana size", read(mana, "AbsoluteSize"))
report("Character present", character ~= nil)

local function findDetector(root)
	local queue = { { root, 0 } }
	local index = 1
	while index <= #queue and index <= 32 do
		local entry = queue[index]
		index = index + 1
		if read(entry[1], "ClassName") == "ClickDetector" then
			return entry[1]
		end
		if entry[2] < 3 then
			for _, object in ipairs(entry[1]:GetChildren()) do
				if #queue >= 32 then
					break
				end
				queue[#queue + 1] = { object, entry[2] + 1 }
			end
		end
	end
	return nil
end

local sampled, detectors, readable = 0, 0, 0
if workspace then
	for _, object in ipairs(workspace:GetChildren()) do
		if read(object, "Name") == "Part" and child(object, "ID") then
			sampled = sampled + 1
			local detector = findDetector(object)
			if detector then
				detectors = detectors + 1
				local distance = read(detector, "MaxActivationDistance")
				if type(distance) == "number" and distance == distance and distance > 0 and distance < math.huge then
					readable = readable + 1
				end
			end
			if sampled >= 8 then
				break
			end
		end
	end
end
report("Candidate sample (maximum 8)", sampled)
report("ClickDetectors found", detectors)
report("Readable positive activation ranges", readable)
report("Complete", "No input, camera/property writes, remotes, hooks, files or background tasks")
