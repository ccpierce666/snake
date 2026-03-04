local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

print("[SnakeGameService] 模块加载")

-- 配置参数
local GAME_AREA_SIZE = 240
local WALL_POSITION = 240 -- 围墙内侧表面位置
local INITIAL_LENGTH = 2      -- 头+尾
local SNAKE_SPEED = 15
local GAME_TICK = 1/60
-- local MONEY_PER_FOOD = 10 -- 已废弃，改为吃2个食物得1金钱
local BASE_PHYSICAL_COST = 300 -- 调优：300分换一节身体，1k奖励=3.3节，加上初始共5.3节，视觉合理

local moneyStore = DataStoreService:GetDataStore("SnakeGameMoney_v1")
local giftStore = DataStoreService:GetDataStore("SnakeGameGifts_v1")
local spinStore = DataStoreService:GetDataStore("SnakeGameSpins_v1")

local Knit = _G.KnitInstance or require(ReplicatedStorage.Common.Knit)

-- 创建信号
local FoodChangedSignal = Knit.CreateSignal()
local LeaderboardChangedSignal = Knit.CreateSignal()
local DirectionChangedSignal = Knit.CreateSignal()
local MoneyChangedSignal = Knit.CreateSignal()
local SnakeSpawnedSignal = Knit.CreateSignal()
local SnakeDiedSignal = Knit.CreateSignal()
local GiftUpdateSignal = Knit.CreateSignal()
local SpinsChangedSignal = Knit.CreateSignal()  -- 抽奖次数更新信号

local SnakeGameService = Knit.CreateService {
    Name = "SnakeGameService",
    Client = {
        FoodChanged = FoodChangedSignal,
        LeaderboardChanged = LeaderboardChangedSignal,
        DirectionChanged = DirectionChangedSignal,
        MoneyChanged = MoneyChangedSignal,
        SnakeSpawned = SnakeSpawnedSignal,
        SnakeDied = SnakeDiedSignal,
        GiftUpdate = GiftUpdateSignal,
        SpinsChanged = SpinsChangedSignal,
    },
}

-- 游戏数据
local snakes = {}
local food = {}
local nextFoodId = 1
local playerMoney = {}
local playerSpins = {}
local playerDailyGifts = {}
local playerFoodCounts = {} -- 用于记录吃食物数量，实现 2:1 金钱逻辑

-- 奖励配置
local GIFT_REWARDS = {
    { time = 30, type = "Length", amount = 1000 },
    { time = 90, type = "Length", amount = 3000 },
    { time = 180, type = "Spin", amount = 1 },
    { time = 300, type = "Length", amount = 5000 },
    { time = 600, type = "Length", amount = 10000 },
    { time = 900, type = "Spin", amount = 2 },
    { time = 1200, type = "Length", amount = 25000 },
    { time = 1800, type = "Length", amount = 30000 },
    { time = 2100, type = "Spin", amount = 3 },
    { time = 3000, type = "Length", amount = 100000 },
    { time = 4200, type = "Length", amount = 250000 },
    { time = 5400, type = "Length", amount = 1000000 },
}

-- 抽奖轮盘配置 (8个奖项，对应图片顺时针顺序)
local SPIN_WHEEL = {
    { id=1, reward = "2K Length",   type="Length", amount=2000,    probability = 0.35 }, -- Red
    { id=2, reward = "x100 Special",type="Spin",   amount=100,     probability = 0.01 }, -- Black (假设是100次抽奖或特殊奖励)
    { id=3, reward = "50K Length",  type="Length", amount=50000,   probability = 0.05 }, -- Purple
    { id=4, reward = "5K Length",   type="Length", amount=5000,    probability = 0.15 }, -- Dark Purple
    { id=5, reward = "25K Length",  type="Length", amount=25000,   probability = 0.15 }, -- Blue
    { id=6, reward = "100K Length", type="Length", amount=100000,  probability = 0.02 }, -- Cyan
    { id=7, reward = "10K Length",  type="Length", amount=10000,   probability = 0.15 }, -- Green
    { id=8, reward = "1M Length",   type="Length", amount=1000000, probability = 0.005 }, -- Orange
}

local FOOD_GROWTH_MAP = {
    [1] = 2, [2] = 4, [3] = 8, [4] = 16, [5] = 32, [6] = 64, [7] = 128, [8] = 256, [9] = 512, [10] = 1024, [11] = 2048
}

