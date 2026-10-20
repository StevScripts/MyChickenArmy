--!strict
-- Original artwork. The masks are plain hex geometry, never baked UI labels.
-- October 20 coin art (assets/gold-coins-20261020): `cash` is the gold coin, and the
-- egg value icons show gold coins instead of banknotes (old egg 74642843536793,
-- old cashEggValue 109589411633165).
local Theme=require(script.Parent.UITheme)
local Assets={
	index=Theme.Assets.Index, luck=Theme.Assets.Luck, army=Theme.Assets.ArmyHud, cash=Theme.Assets.Coin,
	callArmy=Theme.Assets.CallArmy, fuseMachine=Theme.Assets.Merge,
	magnet=Theme.Assets.EggMagnet, egg="rbxassetid://109799576309561",
	bandages="rbxassetid://120779534623977", boots="rbxassetid://137818969643923",
	feed="rbxassetid://122007287446526", medkit="rbxassetid://80368789706410",
	lab="rbxassetid://85565793294890", rally="rbxassetid://106333000080346",
	cashEggSpeed="rbxassetid://71023601644268", cashEggValue="rbxassetid://131663330897554",
	cashLuck="rbxassetid://136683191941433", cashPlotSize="rbxassetid://137569434618832",
	cashArmySize="rbxassetid://92487563557623", cashRollSlots="rbxassetid://91702817085017",
	hexMask="rbxassetid://117593460258785", hexFill="rbxassetid://103453394949472",
}
-- October 20 Upgrades tree: one icon per UpgradeCatalog `icon` key. S6's art
-- (assets/upgrade-icons-20261020/upload, file named after each comment) is not
-- uploaded yet: until its ids are pasted here, each key shows today's closest art.
-- The tier number is live text on the hex, never part of the art.
Assets.upgrades={
	start=Assets.index, -- no S6 file: the Start flag
	back="", -- Back.png (the hex also says "Back")
	openTools=Assets.magnet, -- OpenTools.png
	openPlayer=Theme.Assets.Commander, -- OpenPlayer.png
	openArmy=Assets.army, -- OpenArmy.png
	eggSpeed=Assets.cashEggSpeed, -- EggSpeed.png
	eggValue=Assets.cashEggValue, -- EggValue.png
	luck=Assets.cashLuck, -- Luck.png
	flockSize=Assets.cashPlotSize, -- FlockSize.png
	armySize=Assets.cashArmySize, -- ArmySize.png
	rollSlots=Assets.cashRollSlots, -- RollSlot.png
	rollSpeed=Assets.boots, -- RollSpeed.png
	goldMachine=Assets.cashRollSlots, -- GoldMachine.png
	goldRate=Assets.cashRollSlots, -- GoldRate.png
	diamondMachine=Assets.cashRollSlots, -- DiamondMachine.png
	prismMachine=Assets.cashRollSlots, -- RainbowMachine.png (catalog name is a placeholder)
	eggVacuum=Assets.magnet, -- EggVacuum.png
	vacuumCapacity=Assets.magnet, -- VacuumCapacity.png
	vacuumRange=Assets.magnet, -- VacuumRange.png
	chickenFeed=Assets.feed, -- ChickenFeed.png
	walkSpeed=Assets.boots, -- WalkSpeed.png
	clickRange=Assets.magnet, -- ClickRange.png
	offlineTime=Assets.feed, -- OfflineTime.png
	damage=Assets.army, -- Damage.png
	health=Assets.bandages, -- Health.png
	marchSpeed=Assets.boots, -- MarchSpeed.png
	armor=Assets.army, -- Armor.png
	recovery=Assets.medkit, -- Recovery.png
	bossDamage=Assets.army, -- BossDamage.png
	bounty=Assets.cash, -- Bounty.png
	captureSpeed=Assets.index, -- CaptureSpeed.png
}
return Assets
--stevin
