local Params = {
    RepoURL = "https://raw.githubusercontent.com/luau/UniversalSynSaveInstance/main/",
    SSI = "saveinstance",
}
local synsaveinstance = loadstring(game:HttpGet(Params.RepoURL .. Params.SSI .. ".luau", true), Params.SSI)()
local ok, err = xpcall(function()
    synsaveinstance({})
end, function(e)
    return debug.traceback(e, 2)
end)
print("OK:", ok)
print("ERR:", err)