-------------------------------------------------------------------------------
-- 工具方法
-------------------------------------------------------------------------------

local function getLeaderboard()
    local list = {}
    for userId, s in pairs(snakes) do
        if s.alive then
            table.insert(list, { 
                userId = userId, 
                score = s.score or 0, 
                kills = s.kills or 0, 
                length = s.displayLength or #s.body,
                bodyCount = #s.body
            })
        end
    end
    table.sort(list, function(a, b) return a.score > b.score end)
    return list
end

local function calculateSnakeRadius(score)
    if score < 1000 then return 0.8
    elseif score < 10000 then return 1.5
    elseif score < 100000 then return 2.5
    else return 4.0 end
end

-- 用于计算视觉大小，与客户端保持一致
local function calculateVisualBodySize(score)
    if score < 100 then
        -- 0-100: 3x growth (0.6 -> 1.8)
        return 0.6 + (score / 100) * 1.2
    elseif score < 1000 then
        -- 100-1000: 2x growth (1.8 -> 3.6)
        return 1.8 + ((score - 100) / 900) * 1.8
    elseif score < 10000 then
        -- 1000-10000: Slow growth (3.6 -> 6.0)
        return 3.6 + ((score - 1000) / 9000) * 2.4
    else
        -- 10000+: Cap at 8.0
        return math.min(8.0, 6.0 + ((score - 10000) / 90000) * 2.0)
    end
end

local function getGrowthMultiplier(score)
    if score < 10000 then return 1.00 + (score / 10000) * 0.06
    elseif score < 100000 then return 1.06 + ((score - 10000) / 90000) * 0.27
    elseif score < 500000 then return 1.33 + ((score - 100000) / 400000) * 0.67
    else return 2.0 end
end

local function loadGiftData(userId)
    local success, saved = pcall(function() return giftStore:GetAsync("gift_" .. tostring(userId)) end)
    local today = os.date("%Y-%m-%d")
    if success and saved and type(saved) == "table" and saved.lastDate == today then
        saved.timePlayed = tonumber(saved.timePlayed) or 0
        saved.claimed = saved.claimed or {}
        return saved
    end
    return { lastDate = today, timePlayed = 0, claimed = {} }
end

local function loadMoney(userId)
    local success, saved = pcall(function() return moneyStore:GetAsync("money_" .. tostring(userId)) end)
    if success and saved then
        return tonumber(saved) or 0
    end
    return 0
end

local function saveMoney(userId)
    local uid = tostring(userId)
    local m = playerMoney[uid]
    if m then
        pcall(function() moneyStore:SetAsync("money_" .. uid, m) end)
    end
end

local function saveSpins(userId)
    local uid = tostring(userId)
    local s = playerSpins[uid]
    if s then
        pcall(function() spinStore:SetAsync("spin_" .. uid, s) end)
    end
end

-------------------------------------------------------------------------------
-- Service 核心方法
-------------------------------------------------------------------------------

