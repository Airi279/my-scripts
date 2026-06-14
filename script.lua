local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
task.wait(2)

local Players     = game:GetService("Players")
local VIM         = game:GetService("VirtualInputManager")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- =====================================================
-- SAVE / LOAD
-- =====================================================

local FILE = "AIRI_settings.json"

local DEFAULT = {
    selectedMobs  = {},
    equippedSlot  = 1,
    autoSkillZ    = false,
    autoSkillX    = false,
    autoSkillC    = false,
    autoSkillV    = false,
    autoSkillR    = false,
    Block         = false,
    autoFarm      = false,
    attackDelay   = 0.1,
    tpDelay       = 0.1,
    tpOffset      = 3,
    autoFarmAoE   = false,
    autoFarmBoss  = false,
    scanRange     = 99999,
    autoReroll    = false,
    wantHoly      = false,
    wantSpaceChest = true,
    wantAmount    = 1,
    wantHolyAmount   = 1,
    wantSpaceChestAmount = 1,
    blacklist1 = "",
    blacklist2 = "",
    blacklist3 = "",
    blacklist4 = "",
    blacklist5 = "",
    blacklist6 = "",
    rerollWait = 0.6,
    selectedRaidName = "Moraros Hard",
    autoHop = false,
    autoRaid = false,
    autoTower = false,
    towerLayer = 1,
    autoMegumin = false,
    autoGaspa = false,
    autoSpaceInvader = false,
    lowGraphics = false,
}

local cfg = {}
for k,v in pairs(DEFAULT) do cfg[k] = v end

local function save()
    pcall(function() writefile(FILE, HttpService:JSONEncode(cfg)) end)
end

local function load()
    if isfile(FILE) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(FILE)) end)
        if ok and data then
            for k,v in pairs(DEFAULT) do
                if data[k] == nil then data[k] = v end
            end
            cfg = data
        end
    end
end

load()
task.spawn(function()
    while true do task.wait(10); save() end
end)

-- =====================================================
-- TELEPORT
-- =====================================================

local function teleportToMob(mob)
    if not mob then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local ok, pivot = pcall(function() return mob:GetPivot() end)
    if not ok or not pivot then return end
    local pos  = pivot.Position
    local look = pivot.LookVector
    hrp.CFrame = CFrame.new(pos + (look * -(cfg.tpOffset or 3)), pos)
    hrp.AssemblyLinearVelocity = Vector3.zero
end

local function teleportToPos(pos)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    hrp.AssemblyLinearVelocity = Vector3.zero
end

-- =====================================================
-- WINDOW
-- =====================================================

local Window = WindUI:CreateWindow({
    Title            = "AIRI",
    Icon             = "swords",
    Author           = "by me",
    Folder           = "AIRI",
    Size             = UDim2.fromOffset(580,460),
    MinSize          = Vector2.new(560,350),
    MaxSize          = Vector2.new(850,560),
    ToggleKey        = Enum.KeyCode.LeftShift,
    Transparent      = true,
    Theme            = "Dark",
    Resizable        = true,
    SideBarWidth     = 200,
    HideSearchBar    = true,
    ScrollBarEnabled = false,
})

-- =====================================================
-- HELPERS
-- =====================================================

local function pressKey(key)
    VIM:SendKeyEvent(true, key, false, game)
    task.wait(0.05)
    VIM:SendKeyEvent(false, key, false, game)
end

local function clickLeft()
    if isRerolling then return end
    VIM:SendMouseButtonEvent(0,0,0,true,game,0)
    task.wait(cfg.attackDelay or 0.01)
    VIM:SendMouseButtonEvent(0,0,0,false,game,0)
end

local function equipSlot(slot)
    local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three }
    if keys[slot] then pressKey(keys[slot]) end
    task.wait(0.15)
end

local function unequipWeapon()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:UnequipTools() end) end
end

local function reEquip()
    local s = cfg.equippedSlot or 1
    if s == 1 then pressKey(Enum.KeyCode.Two); task.wait(1); pressKey(Enum.KeyCode.One)
    elseif s == 2 then pressKey(Enum.KeyCode.One); task.wait(1); pressKey(Enum.KeyCode.Two)
    elseif s == 3 then pressKey(Enum.KeyCode.Two); task.wait(1); pressKey(Enum.KeyCode.Three) end
end

-- =====================================================
-- AUTO REROLL
-- =====================================================

local CHEST_IMAGES = {
    Holy = "rbxassetid://95667940960287",
    Secret = "rbxassetid://101939275166907",
}

local function questCheck()
    for _, v in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if v:IsA("ImageLabel")
        and v.Parent.Name == "Icon"
        and v.Parent.Parent.Name == "Task" then
            if cfg.wantSpaceChest and v.Image == CHEST_IMAGES.Secret then
                local num = v.Parent:FindFirstChild("Number")
                local amount = num and tonumber(num.Text) or 0
                if amount >= (cfg.wantSpaceChestAmount or 1) then
                    return true
                end
            end
            if cfg.wantHoly and v.Image == CHEST_IMAGES.Holy then
                local num = v.Parent:FindFirstChild("Number")
                local amount = num and tonumber(num.Text) or 0
                if amount >= (cfg.wantHolyAmount or 1) then
                    return true
                end
            end
        end
    end
    return false
end

local function getNearestRerollNPC()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local bossTask = workspace:FindFirstChild("World") and
                     workspace.World:FindFirstChild("NPC") and
                     workspace.World.NPC:FindFirstChild("BossTask")
    if not bossTask then return nil end
    local nearest, dist = nil, math.huge
    for _, npc in ipairs(bossTask:GetChildren()) do
        if npc:IsA("Model") then
            local root = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Head")
            if root then
                local d = (hrp.Position - root.Position).Magnitude
                if d < dist then dist = d; nearest = npc end
            end
        end
    end
    return nearest
end

local function doReroll()
    if questCheck() then
        print("[AIRI] มีกล่องอยู่แล้ว")
        return true
    end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local npc

    if cfg.wantSpaceChest then
        npc = workspace.World.NPC.BossTask:FindFirstChild("240012")
        if not npc then
            warn("[AIRI] ไม่เจอ NPC 240012")
            return false
        end
    elseif cfg.wantHoly then
        npc = getNearestRerollNPC()
        if not npc then
            warn("[AIRI] ไม่เจอ NPC reroll ใกล้ตัว")
            return false
        end
    end

    -- หา ProximityPrompt ใต้ NPC (ไม่จำกัดระยะ)
    local prompt = nil
    if npc then
        for _, v in ipairs(npc:GetDescendants()) do
            if v:IsA("ProximityPrompt") then
                prompt = v
                break
            end
        end
    end

    if not prompt then
        warn("[AIRI] ไม่เจอ ProximityPrompt ใน NPC เลย")
        return false
    end

    -- วาปไปที่ part ของ prompt ตรงๆ
    local promptPart = prompt.Parent
    local promptPos = nil
    if promptPart then
        if promptPart:IsA("BasePart") then
            promptPos = promptPart.Position
        elseif promptPart:IsA("Attachment") then
            promptPos = promptPart.WorldPosition
        end
    end

    if promptPos then
        hrp.CFrame = CFrame.new(promptPos + Vector3.new(0, 3, 0))
        hrp.AssemblyLinearVelocity = Vector3.zero
    end

    task.wait(cfg.rerollWait or 0.6)

    local attempts = 0
    while not questCheck() do
        fireproximityprompt(prompt)
        attempts = attempts + 1
        task.wait(cfg.rerollWait or 0.6)
        if attempts > 300 then
            warn("[AIRI] reroll เกิน 300 ครั้ง หยุด")
            return false
        end
    end
    print("[AIRI] ได้กล่องแล้ว! (" .. attempts .. " ครั้ง)")
    return true
