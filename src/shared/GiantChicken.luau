--!strict
-- October 14 Giants (docs/team/GIANT_CHICKEN_DESIGN.md): every fusion is a level-up
-- merge; it has a chance (with a guarantee) to make a Giant. Giants fight harder
-- (Rules.Stats), a Giant input keeps the result a Giant, and three Giants can make
-- a Colossal that boosts its whole army. Rarity still sets the visual size band.
local Giant = {}
-- Chance for a fusion of three normal chickens: Base + PerLevel × input level.
-- October 14 owner retune: huge chickens must not be easy (was 10% + 2%/level,
-- pity 8, Colossal 25%).
Giant.BaseChance = 0.03
Giant.ChancePerLevel = 0.005
-- After this many fusions in a row without a Giant, the next one is guaranteed.
Giant.PityLimit = 30
-- Three Giant inputs: chance the result becomes a Colossal (otherwise a Giant).
Giant.ColossalFromGiantsChance = 0.10
-- Combat: Giants have more health and damage and stomp (splash) like Wizards.
Giant.HealthMultiplier = 2
Giant.DamageMultiplier = 1.5
-- A fielded Colossal adds this much damage to every chicken on its side.
Giant.ColossalArmyDamage = 0.10
Giant.MinSize = 4
Giant.MaxSize = 27.5
Giant.ColossalMinSize = 20
Giant.MaxArmyColossals = 1
-- New Common Giants stay modest. Rarer recipes unlock progressively larger
-- bands; old saved Giants keep their size even if above a new recipe's band.
Giant.Bands = {
	Common={min=4,max=6,exponent=2}, Uncommon={min=4.5,max=8,exponent=1.8},
	Rare={min=6,max=12,exponent=1.6}, Epic={min=8,max=17,exponent=1.4},
	Legendary={min=11,max=22,exponent=3,colossalChance=0.01},
	Mythic={min=15,max=27.5,exponent=3,colossalChance=0.03},
	Secret={min=15,max=27.5,exponent=3,colossalChance=0.03}, -- October 15: same band as Mythic.
}

function Giant.IsValidSize(size: any): boolean
	return type(size)=="number" and size==size and size>=Giant.MinSize and size<=Giant.MaxSize
end

function Giant.Range(rarity: string, inheritedSize: number?): (number, number)
	local band=Giant.Bands[rarity] or Giant.Bands.Common
	local inherited=if Giant.IsValidSize(inheritedSize) then inheritedSize :: number else Giant.MinSize
	return math.max(band.min,inherited),math.max(band.max,inherited)
end

function Giant.IsColossal(size: any): boolean
	return Giant.IsValidSize(size) and size>=Giant.ColossalMinSize
end

function Giant.Kind(size: number): string
	return if Giant.IsColossal(size) then "Colossal" else "Giant"
end

function Giant.ColossalChance(rarity: string, inheritedSize: number?): number
	if Giant.IsColossal(inheritedSize) then return 1 end
	return (Giant.Bands[rarity] or Giant.Bands.Common).colossalChance or 0
end

-- The server supplies one random quantile after validating the transaction.
-- The top tail is explicitly rare even for Mythics. Keep ordinary rolls below
-- 20 after rounding so 19.95 cannot accidentally become an extra Colossal.
function Giant.SizeFromRoll(rarity: string, quantile: number, inheritedSize: number?): number
	assert(quantile==quantile and quantile>=0 and quantile<=1, "Invalid size roll")
	local band = Giant.Bands[rarity] or Giant.Bands.Common
	local chance=band.colossalChance or 0
	local rolled
	if chance>0 and quantile>=1-chance then
		local tail=math.clamp((quantile-(1-chance))/chance,0,1)
		rolled=Giant.ColossalMinSize+(band.max-Giant.ColossalMinSize)*tail^2
	else
		local ordinary=quantile/(1-chance)
		local maximum=if chance>0 then Giant.ColossalMinSize-0.1 else band.max
		rolled=band.min+(maximum-band.min)*ordinary^band.exponent
	end
	local inherited = if Giant.IsValidSize(inheritedSize) then inheritedSize :: number else Giant.MinSize
	return math.clamp(math.max(math.floor(rolled*10+0.5)/10,inherited),Giant.MinSize,Giant.MaxSize)
end

function Giant.Label(size: number): string
	return string.format("%s · %.1f studs",Giant.Kind(size),size)
end

function Giant.IsGiant(pet: any): boolean
	return type(pet)=="table" and Giant.IsValidSize(pet.giantSize)
end

-- Chance that three normal chickens of this input level fuse into a Giant.
function Giant.Chance(level: number?): number
	local rank=math.max(1,math.floor(tonumber(level) or 1))
	return math.clamp(Giant.BaseChance+Giant.ChancePerLevel*rank,0,1)
end

-- The outcome kind a fusion of these inputs can produce, for previews:
-- "Colossal" (an input is already Colossal), "ColossalChance" (three Giants),
-- "Giant" (at least one Giant input), or "Chance" (no Giant inputs).
function Giant.FusionKind(inputs): string
	local giants,colossal=0,false
	for _,pet in inputs do
		if Giant.IsGiant(pet) then giants+=1 end
		if type(pet)=="table" and Giant.IsColossal(pet.giantSize) then colossal=true end
	end
	if colossal then return "Colossal" end
	if giants>=3 then return "ColossalChance" end
	if giants>=1 then return "Giant" end
	return "Chance"
end

-- A fresh Colossal: 20 studs up to the global maximum, biased toward 20.
function Giant.ColossalSize(quantile: number, inheritedSize: number?): number
	assert(quantile==quantile and quantile>=0 and quantile<=1, "Invalid size roll")
	local rolled=Giant.ColossalMinSize+(Giant.MaxSize-Giant.ColossalMinSize)*quantile^2
	local inherited=if Giant.IsValidSize(inheritedSize) then inheritedSize :: number else Giant.ColossalMinSize
	return math.clamp(math.max(math.floor(rolled*10+0.5)/10,inherited),Giant.ColossalMinSize,Giant.MaxSize)
end

-- An ordinary Giant from a fusion: the rarity band without the old Colossal tail
-- (Colossals now come only from three Giants), never smaller than an input.
function Giant.OrdinarySize(rarity: string, quantile: number, inheritedSize: number?): number
	assert(quantile==quantile and quantile>=0 and quantile<=1, "Invalid size roll")
	local band=Giant.Bands[rarity] or Giant.Bands.Common
	local maximum=math.min(band.max,Giant.ColossalMinSize-0.1)
	local rolled=band.min+(maximum-band.min)*quantile^band.exponent
	local inherited=if Giant.IsValidSize(inheritedSize) then inheritedSize :: number else Giant.MinSize
	return math.clamp(math.max(math.floor(rolled*10+0.5)/10,inherited),Giant.MinSize,Giant.MaxSize)
end

return Giant
