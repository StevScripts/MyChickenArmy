local fs = Harness.fs
local M = Harness.luau.load(fs.readFile(ARGS[1] .. "/battle.luau"), {environment = getfenv()})()
