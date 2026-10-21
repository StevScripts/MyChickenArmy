--!strict
-- Fixed design-time flocks, never a player's wallet or live income.
local Economy = {
	RecruitPaybackSeconds = 600,
	StarterRecruitPrice = 0, -- October 21 (Stevin): the guide's first roll is FREE, like the reference.
	FusionRecruitFraction = 0.25, -- Cash fee relative to one normal matching recruit.
	-- One paid level; scales with the current recruit level. October 21 later (P5): 0.45
	-- (was 0.75) with x1.6 eggs a level, so the first Feed level pays back as before.
	ChickenUpgradeRecruitFraction = 0.45,
	IncomeUpgradeSeconds = 180,
	LuckUpgradeSeconds = 120,
	-- Capped board continuation. Preserve the opening four benchmark prices.
	IncomeUpgradeMax = 25,
	IncomePriceGrowth = 1.6, -- October 8: 1.35 let every cash track max by day 3.
	LuckUpgradeMax = 20,
	LuckPriceGrowth = 1.25, -- Superseded October 14 by the accelerating Base/Step below.
	LuckPriceBase = 1.5,
	LuckPriceStep = 0.07,
	UpgradePriceStep = 1000,
	ReferenceIncome = {
		16, -- Fixed opening price benchmark; independent of the initial flock.
		5 * 28 * 2 * 1.25, -- Iron: five level-2 Bucket chickens, egg value 1.
		7 * 96 * 4 * 1.5, -- Royal: seven level-3 Knights, egg value 2.
		9 * 160 * 8 * 1.75, -- Storm: nine level-4 Wizards, egg value 3.
	},
}

local function pacedPrice(rank: number, seconds: number): number
	return math.floor(Economy.ReferenceIncome[rank] * seconds + 0.5)
end

