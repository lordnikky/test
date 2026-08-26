loadstring([[
local version = tostring(version())
print("version:", version)
local ok, raw = pcall(function()
    return game:HttpGet("https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Mini-API-Dump.json", true)
end)
print("fetch ok:", ok, ok and #raw or raw)
if ok then
    local decoded = game:GetService("HttpService"):JSONDecode(raw)
    print("classes:", #decoded.Classes)
    writefile("ussi_cache/API_DUMP.json", game:GetService("HttpService"):JSONEncode({ [version] = decoded.Classes }))
    print("cache written")
end
]])()
