local t = {}
local old
old = hookmetamethod(t, "__index", function(self, key)
    print("index:", key)
    return old and old(self, key) or nil
end)
print(t.hello)