end
-- =====================================================
-- MOB HELPERS
-- =====================================================

local EnemyService = workspace:WaitForChild("EnemyService", 30)

local function getES()
    return EnemyService or workspace:FindFirstChild("EnemyService")
end

local function isAlive(v)
    if not v or not v.Parent then return false end
    local h = v:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0.5
end

local function isNameSelected(name)
    for _, n in ipairs(cfg.selectedMobs or {}) do
        if n == name then return true end
    end
    return false
end

local mobCache = {}

local function rebuildCache()
    local es = getES()
    if not es then mobCache = {}; return end
    local list = {}
    for _, v in ipairs(es:GetDescendants()) do
        if v:IsA("Model") then
            local h = v:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 1 then
                table.insert(list, v)
            end
        end
    end
    mobCache = list
end

local function getNearestFromCache(filterFn)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local nearest, dist = nil, math.huge
    for _, v in ipairs(mobCache) do
        if isAlive(v) and (not filterFn or filterFn(v)) then
            local ok, pivot = pcall(function() return v:GetPivot() end)
            if ok and pivot then
                local d = (hrp.Position - pivot.Position).Magnitude
                if d < dist then dist = d; nearest = v end
            end
        end
    end
    return nearest
end

local function getNearestSelectedMob()
    return getNearestFromCache(function(v)
        return isNameSelected(tostring(v.Name))
    end)
end

local function getMobsInRange()
    local range = cfg.scanRange or 99999
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local nearest, dist = nil, math.huge
    for _, v in ipairs(mobCache) do
        if isAlive(v) then
            local ok, pivot = pcall(function() return v:GetPivot() end)
            if ok and pivot then
                local d = (hrp.Position - pivot.Position).Magnitude
                if d < range and d < dist then dist = d; nearest = v end
            end
        end
    end
    return nearest
end

local function getBossInRange()
    local nameCount = {}
    for _, v in ipairs(mobCache) do
        if isAlive(v) then
            local n = tostring(v.Name)
            nameCount[n] = (nameCount[n] or 0) + 1
        end
    end
    local range = cfg.scanRange or 99999
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local nearest, dist = nil, math.huge
    for _, v in ipairs(mobCache) do
        if isAlive(v) then
            local n = tostring(v.Name)
            if nameCount[n] == 1 then
                local ok, pivot = pcall(function() return v:GetPivot() end)
                if ok and pivot then
                    local d = (hrp.Position - pivot.Position).Magnitude
                    if d < range and d < dist then dist = d; nearest = v end
                end
            end
        end
    end
    return nearest
end

local function getMobInfo(name)
    local count, hpNow, hpMax = 0, 0, 0
    for _, v in ipairs(mobCache) do
        if tostring(v.Name) == name and isAlive(v) then
            local h = v:FindFirstChildOfClass("Humanoid")
            if h then
                count = count + 1
                hpNow = hpNow + h.Health
                hpMax = hpMax + h.MaxHealth
            end
        end
    end
    return count, hpNow, hpMax
end

-- =====================================================
-- MOB LIST
-- =====================================================

local knownMobNames = {}

local function scanAllEver()
    local es = getES()
    if not es then return end
    for _, v in ipairs(es:GetDescendants()) do
        if v:IsA("Model") then
            local h = v:FindFirstChildOfClass("Humanoid")
            if h then knownMobNames[tostring(v.Name)] = true end
        end
    end
end

-- =====================================================
-- THREADS
-- =====================================================

local threads = {}
local function killThread(name)
    if threads[name] then
        pcall(function() task.cancel(threads[name]) end)
        threads[name] = nil
    end
end

local autoFarm     = false
local autoFarmAoE  = false
local autoFarmBoss = false
local AutoFarmToggleRef
local AutoFarmAoERef
local AutoFarmBossRef
local lastFarmAlive = 0
local isRerolling   = false
local autoRaid = false
local AutoRaidRef
local selectedRaidId = 220001
local autoTower = false
local AutoTowerRef
local isTargetingBoss = false
local autoSpaceInvader = false
local AutoSpaceInvaderRef

-- =====================================================
-- SKILLS
-- =====================================================

local skillDef = {
    {key="Z", cfgKey="autoSkillZ", keyCode=Enum.KeyCode.Z},
    {key="X", cfgKey="autoSkillX", keyCode=Enum.KeyCode.X},
    {key="C", cfgKey="autoSkillC", keyCode=Enum.KeyCode.C},
    {key="V", cfgKey="autoSkillV", keyCode=Enum.KeyCode.V},
    {key="R", cfgKey="autoSkillR", keyCode=Enum.KeyCode.R},
    {key="F", cfgKey="Block", keyCode=Enum.KeyCode.F, label="Block"},
}

local skillEnabled = {}

local function startSkill(def)
    killThread("skill_"..def.key)
    skillEnabled[def.key] = true

    threads["skill_"..def.key] = task.spawn(function()
        while skillEnabled[def.key] do

            -- ⛔ หยุดชั่วคราวตอนกำลังค้นหา/วาร์ปบอส
            if isTargetingBoss then
                task.wait(0.2)
                continue
            end

            local mob =
                getNearestSelectedMob()
                or getMobsInRange()
                or getBossInRange()

            if mob then
                pressKey(def.keyCode)
                task.wait(0.1)
            else
                task.wait(0.5)
            end
        end
    end)
end

local function stopSkill(def)
    skillEnabled[def.key] = false
    killThread("skill_"..def.key)
end

task.spawn(function()
    while true do
        task.wait(120)
        if autoFarm or autoFarmAoE or autoFarmBoss then pcall(reEquip) end
    end
end)

-- =====================================================
-- FARM LOOPS
-- =====================================================

