--!strict
-- A bounty belongs to one defeated life, not to conquest completion.
local Config = require(script.Parent.Config)
local Catalog = require(script.Parent.PetCatalog)
local CombatRewards = {}
-- The King's bounty pays in full once per player; later kills pay this share,
-- like Operation replays, so unclaim/re-kill cannot farm the full bounty.
CombatRewards.BossRepeatFraction = 0.1

function CombatRewards.ForUnit(unit, pvpRank: number?, repeatBoss: boolean?): number
 local definition = Catalog[unit.species]
 local species = if definition then definition.economyBase or unit.species else unit.species
 local amount = if unit.boss then Config.KingKillCoins * (if repeatBoss then CombatRewards.BossRepeatFraction else 1)
  else (Config.KillCoins[species] or 0) * (1 + (math.clamp(unit.level or 1,1,Config.MaxPetLevel)-1) * Config.KillLevelBonus)
 -- Player duels still pay every kill, but cannot turn a friend's costly units
 -- into a shortcut past the attacker's unlocked NPC progression.
 if pvpRank then
  local rank=math.clamp(math.floor(pvpRank),1,#Config.PvPKillCaps)
  amount=math.min(amount*Config.PvPKillMultiplier,Config.PvPKillCaps[rank])
 end
 return math.max(0,math.floor(amount+0.5))
end

function CombatRewards.Range(roster, pvpRank: number?)
 local low,high=math.huge,0
 for _,unit in roster do
  local amount=CombatRewards.ForUnit(unit,pvpRank)
  low,high=math.min(low,amount),math.max(high,amount)
 end
 return if low==math.huge then 0 else low,high
end
return CombatRewards
