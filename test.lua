loadstring([[
local function original(x)
    return x + 1
end

local function hook(x)
    return original(x) * 10
end

local old = hookfunction(original, hook)
print("original(5):", original(5))   -- expect 60 (hooked)
print("old(5):", old(5))             -- expect 6 (original)

print("restore:", restorefunction(original), original(5))   -- expect true, 6
]])()