local function startFarmLoop()
    killThread("farm")
    lastFarmAlive = tick()
    threads["farm"] = task.spawn(function()
        equipSlot(cfg.equippedSlot or 1)
        task.wait(0.3)
        while autoFarm do
            lastFarmAlive = tick()
            local mob = getNearestSelectedMob()
            if not mob then rebuildCache(); task.wait(0.5); continue end

            -- ลอยเหนือบอสก่อน เฉพาะตอนเปิด reroll
            if cfg.autoReroll then
                local ok, pivot = pcall(function() return mob:GetPivot() end)
                if ok and pivot then
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local floatPos = pivot.Position + Vector3.new(0, 70, 0)
                        local floatTime = tick()
                        while tick() - floatTime < 1 do
                            hrp.CFrame = CFrame.new(floatPos)
                            hrp.AssemblyLinearVelocity = Vector3.zero
                            task.wait(0.05)
                        end
                        -- ออกจาก loop แล้วไปรีโรทันทีไม่มี gap
                        isRerolling = true
                        for _, def in ipairs(skillDef) do stopSkill(def) end
                        doReroll()
                        task.wait(0.6)
                        isRerolling = false
                        for _, def in ipairs(skillDef) do
                            if cfg[def.cfgKey] then startSkill(def) end
                        end
                    end
                end
            end

                    -- รีโรลเสร็จค่อยวาร์ปไปตี
             teleportToMob(mob)

            local hum = mob:FindFirstChildOfClass("Humanoid")
            local lastHP = hum and hum.Health or math.huge
            local hpStuckTime = tick()

            while autoFarm and isAlive(mob) do
                lastFarmAlive = tick()
                if not LocalPlayer.Character then break end
                local h = mob:FindFirstChildOfClass("Humanoid")
                if h then
                    if h.Health < lastHP then
                        lastHP = h.Health
                        hpStuckTime = tick()
                    elseif tick() - hpStuckTime > 60 then
                        break
                    end
                else
                    break
                end
                teleportToMob(mob)
                task.wait(cfg.tpDelay or 0.1)
            end
        end
    end)
end

local function startFarmAoELoop()
    killThread("farmAoE")
    lastFarmAlive = tick()
    threads["farmAoE"] = task.spawn(function()
        equipSlot(cfg.equippedSlot or 1)
        task.wait(0.3)
        while autoFarmAoE do
            lastFarmAlive = tick()
            local mob = getMobsInRange()
            if not mob then rebuildCache(); task.wait(0.5); continue end

            teleportToMob(mob)
            if cfg.autoReroll then
                task.wait(1)
                isRerolling = true
                for _, def in ipairs(skillDef) do stopSkill(def) end
                doReroll()
                task.wait(0.6)
                isRerolling = false
                for _, def in ipairs(skillDef) do
                    if cfg[def.cfgKey] then startSkill(def) end
                end
                teleportToMob(mob)
            end

            local hum = mob:FindFirstChildOfClass("Humanoid")
            local lastHP = hum and hum.Health or math.huge
            local hpStuckTime = tick()

            while autoFarmAoE and isAlive(mob) do
                lastFarmAlive = tick()
                if not LocalPlayer.Character then break end
                local h = mob:FindFirstChildOfClass("Humanoid")
                if h then
                    if h.Health < lastHP then
                        lastHP = h.Health
                        hpStuckTime = tick()
                    elseif tick() - hpStuckTime > 10 then
                        break
                    end
                else
                    break
                end
                teleportToMob(mob)
                task.wait(cfg.tpDelay or 0.1)
            end
        end
    end)
end

local function startFarmBossLoop()
    killThread("farmBoss")
    lastFarmAlive = tick()
    threads["farmBoss"] = task.spawn(function()
        equipSlot(cfg.equippedSlot or 1)
        task.wait(0.3)
        while autoFarmBoss do
            lastFarmAlive = tick()
            local mob = getBossInRange()
            if not mob then rebuildCache(); task.wait(0.5); continue end

            teleportToMob(mob)
            if cfg.autoReroll then
                task.wait(1)
                isRerolling = true
                for _, def in ipairs(skillDef) do stopSkill(def) end
                doReroll()
                task.wait(0.6)
                isRerolling = false
                for _, def in ipairs(skillDef) do
                    if cfg[def.cfgKey] then startSkill(def) end
                end
                teleportToMob(mob)
            end

            local hum = mob:FindFirstChildOfClass("Humanoid")
            local lastHP = hum and hum.Health or math.huge
            local hpStuckTime = tick()

            while autoFarmBoss and isAlive(mob) do
                lastFarmAlive = tick()
                if not LocalPlayer.Character then break end
                local h = mob:FindFirstChildOfClass("Humanoid")
                if h then
                    if h.Health < lastHP then
                        lastHP = h.Health
                        hpStuckTime = tick()
                    elseif tick() - hpStuckTime >= 1 then
                        warn("[AIRI] HP stuck 1s -> Retarget: " .. mob.Name)
                        break
                    end
                else
                    break
                end
                teleportToMob(mob)
                task.wait(cfg.tpDelay or 0.1)
            end
        end
    end)
end

local function startWatchdog()
    killThread("watchdog")
    threads["watchdog"] = task.spawn(function()
        while autoFarm or autoFarmAoE or autoFarmBoss do
            task.wait(5)
            if tick() - lastFarmAlive > 6 then
                warn("[AIRI] watchdog restart")
                if autoFarm then startFarmLoop()
                elseif autoFarmAoE then startFarmAoELoop()
                elseif autoFarmBoss then startFarmBossLoop()
                end
            end
        end
    end)
end

local function stopFarm()
    autoFarm = false; cfg.autoFarm = false; save()
    killThread("farm"); killThread("watchdog")
    unequipWeapon()
end

local function startFarm()
    stopFarm()
    if #(cfg.selectedMobs or {}) == 0 then
        warn("[AIRI] เลือกมอนก่อน!")
        pcall(function() AutoFarmToggleRef:Set(false) end)
        return
    end
    autoFarm = true; cfg.autoFarm = true; save()
    startFarmLoop(); startWatchdog()
end

local function stopFarmAoE()
    autoFarmAoE = false; cfg.autoFarmAoE = false; save()
    killThread("farmAoE"); killThread("watchdog")
end

local function stopFarmBoss()
    autoFarmBoss = false; cfg.autoFarmBoss = false; save()
    killThread("farmBoss"); killThread("watchdog")
end

local function startSpaceInvaderLoop()
    killThread("spaceInvader")
    threads["spaceInvader"] = task.spawn(function()
        equipSlot(cfg.equippedSlot or 1)
        task.wait(0.3)

        local needReroll = true
        while autoSpaceInvader do

            -- 1) รีโรล
            if needReroll or not questCheck() then
                needReroll = false

                -- รอให้ UI quest หายก่อน
                local waitTime = tick()
                while questCheck() and tick() - waitTime < 10 do
                    task.wait(0.3)
                end

                isRerolling = true
                for _, def in ipairs(skillDef) do stopSkill(def) end

                local npc = workspace.World.NPC.BossTask:FindFirstChild("240012")
                if not npc then
                    warn("[AIRI] ไม่เจอ NPC 240012")
                    isRerolling = false
                    task.wait(1)
                    continue
                end

                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local ok, pivot = pcall(function() return npc:GetPivot() end)
                    if ok and pivot then
                        hrp.CFrame = CFrame.new(pivot.Position + Vector3.new(0, 3, 0))
                        hrp.AssemblyLinearVelocity = Vector3.zero
                    end
                end

                local prompt = nil
                for _, v in ipairs(npc:GetDescendants()) do
                    if v:IsA("ProximityPrompt") then
                        prompt = v
                        break
                    end
                end

                local attempts = 0
                while not questCheck() do
                    if prompt then fireproximityprompt(prompt) else warn("[AIRI] ไม่เจอ prompt") end
                    attempts = attempts + 1
                    task.wait(cfg.rerollWait or 0.6)
                    if attempts > 300 then
                        warn("[AIRI] reroll เกิน 300 ครั้ง หยุด")
                        break
                    end
                end

                isRerolling = false
                for _, def in ipairs(skillDef) do
                    if cfg[def.cfgKey] then startSkill(def) end
                end
            end

            -- 2) หาบอส
            local mob = nil
            local findTime = tick()
            while autoSpaceInvader and not mob do
                rebuildCache()
                mob = getNearestFromCache(function(v)
                    return tostring(v.Name) == "[Lv.15000] Space Invader"
                end)
                if not mob then task.wait(1) end
                if tick() - findTime > 30 then
                    warn("[AIRI] ไม่เจอ Space Invader 30 วิ")
                    break
                end
            end

            if not mob then task.wait(0.5); continue end

            -- 3) ตีบอส
            while autoSpaceInvader and isAlive(mob) do
                if not LocalPlayer.Character then break end
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then break end

                -- เช็คว่าตัวเราตายไหม
                local myHum = char:FindFirstChildOfClass("Humanoid")
                if not myHum or myHum.Health <= 0 then
                    task.wait(3) -- รอ respawn
                    break
                end

                local ok, pivot = pcall(function() return mob:GetPivot() end)
                if not ok or not pivot then break end
                hrp.CFrame = CFrame.new(pivot.Position + Vector3.new(0, 3, 0))
                hrp.AssemblyLinearVelocity = Vector3.zero
                local h = mob:FindFirstChildOfClass("Humanoid")
                if not h or h.Health <= 0.5 then break end
                task.wait(cfg.tpDelay or 0.1)
            end

            -- บอสตายแล้ว บังคับรีโรลรอบหน้า
            needReroll = true
            local respawnTime = tick()
            while tick() - respawnTime < 5 do
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local myHum = char and char:FindFirstChildOfClass("Humanoid")
                if hrp and myHum and myHum.Health > 0 then break end
                task.wait(0.3)
            end

            task.wait(0.2)
        end
    end)
