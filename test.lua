_G.orig = function(x) return x + 1 end
local old = hookfunction(_G.orig, function(x) return old(x) * 10 end)
print(_G.orig(5))   -- expect 60
print(old(5))       -- expect 6