local Config = {
	-- October 20: Fuse (Merging, paid AutoMerging) is removed; its code is in
	-- archive/fuse-20261020. Both stay false for older readers such as ShopCatalog.
	-- ChickenCashUpgrades: the Army inspector's Upgrade button. Briefly off on October 15
	-- (Fuse-only); back on the same day with the restored Rebirth costs, which need it.
	Features = {Merging = false, AutoMerging = false, IntroCutscene = true, ChickenCashUpgrades = true},
	Economy = Economy,
 Version="1.21.0-overhaul", GameTitle="My Chicken Army!",
 -- October 10: the shared territory contest now runs The Hill inside the King's
 -- arena (Config.Hill). Only one site exists; its internal key stays "income:1".
 -- Rate is unused while the Hill is enabled: HillService pays the holder's boost.
 IncomeOutpost={Enabled=true,ContestsEnabled=true,NpcEnabled=true,
  TargetId="income:1",Name="The Hill",Position={0,1.05,0},Rate=0,
  GraceSeconds=30,RetrySeconds=60,ContestSeconds=90,
  WarningAfter=120,WarningSeconds=30,RepeatAfter=180,
  -- Hill Guards hold an empty Hill; NPC raiders test a lone holder. Ironbeak HQ strength.
  NeutralRoster={{species="Bucket",stars=1,level=2},{species="Bucket",stars=1,level=2},{species="Sailor",stars=1,level=2},{species="Viking",stars=1,level=1}},
  RaidRoster={{species="Bucket",stars=1,level=2},{species="Bucket",stars=1,level=2},{species="Sailor",stars=1,level=2},{species="Viking",stars=1,level=1}},
 },
 -- King of the Hill (docs/team/KING_OF_THE_HILL.md). The arena alternates a Hill
 -- round with a King break. Holding boosts the holder's whole farm income; the
 -- player who held longest wins a Hill Roll; ChampionWins total wins earn the
 -- Hill Champion. King fights are refused only while a round holds the arena;
 -- KingLockSeconds=0 (Oct 14) drops the old 45s pre-round lock.
 Hill={Enabled=true,RoundSeconds=300,BreakSeconds=300,FirstBreakSeconds=120,KingLockSeconds=0,
  BoostPerMinute=0.10,BoostMax=0.50,MinWinSeconds=15,RollLuckBonus=2,
  ChampionWins=10,ChampionSpecies="HillChampion"},
 -- October 20 overhaul, Rebirth v2 (docs/team/OVERHAUL_CONTRACT_20261020.md §7; plan v2
 -- with Stevin's changes). Coins on hand are the only requirement (no camps, no King);
 -- Coins reset to 0, then Time Skip pays. Each rank adds +100% egg Coins (ranks
 -- EggBoostFromRank–EggBoostToRank also multiply it by EggBoostPerRank and later ranks by
 -- EggLateGrowthPerRank: RebirthService.Multiplier) and pays GemsBase + GemsPerRank × rank
 -- Gems. Enemies stay ×1 through EnemyFreeRanks,
 -- then +EnemyScalePerRank per rank of the attacker, capped at EnemyScaleMaxRank (x8:
 -- ranks 31–50 add no enemy strength beyond the old top). Mission tiers open at King
 -- clear or MissionTierRanks (Veteran, Elite, Royal). Saved ranks above MaxRank keep
 -- the highest rank.
 -- Costs: Rebirth 1–20 are the October 21 re-fit with tests/ProgressionSimulation
 -- (OVERHAUL_CONTRACT §10). Later on October 21 (Stevin: "more, not harder") the tail
 -- was reshaped: 21–30 grow x1.2 a rank (R30 51T, was 340T) and 31–50 x1.12 a rank,
 -- so a late Rebirth takes 40–120 min of play instead of 3.5–7 h and the game no
 -- longer ends after about a week. Fit and login-model results:
 -- docs/team/REBIRTH_PACING_20261021.md. The Oct 15 $50M…$185T 20-rank ladder is
 -- history (docs/team/REBIRTH_LADDER.md).
 -- October 21 later (P5, reference parity; REBIRTH_PACING_20261021.md "reference-shaped
 -- ladder"; fitted on the rarity pacing retune 41ee725): Rebirth 2 costs 1M like the
 -- reference (was 62M). In-run growth is tamed (Feed x1.6 eggs a level, pricier Egg
 -- Speed/Egg Value III-IV and Flock 7-15) and the ranks step up instead: x20 to Rebirth 5,
 -- x3-4.3 to 10, x1.5-2 to 13, x1.1-1.25 to 30, x1.41 at 31, then x1.1 to 4.84e15 at 50,
 -- with the egg multiplier x1.7 more on ranks 5-10 and x1.06 a rank after.
 Rebirth={Enabled=true,Version=2,MaxRank=50,
  Costs={5e4,1e6,2e7,4e8,8e9,2.4e10,7.2e10,2.55e11,1.09e12,4.7e12,
   9.6e12,1.5e13,2.2e13,3.18e13,3.9e13,4.58e13,5.35e13,6.26e13,7.83e13,9.12e13,
   1.08e14,1.26e14,1.43e14,1.59e14,1.9e14,2.21e14,2.76e14,3.28e14,4.05e14,4.8e14,
   5.69e14,8.03e14,9.12e14,1.01e15,1.12e15,1.24e15,1.37e15,1.51e15,1.67e15,1.84e15,
   2.03e15,2.24e15,2.47e15,2.72e15,3e15,3.3e15,3.63e15,4e15,4.4e15,4.84e15},
  CostStep=0, -- Unused: every rank up to MaxRank is listed.
  EggBonusPerRank=1.0,EggBoostPerRank=1.7,EggBoostFromRank=5,EggBoostToRank=10,EggLateGrowthPerRank=1.06,
  EnemyFreeRanks=2,EnemyScalePerRank=0.25,EnemyScaleMaxRank=30,
  GemsBase=40,GemsPerRank=10,LegacyGemFactor=2,
  MissionTierRanks={5,10,15}},
 -- Limited event; StartsAt/EndsAt are unix seconds (2026-10-14 to 2026-11-01 00:00 UTC).
 -- Off until the Pumpkin Chicken model and portrait are in (docs/team/launch/handoff/H1.md).
 Event={Enabled=false,Id="Halloween2026",StartsAt=1791936000,EndsAt=1793491200,Species="Pumpkin",OfferChance=0.02},
 -- MaxSlots: the most Army slots without Bigger Army, the tree's 10 plus two +1 Army
 -- Slot Gem Upgrades (October 20, S7b).
 StartingCoins=2400,StartingSlots=3,MaxSlots=12,CollectionLimit=25,LegacyCollectionLimit=100,
 -- October 20: chicken storage is unlimited; StorageLimit is the hidden safety cap per save.
 -- Revision 12 is the tree/Gems economy: EconomyMigration converts revision ≤ 11 saves once.
 StorageLimit=1000,
 DataRevision=12,StarterFlock={"Duck","Duck","Duck"},
 CommandDistance=14,
 PlayerHomeWalkSpeed=32,PlayerTravelWalkSpeed=45,PlayerTravelBoundaryPadding=2,
 -- Active offer slots, capped by the actual authored displays. Future unlocks change this gate.
 RollSlotsUnlocked=8,
 -- Oct 20 (Stevin): a roll lasts about as long as Drop a Fruit's (~3.9 s; was 2.4).
 -- Roll Speed divides it (RollService).
 RollRevealSeconds=4,RollInteractDistance=14,
 -- Pre-October 20 Auto Roll stop names, kept only so AutoRollRules.Read converts old saves.
 AutoRollStops={"Upgrade","Rare","Epic","Legendary","Mythic","Secret"},
 -- October 20 Auto Roll panel (S12b, Stevin: Drop a Fruit's board 1:1; AutoRollRules.luau).
 -- "Stop When Appear" rows: rarities (rarest first), mutations plus Normal, and new
 -- chickens/mutations. Any row that is ON stops it. Defaults for a fresh save:
 AutoRoll={Rarities={"Secret","Mythic","Legendary","Epic","Rare","Uncommon","Common"},
  DefaultRarities={"Legendary","Mythic","Secret"},DefaultMutations={"Golden","Rainbow","Shadow","Cosmic"},
  DefaultNewChicken=true,DefaultNewMutation=false},
 -- October 20 Gold rolls (S12, S12b; GoldRolls.luau). Each machine counts lever pulls on its
 -- own: Gold every Every[goldRate+1]th pull, Diamond every KindEvery.Diamond[diamondRate+1]th
 -- and Prism every KindEvery.Prism[prismRate+1]th. Tree v2 (Stevin, S9c): each Rate has four
 -- tiers that halve the count by tier IV. A special pull rolls every podium with Luck[n]x
 -- Luck (Kinds[n]); if two land on one pull, the bigger boost wins. goldMachine 1/2/3 owns
 -- Gold, +Diamond, +Prism. Live Gold Rate II meant every 6, so saves move to tier III (S7).
 GoldRolls={Every={10,8,7,6,5},Luck={2,5,10},Kinds={"Gold","Diamond","Prism"},
  KindEvery={Diamond={100,85,70,60,50},Prism={500,425,350,300,250}}},
 SlotLevels={3,4,5,6,7,8,9,10},
 SlotUnlocks={
  [3]={capacity=4,price=1200},
  [4]={capacity=5,price=4800},
  [5]={capacity=6,price=pacedPrice(2,120)},
  [6]={capacity=7,price=pacedPrice(2,180)},
  [7]={capacity=8,price=pacedPrice(3,120)},
  [8]={capacity=9,price=pacedPrice(3,180)},
  [9]={capacity=10,price=pacedPrice(4,180)},
 },
 -- SlotUnlocks, LuckPrices and IncomePrices below are the pre-October 20 cash tracks:
 -- kept for reading old saves and for the old cash hexes until S9 ships. The tree in
 -- UpgradeCatalog sells Army Size, Luck and Egg Value now.
 -- MaxPetLevel is the level cap without Feed Max Level. October 20 (S7b): the effect
 -- feedMaxLevel adds Chicken Feed levels above it, up to PetLevelLimit; levels past
 -- MaxPetLevel give +25% eggs each instead of 2x (Rules.EggRate).
 MaxPetLevel=10,PetLevelLimit=20,PetCombatPerLevel=0.25,PetUpgradeGrowth=1.75,
 PetUpgradePriceFraction=0.75,
 PassiveIncomeMultiplier=1,
 SplashDamageFraction=0.5,
 AttackerRespawnSeconds=5,EnemyReclaimSeconds=4,
 -- October 15: a camp an army leaves mid-fight keeps its progress; the bar drains
 -- to empty over LeftProgressDrainSeconds and fallen guards stand back up one per
 -- LeftDefenderRespawnSeconds (BattleService:LeaveProgress/ResumeProgress).
 LeftProgressDrainSeconds=90,LeftDefenderRespawnSeconds=12,
 -- October 15: a marching army fights any open camp whose centre it passes within
 -- InterceptRadius studs of (BattleService:StepIntercepts), then marches on.
 InterceptRadius=16,
 LuckPrices={pacedPrice(1,Economy.LuckUpgradeSeconds),pacedPrice(2,Economy.LuckUpgradeSeconds),pacedPrice(3,Economy.LuckUpgradeSeconds),pacedPrice(4,Economy.LuckUpgradeSeconds)},LuckWeightPerLevel=0.10,
 LuckOpeningLevels=4,LuckContinuationWeightPerLevel=0.10,
 IncomePrices={pacedPrice(1,Economy.IncomeUpgradeSeconds),pacedPrice(2,Economy.IncomeUpgradeSeconds),pacedPrice(3,Economy.IncomeUpgradeSeconds),pacedPrice(4,Economy.IncomeUpgradeSeconds)},IncomeMultiplierPerLevel=0.25,
 MaxStars=1,StarHP={1},StarSize={1},SellFraction=0.5,
 -- October 21 (docs/team/ONE_EGG_VALUE.md): every egg on the ground is one real egg.
 -- A chicken lays one every EggLaySeconds (Egg Speed shortens it, never below
 -- EggMinLaySeconds) and that egg carries all the Coins it earned meanwhile, so
 -- stronger chickens lay more valuable eggs, not more of them.
 EggBaseValue=4,EggLaySeconds=3,EggMinLaySeconds=1,EggsPerChicken=5,EggMaxDrops=80,
 LegacyEggLaySeconds=5, -- Older profile egg timers used the original five-second cycle.
 EggSpriteImage="rbxassetid://91011618236242",EggSpriteSize=2,EggSpriteMaxDistance=120,
 EggMagnetRadius=7.5,EggSettleSeconds=0.4,EggFlightSeconds=0.62,EggPickupBatch=4,
 SaveName="DuckArmy_Pond_v2",SaveInterval=30,SaveLeaseSeconds=180,
 SaveAttempts=3, SaveEnabled=true,
 BattleStep=0.1,SnapshotInterval=0.2,TravelSeconds=5,ReturnSeconds=5,
 -- Authored Blender pecks make contact at 0.30s; damage follows that beat.
 AttackWindupSeconds=0.3,AttackStaggerSeconds=0.06,DefenderSpawnDepth=9,
 -- Camp defenders meet nearby troops before either side reaches pecking range.
 DefenderAggroRadius=18,
 RouteRegroupSeconds=1.2,CampHalfSize=11.7,CampRespawnGrace=2,
 -- October 13 (Mini War-style territory): each held camp adds egg value while its
 -- flag stands (Camp 1/2/3, then the King). Bonuses stack; a camp under attack
 -- pays ContestedShare. HoldLimit is raised only by research (effect holdCap).
 -- October 15 owner request: a stationed mission army also adds egg value while it
 -- holds its territory (Veteran/Elite/Royal), counting toward HoldLimit.
 Territories={CampBonus={0.05,0.15,0.20},KingBonus=0.25,MissionBonus={0.05,0.08,0.10},ContestedShare=0.5,HoldLimit=8},
 -- October 6 footage: one continuous conquest meter, approximately 25s.
 -- Supply Outpost/player contests and Operations retain their existing timing.
 RoamStep=0.1,RoamSpeed=2.5,ConquestSeconds=25,ConquestSecondsByCamp={12,20,25},CaptureSeconds=8,NeutralizeSeconds=4,DefenderRespawnMinSeconds=10,DefenderRespawnMaxSeconds=15,CaptureRadius=7.8,FightTimeout=120,
 KillCoins={Duck=100,Mallard=160,Chunky=280,Sailor=280,Bucket=520,Viking=960,Knight=1760,Wizard=3360,Dragon=7200,IceDuck=9600,StormDuck=14400},
 KillLevelBonus=0.15,
 KingKillCoins=48000,
 PvPKillMultiplier=0.25,
 PvPKillCaps={80,240,720,1800},MoveSpeed=13,AttackRange=3.7,ActorArrivalDistance=1.25,SplashRadius=7,
 -- Builder map: exact home anchors and approximately 80-stud camp legs.
 Map={IslandRadius=453.2087,ShoreRadius=514.0856,HomeRingRadius=370,OutpostRadius=226},
 CampRadii={273,190,109},
 -- Keep generous travel limits for cross-field detours and returning reinforcements.
 TravelTimeout=85,ReturnTimeout=95,
 PlotPositions={{320.50122,-180.00012},{319.00177,185.64453},{0.25604,369.73779},{-317.31348,188.24377},{-318.81384,-182.59717},{0.25464,-366.74768}},
 DebugUserIds={146710616},
 -- October 16 free gift: one free chicken for joining the group. "Like the game" is
 -- honor-system (Roblox exposes no like check); only group membership is verified.
 FreeGift={Enabled=true,GroupId=778575811,Species="Bucket"},
 -- October 20 Gold Rush (GoldRushService, docs/team/GOLD_RUSH_FRIEND_BOOST.md): every
 -- earned Coin (eggs, battles, Missions, the Hill) is multiplied by CoinMultiplier
 -- for Seconds out of every EverySeconds, stacking with 2x Coins. One wall clock for
 -- every server (OffsetSeconds shifts it): rushes start at :00, :20 and :40.
 -- Counted when Coins are paid; never part of offline earnings.
 GoldRush={Enabled=true,EverySeconds=1200,Seconds=300,OffsetSeconds=0,CoinMultiplier=2},
 -- October 20 Friend Boost (FriendBoostService): +PerFriend earned Coins for each
 -- Roblox friend in the same server, up to Max. Never saved; never offline.
 -- StudioTestPlayersAreFriends: Studio's local test players count as friends.
 FriendBoost={Enabled=true,PerFriend=0.10,Max=0.50,StudioTestPlayersAreFriends=true},
 Camps={
  {name="Cluck Camp",position={0,-273},roster={"Duck","Duck","Duck"}},
  {name="Fort Roost",position={0,-190},roster={{species="Bucket",level=1},{species="Sailor",level=1},{species="Mallard",level=1},{species="Mallard",level=1}}},
  {name="Ironbeak HQ",position={0,-109},roster={{species="Bucket",level=2},{species="Bucket",level=2},{species="Sailor",level=2},{species="Viking",level=1}}},
 },
}
-- Quote fixed prices, never prices based on a player's coins or live income.
-- October 14 owner retune ("easy at the start, then harder and harder"): Luck's
-- continuation ratio itself grows each level (1.57x, 1.64x … 2.62x), so the opening
-- stays cheap and the top levels become a long-term goal (L10 ~$67M, L20 ~$240B).
local function extendAcceleratingPrices(prices, maximum, base, step)
	local openingCount, price = #prices, prices[#prices]
	for purchase = openingCount + 1, maximum do
		price *= base + step * (purchase - openingCount)
		prices[purchase] = math.ceil(price / Economy.UpgradePriceStep) * Economy.UpgradePriceStep
	end
end
local function extendPrices(prices, maximum, growth)
	local openingCount, anchor = #prices, prices[#prices]
	for purchase = openingCount + 1, maximum do
		prices[purchase] = math.ceil(anchor * growth ^ (purchase - openingCount)
			/ Economy.UpgradePriceStep) * Economy.UpgradePriceStep
	end
end
extendPrices(Config.IncomePrices, Economy.IncomeUpgradeMax, Economy.IncomePriceGrowth)
extendAcceleratingPrices(Config.LuckPrices, Economy.LuckUpgradeMax, Economy.LuckPriceBase, Economy.LuckPriceStep)
return Config