end
local function stopSpaceInvader()
    autoSpaceInvader = false
    cfg.autoSpaceInvader = false; save()
    killThread("spaceInvader")
end

local function lowGraphics()
    local Lighting = game:GetService("Lighting")

    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    Lighting.Brightness = 0
    Lighting.ClockTime = 14

    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("PostEffect") or v:IsA("Atmosphere") or v:IsA("Sky") then
            v:Destroy()
        end
    end

    settings().Rendering.QualityLevel = 1

    local count = 0
    for _, v in ipairs(workspace:GetDescendants()) do
        if v:IsA("PostEffect") or v:IsA("ParticleEmitter")
        or v:IsA("Trail") or v:IsA("Beam")
        or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles")
        or v:IsA("Decal") or v:IsA("Texture")
        or v:IsA("SpecialMesh") or v:IsA("SelectionBox")
        or v:IsA("Sound") then
            v:Destroy()
        elseif v:IsA("BasePart") then
            v.Material = Enum.Material.SmoothPlastic
            v.CastShadow = false
        elseif v:IsA("Light") then
            v.Shadows = false
            v.Enabled = false
        end
        count = count + 1
        if count % 100 == 0 then task.wait() end
    end

    print("[AIRI] lowGraphics เสร็จ")
end

-- detect ของใหม่แล้วลบทันที
local graphicsConnection = nil

local function startGraphicsWatcher()
    if graphicsConnection then return end
    graphicsConnection = workspace.DescendantAdded:Connect(function(v)
        if not cfg.lowGraphics then return end
        if v:IsA("PostEffect") or v:IsA("ParticleEmitter")
        or v:IsA("Trail") or v:IsA("Beam")
        or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles")
        or v:IsA("Decal") or v:IsA("Texture")
        or v:IsA("SelectionBox") or v:IsA("Sound") then
            v:Destroy()
        elseif v:IsA("BasePart") then
            v.Material = Enum.Material.SmoothPlastic
            v.CastShadow = false
        elseif v:IsA("Light") then
            v.Shadows = false
            v.Enabled = false
        end
    end)
end

if cfg.lowGraphics then
    task.wait(3)
    task.spawn(lowGraphics)
    startGraphicsWatcher()
end

-- =====================================================
-- COMBAT TAB
-- =====================================================

local CombatTab = Window:Tab({ Title = "Combat", Icon = "swords" })
CombatTab:Select()

AutoFarmToggleRef = CombatTab:Toggle({
    Title = "Auto Farm",
    Desc  = "ฟาร์มมอนที่เลือกไว้",
    Icon  = "play",
    Type  = "Checkbox",
    Value = cfg.autoFarm,
    Callback = function(v)
        if v then startFarm() else stopFarm() end
    end
})

AutoSpaceInvaderRef = CombatTab:Toggle({
    Title = "Auto Reroll + Space Invader",
    Desc  = "รีโรลจน 240012 ดรอป Secret Chest แล้ววาปตี Space Invader วนลูป",
    Icon  = "zap",
    Type  = "Checkbox",
    Value = cfg.autoSpaceInvader or false,
    Callback = function(v)
        cfg.autoSpaceInvader = v; save()
        if v then autoSpaceInvader = true; startSpaceInvaderLoop()
        else stopSpaceInvader() end
    end
})

CombatTab:Input({
    Title       = "Attack Delay",
    Desc        = "ดีเลย์โจมตี เช่น 0,1",
    Placeholder = tostring(cfg.attackDelay),
    Callback = function(v)
        local n = tonumber(v)
        if n and n >= 0 then cfg.attackDelay = n; save() end
    end
})

CombatTab:Input({
    Title       = "TP Delay",
    Desc        = "ความเร็ว teleport เช่น 0.1",
    Placeholder = tostring(cfg.tpDelay),
    Callback = function(v)
        local n = tonumber(v)
        if n and n >= 0 then cfg.tpDelay = n; save() end
    end
})

CombatTab:Input({
    Title       = "TP Offset",
    Desc        = "ระยะห่างจากมอน (studs) เช่น 3",
    Placeholder = tostring(cfg.tpOffset),
    Callback = function(v)
        local n = tonumber(v)
        if n and n >= 0 then cfg.tpOffset = n; save() end
    end
})

CombatTab:Divider({ Title = "Auto Skill (ทำงานอิสระ)" })

for _, def in ipairs(skillDef) do
    CombatTab:Toggle({
        Title = def.label and ("Auto "..def.label) or ("Auto Skill "..def.key),
        Desc  = "กด "..(def.label or def.key).." ทุก 0.1วิ เมื่อมีมอน",
        Icon  = "zap",
        Type  = "Checkbox",
        Value = cfg[def.cfgKey],
        Callback = function(v)
            cfg[def.cfgKey] = v; save()
            if v then startSkill(def) else stopSkill(def) end
        end
    })
    if cfg[def.cfgKey] then startSkill(def) end
end

-- =====================================================
-- QUEST TAB
-- =====================================================

local QuestTab = Window:Tab({ Title = "Quest", Icon = "list" })

QuestTab:Toggle({
    Title = "Auto Reroll",
    Desc  = "วาปหา NPC reroll ก่อนตีมอน/บอสทุกครั้ง",
    Icon  = "refresh-cw",
    Type  = "Checkbox",
    Value = cfg.autoReroll,
    Callback = function(v)
        cfg.autoReroll = v; save()
    end
})

QuestTab:Divider({ Title = "เลือกกล่องที่ต้องการ" })

