--!strict
-- October 20 (owner): Giants are retired with Fuse, the only way to make one
-- (docs/team/FUSE_REMOVAL_AND_SELL.md). Old Giants and Colossals are ordinary
-- chickens: PlayerSession keeps a saved size as `retiredGiantSize` (written back as
-- `giantSize`) and never loads it as `giantSize`. The fusion math is archived in
-- archive/fuse-20261020. These predicates and combat numbers stay for the readers
-- that still check a chicken's `giantSize`, which is now always nil.
local Giant = {}
-- Saved `giantPity` (the old fusion streak) still loads within 0..PityLimit-1.
Giant.PityLimit = 30
Giant.HealthMultiplier = 2
Giant.DamageMultiplier = 1.5
Giant.ColossalArmyDamage = 0.10
Giant.MinSize = 4
Giant.MaxSize = 27.5
Giant.ColossalMinSize = 20
Giant.MaxArmyColossals = 1

function Giant.IsValidSize(size: any): boolean
	return type(size)=="number" and size==size and size>=Giant.MinSize and size<=Giant.MaxSize
end

function Giant.IsColossal(size: any): boolean
	return Giant.IsValidSize(size) and size>=Giant.ColossalMinSize
end

function Giant.Kind(size: number): string
	return if Giant.IsColossal(size) then "Colossal" else "Giant"
end

function Giant.IsGiant(pet: any): boolean
	return type(pet)=="table" and Giant.IsValidSize(pet.giantSize)
end

return Giant
