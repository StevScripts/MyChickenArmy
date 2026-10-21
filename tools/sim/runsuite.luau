local name = ARGS[1]
local suite = Harness.require(Harness.Tests[name])
local results = if type(suite) == "function" then suite() else suite.Run()
local passed, failed = 0, 0
for _, result in results do
	if result.passed then passed += 1 else failed += 1; print("FAIL " .. tostring(result.name) .. " :: " .. tostring(result.detail or result.error)) end
end
print(("SUMMARY %s %d passed %d failed"):format(name, passed, failed))
