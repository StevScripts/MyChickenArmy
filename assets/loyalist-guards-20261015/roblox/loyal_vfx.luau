-- Editor-only: author Loyalist guard VFX (October 15) into the staged templates (pattern of the
-- Sept 27 install_vfx). Loops are native emitters/lights on bone attachments that the
-- existing imported-effect lifecycle shows/hides (distance, reduced motion, defeat).
-- Bursts are disabled emitters tagged RosterBurst/RosterBurstCount; SpecialChickenVFX
-- emits them on the clip serials. Pulsing lights carry RosterPulse/RosterPulseTime.
-- Points use Blender rig coordinates (X right, Y back, Z up), converted to Roblox.
return function(models, T)
	local SCALE = 0.670163170
	local function c3(c) return Color3.fromRGB(c[1], c[2], c[3]) end
	local function seq(a, b, c) return NumberSequence.new({NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(.3, b), NumberSequenceKeypoint.new(1, c)}) end
	local function anchor(m, label, bone, point)
		local b = assert(m.Body:FindFirstChild(m.Name .. "_" .. bone, true), m.Name .. " missing bone " .. bone)
		local a = Instance.new("Attachment"); a.Name = "RosterVFX_" .. label; a.Parent = b
		local p = Vector3.new(point[1], point[3], -point[2]) * SCALE
		a.CFrame = b.WorldCFrame:ToObjectSpace(CFrame.new(p)); return a
	end
	local function emitter(a, label, tex, color, size, speed, gravity, life)
		local e = Instance.new("ParticleEmitter"); e.Name = label; e.Texture = assert(T[tex], "texture " .. tex)
		e.Color = if typeof(color) == "ColorSequence" then color else ColorSequence.new(c3(color))
		e.Lifetime = life or NumberRange.new(.5, 1.05); e.Size = seq(0, size, 0); e.Transparency = seq(.9, .1, 1)
		e.Speed = NumberRange.new(speed * .55, speed); e.Acceleration = Vector3.new(0, gravity, 0)
		e.SpreadAngle = Vector2.new(28, 28); e.Rotation = NumberRange.new(0, 360); e.RotSpeed = NumberRange.new(-35, 35)
		e.LightEmission = .75; e.LightInfluence = 0; e.Brightness = 1.4; e.Parent = a
		return e
	end
	local function loop(a, label, tex, color, rate, size, speed, gravity, life)
		local e = emitter(a, label, tex, color, size, speed, gravity, life); e.Rate = rate; e.Enabled = true; return e
	end
	local function burst(a, label, tex, color, on, count, size, speed, gravity, life)
		local e = emitter(a, label, tex, color, size, speed, gravity, life); e.Rate = 0; e.Enabled = false
		e.SpreadAngle = Vector2.new(60, 60); e:SetAttribute("RosterBurst", on); e:SetAttribute("RosterBurstCount", count); return e
	end
	local function light(a, color, brightness, range, peak, period)
		local l = Instance.new("PointLight"); l.Name = "RosterGlow"; l.Color = c3(color); l.Brightness = brightness
		l.Range = range; l.Shadows = false; l.Enabled = true; l.Parent = a
		if peak then l:SetAttribute("RosterPulse", peak); l:SetAttribute("RosterPulseTime", period or 1.2) end
		return l
	end
	local function multi(colors)
		local keys = {}
		for i, c in colors do keys[i] = ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c3(c)) end
		return ColorSequence.new(keys)
	end
	local RAINBOW = multi({{255, 80, 120}, {255, 210, 60}, {80, 220, 120}, {70, 170, 255}, {190, 110, 255}})
	local V = "Victory"
	local A, H, V = "Attack", "Hit", "Victory"
	local EMBER, VIOLET, FROST, GOLDEN, STORM = {255, 130, 40}, {190, 120, 255}, {190, 235, 255}, {255, 214, 90}, {255, 230, 80}
	local specs = {
		LoyalAnvilBrute = function(m)
			burst(anchor(m, "Anvil", "Wing_R", {1.42, -.66, 4.97}), "AnvilSparks", "Ember", EMBER, A, 8, .22, 2.6, -3)
		end,
		LoyalMortarHen = function(m)
			local muzzle = anchor(m, "Muzzle", "Body", {.95, -.47, 4.43})
			burst(muzzle, "MuzzleSmoke", "Smoke", {200, 196, 186}, A, 5, .6, 1.4, .6)
			burst(muzzle, "MuzzleEmbers", "Ember", EMBER, A, 6, .2, 2.4, -2)
		end,
		LoyalShadowBulwark = function(m)
			light(anchor(m, "Visor", "Head", {0, -1.62, 4.34}), VIOLET, .35, 4, 1.0, 1.6)
		end,
		LoyalShadowGunner = function(m)
			local muzzle = anchor(m, "Muzzle", "Wing_R", {1.38, -1.73, 2.98})
			light(muzzle, VIOLET, .3, 4)
			burst(muzzle, "VioletFlash", "Star", VIOLET, A, 6, .3, 2.6, 0)
			burst(muzzle, "MuzzleSmoke", "Smoke", {90, 80, 120}, A, 4, .5, 1.2, .5)
		end,
		LoyalNightCaptain = function(m)
			local lantern = anchor(m, "Lantern", "Wing_R", {1.42, -1.05, 3.84})
			light(lantern, VIOLET, .5, 6, 1.2, 1.8)
			loop(lantern, "LanternMotes", "Glitter", VIOLET, 1.5, .12, .3, .4)
		end,
		LoyalFrostGunner = function(m)
			burst(anchor(m, "Harpoon", "Wing_R", {1.4, -1.9, 2.86}), "FrostShards", "Glitter", FROST, A, 8, .18, 2.4, -1)
		end,
		LoyalHonorGuard = function(m)
			burst(anchor(m, "Halberd", "Wing_R", {1.42, -1.55, 4.3}), "HalberdEmbers", "Ember", EMBER, A, 6, .2, 2.2, -2)
		end,
		LoyalEmberAdept = function(m)
			local orb = anchor(m, "Orb", "Wing_R", {1.42, -.64, 4.86})
			light(orb, EMBER, .5, 6, 1.3, 1.2)
			loop(orb, "OrbEmbers", "Ember", EMBER, 3, .16, .5, .8)
			burst(orb, "OrbBurst", "Ember", EMBER, A, 10, .24, 3, 0)
		end,
		LoyalDragonCommander = function(m)
			loop(anchor(m, "Sword", "Wing_R", {1.42, -.7, 3.6}), "SwordFlame", "Ember", EMBER, 4, .2, .5, 1.2)
			light(anchor(m, "Eyes", "Head", {0, -1.6, 4.73}), {255, 190, 60}, .35, 4)
			local chest = anchor(m, "Roar", "Head", {0, -1.9, 4.5})
			burst(chest, "RoarEmbers", "Ember", EMBER, A, 10, .26, 3, 0)
			burst(chest, "RoarSmoke", "Smoke", {80, 60, 60}, A, 4, .6, 1.2, .4)
		end,
		LoyalGlacierLancer = function(m)
			loop(anchor(m, "Crystal", "Wing_R", {1.42, -1.5, 5.0}), "FrostGlitter", "Glitter", FROST, 2.5, .14, .3, -.3)
		end,
		LoyalDrakeKnight = function(m)
			local blade = anchor(m, "Blade", "Wing_R", {1.44, -.5, 3.8})
			loop(blade, "BladeFlame", "Ember", EMBER, 3, .18, .4, 1)
			burst(blade, "BladeBurst", "Ember", EMBER, A, 8, .22, 2.6, -1)
		end,
		LoyalShieldbearer = function(m)
			burst(anchor(m, "Crest", "Wing_R", {1.56, -.2, 2.2}), "CrestGlint", "Glitter", FROST, H, 6, .2, 1.8, 0)
		end,
		LoyalRoyalWarden = function(m)
			burst(anchor(m, "Mace", "Wing_R", {1.42, -.45, 4.3}), "MaceEmbers", "Ember", EMBER, A, 8, .22, 2.6, -2)
		end,
		LoyalStormHerald = function(m)
			burst(anchor(m, "Bell", "Wing_R", {1.42, -1.98, 3.96}), "ThunderSparks", "Star", STORM, A, 8, .26, 3, 0)
		end,
		LoyalFrostGuard = function(m)
			loop(anchor(m, "Axe", "Wing_R", {1.42, -1.1, 4.35}), "FrostGlitter", "Glitter", FROST, 2, .14, .3, -.3)
		end,
		LoyalFlameGuard = function(m)
			loop(anchor(m, "Flame", "Wing_R", {1.42, -.52, 5.3}), "HalberdFlame", "Ember", EMBER, 4, .2, .5, 1.2)
		end,
		LoyalThunderGuard = function(m)
			loop(anchor(m, "Bolts", "Wing_R", {1.42, -.9, 4.6}), "BoltSparks", "Star", STORM, 2.5, .16, .5, 0)
		end,
		LoyalArmadaKing = function(m)
			loop(anchor(m, "Crown", "Head", {0, -.75, 5.2}), "CrownGlitter", "Glitter", GOLDEN, 3, .14, .3, .3)
			light(anchor(m, "Scepter", "Wing_R", {1.42, -.74, 4.76}), GOLDEN, .5, 6, 1.2, 1.6)
			burst(anchor(m, "Decree", "Head", {0, -1.6, 4.4}), "RoyalStars", "Star", GOLDEN, A, 10, .3, 2.8, 0)
		end,
	}
	local done = {}
	for _, m in models:GetChildren() do
		local spec = specs[m.Name]
		if spec and not m:GetAttribute("RosterVFXReady") then
			spec(m); m:SetAttribute("RosterVFXReady", true); table.insert(done, m.Name)
		end
	end
	return done
end
