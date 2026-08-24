-- assuming `loadstring` refers to Fiu's loadstring
loadstring([[
local function original(x) return x + 1 end
local function hook(x) return original(x) * 10 end
local old = hookfunction(original, hook)
print(original(5))  -- should print 60
print(old(5))        -- should print 6
]])()
