--!strict
-- Approved cartoon-army palette, shared by menus and world-space UI.
-- Gameplay, chicken materials, and scenery palettes are separate.
return {
	Army = Color3.fromRGB(121,197,47),
	Body = Color3.fromRGB(48,72,42),
	Card = Color3.fromRGB(235,208,150),
	Text = Color3.fromRGB(255,251,233),
	Navigation = Color3.fromRGB(45,158,223),
	Rewards = Color3.fromRGB(255,209,42),
	Money = Color3.fromRGB(76,250,32),
	Conquest = Color3.fromRGB(255,66,81),
	ConquestTrack = Color3.fromRGB(74,95,103),
	Upgrade = Color3.fromRGB(168,75,219),
	Purchase = Color3.fromRGB(105,206,37),
	Sell = Color3.fromRGB(255,189,43),
	Danger = Color3.fromRGB(248,73,56),
	Border = Color3.fromRGB(20,32,15),
	HeaderHighlight = Color3.fromRGB(180,233,87),
	Muted = Color3.fromRGB(207,221,189),
	Line = Color3.fromRGB(117,142,94),
	Disabled = Color3.fromRGB(100,113,89),
	CardText = Color3.fromRGB(20,32,15),
	CardMuted = Color3.fromRGB(74,78,49),
	CardMoney = Color3.fromRGB(104,76,16),
	-- One rarity palette for collection menus and physical roll results.
	Rarities = {
		Common=Color3.fromRGB(211,228,207), Uncommon=Color3.fromRGB(81,255,59),
		Rare=Color3.fromRGB(66,211,255), Epic=Color3.fromRGB(210,116,255),
		Legendary=Color3.fromRGB(255,222,41), Mythic=Color3.fromRGB(255,94,139),
		-- October 15: rarer than Mythic (1 in 200,000 or rarer).
		Secret=Color3.fromRGB(64,255,233),
	},
}
