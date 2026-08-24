local t = {}
local old
old = hookmetamethod(t, "__index", function(self, key)
    print("index hook called for:", key)
    if key == "secret" then
        return "hooked"
    end
    return old(self, key)
end)

print(t.secret)    -- should print the hook line and then "hooked"
print(t.nothing)   -- should print the hook line and then nil (since old may be nil or rawindex)
