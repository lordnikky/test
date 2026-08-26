local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local player  = Players.LocalPlayer
local terrain = workspace.Terrain

local canWriteFiles  = writefile  ~= nil
local canAppendFiles = appendfile ~= nil
local hasTask        = task       ~= nil

local CONFIG = {
    ChunkSize = 64,
    SaveTerrain  = true,
    SaveWater    = true,
    SaveLighting = true,
    VacuumParts  = true,
    Noclip       = true,
    FlushEveryLines = 50,
    OutputName      = "MapDump_" .. os.time(),
}

local CHUNK           = CONFIG.ChunkSize
local VOXELS_PER_AXIS = CHUNK / 4
local GRAB_HALF       = 384
local SAMPLE_STEP     = 128
local DRAIN_PER_FRAME = 12
local MAX_QUEUE       = 40000
local MAX_RETRIES     = 5

local recording         = false
local shouldStop        = false
local outputLines       = {}
local lineCount         = 0
local totalChunksSaved  = 0
local totalPartsSaved   = 0
local totalBytesWritten = 0
local fileStarted       = false
local fileName          = CONFIG.OutputName .. ".lua"

local savedChunks        = {}
local processedInstances = {}
local cacheFolder        = nil
local markerFolder       = nil

local pendingQueue       = {}
local queueHead          = 1
local inQueue            = {}
local retryCount         = {}

local function snap(value, grid)
    return math.floor(value / grid) * grid
end

local function c3(color)
    return string.format("Color3.new(%.6f, %.6f, %.6f)", color.R, color.G, color.B)
end

local function newFolder(parent, name)
    local folder = parent:FindFirstChild(name)
    if folder then
        folder:ClearAllChildren()
    else
        folder = Instance.new("Folder")
        folder.Name = name
        folder.Parent = parent
    end
    return folder
end

