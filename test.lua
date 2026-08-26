loadstring([[
local Results = {}
local ok1, v1 = pcall(function() return tostring(version()) end)
table.insert(Results, "version(): " .. tostring(ok1 and v1 or "ERR " .. v1))
local ok2, v2 = pcall(function() return settings():GetService("DebugSettings").RobloxVersion end)
table.insert(Results, "DebugSettings.RobloxVersion: " .. tostring(ok2 and v2 or "ERR " .. tostring(v2)))
local ok3, v3 = pcall(function() return game:GetService("RunService"):GetRobloxVersion() end)
table.insert(Results, "RunService:GetRobloxVersion: " .. tostring(ok3 and v3 or "ERR " .. tostring(v3)))

local ok4, v4 = pcall(function()
    local raw = game:HttpGet("https://raw.githubusercontent.com/MaximumADHD/Roblox-Client-Tracker/roblox/Mini-API-Dump.json", true)
    return #raw
end)
table.insert(Results, "Mini-API-Dump fetch: " .. tostring(ok4 and ("OK " .. v4 .. " bytes") or "ERR " .. tostring(v4)))

local ok5, v5 = pcall(function()
    return game:HttpGet("https://raw.githubusercontent.com/setup-rbxcdn/setup-rbxcdn.github.io/refs/heads/main/version-history/Windows/Studio64.json", true)
end)
table.insert(Results, "version-history fetch: " .. tostring(ok5 and ("OK " .. #v5 .. " bytes") or "ERR " .. tostring(v5)))

print(table.concat(Results, "\n"))
]])()