QuestTab:Toggle({
    Title = "Holy Chest",
    Desc  = "รีจนได้ Holy Chest",
    Icon  = "box",
    Type  = "Checkbox",
    Value = cfg.wantHoly,
    Callback = function(v)
        cfg.wantHoly = v; save()
    end
})

QuestTab:Toggle({
    Title = "Space Chest",
    Desc  = "รีจนได้ Mythical Chest",
    Icon  = "box",
    Type  = "Checkbox",
    Value = cfg.wantSpaceChest,
    Callback = function(v)
        cfg.wantSpaceChest = v; save()
    end
})

QuestTab:Input({
    Title       = "Reroll Wait Time",
    Desc        = "รอกี่วิหลังกด reroll เช่น 1",
    Placeholder = tostring(cfg.rerollWait or 1),
    Callback = function(v)
        local n = tonumber(v)
        if n and n > 0 then cfg.rerollWait = n; save() end
    end
})

QuestTab:Input({
    Title       = "Holy Chest Amount",
    Desc        = "จำนวน Holy Chest ที่ต้องการ",
    Placeholder = tostring(cfg.wantHolyAmount or 1),
    Callback = function(v)
        local n = tonumber(v)
        if n and n > 0 then cfg.wantHolyAmount = n; save() end
    end
})

QuestTab:Input({
    Title = "Space Chest Amount",
    Desc        = "จำนวนSpace Chest ที่ต้องการ",
    Placeholder = tostring(cfg.wantSpaceChestAmount or 1),
    Callback = function(v)
        local n = tonumber(v)
        if n and n > 0 then cfg.wantSpaceChestAmount = n; save() end
    end
})

-- =====================================================
-- AUTO FARM TAB
-- =====================================================

local AutoTab = Window:Tab({ Title = "Auto Farm", Icon = "target" })

AutoTab:Divider({ Title = "ฟาร์มมอนรอบตัว" })

AutoFarmAoERef = AutoTab:Toggle({
    Title = "Farm มอน",
    Desc  = "ตีมอนที่ใกล้ที่สุดในรัศมีที่กำหนด",
    Icon  = "users",
    Type  = "Checkbox",
    Value = cfg.autoFarmAoE,
    Callback = function(v)
        cfg.autoFarmAoE = v; save()
        if v then autoFarmAoE = true; startFarmAoELoop(); startWatchdog()
        else stopFarmAoE() end
    end
})

AutoTab:Divider({ Title = "ฟาร์มบอส" })

AutoFarmBossRef = AutoTab:Toggle({
    Title = "Farm บอส",
    Desc  = "ตีบอสที่ใกล้ที่สุดในรัศมีที่กำหนด",
    Icon  = "zap",
    Type  = "Checkbox",
    Value = cfg.autoFarmBoss,
    Callback = function(v)
        cfg.autoFarmBoss = v; save()
        if v then autoFarmBoss = true; startFarmBossLoop(); startWatchdog()
        else stopFarmBoss() end
    end
})

local function summonBoss()
    pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        local SummonBoss = require(RS.Shared.Features.SummonBoss)
        local TEvent = require(RS.Shared.Core.TEvent)
        TEvent.FireRemote(SummonBoss.OP_EVENT, {
            op = SummonBoss.OP.Summon,
            summonId = selectedRaidId
        })
    end)
end

local function startRaidLoop()
    killThread("raid")
    threads["raid"] = task.spawn(function()
        equipSlot(cfg.equippedSlot or 1)
        task.wait(0.3)
        while autoRaid do
            rebuildCache()
            local raidCenter = Vector3.new(-1266, 59, 576)
            local mob = getNearestFromCache(function(v)
                local name = tostring(v.Name)
                if name == "Dummy" then return false end
                local ok, pivot = pcall(function() return v:GetPivot() end)
                if not ok then return false end
                return (pivot.Position - raidCenter).Magnitude < 200
            end)

            if not mob then
                summonBoss()
                task.wait(0.2)
                teleportToPos(raidCenter)
                task.wait(0.2)
            else
                local hum = mob:FindFirstChildOfClass("Humanoid")
                local lastHP = hum and hum.Health or math.huge
                local hpStuckTime = tick()

                while autoRaid and isAlive(mob) do
                    if not LocalPlayer.Character then break end
                    local h = mob:FindFirstChildOfClass("Humanoid")
                    if h then
                        if h.Health < lastHP then
                            lastHP = h.Health
                            hpStuckTime = tick()
                        elseif tick() - hpStuckTime > 10 then
                            break
                        end
                    else
                        break
                    end
                    teleportToMob(mob)
                    task.wait(cfg.tpDelay or 0.1)
                end
            end
        end
    end)
end

local function stopRaid()
    autoRaid = false
    killThread("raid")
end

local function startTowerLoop()
    killThread("tower")
    threads["tower"] = task.spawn(function()
        equipSlot(cfg.equippedSlot or 1)
        task.wait(0.3)

        -- วาปไป Sky Spire แล้ว Enter
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.CFrame = CFrame.new(Vector3.new(-2662, 52, -2364))
            hrp.AssemblyLinearVelocity = Vector3.zero
            task.wait(1)
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("ProximityPrompt") and v.Enabled then
                    local ok, pivot = pcall(function() return v.Parent:GetPivot() end)
                    if ok and pivot then
                        local d = (hrp.Position - pivot.Position).Magnitude
                        if d < 15 then
                            fireproximityprompt(v)
                            task.wait(1)
                            break
                        end
                    end
                end
            end
        end

        -- Start Tower
        pcall(function()
            local RS = game:GetService("ReplicatedStorage")
            local TEvent = require(RS.Shared.Core.TEvent)
            local TowerChallenge = require(RS.Shared.Features.TowerChallenge)
            TEvent.FireRemote(TowerChallenge.START_REQUEST_EVENT, {
                action = TowerChallenge.ACTION.Start,
                startLayer = cfg.towerLayer or 1,
                loopEnabled = true
            })
        end)
        task.wait(2)

            -- ตีมอนทุก 0.1 วิ
            while autoTower do
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp then task.wait(0.3); continue end
            
                rebuildCache()
                local towerCenter = Vector3.new(12, 525, -27)
                local mob = getNearestFromCache(function(v)
                    local ok, pivot = pcall(function() return v:GetPivot() end)
                    if not ok then return false end
                    return (pivot.Position - towerCenter).Magnitude < 150
                end)
                if mob then
                    teleportToMob(mob)
                end
            
                task.wait(0.1)
            end
        
    end)
end

local function stopTower()
    autoTower = false
    cfg.autoTower = false; save()
    killThread("tower")
end

AutoTab:Divider({ Title = "ตั้งค่า" })

AutoTab:Input({
    Title       = "Scan Range",
    Desc        = "รัศมีสแกนมอน/บอส (studs)",
    Placeholder = tostring(cfg.scanRange),
    Callback = function(v)
        local n = tonumber(v)
        if n and n > 0 then cfg.scanRange = n; save() end
    end
})

-- =====================================================
-- WEAPON TAB
-- =====================================================

local WeaponTab   = Window:Tab({ Title = "Weapon", Icon = "shield" })
local slotToggles = {}

