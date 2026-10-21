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
-- October 20 Upgrades tree: one icon per UpgradeCatalog `icon` key. S6's approved
-- set (assets/upgrade-icons-20261020; ids in upload-receipts.json), with the receipts'
-- reused in-game art for the original six tracks, Chicken Feed, March Speed, Health
-- and Recovery. The tier number is live text on the hex, never part of the art.
Assets.upgrades={
	start=Assets.index, -- no S6 icon for Start
	back="rbxassetid://74062628727086",
	openTools="rbxassetid://135859626721110",
	openPlayer="rbxassetid://100646125537844",
	openArmy="rbxassetid://131832119562907",
	eggSpeed=Assets.cashEggSpeed,
	eggValue=Assets.cashEggValue,
	luck=Assets.cashLuck,
	flockSize=Assets.cashPlotSize,
	armySize=Assets.cashArmySize,
	rollSlots=Assets.cashRollSlots,
	rollSpeed="rbxassetid://70386312720480",
	goldMachine="rbxassetid://75354767460656",
	goldRate="rbxassetid://117354946749376",
	diamondMachine="rbxassetid://113120386630417",
	prismMachine="rbxassetid://90010215769789", -- S6's RainbowMachine art for the Prism Machine
	eggVacuum="rbxassetid://130089766443010",
	vacuumCapacity="rbxassetid://72175945483273",
	vacuumRange="rbxassetid://82362785406642",
	chickenFeed=Assets.feed,
	walkSpeed="rbxassetid://85985460964540",
	clickRange="rbxassetid://76024349131743",
	offlineTime="rbxassetid://112666918598506",
	damage="rbxassetid://95203381451260",
	health=Assets.medkit,
	marchSpeed=Assets.boots,
	armor="rbxassetid://100107542181359",
	recovery=Assets.bandages,
	bossDamage="rbxassetid://102931726698589",
	bounty="rbxassetid://111140823257162",
	captureSpeed="rbxassetid://112004220419400",
}
-- Tree v2 (S9c): S6c's icons, uploaded October 20 (same receipts file): the Super Luck
-- (cyan) and Mega Luck (purple) clovers, the Rate dice, Max Level and the mutations.
local treeV2={
	superLuck="rbxassetid://106398620255480", megaLuck="rbxassetid://130839637754661",
	diamondRate="rbxassetid://87592801828456", prismRate="rbxassetid://94923187253083",
	feedMaxLevel="rbxassetid://108213051661738",
	mutationGolden="rbxassetid://80129578684601", mutationRainbow="rbxassetid://95442316893461",
	mutationShadow="rbxassetid://92726160751769", mutationCosmic="rbxassetid://133241731715561",
}
for key,image in treeV2 do Assets.upgrades[key]=image end
return Assets
--stevin
