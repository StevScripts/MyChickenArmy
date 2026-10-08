--!strict
-- Catalog IDs and recorded launch base prices; never a checkout quote.
-- The client reads each buyer's current Marketplace price.
local Config = require(script.Parent.Config)
local ProcessorConfig = require(script.Parent.EggProcessorConfig)
local PetCatalog = require(script.Parent.PetCatalog)
local RarityRank = {Common=1, Uncommon=2, Rare=3, Epic=4, Legendary=5, Mythic=6}

-- Fallback matches the October 7 rarity reset; used only if the catalog lookup fails.
local FALLBACK_GUARANTEED = {
	"Bucket","Zombie","Tiger","Jungle","Bonsai","Viking","Skeleton","Pirate","Slime","Gentleman",
	"Knight","Frost","Ninja","Wizard","Storm","Jockey","Toxic","Dragon","Diamond","SolarFlare","Water",
	"Rainbow","IceDuck","Devil","Heavenly","StormDuck",
}

-- Every normal-roll Rare+ chicken, weakest first: rarity, income, then hp, then catalog order.
local function guaranteedSequence(): {string}
	local entries = {}
	for index, id in PetCatalog.Order do
		local pet = PetCatalog[id]
		local rank = RarityRank[pet.rarity] or 0
		if rank >= RarityRank.Rare and not pet.crateExclusive and (pet.weight or 0) > 0 then
			table.insert(entries, {id=id, rank=rank, income=pet.income, hp=pet.hp, index=index})
		end
	end
	table.sort(entries, function(a, b)
		if a.rank ~= b.rank then return a.rank < b.rank end
		if a.income ~= b.income then return a.income < b.income end
		if a.hp ~= b.hp then return a.hp < b.hp end
		return a.index < b.index
	end)
	local sequence = {}
	for _, entry in entries do table.insert(sequence, entry.id) end
	return sequence
end
local derivedOk, derived = pcall(guaranteedSequence)
local guaranteed = if derivedOk and #derived > 0 then derived else table.clone(FALLBACK_GUARANTEED)
-- Never disclose a below-Rare guarantee; tests/ShopIndexChecks asserts the full list.
for index = #guaranteed, 1, -1 do
	local pet = PetCatalog[guaranteed[index]]
	if not pet or (RarityRank[pet.rarity] or 0) < RarityRank.Rare then
		warn("[PetRoll] Dropped below-Rare guaranteed offer "..tostring(guaranteed[index]))
		table.remove(guaranteed, index)
	end
end
local ShopCatalog = {
	Order = {"AutoCollectEggs", "DoubleCash", "DoubleEggSpawn", "AutoMerge", "BiggerArmy", "DoubleLuck", "EggMagnet", "CommanderBanner", "DoubleBounty"},
	ProductOrder = {"PocketCoins", "CoopStash", "ArmyChest", "CommandersVault", "OuterSpaceCrate1", "OuterSpaceCrate3", "OuterSpaceCrate10", "FinishEggs"},
	ArmyBonus = 5,
	Crate = {enabled=true,name="Galaxy Crate",rewards={
		{species="Astronaut",chance=0.40},
		{species="Alien",chance=0.30},
		{species="StormDuck",chance=0.20},
		{species="DarkMatter",chance=0.09},
		{species="CosmicDragon",chance=0.01},
	}},
	RestrictedTreatment = "GuaranteedOffers",
	-- Restricted owners receive these known offers in order; never a random reward.
	-- The recruit's normal coin purchase is still required after the free reveal.
	GuaranteedLuck = {interval=10, sequence=guaranteed},
	Products = {
		FinishEggs = {enabled=ProcessorConfig.Enabled, productId=3714566216, name="Finish Processing Now", finishEggs=true, boardOnly=true},
		PocketCoins = {productId=3712929487, name="Pocket Cash", coins=10000, proposedPrice=49},
		CoopStash = {productId=3712929549, name="Coop Stash", coins=100000, proposedPrice=199},
		ArmyChest = {productId=3712929607, name="Cash Sack", coins=1000000, proposedPrice=799},
		CommandersVault = {productId=3712929634, name="Commander's Vault", coins=10000000, proposedPrice=2499},
		OuterSpaceCrate1 = {productId=3712929703, name="Galaxy Crate", crates=1, proposedPrice=500, paidRandom=true},
		OuterSpaceCrate3 = {productId=3712929865, name="3 Galaxy Crates", crates=3, proposedPrice=1250, paidRandom=true},
		OuterSpaceCrate10 = {productId=3712929926, name="10 Galaxy Crates", crates=10, proposedPrice=4000, paidRandom=true},
	},
	RadiusMultiplier = 2,
	BountyMultiplier = 2,
	Definitions = {
		AutoCollectEggs = {passId=1978713718, name="Auto Collect Eggs", proposedPrice=199, automatic=true, description="A vacuum collects eggs around your yard.", scope="Sweeps the yard and delivers eggs to your sell stand."},
		DoubleCash = {passId=1980764263, name="2x Cash", proposedPrice=399, description="2x cash from eggs and combat.", scope="Earned cash only; excludes cash packs and chicken sales."},
		DoubleEggSpawn = {passId=1979943376, name="2x Egg Spawn", proposedPrice=199, description="Home chickens produce twice as many eggs.", scope=if ProcessorConfig.Enabled then "2x egg production and selling speed; stacks with 2x Cash." else "2x egg production; stacks with 2x Cash."},
		AutoMerge = {enabled=Config.Features.Merging and Config.Features.AutoMerging, passId=1975401932, name="Auto Merge", proposedPrice=249, automatic=true, description="Merge matching home chickens automatically.", scope="Protects favorites, deployed and manually selected chickens."},
		BiggerArmy = {passId=1980638268, name="Bigger Army", proposedPrice=499, description="Add 5 deployment slots.", scope="Starts at 8; upgrade your base capacity to field 15."},
		DoubleLuck = {passId=1975521949, name="2x Luck", proposedPrice=399, paidRandom=true, description="Double Luck strength to favor stronger chickens.", scope="Actual chances are shown in Details. Crates unaffected."},
		EggMagnet = {
			name = "Egg Magnet", category = "Convenience", proposedPrice = 49, passId = 1980009442,
			description = "Collect eggs from twice as far.",
			scope = "Your eggs · same value and laying rate",
		},
		CommanderBanner = {
			name = "Commander Banner", category = "Style", proposedPrice = 99, passId = 1975521947,
			description = "Gold portrait frame and crown on conquered flags.",
			scope = "Cosmetic · no combat bonus",
		},
		DoubleBounty = {
			name = "Double NPC Bounty", category = "Rewards", proposedPrice = 249, passId = 1981040250,
			description = "2× cash from regular NPC kills.",
			scope = "Excludes the King, PvP and Supply Outpost",
		},
	},
}

for index = #ShopCatalog.Order, 1, -1 do
	if ShopCatalog.Definitions[ShopCatalog.Order[index]].enabled == false then table.remove(ShopCatalog.Order, index) end
end
for _, definition in ShopCatalog.Definitions do table.freeze(definition) end
for _, definition in ShopCatalog.Products do table.freeze(definition) end
table.freeze(ShopCatalog.GuaranteedLuck.sequence)
table.freeze(ShopCatalog.GuaranteedLuck)
table.freeze(ShopCatalog.Products)
table.freeze(ShopCatalog.ProductOrder)
table.freeze(ShopCatalog.Definitions)
table.freeze(ShopCatalog.Order)
return table.freeze(ShopCatalog)
