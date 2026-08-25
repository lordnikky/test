local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientStatCache = require(ReplicatedStorage.ClientStatCache)
local BeequipFile = require(ReplicatedStorage.Beequips.BeequipFile)
local BeequipTypes = require(ReplicatedStorage.Beequips.BeequipTypes)
local WaxTypes = require(ReplicatedStorage.WaxTypes)

-- !!! CONFIGURATION !!!
local TARGETS = {
    { Name = "Kazoo", Quantity = 50 },
    { Name = "Poinsettia", Quantity = 50 },
    { Name = "Elf Cap", Quantity = 50 }
}

local CAUSTIC_COUNT = 5 -- How many Caustic Waxes to apply (Stats)
-- !!!!!!!!!!!!!!!!!!!!!

print("--- ACTIVATING MULTI-ITEM 5 POT CUSTOM GENERATOR ---")

-- 1. GET CAUSTIC WAX ID
local CausticID = 1
for id, data in pairs(WaxTypes.TypeByID) do
    if string.find(data.Name, "Caustic") then
        CausticID = id
        break
    end
end

-- 2. PREPARE THE FAKE ITEMS
local FakeItemsList = {}
local Rng = Random.new()
local GlobalIndex = 0 -- Ensures every item has a unique ID across the loop

for _, targetData in ipairs(TARGETS) do
    local itemName = targetData.Name
    local quantity = targetData.Quantity
    
    -- Get Definition safely
    local RealDefinition = BeequipTypes.Get(itemName)
    
    if not RealDefinition then
        warn("Definition not found for " .. itemName .. ", using fallback.")
        RealDefinition = {
            Name = itemName, DisplayName = itemName, Description = "Injected Item",
            Rarity = "Legendary", Modifiers = {}, Upgrades = {}, StorageSize = 1
        }
    end
    
    print("Generating " .. quantity .. " x " .. itemName)

    for i = 1, quantity do
        GlobalIndex = GlobalIndex + 1
        
        -- Generate IDs safely
        local myUserId = game.Players.LocalPlayer.UserId
        local creationId = 600000 + GlobalIndex -- Unique for every single item
        local randomId = Rng:NextInteger(1, 9007199254740991)
        local timeNow = os.time()

        -- Apply Waxes
        local waxHistory = {}
        for _ = 1, CAUSTIC_COUNT do
            table.insert(waxHistory, {
                CausticID,  -- The ID of Caustic Wax
                true,       -- Success = True
                math.random(1, 10000) -- Random Seed for the stat roll
            })
        end

        -- CORRECT DATA STRUCTURE (From your working script)
        local rawItem = {
            ["T"] = itemName,
            ["Q"] = 1, -- Quality 1 = Perfect
            ["S"] = Rng:NextInteger(1, 2199023255551), -- Stat Seed
            ["OS"] = nil,
            ["IDs"] = { myUserId, creationId, randomId, timeNow },
            ["UC"] = 0, -- Upgrade Count
            ["RC"] = 0, -- Turpentine Count
            ["W"] = waxHistory, -- Waxes applied here
            ["TC"] = 0
        }

        -- Apply Metatable
        setmetatable(rawItem, BeequipFile)
        
        -- Force Definition (Prevents crashes)
        rawItem.GetTypeDef = function() return RealDefinition end
        
        -- 5 POTENTIAL VISUAL TRICK
        -- Shows empty stars but keeps the wax stats
        rawItem.GetWaxUseCount = function() return 0 end
        
        table.insert(FakeItemsList, rawItem)
    end
end

-- 3. HOOK THE STAT CACHE
if not getgenv().OldStatGet then
    getgenv().OldStatGet = ClientStatCache.Get
end

-- We use a tracking table to ensure we inject exactly once per storage instance
local ProcessedTables = setmetatable({}, {__mode = "k"})

ClientStatCache.Get = function(self)
    local stats = getgenv().OldStatGet(self)
    
    if stats and stats.Beequips then
        -- Fix StorageSize so all items fit
        if stats.Beequips.StorageSize == nil or stats.Beequips.StorageSize > 100000 then 
            stats.Beequips.StorageSize = 99999 -- Increased size for safety
        end
        
        if not stats.Beequips.Storage then stats.Beequips.Storage = {} end
        local storage = stats.Beequips.Storage
        
        -- Only inject if we haven't touched this table yet
        if not ProcessedTables[storage] then
            for _, fake in ipairs(FakeItemsList) do
                table.insert(storage, fake)
            end
            ProcessedTables[storage] = true
        end
    end
    
    return stats
end

-- 4. REFRESH UI
local success, menuScript = pcall(function() return require(ReplicatedStorage.Gui.BeequipMenus) end)
if success and menuScript then
    if menuScript.UpdateAll then pcall(function() menuScript.UpdateAll() end) end
    local storageMenu = menuScript.GetByName and menuScript.GetByName("Beequip Storage")
    if storageMenu and storageMenu.Open then
        pcall(function() storageMenu:Update() end)
    end
end

print("SUCCESS! Generated " .. GlobalIndex .. " items across 3 types.")
