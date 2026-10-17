--!strict
-- Catalog IDs and recorded launch base prices; never a checkout quote.
-- The client reads each buyer's current Marketplace price.
local Config = require(script.Parent.Config)
local ProcessorConfig = require(script.Parent.EggProcessorConfig)
local PetCatalog = require(script.Parent.PetCatalog)
local Currency = require(script.Parent.CurrencyLimits)
local RarityRank = {Common=1, Uncommon=2, Rare=3, Epic=4, Legendary=5, Mythic=6, Secret=7}

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
	ProductOrder = {"ChickenOffer1", "ChickenOffer2", "ChickenOffer3", "ChickenOffer4", "ChickenOffer5", "ChickenOffer6", "PocketCoins", "CoopStash", "ArmyChest", "CommandersVault", "OuterSpaceCrate1", "OuterSpaceCrate3", "OuterSpaceCrate10", "FinishEggs",
		"ResearchSkip1m", "ResearchSkip5m", "ResearchSkip15m", "ResearchSkip30m", "ResearchSkip1h", "ResearchSkip2h", "ResearchSkip4h", "ResearchSkip8h", "ResearchSkip12h", "ResearchSkip24h"},
	-- October 15: Robux research skips, shortest first. The Upgrades card offers the
	-- smallest tier that covers the job's remaining time; never listed in the Shop.
	ResearchSkipOrder = {"ResearchSkip1m", "ResearchSkip5m", "ResearchSkip15m", "ResearchSkip30m", "ResearchSkip1h", "ResearchSkip2h", "ResearchSkip4h", "ResearchSkip8h", "ResearchSkip12h", "ResearchSkip24h"},
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
		-- October 14: each pack pays its minutes of current egg income, never less than
		-- `coins` (CashPackAmount). Minutes keep roughly the Robux price ratio, with a
		-- small bonus on larger packs.
		PocketCoins = {productId=3712929487, name="Pocket Cash", coins=10000, incomeMinutes=10, description="10 minutes of income (at least $10K)", proposedPrice=49},
		CoopStash = {productId=3712929549, name="Coop Stash", coins=100000, incomeMinutes=45, description="45 minutes of income (at least $100K)", proposedPrice=199},
		ArmyChest = {productId=3712929607, name="Cash Sack", coins=1000000, incomeMinutes=180, description="3 hours of income (at least $1M)", proposedPrice=799},
		CommandersVault = {productId=3712929634, name="Commander's Vault", coins=10000000, incomeMinutes=600, description="10 hours of income (at least $10M)", proposedPrice=2499},
		OuterSpaceCrate1 = {productId=3712929703, name="Galaxy Crate", crates=1, proposedPrice=500, paidRandom=true},
		OuterSpaceCrate3 = {productId=3712929865, name="3 Galaxy Crates", crates=3, proposedPrice=1250, paidRandom=true},
		OuterSpaceCrate10 = {productId=3712929926, name="10 Galaxy Crates", crates=10, proposedPrice=4000, paidRandom=true},
		ResearchSkip1m = {productId=3718778626, name="Skip Research (1 min)", researchSkipSeconds=60, proposedPrice=5},
		ResearchSkip5m = {productId=3718778636, name="Skip Research (5 min)", researchSkipSeconds=300, proposedPrice=15},
		ResearchSkip15m = {productId=3718778649, name="Skip Research (15 min)", researchSkipSeconds=900, proposedPrice=29},
		ResearchSkip30m = {productId=3718778658, name="Skip Research (30 min)", researchSkipSeconds=1800, proposedPrice=49},
		ResearchSkip1h = {productId=3718778661, name="Skip Research (1 hr)", researchSkipSeconds=3600, proposedPrice=79},
		ResearchSkip2h = {productId=3718778673, name="Skip Research (2 hr)", researchSkipSeconds=7200, proposedPrice=129},
		ResearchSkip4h = {productId=3718778682, name="Skip Research (4 hr)", researchSkipSeconds=14400, proposedPrice=199},
		ResearchSkip8h = {productId=3718778696, name="Skip Research (8 hr)", researchSkipSeconds=28800, proposedPrice=299},
		ResearchSkip12h = {productId=3718778705, name="Skip Research (12 hr)", researchSkipSeconds=43200, proposedPrice=399},
		ResearchSkip24h = {productId=3718778720, name="Skip Research (24 hr)", researchSkipSeconds=86400, proposedPrice=549},
		-- October 16 chicken offers (docs/team/CHICKEN_OFFERS.md): a Robux ladder in the free
		-- gift's HUD slot, one step at a time. `image` is the offer art (portrait + light VFX).
		ChickenOffer1 = {productId=3719084263, name="Chicken Jockey", proposedPrice=9, chickenOffer=1, species="Jockey", image="rbxassetid://94324670825392"},
		ChickenOffer2 = {productId=3719084274, name="Rainbow Rider", proposedPrice=49, chickenOffer=2, species="Rainbow", image="rbxassetid://130925911317702"},
		ChickenOffer3 = {productId=3719084284, name="Glitch Chicken", proposedPrice=150, chickenOffer=3, species="IceDuck", image="rbxassetid://99244169798833"},
		ChickenOffer4 = {productId=3719084303, name="Eclipse Chicken", proposedPrice=250, chickenOffer=4, species="Eclipse", image="rbxassetid://99434923012329"},
		ChickenOffer5 = {productId=3719084320, name="Rift Walker", proposedPrice=500, chickenOffer=5, species="RiftWalker", image="rbxassetid://70776617003564"},
		ChickenOffer6 = {productId=3719084332, name="Cosmic Galaxy Overlord", proposedPrice=1200, chickenOffer=6, species="StormDuck", mutation="Cosmic", image="rbxassetid://111079345447458"},
	},
	ChickenOfferOrder = {"ChickenOffer1", "ChickenOffer2", "ChickenOffer3", "ChickenOffer4", "ChickenOffer5", "ChickenOffer6"},
	RadiusMultiplier = 2,
	BountyMultiplier = 2,
	Definitions = {
		AutoCollectEggs = {passId=1978713718, name="Auto Collect Eggs", proposedPrice=199, automatic=true, description="A vacuum collects eggs around your yard.", scope="Sweeps the yard and delivers eggs to your sell stand."},
		DoubleCash = {passId=1980764263, name="2x Cash", proposedPrice=399, description="2x cash from eggs and combat.", scope="Earned cash only; excludes cash packs and chicken sales."},
		DoubleEggSpawn = {passId=1979943376, name="2x Egg Spawn", proposedPrice=199, description="Chickens at your base lay twice as many eggs.", scope=if ProcessorConfig.Enabled then "2x egg production and selling speed; stacks with 2x Cash." else "2x egg production; stacks with 2x Cash."},
		AutoMerge = {enabled=Config.Features.Merging and Config.Features.AutoMerging, passId=1975401932, name="Auto Fuse", proposedPrice=249, automatic=true, description="Fuse matching chickens at your base automatically.", scope="Protects favorites, deployed and manually selected chickens."},
		BiggerArmy = {passId=1980638268, name="Bigger Army", proposedPrice=499, description="Add 5 army slots.", scope="Stacks with Army Size to field up to 15 chickens."},
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
			scope = "Excludes the King and other players' armies",
		},
	},
}

