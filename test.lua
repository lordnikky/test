loadstring([[
-- STEP 1: what the hookmetamethod test leaves behind
local old
old = hookmetamethod(game, "__index", function(self, key)
    if self == game and key == "__UNC_HOOK_TEST__" then
        return "ok"
    end
    return old(self, key)
end)
print("hook registered")

-- STEP 2: the exact pushNotif flow
local cb = Instance.new("BindableFunction")
local ans
cb.OnInvoke = function(v)
    ans = tostring(v)
end

local sg = game:GetService("StarterGui")
sg:SetCore("SendNotification", {
    Title = "prompt test",
    Text = "with buttons + callback",
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