function SnakeGameService:AddSnakeLength(userId, amount)
    local s = snakes[userId]
    if not s or not s.alive then return end

    s.score = (s.score or 0) + amount
    s.displayLength = (s.displayLength or #s.body) + amount
    
    -- 核心修复：直接根据目标长度来决定是否生长，不再依赖 cost 累积
    -- 目标是：在 X 分数时，应该有 Y 个视觉节
    -- 1 个视觉节需要的物理长度 = visualSize * 0.6
    -- 1 个物理帧提供的长度 = SNAKE_SPEED * GAME_TICK = 0.25
    
    local visualSize = calculateVisualBodySize(s.score)
    local spacing = visualSize * 0.6
    
    -- 计算目标节数 (Target Visual Segments)
    local targetSegments = 2
    if s.score < 300 then
        -- 0-300: 2 -> 8 (每50分长一节)
        targetSegments = 2 + math.floor(s.score / 50)
    elseif s.score < 1000 then
        -- 300-1000: 8 -> 15 (每100分长一节)
        targetSegments = 8 + math.floor((s.score - 300) / 100)
    elseif s.score < 2000 then
        -- 1000-2000: 15 -> 20 (每200分长一节)
        targetSegments = 15 + math.floor((s.score - 1000) / 200)
    else
        -- 2000+: 每300分长一节
        targetSegments = 20 + math.floor((s.score - 2000) / 300)
    end
    
    -- 计算目标物理帧数 (Target Physical Frames)
    -- 总物理长度 = 目标节数 * 间距
    -- 总帧数 = 总物理长度 / 每帧长度
    local speedPerFrame = SNAKE_SPEED * GAME_TICK -- 0.25
    local targetPhysicalLength = targetSegments * spacing
    local targetFrameCount = math.ceil(targetPhysicalLength / speedPerFrame)
    
    -- 当前帧数
    local currentFrameCount = #s.body
    
    -- 如果当前帧数不足，则补充 growthPending
    if currentFrameCount < targetFrameCount then
        local diff = targetFrameCount - currentFrameCount
        s.growthPending = (s.growthPending or 0) + diff
    end
    
    -- 清空旧的积分逻辑，避免冲突
    s.pendingGrowthScore = 0
    
    -- 核心修复：长度变化时立即同步，确保客户端生长可见，且不需要定时刷新
    local state = self:GetGameState()
    LeaderboardChangedSignal:Fire(state.leaderboard, state.snakes)
end

function SnakeGameService:ClaimGift(player, index)
    local uid = tostring(player.UserId)
    local data = playerDailyGifts[uid]
    local reward = GIFT_REWARDS[index]
    if not data or not reward or data.claimed[tostring(index)] or data.timePlayed < reward.time then
        return false, "Cannot claim"
    end
    
    data.claimed[tostring(index)] = true
    if reward.type == "Length" then
        self:AddSnakeLength(player.UserId, reward.amount)
    elseif reward.type == "Spin" then
        playerSpins[uid] = (playerSpins[uid] or 0) + reward.amount
    end
    
    pcall(function() giftStore:SetAsync("gift_" .. uid, data) end)
    GiftUpdateSignal:FireTo(player, data)
    return true
end

function SnakeGameService:ChangeDirection(player, direction)
    local s = snakes[player.UserId]
    if not s then return end
    if not s.alive then
        self:RequestRespawn(player)
        s = snakes[player.UserId]
    end
    
    if direction.Magnitude > 0.1 then
        s.targetDirection = direction.Unit
        s.isMoving = true
        DirectionChangedSignal:Fire(player.UserId, s.targetDirection, true)
    else
        s.isMoving = false
        DirectionChangedSignal:Fire(player.UserId, s.targetDirection, false)
    end
end

function SnakeGameService:RequestRespawn(player)
    local pos = Vector3.new((math.random()*2-1)*80, 0, (math.random()*2-1)*80)
    local body = { pos }
    for i = 1, INITIAL_LENGTH - 1 do
        table.insert(body, pos - Vector3.new(0.8 * i, 0, 0))
    end
    
    snakes[player.UserId] = {
        body = body,
        direction = Vector3.new(1, 0, 0),
        targetDirection = Vector3.new(0, 0, 0),
        isMoving = false,
        score = 0,
        alive = true,
        growthPending = 0,
        pendingGrowthScore = 0,
        displayLength = INITIAL_LENGTH
    }
    SnakeSpawnedSignal:Fire(player.UserId, body, Color3.new(math.random(), math.random(), math.random()))
    
    -- 玩家重生时也发送排行榜更新
    local state = self:GetGameState()
    LeaderboardChangedSignal:Fire(state.leaderboard, state.snakes)
end

-- 抽奖功能
function SnakeGameService:Spin(player)
    local uid = tostring(player.UserId)
    local spins = playerSpins[uid] or 0
    
    if spins <= 0 then
        return false, "No spins"
    end
    
    -- 扣除一次抽奖次数
    playerSpins[uid] = spins - 1
    saveSpins(player.UserId)
    
    -- 通知客户端抽奖次数更新
    SpinsChangedSignal:FireTo(player, playerSpins[uid])
    
    -- 根据概率随机抽奖
    local rand = math.random()
    local accumulated = 0
    local selectedReward = nil
    
    for _, reward in ipairs(SPIN_WHEEL) do
        accumulated = accumulated + reward.probability
        if rand <= accumulated then
            selectedReward = reward
            break
        end
    end
    
    if not selectedReward then
        selectedReward = SPIN_WHEEL[1]  -- 默认为第一个
    end
    
    -- 发放奖励
    if selectedReward.type == "Length" then
        self:AddSnakeLength(player.UserId, selectedReward.amount)
    elseif selectedReward.type == "Spin" then
        playerSpins[uid] = (playerSpins[uid] or 0) + selectedReward.amount
        saveSpins(player.UserId)
    end
    
    print(string.format("[Spin] 玩家 %s 抽到: %s, 剩余抽奖: %d", 
        player.Name, selectedReward.reward, playerSpins[uid]))
    
    return true, selectedReward
end

function SnakeGameService:GetGameState()
    local state = { snakes = {}, food = food, leaderboard = getLeaderboard() }
    for uid, s in pairs(snakes) do
        state.snakes[tostring(uid)] = {
            body = s.body, direction = s.direction, isMoving = s.isMoving,
            score = s.score, alive = s.alive
        }
    end
    return state
end

-------------------------------------------------------------------------------
-- 客户端映射
-------------------------------------------------------------------------------

function SnakeGameService.Client:ClaimGift(player, index) return self.Server:ClaimGift(player, index) end
function SnakeGameService.Client:GetGiftData(player) return playerDailyGifts[tostring(player.UserId)] or loadGiftData(player.UserId) end
function SnakeGameService.Client:Spin(player) return self.Server:Spin(player) end
function SnakeGameService.Client:GetSpins(player) return playerSpins[tostring(player.UserId)] or 0 end
function SnakeGameService.Client:GetGameState(p) return self.Server:GetGameState() end
function SnakeGameService.Client:ChangeDirection(p, d) self.Server:ChangeDirection(p, d) end
function SnakeGameService.Client:RequestRespawn(p) self.Server:RequestRespawn(p) end

-------------------------------------------------------------------------------
-- 核心循环
-------------------------------------------------------------------------------

local MAX_FOOD = 1200 -- 400 * 3
local CENTER_RADIUS = 50 -- 100*100区域，半径50

local function spawnFood()
    -- 1. 决定等级
    local rand = math.random()
    local val = 1
    
    -- 6以上概率调小为之前的1/4
    if rand < 0.0005 then val = 11      -- 0.05% (极品)
    elseif rand < 0.0012 then val = 10  -- 0.12%
    elseif rand < 0.0025 then val = 8    -- 0.25%
    elseif rand < 0.005 then val = 7     -- 0.5%
    -- 1-6 (99%+)
    elseif rand < 0.05 then val = 6    -- 3%
    elseif rand < 0.10 then val = 5    -- 5%
    elseif rand < 0.20 then val = 4    -- 10%
    elseif rand < 0.30 then val = 3    -- 10%
    elseif rand < 0.45 then val = 2    -- 15%
    else val = 1 end                   -- 55% (白色基础)

    local pos
    local isCenter = false
    
    if val > 6 then
        isCenter = true -- 6以上强制中心
    else
        -- 1-6: 少量在中心 (10%)，大部分在外层
        if math.random() < 0.1 then
            isCenter = true
        else
            isCenter = false
        end
    end
    
    if isCenter then
        -- 中心区域 100x100 (-50..50)
        local range = CENTER_RADIUS
        pos = Vector3.new((math.random()*2-1)*range, 0, (math.random()*2-1)*range)
    else
        -- 外层区域 (围墙附近)
        -- 避开中心区域 (-60..60)，最大到 230
        local limit = 230
        local inner = 60 -- 稍微大于中心区域，留点空隙或重叠
        
        -- 随机生成在空心矩形内
        local side = math.random(1, 4)
        local x, z
        
        if side == 1 then     -- Top (Z < -inner)
            x = (math.random()*2-1) * limit
            z = -inner - math.random() * (limit - inner)
        elseif side == 2 then -- Bottom (Z > inner)
            x = (math.random()*2-1) * limit
            z = inner + math.random() * (limit - inner)
        elseif side == 3 then -- Left (X < -inner)
            x = -inner - math.random() * (limit - inner)
            z = (math.random()*2-1) * limit
        else                  -- Right (X > inner)
            x = inner + math.random() * (limit - inner)
            z = (math.random()*2-1) * limit
        end
        pos = Vector3.new(x, 0, z)
    end

    table.insert(food, { id = nextFoodId, pos = pos, value = val })
    nextFoodId = nextFoodId + 1
    FoodChangedSignal:Fire(food)
end

local function moveSnakes()
    for pid, s in pairs(snakes) do
        if s.alive and s.isMoving then
            local head = s.body[1]
            local nextHead = head + s.targetDirection * SNAKE_SPEED * GAME_TICK
            
            -- 计算视觉大小和半径
            local visualSize = calculateVisualBodySize(s.score or 0)
            local visualRadius = visualSize * 0.75 -- 头部半径约为 size * 1.5 / 2

            -- 动态边界限制：围墙位置(240) - 视觉半径，确保头部正好切到墙面
            local limit = WALL_POSITION - visualRadius
            
            -- 额外的微小缓冲，防止浮点误差导致穿插
            limit = limit - 0.2

            nextHead = Vector3.new(math.clamp(nextHead.X, -limit, limit), 0, math.clamp(nextHead.Z, -limit, limit))
            table.insert(s.body, 1, nextHead)
            
            -- 食物检测
            local radius = calculateSnakeRadius(s.score)
            local pickupRange = 6 + radius
            
            for i = #food, 1, -1 do
                local f = food[i]
                local dist = (nextHead - f.pos).Magnitude
                if dist < pickupRange then
                    local growth = FOOD_GROWTH_MAP[f.value or 1] or 2
                    SnakeGameService:AddSnakeLength(pid, growth)
                    
                    -- 修改金钱获取逻辑：每吃 2 个食物获得 1 金钱 (2:1)
                    local uid = tostring(pid)
                    playerFoodCounts[uid] = (playerFoodCounts[uid] or 0) + 1
                    if playerFoodCounts[uid] % 2 == 0 then
                        playerMoney[uid] = (playerMoney[uid] or 0) + 1
                        local p = Players:GetPlayerByUserId(tonumber(pid))
                        if p then MoneyChangedSignal:FireTo(p, playerMoney[uid]) end
                    end
                    
                    table.remove(food, i)
                    FoodChangedSignal:Fire(food)
                end
            end
            
            if (s.growthPending or 0) > 0 then
                s.growthPending = s.growthPending - 1
            else
                table.remove(s.body)
            end
        end
    end
end

function SnakeGameService:KnitInit()
    -- 核心修复：删除默认 Baseplate 防止闪烁
    local baseplate = workspace:FindFirstChild("Baseplate")
    if baseplate then baseplate:Destroy() end

    RunService.Heartbeat:Connect(function()
        moveSnakes()
        -- 提高生成速度：每次检查多次，以便快速达到高上限
        if #food < MAX_FOOD then
            for _ = 1, 5 do
                spawnFood()
                if #food >= MAX_FOOD then break end
            end
        end
    end)
    
    Players.PlayerAdded:Connect(function(p)
        playerDailyGifts[tostring(p.UserId)] = loadGiftData(p.UserId)
        
        -- 加载金钱
        playerMoney[tostring(p.UserId)] = loadMoney(p.UserId)
        playerFoodCounts[tostring(p.UserId)] = 0
        
        -- 延迟同步金钱，确保客户端已加载
        task.delay(1, function()
            MoneyChangedSignal:FireTo(p, playerMoney[tostring(p.UserId)])
        end)
        
        self:RequestRespawn(p)
        
        -- 核心修复：确保角色重生时也能隐藏
        p.CharacterAdded:Connect(function()
            task.wait(0.5)
            SnakeSpawnedSignal:Fire(p.UserId, snakes[p.UserId].body, Color3.new(1,1,1))
        end)
    end)
    
    Players.PlayerRemoving:Connect(function(p)
        saveMoney(p.UserId)
        local uid = tostring(p.UserId)
        playerMoney[uid] = nil
        playerFoodCounts[uid] = nil
        playerDailyGifts[uid] = nil
        if snakes[p.UserId] then snakes[p.UserId] = nil end
    end)
    
    task.spawn(function()
        while true do
            task.wait(1)
            for _, p in ipairs(Players:GetPlayers()) do
                local d = playerDailyGifts[tostring(p.UserId)]
                if d then
                    d.timePlayed = d.timePlayed + 1
                    if d.timePlayed % 5 == 0 then GiftUpdateSignal:FireTo(p, d) end
                end
                
                -- 自动保存金钱 (每60秒)
                if os.time() % 60 == 0 then
                    saveMoney(p.UserId)
                end
            end
        end
    end)
end

function SnakeGameService:KnitStart() print("[SnakeGameService] 启动完成") end

return SnakeGameService