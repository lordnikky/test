loadstring([[
-- __newindex
local t = {}
local old = hookmetamethod(t, "__newindex", function(self, key, value)
    print("newindex:", key, "=", value)
    if key ~= "blocked" then
        old(self, key, value)
    end
end)
t.hello = "world"
print("t.hello:", t.hello)     -- world
t.blocked = "nope"             -- hook sees it, blocks the write
print("t.blocked:", t.blocked) -- nil
hookmetamethod(t, "__newindex", nil)  -- unhook

-- __namecall on game
local oldnc = hookmetamethod(game, "__namecall", function(self, ...)
    local m = getnamecallmethod()
    if m == "GetService" then
        print("namecall: GetService")
    end
    return oldnc(self, ...)
end)
print(game:GetService("Players").ClassName)  -- Players

-- cleanup
hookmetamethod(game, "__namecall", nil)
print("ALL DONE")
]])()