for i = 1,3 do
    local t = WeaponTab:Toggle({
        Title = "Slot "..i,
        Desc  = "เลือกสล็อต "..i,
        Icon  = "sword",
        Type  = "Checkbox",
        Value = cfg.equippedSlot == i,
        Callback = function(v)
            if v then
                for s,tog in pairs(slotToggles) do
                    if s ~= i then pcall(function() tog:Set(false) end) end
                end
                cfg.equippedSlot = i; save(); equipSlot(i)
            end
        end
    })
    slotToggles[i] = t
end

-- =====================================================
-- MOBS TAB
-- =====================================================

local MobTab      = Window:Tab({ Title = "Mobs", Icon = "skull" })
local mobWidgets  = {}
local builtNames  = {}
local mobNameList = {}

local function buildMobList()
    local newNames = {}
    for name in pairs(knownMobNames) do
        if not builtNames[name] then
            table.insert(newNames, name)
        end
    end
    table.sort(newNames)

    for _, name in ipairs(newNames) do
        builtNames[name] = true
        table.insert(mobNameList, name)
        local count, hpNow, hpMax = getMobInfo(name)
        local desc = string.format("%d ตัว | HP %d/%d", count, math.floor(hpNow), math.floor(hpMax))
        local t = MobTab:Toggle({
            Title = name,
            Desc  = desc,
            Icon  = "crosshair",
            Type  = "Checkbox",
            Value = isNameSelected(name),
            Callback = function(v)
                if v then
                    if not isNameSelected(name) then
                        table.insert(cfg.selectedMobs, name); save()
                    end
                else
                    for i,n in ipairs(cfg.selectedMobs) do
                        if n == name then table.remove(cfg.selectedMobs, i); break end
                    end
                    save()
                end
            end
        })
        table.insert(mobWidgets, t)
    end
end

MobTab:Button({
    Title    = "Refresh Mob",
    Desc     = "สแกนหาชื่อมอนใหม่",
    Icon     = "refresh-cw",
    Callback = function()
        rebuildCache()
        scanAllEver()
        buildMobList()
    end
})


MobTab:Button({
    Title    = "ล้างมอนที่เลือก",
    Desc     = "เอา lock ทั้งหมดออก",
    Icon     = "trash",
    Callback = function()
        cfg.selectedMobs = {}; save()
        for _, w in ipairs(mobWidgets) do pcall(function() w:Destroy() end) end
        mobWidgets = {}; builtNames = {}; mobNameList = {}
        rebuildCache(); scanAllEver(); buildMobList()
    end
})

-- =====================================================
-- HOP FUNCTIONS
-- =====================================================

local function getServerWithLeastPlayers()
    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
    local ok, result = pcall(function()
        return request({ Url = url, Method = "GET" }).Body
    end)
    if not ok then warn("[AIRI] HttpGet ล้มเหลว"); return nil end
    local data = HttpService:JSONDecode(result)
    local best, bestCount = nil, math.huge
    for _, server in ipairs(data.data or {}) do
        if server.id ~= game.JobId and server.playing < bestCount then
            best = server.id
            bestCount = server.playing
        end
    end
    return best
end

local function hopServer()
    local jobId = getServerWithLeastPlayers()
    if jobId then
        game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, jobId, LocalPlayer)
    else
        warn("[AIRI] ไม่เจอเซิร์ฟ")
    end
end

local function checkBlacklist()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            for i = 1, 6 do
                local name = cfg["blacklist"..i] or ""
                if name ~= "" and (p.Name == name or p.DisplayName == name) then
                    warn("[AIRI] เจอ " .. name .. " -> hop")
                    hopServer()
                    return
                end
            end
        end
    end
end


-- =====================================================
-- HOP TAB
-- =====================================================

local HopTab = Window:Tab({ Title = "Hop", Icon = "user-x" })

local autoHop = false

HopTab:Toggle({
    Title = "Auto Hop",
    Desc  = "เปิดแล้วจะเช็คทุก 30 วิ ถ้าเจอคนใน blacklist จะ hop",
    Icon  = "log-out",
    Type  = "Checkbox",
    Value = cfg.autoHop or false,  -- โหลดค่าจาก cfg
    Callback = function(v)
        autoHop = v
        cfg.autoHop = v  -- บันทึกลง cfg
        save()
        if v then
            task.spawn(function()
                while autoHop do
                    task.wait(30)
                    if autoHop then
                        checkBlacklist()
                    end
                end
            end)
        end
    end
})

HopTab:Divider({ Title = "Blacklist Player" })

local blacklistToggles = {}

local function refreshBlacklistUI()
    for _, t in ipairs(blacklistToggles) do
        pcall(function() t:Destroy() end)
    end
    blacklistToggles = {}

    local shown = {}
    for i = 1, 6 do
        local savedName = cfg["blacklist"..i] or ""
        if savedName ~= "" and not shown[savedName] then
            shown[savedName] = true
            local capName = savedName
            local t = HopTab:Toggle({
                Title = capName,
                Desc  = "blacklisted",
                Icon  = "user-x",
                Type  = "Checkbox",
                Value = true,
                Callback = function(v)
                    if not v then
                        for j = 1, 6 do
                            if cfg["blacklist"..j] == capName then
                                cfg["blacklist"..j] = ""
                                save()
                                print("[AIRI] Unblacklist: " .. capName)
                                break
                            end
                        end
                    end
                end
            })
            table.insert(blacklistToggles, t)
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and not shown[p.Name] then
            local pName = p.Name
            shown[pName] = true
            local t = HopTab:Toggle({
                Title = p.DisplayName,
                Desc  = "@"..pName,
                Icon  = "user-x",
                Type  = "Checkbox",
                Value = false,
                Callback = function(v)
                    if v then
                        for i = 1, 6 do
                            if cfg["blacklist"..i] == "" then
                                cfg["blacklist"..i] = pName
                                save()
                                print("[AIRI] Blacklist: " .. pName)
                                break
                            end
                        end
                    else
                        for i = 1, 6 do
                            if cfg["blacklist"..i] == pName then
                                cfg["blacklist"..i] = ""
                                save()
                                print("[AIRI] Unblacklist: " .. pName)
                                break
                            end
                        end
                    end
                end
            })
            table.insert(blacklistToggles, t)
        end
    end
end

refreshBlacklistUI()

Players.PlayerAdded:Connect(function()
    refreshBlacklistUI()
end)

Players.PlayerRemoving:Connect(function()
    refreshBlacklistUI()
end)

task.spawn(function()
    while true do
        task.wait(60)
        refreshBlacklistUI()
    end
end)


-- =====================================================
-- TELEPORT TAB
-- =====================================================

local TpAllTab = Window:Tab({ Title = "TeleportAll", Icon = "map-pin" })

TpAllTab:Divider({ Title = "Altar" })