-- Cash a pack pays now: `incomeMinutes` of egg income per second (as
-- PlayerSession:PackIncome reports it), never below the pack's fixed `coins`.
function ShopCatalog.CashPackAmount(product, incomePerSecond: number?): number
	local floor = product.coins or 0
	local minutes = product.incomeMinutes
	if type(minutes) ~= "number" or type(incomePerSecond) ~= "number" or incomePerSecond ~= incomePerSecond
		or incomePerSecond <= 0 then return floor end
	return math.max(floor, math.floor(math.min(incomePerSecond * minutes * 60, Currency.MaxCoins)))
end

-- Smallest research skip that covers `remaining` seconds, or nil past the largest tier.
function ShopCatalog.ResearchSkipFor(remaining: number): string?
	for _, key in ShopCatalog.ResearchSkipOrder do
		if ShopCatalog.Products[key].researchSkipSeconds >= remaining then return key end
	end
	return nil
end

for index = #ShopCatalog.Order, 1, -1 do
	if ShopCatalog.Definitions[ShopCatalog.Order[index]].enabled == false then table.remove(ShopCatalog.Order, index) end
end
for _, definition in ShopCatalog.Definitions do table.freeze(definition) end
for _, definition in ShopCatalog.Products do table.freeze(definition) end
table.freeze(ShopCatalog.GuaranteedLuck.sequence)
table.freeze(ShopCatalog.GuaranteedLuck)
table.freeze(ShopCatalog.Products)
table.freeze(ShopCatalog.ProductOrder)
table.freeze(ShopCatalog.ResearchSkipOrder)
table.freeze(ShopCatalog.Definitions)
table.freeze(ShopCatalog.Order)
return table.freeze(ShopCatalog)
