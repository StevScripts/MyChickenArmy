--!strict
-- Garden-style world dialogue. Selling rules and requests belong to SellBrowser.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.UITheme)
local Dialogue = {}
Dialogue.__index = Dialogue

local WIDTH, ROW, RESPONSE_X, HOVER = 520, 520 / 12.953773498535156, 48, 22
local QUESTION_WIDTH, QUESTION_HEIGHT = 0.26350462436676025, 0.03614457696676254
local RESPONSE_SIZE, SPEECH_SIZE = 38, 31
local WHITE, CREAM = Color3.new(1, 1, 1), Color3.fromRGB(255, 255, 190)
local OUTLINE = Color3.fromRGB(37, 37, 37)

local function label(parent, name, text, size, color)
 local item = Instance.new("TextLabel")
 item.Name, item.Text, item.Font = name, text, Theme.Font
 item.BackgroundTransparency, item.TextColor3, item.TextSize = 1, color or WHITE, size
 item.TextXAlignment, item.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Center
 item.TextStrokeTransparency, item.ZIndex, item.TextScaled = 1, 2, true
 local stroke = Instance.new("UIStroke")
 stroke.Name, stroke.Color, stroke.Thickness, stroke.Parent = "TextOutline", OUTLINE, 2, item
 item.Parent = parent
 Theme.ScaleText(item)
 return item
end

function Dialogue.new(app)
 local self = setmetatable({app = app, serial = 0, tweens = {}}, Dialogue)
 local gui=Theme.InsetContainer(app.other,"MerchantDialogue",Enum.ScreenInsets.None)
 gui.ZIndex=50
 self.gui = gui
 local root = Instance.new("Frame")
 root.Name, root.BackgroundTransparency, root.Size = "Responses", 1, UDim2.fromScale(QUESTION_WIDTH, QUESTION_HEIGHT * 4)
 root.Visible, root.Parent = false, gui
 self.root = root
 Theme.Aspect(root, WIDTH / (ROW * 4))
 local speech = label(gui, "MerchantSpeech", "", SPEECH_SIZE)
 speech.AnchorPoint, speech.Size = Vector2.new(0.5, 1), UDim2.fromScale(0.4, 0.104)
 Theme.Aspect(speech, 6.5)
 speech.TextXAlignment, speech.TextYAlignment = Enum.TextXAlignment.Center, Enum.TextYAlignment.Bottom
 speech.TextWrapped, speech.RichText, speech.Visible = true, true, false
 self.speech = speech
 self.connection = RunService.RenderStepped:Connect(function() self:Step() end)
 return self
end