local function getLightingHeader()
    if not CONFIG.SaveLighting then return "" end
    local L = game.Lighting
    local s = {}
    s[#s + 1] = "local L = game.Lighting"
    s[#s + 1] = "L.Ambient = " .. c3(L.Ambient)
    s[#s + 1] = "L.OutdoorAmbient = " .. c3(L.OutdoorAmbient)
    s[#s + 1] = string.format("L.Brightness = %.2f", L.Brightness)
    s[#s + 1] = string.format("L.ClockTime = %.2f", L.ClockTime)
    s[#s + 1] = "L.FogColor = " .. c3(L.FogColor)
    s[#s + 1] = string.format("L.FogEnd = %.2f", L.FogEnd)
    s[#s + 1] = string.format("L.FogStart = %.2f", L.FogStart)
    s[#s + 1] = "L.GlobalShadows = " .. tostring(L.GlobalShadows)
    return table.concat(s, "\n")
end

local function getRestoreHeader()
    local parts = {}
    parts[#parts + 1] = ""
    parts[#parts + 1] = "local T = workspace.Terrain"
    parts[#parts + 1] = "T:Clear()"
    parts[#parts + 1] = ""

    if CONFIG.SaveLighting then
        parts[#parts + 1] = getLightingHeader()
        parts[#parts + 1] = ""
    end

    parts[#parts + 1] = "T.WaterColor = " .. c3(terrain.WaterColor)
    parts[#parts + 1] = string.format("T.WaterTransparency = %.4f", terrain.WaterTransparency)
    parts[#parts + 1] = string.format("T.WaterWaveSize = %.4f", terrain.WaterWaveSize)
    parts[#parts + 1] = string.format("T.WaterWaveSpeed = %.4f", terrain.WaterWaveSpeed)
    parts[#parts + 1] = string.format("T.WaterReflectance = %.4f", terrain.WaterReflectance)
    parts[#parts + 1] = ""

    parts[#parts + 1] = string.format([====[
local N = %d

local function expand(rle, dst)
    local p = 0
    local i = 1
    local n = #rle
    while i <= n do
        local v = rle[i]
        local c = rle[i + 1]
        for _ = 1, c do
            p = p + 1
            dst[p] = v
        end
        i = i + 2
    end
end

local function C(x, y, z, mRLE, oRLE, wRLE)
    local mF, oF, wF = {}, {}, {}
    expand(mRLE, mF)
    expand(oRLE, oF)
    expand(wRLE, wF)

    local mat, occ, wat = {}, {}, {}
    local idx = 0
    for xx = 1, N do
        mat[xx], occ[xx], wat[xx] = {}, {}, {}
        for yy = 1, N do
            mat[xx][yy], occ[xx][yy], wat[xx][yy] = {}, {}, {}
            for zz = 1, N do
                idx = idx + 1
                mat[xx][yy][zz] = Enum.Material:FromValue(mF[idx])
                occ[xx][yy][zz] = oF[idx] / 255
                wat[xx][yy][zz] = wF[idx] / 255
            end
        end
    end

    local region = Region3.new(Vector3.new(x, y, z), Vector3.new(x + %d, y + %d, z + %d))
    T:WriteVoxelChannels(region, 4, {
        SolidMaterial = mat,
        SolidOccupancy = occ,
        LiquidOccupancy = wat,
    })
end
]====], VOXELS_PER_AXIS, CHUNK, CHUNK, CHUNK)

    return table.concat(parts, "\n")
end

local function flushBuffer()
    if lineCount == 0 then return true end
    if not canWriteFiles then return false end

    local content = table.concat(outputLines, "\n", 1, lineCount)
    local success = false

    for attempt = 1, 3 do
        local s = pcall(function()
            if not fileStarted then
                writefile(fileName, getRestoreHeader() .. "\n" .. content)
                fileStarted = true
            elseif canAppendFiles then
                appendfile(fileName, "\n" .. content)
            else
                local existing = readfile(fileName)
                writefile(fileName, existing .. "\n" .. content)
            end
        end)
        if s then success = true break end
        if hasTask then task.wait(0.1) else wait(0.1) end
    end

    if success then
        totalBytesWritten = totalBytesWritten + #content
        for i = 1, lineCount do outputLines[i] = nil end
        lineCount = 0
    end
    return success
end

local function addLine(line)
    lineCount = lineCount + 1
    outputLines[lineCount] = line
    if lineCount >= CONFIG.FlushEveryLines then
        flushBuffer()
    end
end

local function finalizeFile()
    flushBuffer()
end

local function rleEncode(values, n)
    if not values or n <= 0 then return "" end
    local out, p = {}, 0
    local current = values[1]
    local count   = 1
    for i = 2, n do
        local v = values[i]
        if v == current and count < 65535 then
            count = count + 1
        else
            p = p + 1; out[p] = current
            p = p + 1; out[p] = count
            current, count = v, 1
        end
    end
    p = p + 1; out[p] = current
    p = p + 1; out[p] = count
    return table.concat(out, ",", 1, p)
end

local function readChunkChannels(region)
    if terrain.ReadVoxelChannels then
        local ok, ch = pcall(function()
            return terrain:ReadVoxelChannels(region, 4, {
                "SolidMaterial", "SolidOccupancy", "LiquidOccupancy",
            })
        end)
        if ok and ch and ch.SolidMaterial then
            return ch.SolidMaterial, ch.SolidOccupancy, ch.LiquidOccupancy
        end
    end
    local ok, mat, occ = pcall(function()
        return terrain:ReadVoxels(region, 4)
    end)
    if ok and mat then return mat, occ, nil end
    return nil, nil, nil
end

local function encodeChunk(x, y, z)
    local region = Region3.new(Vector3.new(x, y, z), Vector3.new(x + CHUNK, y + CHUNK, z + CHUNK))
    local mat3, occ3, wat3 = readChunkChannels(region)
    if not mat3 then return end

    local N = VOXELS_PER_AXIS
    local total = N * N * N
    local floor = math.floor
    local AIR = Enum.Material.Air

    local mF, oF, wF = {}, {}, {}
    local idx = 0
    local hasSolid, hasWater = false, false

    for xx = 1, N do
        local mx, ox = mat3[xx], occ3[xx]
        local wx = wat3 and wat3[xx]
        for yy = 1, N do
            local my, oy = mx[yy], ox[yy]
            local wy = wx and wx[yy]
            for zz = 1, N do
                idx = idx + 1
                local mv = my[zz]
                local ov = oy[zz]
                local wv = wy and wy[zz] or 0
                mF[idx] = mv.Value
                oF[idx] = floor(ov * 255 + 0.5)
                wF[idx] = floor(wv * 255 + 0.5)
                if ov > 0 and mv ~= AIR then hasSolid = true end
                if wv > 0 then hasWater = true end
            end
        end
    end

    if not hasSolid and not hasWater then return end

    local mStr = rleEncode(mF, total)
    local oStr = rleEncode(oF, total)
    local wStr = rleEncode(wF, total)

    return string.format("C(%d,%d,%d,{%s},{%s},{%s})", x, y, z, mStr, oStr, wStr)
end

local function processFoundInstance(inst)
    if not inst or processedInstances[inst] then return end
    if inst:IsDescendantOf(player.Character) then return end
    if cacheFolder and inst:IsDescendantOf(cacheFolder) then return end
    if markerFolder and (inst == markerFolder or inst:IsDescendantOf(markerFolder)) then return end
    if inst == terrain then return end

    processedInstances[inst] = true

    if CONFIG.VacuumParts then
        pcall(function()
            if inst:IsA("BasePart") then inst.Locked = false end
            for _, v in ipairs(inst:GetDescendants()) do
                if v:IsA("BasePart") then v.Locked = false end
            end
            inst.Archivable = true
            inst.Parent = cacheFolder
        end)
        totalPartsSaved = totalPartsSaved + 1
    end
end

local function applyNoclip()
    if not CONFIG.Noclip then return end
    if not player.Character then return end
    pcall(function()
        for _, v in ipairs(player.Character:GetDescendants()) do
            if v:IsA("BasePart") then v.CanCollide = false end
        end
    end)
end

local function enqueueChunk(x, y, z)
    local key = x .. "," .. y .. "," .. z
    if savedChunks[key] or inQueue[key] then return end
    if (#pendingQueue - queueHead + 1) >= MAX_QUEUE then return end
    inQueue[key] = true
    pendingQueue[#pendingQueue + 1] = { x, y, z }
end

local function enqueueAround(pos)
    if not CONFIG.SaveTerrain then return end
    local steps = math.floor(GRAB_HALF / CHUNK)
    local cx = snap(pos.X, CHUNK)
    local cy = snap(pos.Y, CHUNK)
    local cz = snap(pos.Z, CHUNK)
    for ox = -steps, steps do
        for oy = -steps, steps do
            for oz = -steps, steps do
                enqueueChunk(cx + ox * CHUNK, cy + oy * CHUNK, cz + oz * CHUNK)
            end
        end
    end
end

local function clearChunk(x, y, z)
    local region = Region3.new(Vector3.new(x, y, z), Vector3.new(x + CHUNK, y + CHUNK, z + CHUNK))
    pcall(function()
        terrain:FillRegion(region, 4, Enum.Material.Air)
    end)
end

local function spawnMarker(x, y, z)
    if not markerFolder then return end
    local marker = Instance.new("Part")
    marker.Name = "SavedChunkMarker"
    marker.Anchored = true
    marker.CanCollide = false
    marker.CastShadow = false
    marker.Material = Enum.Material.Neon
    marker.Color = Color3.new(0, 1, 0)
    marker.Transparency = 0.2
    marker.Size = Vector3.new(CHUNK, CHUNK, CHUNK)
    marker.Position = Vector3.new(x + CHUNK/2, y + CHUNK/2, z + CHUNK/2)
    marker.Parent = markerFolder
end

local function drainQueue()
    local drained = 0
    while queueHead <= #pendingQueue and drained < DRAIN_PER_FRAME do
        local c = pendingQueue[queueHead]
        local key = c[1]..","..c[2]..","..c[3]
        inQueue[key] = nil

        local probeRegion = Region3.new(
            Vector3.new(c[1]+CHUNK/2, c[2]+CHUNK/2, c[3]+CHUNK/2),
            Vector3.new(c[1]+CHUNK/2+4, c[2]+CHUNK/2+4, c[3]+CHUNK/2+4)
        )
        local ok, probe = pcall(function()
            return terrain:ReadVoxelChannels(probeRegion, 4, {
                "SolidMaterial", "LiquidOccupancy",
            })
        end)

        if not ok then
            queueHead = queueHead + 1
            pendingQueue[#pendingQueue + 1] = c
            inQueue[key] = true
            drained = drained + 1
        else
            queueHead = queueHead + 1
            drained = drained + 1

            local hasContent = false
            local pm, pw = probe.SolidMaterial, probe.LiquidOccupancy
            if pm then
                for xx = 1, #pm do
                    local mx = pm[xx]
                    if mx then
                        for yy = 1, #mx do
                            local my = mx[yy]
                            if my then
                                for zz = 1, #my do
                                    if my[zz] ~= Enum.Material.Air then
                                        hasContent = true
                                        break
                                    end
                                end
                                if hasContent then break end
                            end
                        end
                        if hasContent then break end
                    end
                end
            end
            if not hasContent and pw then
                for xx = 1, #pw do
                    local mx = pw[xx]
                    if mx then
                        for yy = 1, #mx do
                            local my = mx[yy]
                            if my then
                                for zz = 1, #my do
                                    if (my[zz] or 0) > 0 then
                                        hasContent = true
                                        break
                                    end
                                end
                                if hasContent then break end
                            end
                        end
                        if hasContent then break end
                    end
                end
            end

            if hasContent then
                local line = encodeChunk(c[1], c[2], c[3])
                if line then
                    savedChunks[key] = true
                    addLine(line)
                    totalChunksSaved = totalChunksSaved + 1
                    spawnMarker(c[1], c[2], c[3])
                end
            else
                savedChunks[key] = true
            end
        end

        if drained >= DRAIN_PER_FRAME then break end
    end

    if queueHead > 1000 and queueHead > #pendingQueue / 2 then
        local compact = {}
        for i = queueHead, #pendingQueue do
            compact[#compact + 1] = pendingQueue[i]
        end
        pendingQueue = compact
        queueHead = 1
    end
end

local function recordPartsAround(pos)
    if not CONFIG.VacuumParts then return end

    local exclude = { cacheFolder, terrain, markerFolder }
    if player.Character then table.insert(exclude, player.Character) end

    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = exclude

    local size = GRAB_HALF * 2
    local found = workspace:GetPartBoundsInBox(CFrame.new(pos), Vector3.new(size, size, size), params)

    for _, part in ipairs(found) do
        if shouldStop then return end
        local root = part
        while root.Parent and not root.Parent:IsA("Workspace") do
            root = root.Parent
        end
        processFoundInstance(root)
    end
end

local function recordLoop()
    local lastPos = nil
    local lastNoclip = 0
    while recording and not shouldStop do
        local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            if os.clock() - lastNoclip > 1 then
                applyNoclip()
                lastNoclip = os.clock()
            end
            local p = hrp.Position
            if lastPos == nil or (p - lastPos).Magnitude >= SAMPLE_STEP then
                lastPos = p
                enqueueAround(p)
                recordPartsAround(p)
            end
        end
        drainQueue()
        RunService.Heartbeat:Wait()
    end
end

local function deleteSavedTerrain()
    local keys = {}
    for key in pairs(savedChunks) do
        keys[#keys + 1] = key
    end
    local total = #keys
    for i, key in ipairs(keys) do
        if shouldStop then break end
        local x, y, z = key:match("(-?%d+),(-?%d+),(-?%d+)")
        if x then
            clearChunk(tonumber(x), tonumber(y), tonumber(z))
            savedChunks[key] = nil
        end
        if i % 20 == 0 then
            RunService.Heartbeat:Wait()
        end
    end
    return total
end

local function buildUI()
    local old = game:GetService("CoreGui"):FindFirstChild("MapSaverUI")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "MapSaverUI"
    gui.ResetOnSpawn = false
    pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if not gui.Parent then
        gui.Parent = player:WaitForChild("PlayerGui")
    end

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 300, 0, 400)
    main.Position = UDim2.new(0.5, -150, 0.12, 0)
    main.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    main.BorderSizePixel = 2
    main.BorderColor3 = Color3.fromRGB(255, 0, 85)
    main.Active = true
    main.Draggable = true
    main.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 34)
    title.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
    title.Text = "Universal Map Saver (Fly & Record)"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 16
    title.Parent = main

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -20, 1, -44)
    content.Position = UDim2.new(0, 10, 0, 40)
    content.BackgroundTransparency = 1
    content.Parent = main

    local function button(text, y, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 0, 30)
        b.Position = UDim2.new(0, 0, 0, y)
        b.BackgroundColor3 = color
        b.BorderSizePixel = 1
        b.BorderColor3 = Color3.fromRGB(60, 60, 60)
        b.Text = text
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Font = Enum.Font.SourceSansBold
        b.TextSize = 14
        b.Parent = content
        return b
    end

    local function label(text, y, color)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 16)
        l.Position = UDim2.new(0, 0, 0, y)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = color or Color3.fromRGB(200, 200, 200)
        l.Font = Enum.Font.SourceSans
        l.TextSize = 13
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = content
        return l
    end

    local startBtn   = button("Start Recording", 0,   Color3.fromRGB(50, 120, 200))
    local stopBtn    = button("Stop & Save",     35,  Color3.fromRGB(180, 60, 60))
    local saveBtn    = button("Force Save Now",  70,  Color3.fromRGB(200, 140, 40))
    local restoreBtn = button("Restore Parts (from cache)", 105, Color3.fromRGB(60, 160, 80))
    local deleteBtn  = button("Delete Saved Terrain",       140, Color3.fromRGB(160, 60, 120))

    local statusLabel  = label("Ready",            185, Color3.fromRGB(150, 150, 150))
    local terrainLabel = label("Terrain chunks: 0",205, Color3.fromRGB(200, 140, 40))
    local partsLabel   = label("Parts: 0",         221, Color3.fromRGB(60, 160, 80))
    local bufferLabel  = label("Buffer: 0 lines",  237, Color3.fromRGB(100, 180, 255))
    local bytesLabel   = label("Written: 0 KB",    253, Color3.fromRGB(255, 180, 100))
    local writeLabel   = label("",                 300, Color3.fromRGB(255, 200, 100))

    if not canWriteFiles then
        writeLabel.Text = "Warning: writefile not available!"
    end

    return {
        startBtn = startBtn, stopBtn = stopBtn, saveBtn = saveBtn,
        restoreBtn = restoreBtn, deleteBtn = deleteBtn,
        statusLabel = statusLabel, terrainLabel = terrainLabel,
        partsLabel = partsLabel, bufferLabel = bufferLabel,
        bytesLabel = bytesLabel, writeLabel = writeLabel,
    }
end

local function updateLabels(ui)
    ui.terrainLabel.Text = "Terrain chunks: " .. totalChunksSaved
    ui.partsLabel.Text   = "Parts: " .. totalPartsSaved
    ui.bufferLabel.Text  = "Buffer: " .. lineCount .. " lines"
    if totalBytesWritten > 1024 then
        ui.bytesLabel.Text = string.format("Written: %.1f KB", totalBytesWritten / 1024)
    else
        ui.bytesLabel.Text = "Written: " .. totalBytesWritten .. " B"
    end
end

cacheFolder  = newFolder(ReplicatedStorage, "MapSaverCache")
markerFolder = newFolder(workspace, "MapSaverMarkers")
local ui = buildUI()

ui.startBtn.MouseButton1Click:Connect(function()
    if recording then return end
    recording = true
    shouldStop = false
    applyNoclip()
    ui.statusLabel.Text = "Recording... fly around!"
    ui.writeLabel.Text  = "Output: " .. fileName

    if hasTask then task.spawn(recordLoop) else spawn(recordLoop) end

    while recording do
        updateLabels(ui)
        if hasTask then task.wait(0.2) else wait(0.2) end
    end
    updateLabels(ui)
end)

ui.stopBtn.MouseButton1Click:Connect(function()
    recording = false
    shouldStop = true
    finalizeFile()
    ui.statusLabel.Text = "Saved to " .. fileName
    updateLabels(ui)
end)

ui.saveBtn.MouseButton1Click:Connect(function()
    flushBuffer()
    ui.writeLabel.Text = "Buffer flushed to " .. fileName
end)

ui.restoreBtn.MouseButton1Click:Connect(function()
    local parts = cacheFolder:GetChildren()
    for _, obj in ipairs(parts) do
        pcall(function() obj.Parent = workspace end)
    end
    processedInstances = {}
    ui.statusLabel.Text = "Restored " .. #parts .. " parts."
end)

ui.deleteBtn.MouseButton1Click:Connect(function()
    if recording then
        ui.statusLabel.Text = "Stop recording before deleting."
        return
    end
    ui.statusLabel.Text = "Deleting saved terrain..."
    local function runDelete()
        local n = deleteSavedTerrain()
        ui.statusLabel.Text = "Deleted " .. n .. " terrain chunks."
    end
    if hasTask then task.spawn(runDelete) else spawn(runDelete) end
end)

print("[MapSaver] Fly & Record loaded. Output: " .. fileName)
