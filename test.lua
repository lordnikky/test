loadstring([[
local function original(x)
    return x + 1
end

local function hook(x)
    return original(x) * 10
end

local old = hookfunction(original, hook)
print("original(5):", original(5))  -- 60
print("old(5):", old(5))            -- 6

print("restore:", restorefunction(original), original(5))  -- true, 6

local t = {}
local oldmm = hookmetamethod(t, "__index", function(self, key)
    if key == "secret" then
        return "hooked"
    end
    return oldmm(self, key)
end)
print("t.secret:", t.secret)    -- hooked
print("t.nothing:", t.nothing)  -- nil
]])()
