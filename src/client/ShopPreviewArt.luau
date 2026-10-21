--!strict
-- Original generated shop art. All final image IDs belong to the experience group.
local ContentProvider=game:GetService("ContentProvider")
local Theme=require(script.Parent.UITheme)
local Art={}
local CRATE_IMAGE="rbxassetid://123737204833674"
-- Approved Figma exports uploaded as group-owned images on 2026-09-16.
-- Source/receipt metadata: assets/shop-current-figma-20260914/manifest.json.
local FIGMA_CIRCULAR_RAYS="rbxassetid://85196345053937"
-- October 20 gold coins (assets/gold-coins-20261020/upload-receipts.json): the wide
-- Commander's Vault card art keeps its vault on the right, leaving room for labels.
-- It replaced the mirrored banknote overflow rbxassetid://138029740866650.
local VAULT_BANNER="rbxassetid://114439841862473"
local PASS_BACKGROUNDS={
 orange="rbxassetid://109571654494595",cash="rbxassetid://76189535858143",eggs="rbxassetid://100581807296540",
 cyan="rbxassetid://108126212890055",army="rbxassetid://104740897094702",gold="rbxassetid://73918372038700",
}
local PASS_IMAGES={
 CommanderBanner="rbxassetid://74770565038105",
 DoubleBounty="rbxassetid://101536323150933",
 AutoMerge="rbxassetid://101241605086561",
 BiggerArmy="rbxassetid://81931003230758",
 DoubleLuck="rbxassetid://117200377623767",
}
-- Coin packs by tier: Pocket Coins, Coop Stash (sack), Coin Chest, Commander's Vault.
-- The banknote art they replaced: 105035750065002, 139457712564032, 110055873622600, 103786010617501.
local CASH_IMAGES={
 [1]="rbxassetid://107445346366690",
 [2]="rbxassetid://116335920476744",
 [3]="rbxassetid://132347263460940",
 [4]="rbxassetid://138392235740834",
}

local function illustration(parent,name,asset)
 local image=Theme.Image(parent,name,asset,UDim2.fromScale(1,1))
 image.ImageTransparency,image.ScaleType,image.ZIndex=0,Enum.ScaleType.Fit,5
 -- Explicitly request hidden shop art; do not hide the ImageLabel behind IsLoaded.
 task.spawn(function()
  if image.Parent then pcall(function() ContentProvider:PreloadAsync({image}) end) end
 end)
 return image
end

-- These are exact Figma background exports, not a recreated gradient.
function Art.PassBackdrop(parent,key)
 local image=illustration(parent,"FigmaPassBackground",assert(PASS_BACKGROUNDS[key],"Unknown pass palette"))
 image.ScaleType,image.ZIndex=Enum.ScaleType.Stretch,1
 return image
end

function Art.Crate(parent)
 return illustration(parent,"CrateIllustration",CRATE_IMAGE)
end

function Art.Starfield(parent)
 local stars=Theme.Frame(parent,"Starfield",UDim2.fromScale(1,1))
 stars.BackgroundTransparency,stars.ClipsDescendants,stars.ZIndex=1,true,1
 for i=1,14 do
  local size=if i%4==0 then 3 else 2
  local star=Theme.Frame(stars,"Star"..i,UDim2.fromOffset(size,size),Color3.fromRGB(169,215,230))
  star.Position=UDim2.new(((i*37)%97)/100,0,((i*23)%89)/100,0)
  star.Rotation,star.BackgroundTransparency,star.ZIndex=45,0.56,1
 end
 return stars
end

function Art.Eggs(parent)
 -- Exact transparent Figma export. Rotation is baked into the image rather than
 -- its GUI, allowing the ScrollingFrame to clip the artwork correctly.
 local image=illustration(parent,"EggPairIllustration","rbxassetid://97001569720620")
 -- Preserve the export bounds around the original 156px artwork frame.
 image.Size=UDim2.fromScale(192/156,193/156)
 image.Position=UDim2.fromScale(-22.95068359375/156,-14.815445899963379/156)
 image.ScaleType=Enum.ScaleType.Stretch
 return image
end

function Art.PassIcon(parent,key,double)
 if key=="Eggs" then Art.Eggs(parent)
 elseif key=="Cash" then illustration(parent,"Icon",Theme.Assets.Coin)
 else illustration(parent,"Icon",PASS_IMAGES[key] or Theme.Assets[key]) end
 if double then
  local multiplier=Theme.Display(parent,"Multiplier","x2",40.8,Color3.new(1,1,1))
  multiplier.Size,multiplier.Position,multiplier.ZIndex=UDim2.fromScale(0.43,0.4),UDim2.fromScale(0.55,0.59),6
  multiplier.TextXAlignment=Enum.TextXAlignment.Center
  -- Display renders its visible glyphs in TextFace; the outer label is hidden.
  Theme.Gradient(multiplier.TextFace,Color3.fromRGB(255,247,57),Color3.fromRGB(255,153,0))
  return multiplier
 end
 return nil
end

function Art.ProductRays(parent,color)
 local pending=FIGMA_CIRCULAR_RAYS==""
 local rays=illustration(parent,"ProductRays",if pending then Theme.Assets.Rays else FIGMA_CIRCULAR_RAYS)
 rays.ImageColor3,rays.ImageTransparency,rays.ZIndex=color,if pending then 0.8 else 0,1
 rays:SetAttribute("FigmaAssetPending",pending)
 -- The approved export already contains the 20%-opacity rays and circular fade.
 return rays
end

function Art.CashOverflow(parent)
 local image=illustration(parent,"CashOverflowIllustration",VAULT_BANNER)
 image:SetAttribute("FigmaAssetPending",false)
 -- Art only: the card's labels and price stay native text. Never include backgrounds or text.
 return image
end

function Art.CashPile(parent,tier)
 return illustration(parent,"CashTier"..tier,CASH_IMAGES[tier] or Theme.Assets.Coin)
end
return Art
