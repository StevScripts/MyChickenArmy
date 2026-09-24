--!strict
-- Structural engine checks for the shared home/podium/battle duck factory.
-- Uses disposable models far away from the live map, then destroys them all.
local Shared = game:GetService("ReplicatedStorage").PetRoll.Shared
local PetView = require(Shared.PetView)
local Catalog = require(Shared.PetCatalog)
local Checks = {}

local function close(a: number, b: number, message: string)
	assert(math.abs(a - b) < 0.002, message .. ": " .. tostring(a) .. " versus " .. tostring(b))
end

function Checks.Run()
	local folder = Instance.new("Folder")
	folder.Name = "PetVisualChecks_Temporary"
	folder.Parent = workspace
	local results, metrics = {}, {}
	local function test(name, operation)
		local ok, why = pcall(operation)
		table.insert(results, {name = name, passed = ok, error = if ok then nil else tostring(why)})
	end
	local fatalOK, fatalError = xpcall(function()
		for _, species in Catalog.Order do
			local foot = Vector3.new(10000, 1000, 10000)
			local model
			test(species .. " is a bounded, grounded native duck", function()
				model = PetView.Create(folder, "Check_" .. species, species, 1, foot)
				assert(model.PrimaryPart and model.PrimaryPart.Name == "Body", "Visible Body must remain the primary part")
				assert(model:FindFirstChild("Head") and model:FindFirstChild("Bill"), "Duck silhouette needs a head and bill")
				local parts = 0
				for _, item in model:GetDescendants() do
					assert(not item:IsA("LuaSourceContainer") and not item:IsA("Humanoid"), "Pet model cannot create scripts or Humanoids")
					assert(not item:IsA("MeshPart") and not item:IsA("SpecialMesh"), "This authored roster must not depend on imported meshes")
					if item:IsA("BasePart") then
						parts += 1
						assert(item.Anchored and not item.CanCollide and not item.CanTouch and not item.CanQuery, "Every cosmetic part must be non-interactive")
						assert(item.Transparency == 0, "No invisible root should become visible on camp respawn")
					end
				end
				assert(parts <= 25, "Duck exceeds the 25-part art budget")
				local cf, bounds = model:GetBoundingBox()
				close(cf.Position.Y - bounds.Y / 2, foot.Y, "Feet should meet the supplied floor")
				assert(bounds.X < 8 and bounds.Z < 8, "Duck should fit the 8-stud rolling podium")
				assert(bounds.Y > 2 and bounds.Y < 8, "Duck height should be readable beside a Roblox character")
				metrics[species] = {parts = parts, width = bounds.X, height = bounds.Y, depth = bounds.Z}
			end)
			if model then
				test(species .. " moves its bill forward and respects reduced motion", function()
					model:SetAttribute("ReducedMotion", true)
					local destination = foot + Vector3.new(3, 0, 2)
					PetView.Move(model, destination, Vector3.xAxis, 0.8)
					local root = model.PrimaryPart
					local bill = model:FindFirstChild("Bill")
					assert(bill.Position.X > root.Position.X, "Bill faces backward when moving +X")
					close(root.Position.X, destination.X, "Move X drift")
					close(root.Position.Z, destination.Z, "Move Z drift")
					local cf, bounds = model:GetBoundingBox()
					close(cf.Position.Y - bounds.Y / 2, destination.Y, "Reduced motion must suppress attack hops")
					local facing = root.CFrame.LookVector
					PetView.Move(model, destination, nil)
					assert(root.CFrame.LookVector:Dot(facing) > 0.999, "Missing direction should preserve facing")
				end)
				test(species .. " switches cleanly between home cash and battle health", function()
					local tag = model.PrimaryPart:FindFirstChild("Tag")
					assert(tag and tag:FindFirstChild("NameLabel") and tag:FindFirstChild("Health"), "Existing Tag API paths must stay available")
					assert(not string.find(tag.NameLabel.Text, "★", 1, true), "Removed merging stars should not remain in names")
					PetView.Cash(model, 127.75, true)
					assert(tag.Cash.Visible and tag.Cash.Text == "$127", "Stored cash must be legible without fractional noise")
					assert(not tag.NameLabel.Visible and not tag.Health.Visible, "Home cash should not stack with name and health")
					assert(tag.MaxDistance <= 40, "Cash labels should stay local to the yard")
					PetView.Cash(model, 0, true)
					assert(not tag.Cash.Visible, "Zero balances should not clutter a full yard")
					PetView.Health(model, 0.25)
					assert(tag.Health.Visible and not tag.Cash.Visible, "Battle mode should show health without home money")
					close(tag.Health.Fill.Size.X.Scale, 0.25, "Health fill ratio")
					PetView.Health(model, 0)
					assert(not tag.Health.Visible, "Defeated units should not retain an empty overhead bar")
					PetView.Cash(model, 10, false)
					assert(tag.NameLabel.Visible and not tag.Cash.Visible, "Non-home displays can restore the ordinary name")
				end)
				test(species .. " hit feedback restores every authored color", function()
					local colors = {}
					for _, item in model:GetDescendants() do if item:IsA("BasePart") then colors[item] = item.Color end end
					PetView.Flash(model, true)
					assert(model.PrimaryPart.Color ~= colors[model.PrimaryPart], "Hit should visibly brighten the duck")
					local bright = model.PrimaryPart.Color
					PetView.Flash(model, true)
					assert(model.PrimaryPart.Color == bright, "Repeated active flash must not accumulate tint")
					PetView.Flash(model, false)
					for item, color in colors do assert(item.Color == color, "Authored accessory color was lost after a hit") end
				end)
				model:Destroy()
			end
		end
		test("Engine-owned ducks stay movable across fresh hierarchy lookups", function()
			local owner = Instance.new("Folder")
			owner.Name = "HierarchyOwnedDuck"
			owner.Parent = folder
			-- Deliberately keep no caller-side reference to the returned model.
			PetView.Create(owner, "Resident", "Duck", 1, Vector3.new(10000, 1000, 10000))
			for step = 1, 8 do
				-- Bounded allocation and scheduler turns exercise ordinary wrapper
				-- lifetimes; Roblox does not expose deterministic forced collection.
				do
					local temporary = {}
					for index = 1, 1000 do temporary[index] = {index, step} end
				end
				task.wait()
				local resident = owner:FindFirstChild("Resident")
				assert(resident and resident:IsA("Model"))
				resident:SetAttribute("ReducedMotion", true)
				PetView.Move(resident, Vector3.new(10000 + step, 1000, 10000), Vector3.xAxis)
				close(resident.PrimaryPart.Position.X, 10000 + step, "Hierarchy-owned duck lost its movement pose")
			end
			owner:Destroy()
		end)
	end, debug.traceback)
	folder:Destroy()
	if not fatalOK then table.insert(results, {name = "Visual check harness", passed = false, error = tostring(fatalError)}) end
	local passed = 0
	for _, result in results do if result.passed then passed += 1 end end
	return {passed = passed == #results, count = #results, passedCount = passed, results = results, metrics = metrics}
end

return Checks
