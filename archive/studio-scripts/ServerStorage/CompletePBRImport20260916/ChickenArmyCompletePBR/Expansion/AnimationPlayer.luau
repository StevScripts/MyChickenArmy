-- Explicitly scheduled clip player for the expansion assets; no autonomous loop.
local Player = {}
Player.__index = Player

function Player.new(model, data)
    local self = setmetatable({model=model, data=data, bones={}, name="Idle", start=0}, Player)
    for _, bone in model:GetDescendants() do
        if bone:IsA("Bone") then
            self.bones[bone.Name] = self.bones[bone.Name] or {}
            table.insert(self.bones[bone.Name], bone)
        end
    end
    return self
end

function Player:Play(name, now)
    assert(self.data.clips[name], "Unknown chicken clip: " .. name)
    self.name, self.start = name, now or 0
end

function Player:Step(now)
    local clip = self.data.clips[self.name]
    local at = math.max(0, now-self.start)
    at = if clip.loop then at % clip.duration else math.min(at, clip.duration)
    local frames = clip.frames
    local lo, hi = 1, #frames
    while hi-lo > 1 do
        local mid = math.floor((hi+lo)/2)
        if frames[mid].time <= at then lo=mid else hi=mid end
    end
    local a, b = frames[lo], frames[hi]
    local alpha = math.clamp((at-a.time)/math.max(b.time-a.time, 0.0001),0,1)
    local scale = self.model:GetScale()
    for i, name in self.data.bones do
        local pose = CFrame.new(table.unpack(a.poses[i])):Lerp(CFrame.new(table.unpack(b.poses[i])), alpha)
        pose = pose.Rotation + pose.Position*scale
        for _, bone in self.bones[name] or {} do bone.Transform=pose end
    end
end

function Player:Reset()
    for _, group in self.bones do for _, bone in group do bone.Transform=CFrame.identity end end
end

function Player:Destroy()
    self:Reset()
    table.clear(self.bones)
end

return Player
