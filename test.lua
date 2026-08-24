loadstring([[
local cb = Instance.new("BindableFunction")
local ans
cb.OnInvoke = function(v)
    ans = tostring(v)
end

local sg = game:GetService("StarterGui")
sg:SetCore("SendNotification", {
    Title = "UNC rconsole tests",
    Text = "Some executors crash on rconsole. Test rconsole functions?",
    Duration = 15,
    Button1 = "Yes",
    Button2 = "No",
    Callback = cb,
})

local t0 = os.clock()
while ans == nil and os.clock() - t0 < 15 do
    task.wait(0.05)
end
print("RESULT:", ans or "no answer")
]])()
