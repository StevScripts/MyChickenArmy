-- Editor-only: author roster-expansion VFX into the staged templates (pattern of the
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
	local specs = {
		-- Mythic
		FirstHen = function(m)
			local core = anchor(m, "Runes", "BackSocket", {0, .5, 3.5}); light(core, {255, 200, 90}, .4, 5, 1.2, 1.6)
			loop(anchor(m, "Motes", "Body", {0, .1, 2.0}), "SandMotes", "Glitter", {255, 214, 120}, 3, .14, .35, .4)
			burst(core, "RuneRing", "Star", {255, 214, 90}, V, 12, .3, 2.2, 0)
		end,
		RiftWalker = function(m)
			loop(anchor(m, "SeamHead", "Head", {0, -.9, 4.4}), "RiftSpark", "Star", {255, 80, 220}, 3, .16, .5, .3)
			loop(anchor(m, "SeamBack", "Body", {0, 1.6, 2.4}), "RiftSparkCyan", "Star", {90, 240, 255}, 3, .16, .5, .3)
			burst(anchor(m, "Void", "Body", {0, 0, 2.2}), "VoidWisps", "Smoke", {90, 40, 150}, V, 8, .6, 1.2, .4)
		end,
		Supernova = function(m)
			local core = anchor(m, "Core", "ChestSocket", {0, -1.3, 2.1}); light(core, {255, 222, 150}, .6, 7, 1.8, 1.0)
			loop(anchor(m, "Shell", "Body", {0, 0, 2.2}), "NovaGlitter", "Glitter", {255, 246, 190}, 5, .16, .8, .2)
			burst(core, "NovaBurst", "Star", {255, 214, 80}, V, 16, .35, 3, 0)
		end,
		TimeKeeper = function(m)
			local glass = anchor(m, "Hourglass", "BackSocket", {0, .75, 3.6})
			loop(glass, "FallingSand", "Glitter", {255, 210, 90}, 3, .08, .1, -1.5, NumberRange.new(.4, .6))
			light(glass, {255, 214, 120}, .3, 3, .8, 2.0)
			burst(anchor(m, "Gear", "Head", {0, -.8, 4.6}), "TimeStars", "Star", {255, 222, 120}, V, 10, .25, 2, 0)
		end,
		Mecha = function(m)
			for _, s in {-1, 1} do
				local foot = anchor(m, "Thruster" .. s, if s < 0 then "Foot_L" else "Foot_R", {s * .62, .15, .15})
				local e = loop(foot, "Thrust", "Ember", {255, 150, 40}, 4, .3, 1.4, -2, NumberRange.new(.2, .35)); e.EmissionDirection = Enum.NormalId.Bottom
				local b = burst(foot, "ThrustBurst", "Ember", {255, 170, 60}, V, 10, .4, 2.5, -2); b.EmissionDirection = Enum.NormalId.Bottom
			end
			light(anchor(m, "Visor", "FaceSocket", {0, -1.55, 3.75}), {60, 230, 255}, .3, 3, .9, 1.4)
		end,
		Kitsune = function(m)
			for i, p in {{-1.6, -.4, 3.4}, {1.6, -.2, 3.9}, {1.45, 1.2, 2.6}} do
				loop(anchor(m, "Foxfire" .. i, "Body", p), "Foxfire", "Ember", {90, 170, 255}, 2, .32, .2, .5)
			end
			burst(anchor(m, "Spirit", "Body", {0, 0, 2.6}), "SpiritWisps", "Smoke", {240, 244, 255}, V, 6, .5, 1.2, .5)
		end,
		Kingslayer = function(m)
			loop(anchor(m, "Crown", "HatSocket", {.1, -.9, 4.6}), "CrownGlint", "Glitter", {255, 214, 90}, 2, .14, .3, .1)
			burst(anchor(m, "Cheer", "Body", {0, 0, 3.0}), "RoyalConfetti", "Confetti", multi({{255, 214, 90}, {130, 70, 200}}), V, 14, .22, 3, -2)
		end,
		Ascendant = function(m)
			loop(anchor(m, "Aura", "Body", {0, 0, 2.2}), "PearlGlitter", "Glitter", {255, 246, 220}, 3, .14, .5, .3)
			light(anchor(m, "Halo", "Head", {0, -.8, 4.75}), {255, 226, 150}, .4, 4, 1.0, 1.8)
			burst(anchor(m, "Ascend", "Body", {0, 0, 3.0}), "AscendStars", "Star", {255, 234, 160}, V, 10, .28, 2.4, 0)
		end,
		Eclipse = function(m)
			light(anchor(m, "Corona", "Body", {0, 0, 2.4}), {255, 160, 50}, .5, 6, 1.5, 1.4)
			loop(anchor(m, "Flare1", "Body", {1.1, 1.3, 2.9}), "FlareEmber", "Ember", {255, 160, 50}, 2, .26, .6, .8)
			loop(anchor(m, "Flare2", "Head", {-.9, -.8, 4.5}), "FlareEmber", "Ember", {255, 190, 80}, 2, .22, .6, .8)
			local smoke = loop(anchor(m, "Aura", "Body", {0, .3, 1.6}), "DarkAura", "Smoke", {110, 20, 20}, 2, .7, .3, .3); smoke.Transparency = seq(1, .75, 1)
		end,
		ForestGuardian = function(m)
			light(anchor(m, "Shrooms", "Body", {0, .6, 3.0}), {130, 255, 120}, .3, 4, .9, 2.2)
			loop(anchor(m, "Fireflies", "Body", {0, 0, 3.3}), "Fireflies", "Glitter", {170, 255, 120}, 3, .12, .4, .2)
			burst(anchor(m, "Leaves", "Head", {0, -.6, 5.0}), "LeafBurst", "Confetti", {110, 200, 70}, V, 10, .22, 2.4, -2)
		end,
		-- Legendary
		Phoenix = function(m)
			local tail = anchor(m, "Tail", "BackSocket", {0, 2.2, 3.3})
			loop(tail, "TailEmbers", "Ember", {255, 150, 40}, 5, .26, .7, 1)
			light(tail, {255, 140, 40}, .5, 5)
			burst(anchor(m, "Flare", "Body", {0, 0, 2.4}), "RebirthFlare", "Ember", {255, 190, 70}, V, 14, .45, 3, 1)
		end,
		Unicorn = function(m)
			loop(anchor(m, "Trail", "Body", {0, 1.4, 2.4}), "PastelTrail", "Glitter", multi({{255, 120, 190}, {170, 130, 255}, {90, 220, 200}}), 4, .15, .4, .2)
			burst(anchor(m, "Horn", "Head", {0, -1.3, 5.1}), "PastelStars", "Star", multi({{255, 140, 200}, {120, 200, 255}}), V, 12, .28, 2.4, 0)
		end,
		Kraken = function(m)
			local beard = anchor(m, "Tentacles", "Wattle", {0, -1.95, 2.3})
			burst(beard, "InkSplash", "Smoke", {50, 20, 70}, "Hit", 8, .6, 2, -1)
			loop(beard, "Drips", "Bubble", {170, 230, 255}, 1.5, .16, .3, .6)
		end,
		DragonKnight = function(m)
			loop(anchor(m, "Eyes", "FaceSocket", {0, -1.6, 3.75}), "EyeEmbers", "Ember", {255, 140, 40}, 2, .14, .4, .8)
			burst(anchor(m, "Horns", "Head", {0, -.6, 5.0}), "HornSmoke", "Smoke", {90, 90, 96}, V, 6, .6, 1.4, .6)
		end,
		Geode = function(m)
			light(anchor(m, "Crystals", "ChestSocket", {0, -1.3, 1.9}), {176, 104, 244}, .8, 5)
			loop(anchor(m, "Glints", "Body", {0, .4, 3.2}), "CrystalGlint", "Glitter", {214, 160, 255}, 3, .14, .4, .2)
			burst(anchor(m, "Shards", "Body", {0, -.6, 2.2}), "CrystalShards", "Glitter", {190, 120, 255}, "Hit", 8, .2, 2.4, -2)
		end,
		AirshipCaptain = function(m)
			local s = loop(anchor(m, "Pack", "BackSocket", {0, 1.95, 2.9}), "PackSteam", "Smoke", {236, 236, 236}, .6, .45, .5, .6); s.Transparency = seq(1, .5, 1)
		end,
		Pharaoh = function(m)
			loop(anchor(m, "Sand", "Root", {0, 0, .3}), "SandSwirl", "Glitter", {236, 200, 120}, 3, .1, .5, .2)
			burst(anchor(m, "Gold", "Head", {0, -.8, 4.6}), "GoldBurst", "Glitter", {255, 210, 70}, V, 10, .2, 2.2, -1)
		end,
		StainedGlass = function(m)
			light(anchor(m, "Inner", "Body", {0, 0, 2.2}), {255, 140, 200}, .4, 5, 1.0, 2.0)
			burst(anchor(m, "Shafts", "Head", {0, -.8, 4.7}), "PaneStars", "Star", RAINBOW, V, 12, .28, 2.4, 0)
		end,
		Moon = function(m)
			light(anchor(m, "Glow", "Head", {0, -.8, 4.9}), {170, 200, 255}, .7, 6)
			for _, s in {-1, 1} do
				loop(anchor(m, "Twinkle" .. s, if s < 0 then "Wing_L" else "Wing_R", {s * 1.3, .2, 1.8}), "Twinkle", "Star", {255, 240, 180}, 1, .14, .1, 0)
			end
		end,
		Witch = function(m)
			loop(anchor(m, "Hat", "HatSocket", {0, -.6, 5.2}), "HatStars", "Star", {200, 150, 255}, 2, .16, .3, .1)
			burst(anchor(m, "Cauldron", "Body", {0, -.6, 2.6}), "CauldronSparkle", "Glitter", {120, 255, 150}, V, 14, .22, 2.4, -1)
		end,
		Firework = function(m)
			loop(anchor(m, "Fuse", "HatSocket", {.34, -.85, 5.05}), "FuseSpark", "Glitter", {255, 230, 120}, 6, .1, 1, -1, NumberRange.new(.2, .4))
			burst(anchor(m, "Sky", "Head", {0, -.8, 5.6}), "FireworkBurst", "Confetti", RAINBOW, V, 16, .2, 4, -2)
		end,
		Olympian = function(m)
			local bolt = anchor(m, "Bolt", "Wing_R", {1.44, 0, 2.5})
			light(bolt, {255, 220, 90}, .4, 4, 1.2, .9)
			loop(bolt, "BoltSparks", "Glitter", {255, 236, 140}, 2, .1, .6, 0)
			burst(anchor(m, "Divine", "Body", {0, 0, 3.0}), "DivineGlitter", "Glitter", {255, 220, 120}, V, 10, .2, 2.2, -1)
		end,
		Aurora = function(m)
			light(anchor(m, "Glow", "Body", {0, 0, 2.4}), {80, 255, 170}, .4, 5, 1.1, 2.0)
		end,
		Jade = function(m)
			loop(anchor(m, "Glint", "Body", {0, 0, 2.4}), "JadeGlint", "Glitter", {120, 230, 160}, 1.5, .14, .3, .1)
			burst(anchor(m, "Gold", "Head", {0, -.8, 4.6}), "GoldGlitter", "Glitter", {255, 210, 70}, V, 8, .2, 2.2, -1)
		end,
		Griffin = function(m)
			burst(anchor(m, "Feathers", "Body", {0, 0, 2.8}), "FeatherBurst", "Confetti", multi({{250, 245, 230}, {150, 96, 46}}), V, 10, .24, 2.6, -2)
		end,
		Valkyrie = function(m)
			local tip = anchor(m, "Spear", "Wing_R", {1.44, -.46, 4.4})
			light(tip, {110, 200, 255}, .4, 4, 1.2, 1.0)
			burst(tip, "SpearSparks", "Glitter", {130, 210, 255}, "Attack", 4, .16, 2, 0)
			burst(anchor(m, "Wings", "Head", {0, -.8, 4.8}), "FeatherGlitter", "Glitter", {255, 255, 255}, V, 8, .2, 2, -1)
		end,
		-- Epic
		Pumpkin = function(m)
			local face = anchor(m, "Carving", "ChestSocket", {0, -1.3, 1.6})
			light(face, {255, 150, 40}, .5, 5, 1.1, .25)
			burst(face, "PumpkinEmbers", "Ember", {255, 160, 50}, V, 8, .26, 2, 1)
		end,
		Animatronic = function(m)
			light(anchor(m, "Eye", "FaceSocket", {.445, -1.6, 3.75}), {255, 40, 30}, .2, 3, .9, .35)
			burst(anchor(m, "Wires", "Body", {0, -1.3, 2.6}), "WireSparks", "Glitter", {255, 230, 120}, "Hit", 6, .14, 2.4, -2)
		end,
		Vampire = function(m)
			burst(anchor(m, "Bats", "Body", {0, 0, 3.1}), "BatSwarm", "Bat", {70, 30, 90}, V, 5, .45, 3, 1)
		end,
		DeepseaDiver = function(m)
			loop(anchor(m, "Valve", "HatSocket", {0, -.6, 4.8}), "HelmetBubbles", "Bubble", {200, 240, 255}, 2, .2, .6, 1)
		end,
		DragonHatchling = function(m)
			burst(anchor(m, "Beak", "Beak", {0, -2.2, 3.1}), "BeakEmbers", "Ember", {255, 140, 40}, "Attack", 5, .22, 1.6, .5)
			burst(anchor(m, "Puff", "Head", {0, -.8, 4.6}), "SmokeRing", "Smoke", {150, 150, 156}, V, 6, .5, 1.2, .5)
		end,
		Neon = function(m)
			light(anchor(m, "Underglow", "Root", {0, 0, .2}), {255, 60, 200}, .5, 5, 1.2, 2.0)
		end,
		Gingerbread = function(m)
			local top = anchor(m, "Snow", "Head", {0, -.8, 4.8})
			burst(top, "Snowflakes", "Star", {255, 255, 255}, V, 10, .2, 2, -1)
			burst(top, "Jingle", "Note", {255, 214, 90}, V, 3, .3, 1.5, 0)
		end,
		Yeti = function(m)
			loop(anchor(m, "Frost", "Body", {0, 0, 2.6}), "Frost", "Star", {200, 230, 255}, 2, .12, .3, .1)
			burst(anchor(m, "Breath", "Beak", {0, -2.2, 3.1}), "FrostBreath", "Smoke", {240, 248, 255}, V, 4, .45, 1.2, .3)
		end,
		Mimic = function(m)
			burst(anchor(m, "Lid", "Body", {0, .5, 3.2}), "GoldCoins", "Glitter", {255, 210, 70}, V, 10, .22, 2.4, -2)
		end,
		Gladiator = function(m)
			burst(anchor(m, "Shield", "Wing_R", {1.5, -.05, 1.95}), "ShieldSpark", "Glitter", {255, 220, 140}, "Hit", 4, .16, 2, -1)
		end,
		-- Rare and below
		ZombieHunter = function(m)
			light(anchor(m, "Flashlight", "Body", {-.55, -1.55, 2.5}), {255, 244, 200}, .6, 6)
		end,
		Mummy = function(m)
			light(anchor(m, "Eye", "FaceSocket", {-.445, -1.6, 3.75}), {120, 255, 120}, .4, 3)
			burst(anchor(m, "Dust", "Body", {0, 0, 1.6}), "BandageDust", "Smoke", {200, 186, 150}, "Hit", 6, .5, 1, .2)
		end,
		Jester = function(m)
			local top = anchor(m, "Bells", "Head", {0, -.8, 4.8})
			burst(top, "JesterConfetti", "Confetti", RAINBOW, V, 10, .2, 2.6, -2)
			burst(top, "Jingle", "Note", {255, 214, 90}, V, 2, .3, 1.5, 0)
		end,
		Ironbeak = function(m)
			burst(anchor(m, "Beak", "Beak", {0, -2.2, 3.1}), "BeakSpark", "Glitter", {255, 230, 160}, "Attack", 4, .14, 2, -1)
		end,
		CastleGuard = function(m)
			burst(anchor(m, "Shield", "Wing_R", {1.5, -.05, 1.95}), "ShieldSpark", "Glitter", {255, 230, 160}, "Hit", 4, .14, 2, -1)
		end,
		Steampunk = function(m)
			local s = loop(anchor(m, "Pipe", "Body", {.45, 1.62, 3.65}), "Steam", "Smoke", {236, 236, 236}, .5, .45, .6, .6); s.Transparency = seq(1, .5, 1)
		end,
		Detective = function(m)
			burst(anchor(m, "Lens", "Wing_R", {.92, -1.5, 2.3}), "LensGlint", "Glitter", {255, 255, 255}, V, 3, .2, .4, 0)
		end,
		Miner = function(m)
			light(anchor(m, "Lamp", "HatSocket", {0, -1.85, 4.53}), {255, 240, 190}, .7, 7)
			burst(anchor(m, "Pick", "Beak", {0, -2.2, 3.0}), "PickSpark", "Glitter", {255, 220, 140}, "Attack", 3, .14, 1.8, -1)
		end,
		Coral = function(m)
			loop(anchor(m, "Reef", "Head", {0, -.8, 4.5}), "Bubbles", "Bubble", {200, 240, 255}, .8, .18, .5, .8)
		end,
		Pajama = function(m)
			loop(anchor(m, "Sleep", "HatSocket", {.6, -.6, 5.0}), "Zzz", "Zzz", {255, 255, 255}, .4, .45, .3, .4, NumberRange.new(1.4, 2))
		end,
		Party = function(m)
			burst(anchor(m, "Hat", "Head", {.2, -.8, 5.2}), "PartyConfetti", "Confetti", RAINBOW, V, 14, .2, 3, -2)
		end,
		Popcorn = function(m)
			burst(anchor(m, "Pop", "Body", {0, 0, 3.0}), "Kernels", "Confetti", multi({{255, 250, 236}, {250, 220, 120}}), "Hit", 6, .2, 2.4, -3)
		end,
		Gamer = function(m)
			light(anchor(m, "Headset", "Head", {.85, -.8, 3.7}), {255, 60, 200}, .3, 3, .9, 1.5)
		end,
		Donut = function(m)
			burst(anchor(m, "Sprinkles", "Head", {0, -.8, 4.6}), "Sprinkles", "Confetti", RAINBOW, V, 10, .16, 2.4, -2)
		end,
		Piggy = function(m)
			burst(anchor(m, "Mud", "Body", {0, 0, 1.4}), "MudSplat", "Smoke", {120, 80, 50}, "Hit", 4, .5, 1, -1)
		end,
		Snowman = function(m)
			loop(anchor(m, "Snowfall", "Head", {0, -.8, 5.6}), "Snowfall", "Star", {255, 255, 255}, 2, .12, .2, -1, NumberRange.new(1, 1.5))
			burst(anchor(m, "Puff", "Body", {0, 0, 2.2}), "SnowPuff", "Smoke", {245, 250, 255}, "Hit", 6, .5, 1.2, -.5)
		end,
		Ghost = function(m)
			local s = loop(anchor(m, "Wisps", "Body", {0, .6, 1.0}), "GhostWisps", "Smoke", {150, 230, 250}, 2, .5, .3, .4); s.Transparency = seq(1, .6, 1)
			light(anchor(m, "Glow", "Body", {0, 0, 2.4}), {150, 230, 250}, .5, 5)
		end,
		Rockstar = function(m)
			burst(anchor(m, "Guitar", "Body", {0, 1.6, 2.6}), "Notes", "Note", {255, 255, 255}, V, 4, .32, 1.8, .2)
		end,
		Painter = function(m)
			burst(anchor(m, "Palette", "Wing_R", {1.43, -.1, 2.0}), "PaintSplats", "Confetti", RAINBOW, V, 10, .2, 2.4, -2)
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