TpAllTab:Button({
    Title    = "Unlock All Altar",
    Desc     = "วาปกด Unlock ทุก Altar",
    Icon     = "unlock",
    Callback = function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local altarFolder = workspace:FindFirstChild("World") and
                            workspace.World:FindFirstChild("NPC") and
                            workspace.World.NPC:FindFirstChild("Altar")
        if not altarFolder then warn("[AIRI] ไม่เจอ Altar folder"); return end

        for _, altar in ipairs(altarFolder:GetChildren()) do
            local ok, pivot = pcall(function() return altar:GetPivot() end)
            if ok and pivot then
                hrp.CFrame = CFrame.new(pivot.Position + Vector3.new(0, 3, 0))
                hrp.AssemblyLinearVelocity = Vector3.zero
                task.wait(0.5)

                for _, v in ipairs(altar:GetDescendants()) do
                    if v:IsA("ProximityPrompt") then
                        fireproximityprompt(v)
                        print("[AIRI] Unlocked: " .. altar.Name)
                        task.wait(0.3)
                        break
                    end
                end
            end
        end
        print("[AIRI] Unlock All Altar เสร็จแล้ว ✅")
    end
})

TpAllTab:Divider({ Title = "Quest" })

TpAllTab:Button({
    Title    = "Accept All Quest",
    Desc     = "วาปกด Accept ทุก Quest",
    Icon     = "check-circle",
    Callback = function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local questList = {
            { name="Quest Skill Z",  pos=Vector3.new(288,55,-107)     },
            { name="Quest Skill X",  pos=Vector3.new(-594,66,-1124)   },
            { name="Quest Skill C",  pos=Vector3.new(-1478,53,29)     },
            { name="Quest Skill V",  pos=Vector3.new(-3135,478,-2424) },
            { name="Parry Master",   pos=Vector3.new(-1955,194,-488)  },
            { name="Block Master",   pos=Vector3.new(822,94,-272)     },
        }

        for _, q in ipairs(questList) do
            hrp.CFrame = CFrame.new(q.pos + Vector3.new(0, 3, 0))
            hrp.AssemblyLinearVelocity = Vector3.zero
            task.wait(0.5)

            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("ProximityPrompt") and v.Enabled then
                    local ok, pivot = pcall(function() return v.Parent:GetPivot() end)
                    if ok and pivot then
                        local d = (hrp.Position - pivot.Position).Magnitude
                        if d < 15 then
                            fireproximityprompt(v)
                            print("[AIRI] Accepted: " .. q.name)
                            task.wait(0.3)
                        end
                    end
                end
            end
        end
        print("[AIRI] Accept All Quest เสร็จแล้ว ✅")
    end
})

local TpTab = Window:Tab({ Title = "Teleport", Icon = "map-pin" })

local npcList = {
    { name="Summon Boss",      desc="",                   npcId="", pos=Vector3.new(-1273,59,486)    },
    { name="Upgrade 1",        desc="",                   npcId="",       pos=Vector3.new(-839,130,-1279)  },
    { name="Upgrade 2",        desc="",                   npcId="",       pos=Vector3.new(-2783,154,-2424) },
    { name="event",            desc="",                   npcId="",       pos=Vector3.new(-763,50,828)     },
    { name="Sky Spire",        desc="",                   npcId="",       pos=Vector3.new(-2662,52,-2364)  },
    { name="Sword master",     desc="",                   npcId="",       pos=Vector3.new(-653,70,-931)    },
    { name="Katana master",    desc="",                   npcId="",       pos=Vector3.new(-661,62,-831)    },
    { name="Buster Master",    desc="",                   npcId="",       pos=Vector3.new(-1915,135,-190)  },
    { name="Excalibur",        desc="",                   npcId="",       pos=Vector3.new(-2615,1595,-2510)},
    { name="Moon Cut",         desc="",                   npcId="",       pos=Vector3.new(-1406,56,322)    },
    { name="Parr Master",      desc="",                   npcId="",       pos=Vector3.new(-1955,194,-488)  },
    { name="Block Master",     desc="",                   npcId="",       pos=Vector3.new(822,94,-272)     },
    { name="Quest skillz z",   desc="",                   npcId="",       pos=Vector3.new(288,55,-107)     },
    { name="Quest skillz x",   desc="",                   npcId="",       pos=Vector3.new(-594,66,-1124)   },
    { name="Quest skillz c",   desc="",                   npcId="",       pos=Vector3.new(-1478,53,29)     },
    { name="Quest skillz v",   desc="",                   npcId="",       pos=Vector3.new(-3135,478,-2424) },
    { name="Storm chief",      desc="",                   npcId="",       pos=Vector3.new(-2657,437,-2408) },
    { name="flame chief",      desc="",                   npcId="",       pos=Vector3.new(-2743,443,-2411) },
    { name="Thunder Chief",    desc="",                   npcId="",       pos=Vector3.new(-2744,440,-2496) },
    { name="frost Chief",      desc="",                   npcId="",       pos=Vector3.new(-2658,433,-2498) },
    { name="Pale Crossing",    desc="",                   npcId="เขียว",   pos=Vector3.new(958,197,-3658)   },
    { name="Broken Expanse",   desc="",                   npcId="ฟ้า",     pos=Vector3.new(514,197,-3213)   },
    { name="Chrono Sanctum",   desc="",                   npcId="น้ำตาล",  pos=Vector3.new(1336,197,-2386)  },
    { name="Abyss of Null",    desc="",                   npcId="ขาว",     pos=Vector3.new(1788,197,-2832)  },
}

local function tpToNpc(data)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local other = workspace:FindFirstChild("World") and
                  workspace.World:FindFirstChild("NPC") and
                  workspace.World.NPC:FindFirstChild("Other")
    if other then
        local npc = other:FindFirstChild(data.npcId)
        if npc then
            local ok, pivot = pcall(function() return npc:GetPivot() end)
            if ok and pivot then
                local pos  = pivot.Position
                local look = pivot.LookVector
                hrp.CFrame = CFrame.new(pos + (look * -3), pos)
                return
            end
        end
    end
    teleportToPos(data.pos)
end

TpTab:Divider({ Title = "NPC / Raid" })

for _, data in ipairs(npcList) do
    TpTab:Button({
        Title    = data.name,
        Desc     = data.desc,
        Icon     = "map-pin",
        Callback = function() tpToNpc(data) end
    })
end

local RaidTab = Window:Tab({ Title = "Auto Raid", Icon = "zap" })

local raidBossList = {
    { name="Moraros Hard",      id=220001 },
    { name="Moraros Nightmare", id=220101 },
    { name="Magador Hard",      id=220002 },
    { name="Magador Nightmare", id=220102 },
    { name="Ragaros Hard",      id=220003 },
    { name="Ragaros Nightmare", id=220103 },
    { name="Velik Hard",        id=220004 },
    { name="Velik Nightmare",   id=220104 },
    { name="Nivaron Hard",      id=220005 },
    { name="Nivaron Nightmare", id=220105 },
    { name="Gelaros Hard",      id=220006 },
    { name="Gelaros Nightmare", id=220106 },
    { name="Veyrath Hard",      id=220007 },
    { name="Veyrath Nightmare", id=220107 },
}

-- โหลด id จากชื่อที่บันทึกไว้
for _, boss in ipairs(raidBossList) do
    if boss.name == cfg.selectedRaidName then
        selectedRaidId = boss.id
        break
    end
end

RaidTab:Divider({ Title = "เลือกบอส" })