function Dialogue:Tween(item, duration, properties)
 if properties.TextTransparency ~= nil and item:FindFirstChild("TextOutline") then
  self:Tween(item.TextOutline, duration, {Transparency = properties.TextTransparency})
 end
 local tween = TweenService:Create(item, TweenInfo.new(if self.app.reducedMotion then 0 else duration,
  Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
 self.tweens[tween] = true
 tween.Completed:Once(function() self.tweens[tween] = nil end)
 tween:Play()
end

function Dialogue:CancelMotion()
 self.serial += 1
 for tween in self.tweens do tween:Cancel() end
 table.clear(self.tweens)
end

function Dialogue:After(duration, callback)
 local serial = self.serial
 task.delay(duration, function()
  if self.active and self.serial == serial then callback() end
 end)
end

function Dialogue:Open(counter)
 self:Close()
 self.counter = counter
 local merchant = counter.Parent:FindFirstChild("Merchant")
 self.anchor = merchant and merchant:FindFirstChild("Head") or counter
 self.active, self.app.dialogueActive = true, true
 self.app.base:RefreshPromptOwnership()
 self:Step()
end

function Dialogue:Close()
 self:CancelMotion()
 self.active, self.root.Visible, self.speech.Visible = false, false, false
 self.app.dialogueActive = false
 if self.app.base then self.app.base:RefreshPromptOwnership() end
end

function Dialogue:Show(text, choices, note)
 if not self.active then return end
 self:CancelMotion()
 local serial = self.serial
 for _, child in self.root:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
 self.speech.Text, self.speech.TextTransparency, self.speech.TextOutline.Transparency = text, 0, 0
 local plain = text:gsub("<[^>]->", "")
 local length = utf8.len(plain) or #plain
 local typeTime = if self.app.reducedMotion then 0 else math.min(0.42, length * 0.014)
 self.speech.MaxVisibleGraphemes = if self.app.reducedMotion then -1 else 0
 if typeTime > 0 then self:Tween(self.speech, typeTime, {MaxVisibleGraphemes = length}) end
 -- Greeting is a separate beat: type, hold, fade, then reveal the responses.
 local entrance = if self.app.reducedMotion then 0.15 else typeTime + 0.45
 if #choices > 0 then
  self:After(entrance - 0.12, function() self:Tween(self.speech, 0.16, {TextTransparency = 1}) end)
 end
 local noteHeight = if note and note ~= "" then 30 else 0
 local totalHeight = math.max(1, #choices) * ROW + noteHeight + 8
 if noteHeight > 0 then
  local line = label(self.root, "Consequence", note, 18, CREAM)
  line.Size, line.Position = UDim2.fromScale(1, noteHeight / totalHeight), UDim2.fromScale(0, (#choices * ROW + 8) / totalHeight)
  line.TextTransparency, line.TextOutline.Transparency = 1, 1
  self:After(entrance, function() self:Tween(line, 0.16, {TextTransparency = 0}) end)
 end
 for i, choice in choices do
  local row = Instance.new("TextButton")
  row.Name, row.Size, row.Position = "Choice" .. i, UDim2.fromScale(1, ROW / totalHeight), UDim2.fromScale(0, (i - 1) * ROW / totalHeight)
  row.Text, row.AutoButtonColor, row.BackgroundTransparency = "", false, 1
  row.Active, row.Selectable, row.Parent = true, true, self.root
  local number = label(row, "Number", "#" .. i, RESPONSE_SIZE, CREAM)
  number.Size = UDim2.fromScale(RESPONSE_X / WIDTH, 1)
  local responseText = '["' .. choice.text .. '"]'
  local response = label(row, "Response", responseText, RESPONSE_SIZE)
  response.Position, response.Size = UDim2.fromScale(RESPONSE_X / WIDTH, 0), UDim2.fromScale((WIDTH - RESPONSE_X - HOVER) / WIDTH, 1)
  local ready, chosen, hovering = false, false, false
  local function hover(on)
   hovering = on
   if ready and not chosen then self:Tween(response, 0.12, {Position = UDim2.fromScale((RESPONSE_X + (if on then HOVER else 0)) / WIDTH, 0)}) end
  end
  row.MouseEnter:Connect(function() hover(true) end)
  row.MouseLeave:Connect(function() hover(false) end)
  row.SelectionGained:Connect(function() hover(true) end)
  row.SelectionLost:Connect(function() hover(false) end)
  row.Activated:Connect(function()
   if not ready or chosen or not self.active or serial ~= self.serial then return end
   chosen = true
   self.app.audio:Play("Click")
   -- Echo the chosen sentence above the merchant before the reply.
   self:Show(choice.text, {})
   self:After(if self.app.reducedMotion then 0.12 else 0.68, function()
    self:Tween(self.speech, 0.12, {TextTransparency = 1})
    self:After(if self.app.reducedMotion then 0 else 0.12, choice.run)
   end)
  end)
  number.TextTransparency, response.TextTransparency = 1, 1
  number.TextOutline.Transparency, response.TextOutline.Transparency = 1, 1
  response.Position = UDim2.fromScale((RESPONSE_X + (if self.app.reducedMotion then 0 else HOVER)) / WIDTH, 0)
  self:After(entrance + (if self.app.reducedMotion then 0 else (i - 1) * 0.085), function()
   self:Tween(number, 0.16, {TextTransparency = 0})
   self:Tween(response, 0.16, {TextTransparency = 0, Position = UDim2.fromScale((RESPONSE_X + (if hovering then HOVER else 0)) / WIDTH, 0)})
   ready = true
  end)
 end
 self.root.Size = UDim2.fromScale(QUESTION_WIDTH, QUESTION_HEIGHT * totalHeight / ROW)
 Theme.Aspect(self.root, WIDTH / totalHeight)
 self:Step()
end

function Dialogue:Result(text)
 self:Show(text, {})
 self:After(1.9, function()
  self:Tween(self.speech, 0.18, {TextTransparency = 1})
  self:After(0.18, function() self:Close() end)
 end)
end

function Dialogue:Step()
 if not self.active then return end
 local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
 local humanoid = root and root.Parent:FindFirstChildOfClass("Humanoid")
 if not self.counter or not self.counter.Parent or not root or not humanoid or humanoid.Health <= 0
  or (root.Position - self.counter.Position).Magnitude > 14 or (self.app.panel.Visible and not self.app.panelClosing) then self:Close(); return end
 if not self.app.state or self.counter.Parent:GetAttribute("PlotIndex") ~= self.app.state.plotIndex then self:Close(); return end
 local camera = workspace.CurrentCamera
 if not camera or not self.anchor or not self.anchor.Parent then self:Close(); return end
 local point, onScreen = camera:WorldToViewportPoint(self.anchor.Position + Vector3.new(0, 1.4, 0))
 self.root.Visible, self.speech.Visible = onScreen, onScreen
 if not onScreen then return end
 local viewport = camera.ViewportSize
 -- Projection follows the moving merchant; native constraints own all sizing.
 local width, height = self.root.AbsoluteSize.X, self.root.AbsoluteSize.Y
 local gap, margin = width * (96 / WIDTH), viewport.X * 0.012
 local playerPoint, playerVisible = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 2, 0))
 local right = if playerVisible then math.max(point.X, playerPoint.X) else point.X
 local left = if playerVisible then math.min(point.X, playerPoint.X) else point.X
 local rightGap = math.min(gap, viewport.X - margin - width - right)
 local x = if rightGap >= width * (24 / WIDTH) then right + rightGap else left - width - gap
 self.root.Position = UDim2.fromScale(math.clamp(x, margin, math.max(margin, viewport.X - width - margin)) / viewport.X,
  math.clamp(point.Y + width * (76 / WIDTH), viewport.Y * 0.13, math.max(viewport.Y * 0.13, viewport.Y - height - viewport.Y * 0.03)) / viewport.Y)
 local halfSpeech = self.speech.AbsoluteSize.X / 2
 self.speech.Position = UDim2.fromScale(math.clamp(point.X, halfSpeech, math.max(halfSpeech, viewport.X - halfSpeech)) / viewport.X,
  math.max(viewport.Y * 0.13, point.Y - self.speech.AbsoluteSize.Y * 0.1) / viewport.Y)
end

function Dialogue:Destroy()
 self:Close(); self.connection:Disconnect(); self.gui:Destroy()
end
return Dialogue
