--!strict
-- Text budgets only. Never use these rounded display strings for egg accounting.
local TextService=game:GetService("TextService")
local Theme=require(script.Parent.UITheme)
local EggFeedback={}
local UNITS={{1e15,"Qa"},{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}}

function EggFeedback.Width(text,size)
 return TextService:GetTextSize(text,size,Theme.Font,Vector2.new(100000,1000)).X+8
end

-- October 23 (Stevin: "never give a decimal number"): amounts are whole; `fractional`
-- now rounds to the nearest Coin instead of showing tenths.
function EggFeedback.Fit(value,prefix,suffix,width,size,currency,fractional)
 local rounded=if fractional then math.floor(value+0.5) else math.floor(value)
 local exact=Theme.Money(rounded)
 -- October 20: coin amounts read "+1,200 Coins"; the old "$" prefix is retired.
 local unit=if currency then " Coins" else ""
 local text=prefix..exact..unit..suffix
 if EggFeedback.Width(text,size)<=width then return text end
 local compact
 for _,entry in UNITS do
  if value>=entry[1] then
   compact=string.format("%.1f",value/entry[1]):gsub("%.0$","")..entry[2]
   break
  end
 end
 if not compact then return text end -- Short values need layout space, not smaller text.
 text=prefix.."≈"..compact..unit..suffix
 if EggFeedback.Width(text,size)>width then
  text=prefix.."≈"..string.format("%.1e",value)..unit..suffix
 end
 return text
end

return EggFeedback
