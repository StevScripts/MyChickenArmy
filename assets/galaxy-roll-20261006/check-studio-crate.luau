-- Disposable Edit-mode fixtures. No checkout, DataStore calls, real sessions,
-- world models, or GameServer.new. Run after syncing through Studio Flow.
do
	local Http=game:GetService("HttpService")
	local RunService=game:GetService("RunService")
	if not RunService:IsStudio() or RunService:IsRunning() then
		return Http:JSONEncode({ok=false,error="Run these isolated fixtures in Studio Edit mode."})
	end
	local report={name="Disposable Studio crate fixtures",cases={}}
	local clones={}
	local function expect(value,message) assert(value,message or "Expectation failed") end
	local function fresh(source,name)
		local original=source:FindFirstChild(name)
		expect(original and original:IsA("ModuleScript"),"Missing synced module "..name)
		local copy=original:Clone()
		copy.Name="StudioCrateFixture_"..name.."_"..Http:GenerateGUID(false)
		copy.Parent=source -- Preserve relative sibling requires; constructors are never called.
		table.insert(clones,copy)
		return require(copy)
	end
	local function check(name,callback)
		local ok,err=pcall(callback)
		table.insert(report.cases,{name=name,ok=ok,error=if ok then nil else tostring(err)})
	end
	local function session(credits)
		local s={userId=900007,loaded=true,closing=false,saveLost=false,
			saveStatus="studio-session",paidRandomAllowed=true,crateCredits=credits or 0,
			coins=2400,pets={},limit=25,touches=0}
		function s:Count() return #self.pets end
		function s:CollectionLimit() return self.limit end
		function s:AddPet(species,level)
			local pet={id="fixture-pet-"..tostring(#self.pets+1),species=species,level=level}
			table.insert(self.pets,pet)
			return pet
		end
		function s:RefreshArmy() end
		function s:Touch() self.touches+=1 end
		function s:BestPetIds() return {} end
		return s
	end
	local ran,bootstrapError=pcall(function()
		local source=game:GetService("ServerStorage"):FindFirstChild("PetRoll")
		expect(source~=nil,"Missing synced ServerStorage.PetRoll")
		local Crates=fresh(source,"CrateService")
		local Commerce=fresh(source,"CommerceService")
		local Server=fresh(source,"GameServer")
		local function service()
			return Crates.new({random={NextNumber=function() return 0 end}})
		end
		local function serverHarness(s)
			local h={session=s,results={},recruits={},player={UserId=s.userId}}
			h.server=setmetatable({sessions={[s.userId]=s},limits={},crates=service(),
				commerce={TestAllowed=Commerce.TestAllowed},
				products={CanPurchase=function() return false end},
				tutorial={Action=function() end},armyCommands={Sync=function() end},
				world={UpdateSession=function() end,
					Recruit=function(_,which,petId)
						expect(which==s,"Recruit must receive the fake session")
						table.insert(h.recruits,petId)
					end},
				Send=function(_,player,result)
					expect(player==h.player,"Result must address the fake player")
					table.insert(h.results,result)
				end},Server)
			function h:Request(action)
				self.server:Handle(self.player,{action=action,id=#self.results+1})
				return self.results[#self.results]
			end
			return h
		end
		check("OpenTest awards with zero credits and restores zero",function()
			local s=session(0)
			local ok,message,crate=service():OpenTest(s)
			expect(ok and crate and crate.preview==true,"Expected a marked test reward")
			expect(s.crateCredits==0 and #s.pets==1,"One pet, no retained test credit")
			expect(s.pets[1].id==crate.petId and s.pets[1].species==crate.species,"Return the authoritative award")
			expect(s.pets[1].investment==0,"A test award must not fabricate coin investment")
			expect(string.find(message,"TEST",1,true) and string.find(message,"not save",1,true),"Explain temporary test status")
		end)
		check("OpenTest preserves existing credits",function()
			local s=session(7)
			local ok=service():OpenTest(s)
			expect(ok and #s.pets==1 and s.crateCredits==7,"Never consume existing credits")
		end)
		check("Full flock denies without leaking credits or pets",function()
			local s=session(7);s.limit=0
			local ok=service():OpenTest(s)
			expect(not ok and s.crateCredits==7 and #s.pets==0,"Capacity rejection must preserve all state")
		end)
		check("Account policy still denies test rewards",function()
			local s=session(7);s.paidRandomAllowed=false
			local ok=service():OpenTest(s)
			expect(not ok and s.crateCredits==7 and #s.pets==0,"Test opening must preserve policy enforcement")
		end)
		check("Unexpected opening exception restores credits",function()
			local s=session(7)
			local crates=service()
			crates.Open=function() error("Fixture opening exception") end
			local ok,err=pcall(function() crates:OpenTest(s) end)
			expect(not ok and string.find(tostring(err),"Fixture opening exception",1,true),"Preserve the underlying error")
			expect(s.crateCredits==7 and #s.pets==0,"Exception must not leak the temporary credit")
		end)
		check("Real commerce eligibility rejects saved sessions",function()
			local s=session(7);s.saveStatus="ready"
			expect(Commerce.TestAllowed({},s)==false,"Saved sessions must not qualify")
			local h=serverHarness(s)
			local result=h:Request("TestCrate")
			expect(result and result.ok==false and result.action=="TestCrate","Reject through the normal response flow")
			expect(s.crateCredits==7 and #s.pets==0 and #h.recruits==0,"No reward or recruit may occur")
		end)
		check("Real commerce eligibility requires healthy loaded disposable sessions",function()
			for _,flag in {"loaded","closing","saveLost"} do
				local s=session(0)
				s[flag]=flag~="loaded"
				expect(Commerce.TestAllowed({},s)==false,"Ineligible state: "..flag)
			end
		end)
		check("Disposable TestCrate recruits once and enforces cooldown",function()
			local s=session(3)
			expect(Commerce.TestAllowed({},s)==true,"Healthy Studio session should qualify")
			local h=serverHarness(s)
			local before=os.clock()
			local result=h:Request("TestCrate")
			expect(result and result.ok==true and result.action=="TestCrate","Test action should succeed")
			expect(result.crate.preview==true and #h.recruits==1 and h.recruits[1]==result.crate.petId,"Normal recruitment and marked reel result expected")
			expect(#s.pets==1 and s.crateCredits==3,"One temporary award; credits unchanged")
			expect(s.testCrateReadyAt>=before+12 and s.testCrateReadyAt<=os.clock()+12,"Use the 12-second server cooldown")
			local denied=h:Request("TestCrate")
			expect(denied and denied.ok==false and #s.pets==1 and #h.recruits==1,"Immediate second roll must be denied")
			s.testCrateReadyAt=os.clock()-1 -- Advance only the fake session's eligibility.
			local nextResult=h:Request("TestCrate")
			expect(nextResult.ok==true and #s.pets==2 and #h.recruits==2 and s.crateCredits==3,"Allow another roll after cooldown")
		end)
		check("Failed TestCrate does not start cooldown",function()
			local s=session(3);s.limit=0
			local h=serverHarness(s)
			local result=h:Request("TestCrate")
			expect(result.ok==false and s.testCrateReadyAt==nil and s.crateCredits==3,"Rejection cannot consume cooldown or credits")
		end)
		check("Normal OpenCrate still requires product-ready saved progress",function()
			local s=session(3)
			local h=serverHarness(s)
			local result=h:Request("OpenCrate")
			expect(result and result.ok==false and result.action=="OpenCrate","Paid opening must still reject productReady=false")
			expect(s.crateCredits==3 and #s.pets==0 and #h.recruits==0,"Paid opening cannot consume or award in a test session")
		end)
	end)
	for _,copy in clones do copy:Destroy() end
	report.passed,report.failed=0,0
	for _,case in report.cases do
		if case.ok then report.passed+=1 else report.failed+=1 end
	end
	report.ok=ran and report.failed==0
	report.cleanup=true
	if not ran then report.bootstrapError=tostring(bootstrapError) end
	return Http:JSONEncode(report)
end
