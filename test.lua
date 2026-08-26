local Params = {
 RepoURL = "https://raw.githubusercontent.com/luau/UniversalSynSaveInstance/main/",
 SSI = "saveinstance",
}
local synsaveinstance = loadstring(game:HttpGet(Params.RepoURL .. Params.SSI .. ".luau", true), Params.SSI)()
local Options = {
    Workspace = true,
    Lighting = true,
    ReplicatedFirst = true,
    ReplicatedStorage = true,
    StarterGui = true,
    StarterPack = true,
    StarterPlayer = true,
    Teams = true,
    SoundService = true,
    Chat = true,
    LocalizationService = true,
    TestService = true,
    Terrain = true,
    Players = true,
    Decompile = true,              -- MUST be true
    DecompileTimeout = 10,
    DecompileJobless = false,
    SaveBytecode = false,
    SaveNonCreatable = true,
    SaveNotArchivable = true,
    NilInstances = true,
    IgnoreDefaultProperties = false,
    SaveAssets = true,
    SafeMode = true,
    MaxThreads = 128,
    ShowStatus = true,
    Binary = true,
    mode = "optimized",
}
synsaveinstance(Options)
