--!strict
-- Merchant sale flow. Confirmations pin exact IDs and a server-checked quote.
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local Catalog=require(Shared.PetCatalog)
local Dialogue=require(script.Parent.MerchantDialogue)
local Theme=require(script.Parent.UITheme)
local Browser={}
Browser.__index=Browser
local function money(n) return (tostring(math.floor(n or 0)):reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")) end
local function key(pet) return pet.species..":"..pet.level end

function Browser.new(app)
 return setmetatable({app=app,view=Dialogue.new(app),page=1},Browser)
end

function Browser:Available(group)
 local pets={}
 for _,pet in (self.app.state and self.app.state.pets) or {} do
  if pet.canSell and (not group or key(pet)==group) then table.insert(pets,pet) end
 end
 table.sort(pets,function(a,b) return a.refund<b.refund or (a.refund==b.refund and a.id<b.id) end)
 return pets
end

function Browser:Open()
 local world=workspace:FindFirstChild("PetRollWorld")
 local plot=world and self.app.state and world:FindFirstChild("Plot"..self.app.state.plotIndex)
 local stand=plot and plot:FindFirstChild("SellStand")
 local counter=stand and stand:FindFirstChild("Counter")
 if not counter then return end
 self.app:ClosePanel()
 self.page=1;self.quote=nil
 self.view:Open(counter)
 if self.pending then self.view:Show("Checking your sale…",{}) else self:Root() end
end

function Browser:Root(message)
 self.mode,self.quote="root",nil
 self.view:Show(message or "Got anything to sell?",{
  {text="I want to sell my inventory",run=function() self:Review(self:Available()) end},
  {text="I want to sell this",run=function() self:Selected("sell") end},
  {text="How much is this worth?",run=function() self:Selected("value") end},
  {text="Nevermind",run=function() self.view:Close() end},
 })
end

-- This game selects chickens in My Army rather than carrying crop Tools.
-- Use that selection if present; otherwise ask which chicken in the same dialogue.
function Browser:Selected(intent)
 local pet=self.app.selected and self.app:Pet(self.app.selected)
 self.intent=intent
 if not pet then self.page=1;self:Groups();return end
 if intent=="value" then self:Value(pet)
 elseif pet.canSell then self:Review({pet})
 else self:Root(if pet.favorite then "I won't buy favorite chickens." else "That chicken is in your squad.") end
end

function Browser:Value(pet)
 self.mode,self.quote="value",nil
 self.view:Result("I'd value it at <font color='#FFEF40'>"..Theme.Coins(pet.refund).."</font>.")
end

function Browser:Groups()
 self.mode,self.quote="groups",nil
 local groups,ordered={},{}
 for _,pet in self:Available() do
  local id=key(pet)
  if not groups[id] then groups[id]={key=id,pet=pet,count=0};table.insert(ordered,groups[id]) end
  groups[id].count+=1
 end
 table.sort(ordered,function(a,b) return a.key<b.key end)
 if #ordered==0 then self.view:Result("Nothing to sell. Your squad and favorites are kept.");return end
 local pages=math.ceil(#ordered/3);self.page=math.clamp(self.page,1,pages)
 local choices={}
 for i=(self.page-1)*3+1,math.min(#ordered,self.page*3) do
  local group=ordered[i]
  table.insert(choices,{text=Catalog[group.pet.species].name.." · Lv. "..group.pet.level.." · ×"..group.count,
   run=function()
    if self.intent=="value" then
     local live=self:Available(group.key)
     if live[1] then self.app.selected=live[1].id;self:Value(live[1]) else self:Groups() end
    else self:Group(group.key) end
   end})
 end
 if pages>1 then table.insert(choices,{text="More chickens · "..self.page.."/"..pages,run=function() self.page=self.page%pages+1;self:Groups() end}) end
 table.insert(choices,{text="Back",run=function() self:Root() end})
 self.view:Show("Which chickens?",choices)
end

function Browser:Group(group)
 self.mode,self.group="group",group
 local pets=self:Available(group)
 if #pets==0 then self:Groups();return end
 local choices={{text="Sell one",run=function() local live=self:Available(group);if live[1] then self:Review({live[1]}) else self:Groups() end end}}
 if #pets>1 then table.insert(choices,{text="Sell this group · "..#pets,run=function() self:Review(self:Available(group)) end}) end
 table.insert(choices,{text="Back",run=function() self:Groups() end})
 self.view:Show(Catalog[pets[1].species].name.." · Lv. "..pets[1].level,choices)
end

function Browser:Review(pets)
 if #pets==0 then self.view:Result("Nothing to sell. Your squad and favorites are kept.");return end
 local quote={ids={},refund=0,income=0,levels={}}
 for _,pet in pets do
  table.insert(quote.ids,pet.id);quote.refund+=pet.refund;quote.income+=self.app:PetIncome(pet)
  quote.levels[pet.id]=pet.level
 end
 self.mode,self.quote="review",quote
 self.view:Show("I'll buy "..#pets.." spare "..(if #pets==1 then "chicken" else "chickens")..".",{
  {text="Sell "..#pets.." for "..Theme.Coins(quote.refund),run=function() self:Confirm() end},
  {text="Nevermind",run=function() self:Root() end},
 },"Egg income −"..Theme.Coins(quote.income).."/s")
end

function Browser:QuoteValid()
 if not self.quote then return false end
 local available={};for _,pet in self:Available() do available[pet.id]=pet end
 local total,income=0,0
 for _,id in self.quote.ids do
  local pet=available[id]
  if not pet or pet.level~=self.quote.levels[id] then return false end
  total+=pet.refund;income+=self.app:PetIncome(pet)
 end
 return total==self.quote.refund and income==self.quote.income
end

function Browser:Confirm()
 if self.pending or not self.view.active then return end
 if not self:QuoteValid() then self:Root("Your flock changed. Choose again.");return end
 local quote=self.quote
 self.pending={id=self.app:Request("Sell",{petIds=table.clone(quote.ids),expectedTotal=quote.refund,sparesOnly=true}),quote=quote}
 self.mode="pending";self.view:Show("Selling…",{})
end

function Browser:Receive(result)
 if result and self.pending and result.id==self.pending.id then
  self.pending=nil;self.quote=nil
  if not self.view.active then return false end
  if result.ok and result.receipt then
   local receipt=result.receipt
   self.view:Result("Here is <font color='#FFEF40'>"..Theme.Coins(receipt.total).."</font>")
  else self:Root(result.message or "Your flock changed. Choose again.") end
  return true
 end
 if self.view.active and self.mode=="review" and not self.pending and not self:QuoteValid() then self:Root("Your flock changed. Choose again.") end
 return false
end

function Browser:Destroy() self.view:Destroy() end
return Browser
