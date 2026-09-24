--!strict
-- Fixed design-time flocks, never a player's wallet or live income.
local Economy = {
	RecruitPaybackSeconds = 600,
	StarterRecruitPrice = 600,
	IncomeUpgradeSeconds = 180,
	LuckUpgradeSeconds = 120,
	ReferenceIncome = {
		16, -- Rookie: the three starting chickens, no egg-value upgrades.
		5 * 28 * 2 * 1.25, -- Iron: five level-2 Bucket chickens, egg value 1.
		7 * 96 * 4 * 1.5, -- Royal: seven level-3 Knights, egg value 2.
		9 * 160 * 8 * 1.75, -- Storm: nine level-4 Wizards, egg value 3.
	},
}

local function pacedPrice(rank: number, seconds: number): number
	return math.floor(Economy.ReferenceIncome[rank] * seconds + 0.5)
end

local Config = {
	-- Release switch. Merge code and authored stands are retained for a later update.
	Features = {Merging = false},
	Economy = Economy,
 Version="1.19.0-paced-economy", GameTitle="My Chicken Army!",
 -- Staged rollout: enable territory after the opening/feedback PC check.
 IncomeOutpost={Enabled=false,ContestsEnabled=true,NpcEnabled=true,
  TargetId="income:1",Name="Supply Outpost",Position={200,1.05,-200},Rate=8,
  GraceSeconds=30,RetrySeconds=60,ContestSeconds=90,
  WarningAfter=120,WarningSeconds=30,RepeatAfter=180,
  NeutralRoster={{species="Duck",stars=1,level=1},{species="Duck",stars=1,level=1},{species="Duck",stars=1,level=1}},
  RaidRoster={{species="Duck",stars=1,level=1},{species="Duck",stars=1,level=1},{species="Duck",stars=1,level=1},{species="Mallard",stars=1,level=1}},
 },
 StartingCoins=2400,StartingSlots=3,MaxSlots=10,CollectionLimit=40,LegacyCollectionLimit=60,
 DataRevision=10,StarterFlock={"Duck","Duck","Mallard"},
 CommandDistance=14,
 PlayerHomeWalkSpeed=32,PlayerTravelWalkSpeed=45,PlayerTravelBoundaryPadding=2,
 -- Active offer slots, capped by the actual authored displays. Future unlocks change this gate.
 RollSlotsUnlocked=6,
 RollRevealSeconds=2.4,RollInteractDistance=14,
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
 MaxPetLevel=10,PetCombatPerLevel=0.25,PetUpgradeGrowth=1.75,
 PetUpgradePriceFraction=0.75,
 PassiveIncomeMultiplier=1,
 SplashDamageFraction=0.5,
 AttackerRespawnSeconds=5,EnemyReclaimSeconds=4,
 LuckPrices={pacedPrice(1,Economy.LuckUpgradeSeconds),pacedPrice(2,Economy.LuckUpgradeSeconds),pacedPrice(3,Economy.LuckUpgradeSeconds),pacedPrice(4,Economy.LuckUpgradeSeconds)},LuckWeightPerLevel=0.35,
 IncomePrices={pacedPrice(1,Economy.IncomeUpgradeSeconds),pacedPrice(2,Economy.IncomeUpgradeSeconds),pacedPrice(3,Economy.IncomeUpgradeSeconds),pacedPrice(4,Economy.IncomeUpgradeSeconds)},IncomeMultiplierPerLevel=0.25,
 MaxStars=1,StarHP={1},StarSize={1},SellFraction=0.5,
 -- Whole-coin value accumulates only while the chicken is physically home.
 EggLaySeconds=2.4,EggsPerChicken=5,EggMaxDrops=80, -- 25% more frequent pickups; accumulated coin value is preserved.
 LegacyEggLaySeconds=5, -- Older profile egg timers used the original five-second cycle.
 EggSpriteImage="rbxassetid://91011618236242",EggSpriteSize=2,EggSpriteMaxDistance=120,
 EggMagnetRadius=7.5,EggSettleSeconds=0.4,EggFlightSeconds=0.62,EggPickupBatch=4,
 SaveName="DuckArmy_Pond_v2",SaveInterval=30,SaveLeaseSeconds=180,
 SaveAttempts=3, SaveEnabled=true,
 BattleStep=0.1,SnapshotInterval=0.2,TravelSeconds=5,ReturnSeconds=5,
 -- Authored Blender pecks make contact at 0.30s; damage follows that beat.
 AttackWindupSeconds=0.3,AttackStaggerSeconds=0.06,DefenderSpawnDepth=9,
 RouteRegroupSeconds=1.2,CampHalfSize=11.7,CampRespawnGrace=0.4,
 RoamStep=0.1,RoamSpeed=2.5,CaptureSeconds=8,NeutralizeSeconds=4,DefenderRespawnMinSeconds=10,DefenderRespawnMaxSeconds=15,CaptureRadius=7.8,FightTimeout=120,
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
 Camps={
  {name="Cluck Camp",position={0,-273},roster={"Duck","Duck","Duck"}},
  {name="Fort Roost",position={0,-190},roster={{species="Bucket",level=2},{species="Sailor",level=2},{species="Sailor",level=2},{species="Mallard",level=2}}},
  {name="Ironbeak HQ",position={0,-109},roster={{species="Bucket",level=2},{species="Bucket",level=2},{species="Sailor",level=2},{species="Viking",level=1}}},
 },
}
return Config