local raidToggles = {}
for _, boss in ipairs(raidBossList) do
    local b = boss
    local t = RaidTab:Toggle({
        Title = b.name,
        Icon  = "skull",
        Type  = "Checkbox",
        Value = cfg.selectedRaidName == b.name,
        Callback = function(v)
            if v then
                selectedRaidId = b.id
                cfg.selectedRaidName = b.name
                save()
                for name, tog in pairs(raidToggles) do
                    if name ~= b.name then
                        pcall(function() tog:Set(false) end)
                    end
                end
            end
        end
    })
    raidToggles[b.name] = t
end

RaidTab:Divider({ Title = "Auto Raid" })

AutoRaidRef = RaidTab:Toggle({
    Title = "Auto Raid",
    Desc  = "Summon และตีบอสอัตโนมัติ",
    Icon  = "play",
    Type  = "Checkbox",
    Value = cfg.autoRaid or false,
    Callback = function(v)
        cfg.autoRaid = v; save()
        if v then autoRaid = true; startRaidLoop()
        else stopRaid() end
    end
})

RaidTab:Divider({ Title = "Auto Sky Spire" })

RaidTab:Input({
    Title       = "Start Layer",
    Desc        = "ชั้นที่จะเริ่ม",
    Placeholder = tostring(cfg.towerLayer or 1),
    Callback = function(v)
        local n = tonumber(v)
        if n and n > 0 then cfg.towerLayer = n; save() end
    end
})

AutoTowerRef = RaidTab:Toggle({
    Title = "Auto Sky Spire",
    Desc  = "วาปเข้า Tower แล้วตีมอนอัตโนมัติ",
    Icon  = "arrow-up",
    Type  = "Checkbox",
    Value = cfg.autoTower or false,
    Callback = function(v)
        cfg.autoTower = v; save()
        if v then autoTower = true; startTowerLoop()
        else stopTower() end
    end
})

RaidTab:Divider({ Title = "Megumin Boss" })

local autoMegumin = false
local AutoMeguminRef

local function startMeguminLoop()
    killThread("megumin")
    threads["megumin"] = task.spawn(function()
        equipSlot(cfg.equippedSlot or 1)
        task.wait(0.3)
        while autoMegumin do
            rebuildCache()
            local mob = getNearestFromCache(function(v)
                local ok, pivot = pcall(function() return v:GetPivot() end)
                if not ok then return false end
                return (pivot.Position - Vector3.new(-634, 50, 1102)).Magnitude < 200
            end)

            if not mob then
                pcall(function()
                    game:GetService("ReplicatedStorage").Remote_Event:FireServer(
                        buffer.fromstring("\147P\205\001/\145\132\171worldBossId\206\000\006A\155\162op\166Summon\165count\001\171autoEnabled\194")
                    )
                end)
                task.wait(0.2)
            else
                teleportToMob(mob)
                task.wait(cfg.tpDelay or 0.1)
            end
        end
    end)
end

local function stopMegumin()
    autoMegumin = false
    killThread("megumin")
end

AutoMeguminRef = RaidTab:Toggle({
    Title = "Auto Megumin",
    Desc  = "Summon และตีบอสที่ Megumin",
    Icon  = "zap",
    Type  = "Checkbox",
    Value = cfg.autoMegumin or false,
    Callback = function(v)
        cfg.autoMegumin = v; save()
        if v then autoMegumin = true; startMeguminLoop()
        else stopMegumin() end
    end
})

RaidTab:Divider({ Title = "Gaspa Boss" })

local autoGaspa = false
local AutoGaspaRef

local function startGaspaLoop()
    killThread("gaspa")
    threads["gaspa"] = task.spawn(function()
        equipSlot(cfg.equippedSlot or 1)
        task.wait(0.3)
        while autoGaspa do
            rebuildCache()
            local mob = getNearestFromCache(function(v)
                local ok, pivot = pcall(function() return v:GetPivot() end)
                if not ok then return false end
                return (pivot.Position - Vector3.new(-634, 50, 1102)).Magnitude < 200
            end)

            if not mob then
                pcall(function()
                    game:GetService("ReplicatedStorage").Remote_Event:FireServer(
                        buffer.fromstring("\147\205\002c\205\001/\145\132\171worldBossId\206\000\006A\145\162op\166Summon\165count\001\171autoEnabled\194")
                    )
                end)
                task.wait(0.2)
            else
                teleportToMob(mob)
                task.wait(cfg.tpDelay or 0.2)
            end
        end
    end)
end

local function stopGaspa()
    autoGaspa = false
    killThread("gaspa")
end

AutoGaspaRef = RaidTab:Toggle({
    Title = "Auto Gaspa",
    Desc  = "Summon และตีบอส Gaspa",
    Icon  = "zap",
    Type  = "Checkbox",
    Value = cfg.autoGaspa or false,
    Callback = function(v)
        cfg.autoGaspa = v; save()
        if v then autoGaspa = true; startGaspaLoop()
        else stopGaspa() end
    end
})

local GraphicsTab = Window:Tab({ Title = "Graphics", Icon = "monitor" })

GraphicsTab:Toggle({
    Title = "Low Graphics",
    Desc  = "ลบเอฟเฟค/เท็กเจอ/แสง เพื่อลดแลค",
    Icon  = "zap-off",
    Type  = "Checkbox",
    Value = cfg.lowGraphics or false,
    Callback = function(v)
        cfg.lowGraphics = v; save()
        if v then
            task.spawn(lowGraphics)
            startGraphicsWatcher()
        end
    end
})

-- =====================================================
-- INIT
-- =====================================================

task.spawn(function()
    task.wait(2)

    rebuildCache()
    scanAllEver()
    buildMobList()

    local es = getES()
    if es then
        es.DescendantAdded:Connect(function(v)
            if v:IsA("Model") then
                local h = v:FindFirstChildOfClass("Humanoid")
                if h then
                    table.insert(mobCache, v)
                    local name = tostring(v.Name)
                    if not knownMobNames[name] then
                        knownMobNames[name] = true
                        buildMobList()
                    end
                end
            end
        end)
        es.DescendantRemoving:Connect(function(v)
            if v:IsA("Model") then
                for i, m in ipairs(mobCache) do
                    if m == v then table.remove(mobCache, i); break end
                end
            end
        end)
    end

    if cfg.autoFarm and #(cfg.selectedMobs or {}) > 0 then
        autoFarm = false
        pcall(function() AutoFarmToggleRef:Set(true) end)
    end
    if cfg.autoFarmAoE then
        autoFarmAoE = false
        pcall(function() AutoFarmAoERef:Set(true) end)
    end
    if cfg.autoFarmBoss then
        autoFarmBoss = false
        pcall(function() AutoFarmBossRef:Set(true) end)
    end
    if cfg.autoHop then
        autoHop = true
        task.spawn(function()
            while autoHop do
                task.wait(5)
                if autoHop then
                    checkBlacklist()
                end
            end
        end)
    end
end)

if cfg.autoRaid then
    autoRaid = false
    pcall(function() AutoRaidRef:Set(true) end)
end

if cfg.autoTower then
    autoTower = false
    pcall(function() AutoTowerRef:Set(true) end)
end

if cfg.autoMegumin then
    autoMegumin = false
    pcall(function() AutoMeguminRef:Set(true) end)
end

if cfg.autoGaspa then
    autoGaspa = false
    pcall(function() AutoGaspaRef:Set(true) end)
end
