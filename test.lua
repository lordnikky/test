local t = {}
local old
old = hookmetamethod(t, "__newindex", function(self, key, value)
    print("newindex:", key, "=", value)
    if key ~= "blocked" then
        old(self, key, value)
    end
end)
t.hello = "world"
print(t.hello)
