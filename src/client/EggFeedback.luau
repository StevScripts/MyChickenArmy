--!strict
-- Text budgets only. Never use these rounded display strings for egg accounting.
local TextService=game:GetService("TextService")
local Theme=require(script.Parent.UITheme)
local EggFeedback={}
local UNITS={{1e15,"Qa"},{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}}

function EggFeedback.Width(text,size)
 return TextService:GetTextSize(text,size,Theme.Font,Vector2.new(100000,1000)).X+8
end

function EggFeedback.Fit(value,prefix,suffix,width,size,currency,fractional)
 local rounded=if fractional then math.floor(value*10+0.5)/10 else math.floor(value)
 local exact=Theme.Money(rounded)
 if fractional and rounded%1~=0 then exact..="."..math.floor((rounded%1)*10+0.5) end
 local unit=if currency then "$" else ""
 local text=prefix..unit..exact..suffix
 if EggFeedback.Width(text,size)<=width then return text end
 local compact
 for _,entry in UNITS do
  if value>=entry[1] then
   compact=string.format("%.1f",value/entry[1]):gsub("%.0$","")..entry[2]
   break
  end
 end
 if not compact then return text end -- Short values need layout space, not smaller text.
 text=prefix.."≈"..unit..compact..suffix
 if EggFeedback.Width(text,size)>width then
  text=prefix.."≈"..unit..string.format("%.1e",value)..suffix
 end
 return text
end

return EggFeedback
