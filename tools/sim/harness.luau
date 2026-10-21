-- Headless runner for My Chicken Army ModuleScripts (scratch tool, not shipped).
-- Usage: lune run harness.luau <repoRoot> <entry.luau> [args...]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local serde = require("@lune/serde")

local root = process.args[1]
assert(root, "repo root required")

local Random = {}
Random.__index = Random
function Random.new(seed)
	local state = math.floor(tonumber(seed) or (os.clock() * 1e6)) % 2147483647
	if state <= 0 then state = 1 end
	return setmetatable({state = state}, Random)
end
function Random:NextNumber(low, high)
	self.state = self.state * 48271 % 2147483647
	local x = (self.state - 1) / 2147483646
	if low and high then return low + (high - low) * x end
	return x
end
function Random:NextInteger(low, high) return math.floor(self:NextNumber(low, high + 1 - 1e-9)) end
function Random:Clone() return setmetatable({state = self.state}, Random) end

-- Generic stub: any key is a callable that returns another stub (signals, services).
local stubMeta = {}
local function Stub() return setmetatable({}, stubMeta) end
stubMeta.__index = function() return function() return Stub() end end
stubMeta.__call = function() return Stub() end

-- Fake instance tree ---------------------------------------------------------
local Node = {}
local nodeMeta = {}
local function newNode(name, className, parent, path)
	local node = setmetatable({__name = name, __class = className, __parent = parent, __children = {},
		__path = path, __attributes = {}, __fields = {}}, nodeMeta)
	if parent then parent.__children[name] = node end
	return node
end
nodeMeta.__index = function(self, key)
	if key == "Name" then return rawget(self, "__name") end
	if key == "Parent" then return rawget(self, "__parent") end
	if key == "ClassName" then return rawget(self, "__class") end
	if Node[key] then return Node[key] end
	local fields = rawget(self, "__fields")
	if fields[key] ~= nil then return fields[key] end
	local child = rawget(self, "__children")[key]
	if child then return child end
	local fallback = rawget(self, "__fallback")
	if fallback then return fallback[key] end
	return nil
end
nodeMeta.__newindex = function(self, key, value) rawget(self, "__fields")[key] = value end
function Node:FindFirstChild(name) return rawget(self, "__children")[name] end
function Node:WaitForChild(name) return rawget(self, "__children")[name] end
function Node:GetChildren()
	local list = {}
	for _, child in rawget(self, "__children") do table.insert(list, child) end
	return list
end
function Node:GetDescendants()
	local list = {}
	local function walk(n) for _, c in rawget(n, "__children") do table.insert(list, c); walk(c) end end
	walk(self)
	return list
end
function Node:IsA(class) return class == rawget(self, "__class") or class == "Instance" end
function Node:GetAttribute(name) return rawget(self, "__attributes")[name] end
function Node:SetAttribute(name, value) rawget(self, "__attributes")[name] = value end
function Node:FindFirstChildOfClass() return nil end
function Node:FindFirstChildWhichIsA() return nil end
function Node:GetFullName() return rawget(self, "__name") end
function Node:IsDescendantOf(other)
	local p = rawget(self, "__parent")
	while p do if p == other then return true end p = rawget(p, "__parent") end
	return false
end
function Node:GetPropertyChangedSignal() return Stub() end
function Node:GetAttributeChangedSignal() return Stub() end

local game = newNode("game", "DataModel", nil, nil)
local workspaceNode = newNode("Workspace", "Workspace", game, nil)
rawset(workspaceNode, "__fallback", Stub())
workspaceNode.GetServerTimeNow = function() return os.time() + os.clock() % 1 end

-- Mount a source directory: X.luau -> ModuleScript X; dir with init.luau -> module.
local function mount(dir, parent, name)
	local initPath
	for _, init in {"init.luau", "init.lua", "init.server.luau"} do
		if fs.isFile(dir .. "/" .. init) then initPath = dir .. "/" .. init end
	end
	local node = newNode(name, if initPath then "ModuleScript" else "Folder", parent, initPath)
	for _, entry in fs.readDir(dir) do
		local full = dir .. "/" .. entry
		if fs.isDir(full) then
			mount(full, node, entry)
		elseif not string.match(entry, "^init%.") then
			local base = string.match(entry, "^(.-)%.luau$") or string.match(entry, "^(.-)%.lua$")
			if base then newNode(base, "ModuleScript", node, full) end
		end
	end
	return node
end

