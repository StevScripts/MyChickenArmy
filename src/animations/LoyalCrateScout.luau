--!strict
-- Same master skeleton and authored motions; only exported bone names differ.
local base = require(script.Parent.Bee)
local bones = table.create(#base.bones)
for i, name in base.bones do bones[i] = "LoyalCrateScout_" .. name end
return {bones = bones, parents = base.parents, clips = base.clips}
