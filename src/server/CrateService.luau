--!strict
-- Purchased credits are durable; an opening exchanges one credit for one pet.
-- Contents and account eligibility come from the server, never the client.
local Shared=game:GetService("ReplicatedStorage").PetRoll.Shared
local ShopCatalog=require(Shared.ShopCatalog)
local Config=require(Shared.Config)
local Catalog=require(Shared.PetCatalog)
local CrateService={}
CrateService.__index=CrateService

function CrateService.new(dependencies)
 dependencies=dependencies or {}
 return setmetatable({catalog=dependencies.catalog or ShopCatalog,
  random=dependencies.random or Random.new()},CrateService)
end

function CrateService:Open(session)
 local definition=self.catalog.Crate
 if not definition.enabled then return false,"Crate rewards are being prepared." end
 if not session.loaded or session.closing or session.saveLost then return false,"Wait for your flock to load." end
 if session.paidRandomAllowed~=true then return false,"This random reward is unavailable for your account." end
 if session.crateCredits<1 then return false,"You have no crates to open." end
 if session:Count()>=session:CollectionLimit() then return false,"Make room in your flock first. Your crate is safe." end
 local total=0
 for _,entry in definition.rewards do
  if not Catalog[entry.species] or type(entry.chance)~="number" or entry.chance~=entry.chance
   or entry.chance<=0 or entry.chance>1 then return false,"Crate rewards are unavailable." end
  total+=entry.chance
 end
 if math.abs(total-1)>1e-9 then return false,"Crate rewards are unavailable." end
 local roll,cumulative=self.random:NextNumber(),0
 local species=definition.rewards[#definition.rewards].species
 for _,entry in definition.rewards do
  cumulative+=entry.chance
  if roll<cumulative then species=entry.species;break end
 end
 -- Atomic, nonyielding mutation: credit and pet are serialized in the same profile.
 local pet=session:AddPet(species,1)
 pet.investment=0 -- A Robux reward never fabricates a refundable coin investment.
 session.crateCredits-=1
 session:RefreshArmy();session:Touch()
 return true,Catalog[species].name.." joined your flock!",{species=species,level=1,petId=pet.id}
end

return CrateService
