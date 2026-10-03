--!strict
-- Shared high-detail world material; ownership remains with SpecialChickenVFX.
local Flow=require(script.Parent.FlowingChickenTexture)
local Animator={}
function Animator.new(model: Model)
	return Flow.new(model,"Rainbow")
end
return Animator
