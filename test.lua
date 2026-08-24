print("=== hookfunction test ===")
_G.original = function(x) return x + 1 end
local old = hookfunction(_G.original, function(x)
    return old(x) * 10
end)
print("original(5) after hook:", _G.original(5))   -- expect 60
print("old(5):", old(5))                            -- expect 6

print("=== restorefunction test ===")
local ok = restorefunction(_G.original)
print("restore ok:", ok)
print("original(5) after restore:", _G.original(5)) -- expect 6

print("=== hookmetamethod test (on game) ===")
local old_meta = hookmetamethod(game, "__index", function(self, key)
    if key == "__FIU_TEST_KEY__" then
        return "hooked"
    end
    return old_meta(self, key)
end)
print("game.__FIU_TEST_KEY__:", game.__FIU_TEST_KEY__)  -- expect hooked
