--!strict
-- Fusion guarantees Giant. Rarity weights only the saved visual size, not stats.
local Giant = {}
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

return Giant