local services = {}
local function service(name, class)
	local node = newNode(name, class or name, game, nil)
	rawset(node, "__fallback", Stub())
	services[name] = node
	return node
end
local ReplicatedStorage = service("ReplicatedStorage")
local ServerStorage = service("ServerStorage")
local petRoll = newNode("PetRoll", "Folder", ReplicatedStorage, nil)
mount(root .. "/src/shared", petRoll, "Shared")
newNode("Assets", "Folder", petRoll, nil)
local serverFolder = mount(root .. "/src/server", ServerStorage, "PetRoll")
mount(root .. "/tests", ServerStorage, "PetRollTests")
services.Workspace = workspaceNode

local Players = service("Players")
Players.GetPlayers = function() return {} end
Players.GetPlayerByUserId = function() return nil end
Players.LocalPlayer = nil
local RunService = service("RunService")
RunService.IsStudio = function() return true end
RunService.IsServer = function() return true end
RunService.IsClient = function() return false end
RunService.IsRunning = function() return false end
local guid = 0
local HttpService = service("HttpService")
HttpService.GenerateGUID = function() guid += 1; return string.format("guid-%08d", guid) end
HttpService.JSONEncode = function(_, value) return serde.encode("json", value) end
HttpService.JSONDecode = function(_, text) return serde.decode("json", text) end

function Node:GetService(name)
	if name == "Workspace" then return workspaceNode end
	return services[name] or service(name)
end
game.Workspace = workspaceNode

-- require ------------------------------------------------------------------------
local cache, loading = {}, {}
local baseEnv
local function makeEnv(scriptNode)
	local env = {}
	for key, value in baseEnv do env[key] = value end
	env.script = scriptNode
	return env
end
local function customRequire(target)
	if cache[target] ~= nil then return cache[target] or nil end
	assert(type(target) == "table" and rawget(target, "__path"), "require: not a module node " .. tostring(target))
	assert(not loading[target], "circular require " .. rawget(target, "__name"))
	loading[target] = true
	local path = rawget(target, "__path")
	local env = makeEnv(target)
	local chunk = luau.load(fs.readFile(path), {debugName = string.sub(path, #root + 2), environment = env})
	local ok, result = pcall(chunk)
	loading[target] = nil
	if not ok then error(result, 0) end
	cache[target] = if result == nil then false else result
	return result
end

local Enum = roblox.Enum
baseEnv = {
	game = game, workspace = workspaceNode, Random = Random, require = customRequire,
	Enum = Enum, Instance = roblox.Instance,
	task = task, typeof = typeof, warn = function(...) print("[warn]", ...) end, print = print,
	tick = os.clock, time = os.clock, elapsedTime = os.clock,
	math = math, string = string, table = table, os = os, coroutine = coroutine, utf8 = utf8, bit32 = bit32,
	buffer = buffer, debug = debug,
	type = type, pairs = pairs, ipairs = ipairs, next = next, select = select, tostring = tostring,
	tonumber = tonumber, error = error, assert = assert, pcall = pcall, xpcall = xpcall,
	setmetatable = setmetatable, getmetatable = getmetatable, rawget = rawget, rawset = rawset,
	rawequal = rawequal, rawlen = rawlen, unpack = table.unpack, newproxy = newproxy, gcinfo = gcinfo,
}
for key, value in roblox do
	if type(key) == "string" and string.match(key, "^%u") and baseEnv[key] == nil then baseEnv[key] = value end
end
local function paramObject()
	return {new = function(...) return {args = {...}, FilterDescendantsInstances = {}, FilterType = nil} end}
end
baseEnv.RaycastParams = paramObject()
baseEnv.OverlapParams = paramObject()
baseEnv.TweenInfo = paramObject()
baseEnv.DateTime = {now = function() return {UnixTimestamp = os.time(), UnixTimestampMillis = os.time() * 1000} end}

local Harness = {game = game, require = customRequire, root = root, Random = Random,
	Shared = petRoll.Shared, Server = serverFolder, Tests = ServerStorage.PetRollTests, fs = fs, serde = serde}

local entry = process.args[2]
assert(entry, "entry script required")
local env = makeEnv(newNode("Entry", "Script", nil, entry))
env.Harness = Harness
env.ARGS = {table.unpack(process.args, 3)}
local chunk = luau.load(fs.readFile(entry), {debugName = entry, environment = env})
local ok, problem = xpcall(chunk, debug.traceback)
if not ok then
	print("[harness] FAILED: " .. tostring(problem))
	process.exit(1)
end
