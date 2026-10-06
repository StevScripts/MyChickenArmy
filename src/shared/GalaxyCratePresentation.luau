--!strict
-- Original Figma artwork; odds come from the same pool the server draws from.
local ShopCatalog=require(script.Parent.ShopCatalog)
local entries={
 Astronaut={name="Astronaut",image="rbxassetid://75271050682798",color=Color3.fromRGB(76,132,231)},
 Alien={name="Alien",image="rbxassetid://74942259744399",color=Color3.fromRGB(135,207,58)},
 StormDuck={name="Galaxy",image="rbxassetid://134363557302070",color=Color3.fromRGB(119,67,194)},
 DarkMatter={name="Dark Matter",image="rbxassetid://74290048846405",color=Color3.fromRGB(178,54,212)},
 CosmicDragon={name="Cosmic Dragon",image="rbxassetid://88171858947713",color=Color3.fromRGB(223,172,50)},
}
local rewards={}
for _,reward in ShopCatalog.Crate.rewards do
 local entry=table.clone(assert(entries[reward.species],"Missing Galaxy portrait"))
 entry.id,entry.species,entry.chance=reward.species,reward.species,reward.chance
 table.insert(rewards,table.freeze(entry))
end
return table.freeze({Rewards=table.freeze(rewards),
 Background="rbxassetid://86095532575238",CrateImage="rbxassetid://118823454682113"})
