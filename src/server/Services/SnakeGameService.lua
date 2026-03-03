local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

print("[SnakeGameService] 模块加载")

-- 配置参数
local GAME_AREA_SIZE = 240
local INITIAL_LENGTH = 2      -- 头+尾
local SNAKE_SPEED = 15
local GAME_TICK = 1/60
local MONEY_PER_FOOD = 10
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

-------------------------------------------------------------------------------
-- Service 核心方法
-------------------------------------------------------------------------------

function SnakeGameService:AddSnakeLength(userId, amount)
    local s = snakes[userId]
    if not s or not s.alive then return end

    s.score = (s.score or 0) + amount
    s.displayLength = (s.displayLength or #s.body) + amount
    
    local multiplier = getGrowthMultiplier(s.score)
    s.pendingGrowthScore = (s.pendingGrowthScore or 0) + (amount * multiplier)
    
    local added = 0
    while s.pendingGrowthScore >= BASE_PHYSICAL_COST do
        s.pendingGrowthScore = s.pendingGrowthScore - BASE_PHYSICAL_COST
        added = added + 1
    end
    s.growthPending = (s.growthPending or 0) + added
    
    -- 核心修复：长度变化时立即同步，确保客户端生长可见，且不需要定时刷新
    local state = self:GetGameState()
    LeaderboardChangedSignal:Fire(state.leaderboard, state.snakes)
    
    -- 钞票同步
    local uid = tostring(userId)
    playerMoney[uid] = (playerMoney[uid] or 0) + (amount * MONEY_PER_FOOD)
    local p = Players:GetPlayerByUserId(tonumber(userId))
    if p then MoneyChangedSignal:FireTo(p, playerMoney[uid]) end
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

local function spawnFood()
    local pos = Vector3.new((math.random()*2-1)*220, 0, (math.random()*2-1)*220)
    local rand = math.random()
    local val = 1
    if rand < 0.01 then val = 11 elseif rand < 0.05 then val = 8 elseif rand < 0.2 then val = 4 end
    table.insert(food, { id = nextFoodId, pos = pos, value = val })
    nextFoodId = nextFoodId + 1
    FoodChangedSignal:Fire(food)
end

local function moveSnakes()
    for pid, s in pairs(snakes) do
        if s.alive and s.isMoving then
            local head = s.body[1]
            local nextHead = head + s.targetDirection * SNAKE_SPEED * GAME_TICK
            
            -- 边界限制
            nextHead = Vector3.new(math.clamp(nextHead.X, -239, 239), 0, math.clamp(nextHead.Z, -239, 239))
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
        if #food < 250 then spawnFood() end
    end)
    
    Players.PlayerAdded:Connect(function(p)
        playerDailyGifts[tostring(p.UserId)] = loadGiftData(p.UserId)
        self:RequestRespawn(p)
        
        -- 核心修复：确保角色重生时也能隐藏
        p.CharacterAdded:Connect(function()
            task.wait(0.5)
            SnakeSpawnedSignal:Fire(p.UserId, snakes[p.UserId].body, Color3.new(1,1,1))
        end)
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
            end
        end
    end)
end

function SnakeGameService:KnitStart() print("[SnakeGameService] 启动完成") end

return SnakeGameService
