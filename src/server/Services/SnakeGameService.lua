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
local leaderboardUpdateCounter = 0
local LEADERBOARD_UPDATE_INTERVAL = 3 -- 每3帧更新一次排行榜
local playerMoney = {}
local playerSpins = {}
local playerDailyGifts = {}
local playerFoodCounts = {} -- 用于记录吃食物数量
local playerSkinColors = {} -- [userId] = Color3，玩家专属初始颜色

-- 皮肤颜色池：黄、白、蓝、橙、红
local SKIN_COLOR_POOL = {
    Color3.fromRGB(255, 210, 60),  -- 黄
    Color3.fromRGB(240, 240, 240), -- 白
    Color3.fromRGB(80, 160, 255),  -- 蓝
    Color3.fromRGB(255, 140, 40),  -- 橙
    Color3.fromRGB(255, 70, 70),   -- 红
}
local skinColorIndex = 0

-- 统一 key 格式：所有内存表一律用 "u" + userId，避免 Lua 将纯数字字符串误判为整数 key
local function uid(userId) return "u" .. tostring(userId) end
-- 从 "uXXXXXX" 反向提取数字 userId（用于 GetPlayerByUserId 等需要数字的 API）
local function uidNum(key) return tonumber(string.sub(tostring(key), 2)) end

local function assignSkinColor(userId)
    local key = uid(userId)
    if not playerSkinColors[key] then
        skinColorIndex = (skinColorIndex % #SKIN_COLOR_POOL) + 1
        playerSkinColors[key] = SKIN_COLOR_POOL[skinColorIndex]
    end
    return playerSkinColors[key]
end

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
    for k, s in pairs(snakes) do
        if s.alive then
            table.insert(list, { 
                userId = uidNum(k),  -- 客户端需要数字 userId（用于头像加载等）
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
        return 0.6 + (score / 100) * 0.6                              -- 0.6 -> 1.2
    elseif score < 1000 then
        return 1.2 + ((score - 100) / 900) * 0.3                     -- 1.2 -> 1.5
    elseif score < 10000 then
        return 1.5 + ((score - 1000) / 9000) * 0.5                   -- 1.5 -> 2.0
    elseif score < 100000 then
        return 2.0 + ((score - 10000) / 90000) * 0.7                 -- 2.0 -> 2.7
    else
        return math.min(3.6, 2.7 + ((score - 100000) / 900000) * 0.9) -- 2.7 -> 3.6
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
    local key = uid(userId)
    local m = playerMoney[key]
    if m then
        pcall(function() moneyStore:SetAsync("money_" .. tostring(userId), m) end)
    end
end

local function saveSpins(userId)
    local key = uid(userId)
    local s = playerSpins[key]
    if s then
        pcall(function() spinStore:SetAsync("spin_" .. tostring(userId), s) end)
    end
end

-------------------------------------------------------------------------------
-- Service 核心方法
-------------------------------------------------------------------------------

function SnakeGameService:AddSnakeLength(userId, amount)
    local s = snakes[uid(userId)]
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
    local key = uid(player.UserId)
    local data = playerDailyGifts[key]
    local reward = GIFT_REWARDS[index]
    if not data or not reward or data.claimed[tostring(index)] or data.timePlayed < reward.time then
        return false, "Cannot claim"
    end
    
    data.claimed[tostring(index)] = true
    if reward.type == "Length" then
        self:AddSnakeLength(player.UserId, reward.amount)
    elseif reward.type == "Spin" then
        playerSpins[key] = (playerSpins[key] or 0) + reward.amount
    end
    
    pcall(function() giftStore:SetAsync("gift_" .. tostring(player.UserId), data) end)
    GiftUpdateSignal:FireTo(player, data)
    return true
end

function SnakeGameService:ChangeDirection(player, direction)
    local s = snakes[uid(player.UserId)]
    if not s then return end
    if not s.alive then
        self:RequestRespawn(player)
        s = snakes[uid(player.UserId)]
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
    
    snakes[uid(player.UserId)] = {
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
    SnakeSpawnedSignal:Fire(player.UserId, body, assignSkinColor(player.UserId))
    
    -- 玩家重生时也发送排行榜更新
    local state = self:GetGameState()
    LeaderboardChangedSignal:Fire(state.leaderboard, state.snakes)
end

-- 抽奖功能
function SnakeGameService:Spin(player)
    local key = uid(player.UserId)
    local spins = playerSpins[key] or 0
    
    if spins <= 0 then
        return false, "No spins"
    end
    
    -- 扣除一次抽奖次数
    playerSpins[key] = spins - 1
    saveSpins(player.UserId)
    
    -- 通知客户端抽奖次数更新
    SpinsChangedSignal:FireTo(player, playerSpins[key])
    
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
        playerSpins[key] = (playerSpins[key] or 0) + selectedReward.amount
        saveSpins(player.UserId)
    end
    
    print(string.format("[Spin] 玩家 %s 抽到: %s, 剩余抽奖: %d", 
        player.Name, selectedReward.reward, playerSpins[key]))
    
    return true, selectedReward
end

function SnakeGameService:GetGameState()
    local state = { snakes = {}, food = food, leaderboard = getLeaderboard() }
    for k, s in pairs(snakes) do
        state.snakes[k] = {
            body = s.body, direction = s.direction, isMoving = s.isMoving,
            score = s.score, alive = s.alive,
            displayLength = s.displayLength or #s.body,
            color = playerSkinColors[k],
        }
    end
    return state
end

-------------------------------------------------------------------------------
-- 客户端映射
-------------------------------------------------------------------------------

function SnakeGameService.Client:ClaimGift(player, index) return self.Server:ClaimGift(player, index) end
function SnakeGameService.Client:GetGiftData(player) return playerDailyGifts[uid(player.UserId)] or loadGiftData(player.UserId) end
function SnakeGameService.Client:Spin(player) return self.Server:Spin(player) end
function SnakeGameService.Client:GetSpins(player) return playerSpins[uid(player.UserId)] or 0 end
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

-- 私有函数：获取游戏状态（供 moveSnakes 使用）
local function getGameStatePrivate()
    local state = { snakes = {}, food = food, leaderboard = getLeaderboard() }
    for k, s in pairs(snakes) do
        -- k 本身就是 "uXXXXXX"，直接作为广播 key
        state.snakes[k] = {
            body = s.body, direction = s.direction, isMoving = s.isMoving,
            score = s.score, alive = s.alive,
            displayLength = s.displayLength or #s.body,
            color = playerSkinColors[k],
        }
    end
    return state
end

local function moveSnakes()
    for k, s in pairs(snakes) do
        -- k 是 "uXXXXXX" 格式；需要数字 userId 时用 uidNum(k)
        if s.alive and s.isMoving then
            local head = s.body[1]
            local nextHead = head + s.targetDirection * SNAKE_SPEED * GAME_TICK
            
            -- 计算视觉大小和半径
            local visualSize = calculateVisualBodySize(s.score or 0)
            local visualRadius = visualSize * 0.75

            local limit = WALL_POSITION - visualRadius - 0.2

            nextHead = Vector3.new(math.clamp(nextHead.X, -limit, limit), 0, math.clamp(nextHead.Z, -limit, limit))
            table.insert(s.body, 1, nextHead)
            
            -- 食物检测
            local radius = calculateSnakeRadius(s.score)
            local pickupRange = 6 + radius
            
            local foodEaten = false
            for i = #food, 1, -1 do
                local f = food[i]
                local dist = (nextHead - f.pos).Magnitude
                if dist < pickupRange then
                    local growth = FOOD_GROWTH_MAP[f.value or 1] or 2
                    SnakeGameService:AddSnakeLength(uidNum(k), growth)
                    
                    -- 每吃 1 个食物获得 1 金钱 (1:1)
                    playerMoney[k] = (playerMoney[k] or 0) + 1
                    local p = Players:GetPlayerByUserId(uidNum(k))
                    if p then MoneyChangedSignal:FireTo(p, playerMoney[k]) end
                    
                    table.remove(food, i)
                    foodEaten = true
                end
            end
            
            -- 如果吃了食物，更新排行榜
            if foodEaten then
                FoodChangedSignal:Fire(food)
                local state = getGameStatePrivate()
                LeaderboardChangedSignal:Fire(state.leaderboard, state.snakes)
            end
            
            -- 蛇与蛇碰撞检测
            for otherK, otherSnake in pairs(snakes) do
                if otherK ~= k and otherSnake.alive then
                    local otherScore = otherSnake.score or 0
                    local currentScore = s.score or 0
                    local otherHeadRadius = calculateSnakeRadius(otherScore)
                    local collisionDistance = radius + otherHeadRadius
                    
                    -- 检测当前蛇的头部与其他蛇的身体碰撞
                    for bodyIdx, bodySegment in ipairs(otherSnake.body) do
                        if bodyIdx > 1 then
                            local dist = (nextHead - bodySegment).Magnitude
                            if dist < collisionDistance then
                                if otherScore > currentScore then
                                    -- 对方更大，当前蛇死亡
                                    local lostLength = s.displayLength or #s.body
                                    s.alive = false
                                    
                                    local killerPlayer = Players:GetPlayerByUserId(uidNum(otherK))
                                    local killerName = killerPlayer and killerPlayer.Name or "Unknown"
                                    local victim = Players:GetPlayerByUserId(uidNum(k))
                                    
                                    if victim then
                                        SnakeDiedSignal:FireTo(victim, {
                                            killedBy = killerName,
                                            lostSize = lostLength,
                                        })
                                        print("[SnakeGameService] Player " .. victim.Name .. " died to " .. killerName .. ", lost " .. lostLength)
                                    end
                                    
                                    SnakeGameService:AddSnakeLength(uidNum(otherK), lostLength)
                                    break
                                elseif currentScore > otherScore then
                                    -- 当前蛇更大，其他蛇死亡
                                    local lostLength = otherSnake.displayLength or #otherSnake.body
                                    otherSnake.alive = false
                                    
                                    local victim = Players:GetPlayerByUserId(uidNum(otherK))
                                    local victimName = victim and victim.Name or "Unknown"
                                    local killer = Players:GetPlayerByUserId(uidNum(k))
                                    
                                    if victim then
                                        SnakeDiedSignal:FireTo(victim, {
                                            killedBy = killer and killer.Name or "Unknown",
                                            lostSize = lostLength,
                                        })
                                        print("[SnakeGameService] Player " .. victimName .. " died to " .. (killer and killer.Name or "Unknown") .. ", lost " .. lostLength)
                                    end
                                    
                                    SnakeGameService:AddSnakeLength(uidNum(k), lostLength)
                                    break
                                end
                            end
                        end
                    end
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
        
        -- 定期更新排行榜（每3帧更新一次）
        leaderboardUpdateCounter = leaderboardUpdateCounter + 1
        if leaderboardUpdateCounter >= LEADERBOARD_UPDATE_INTERVAL then
            leaderboardUpdateCounter = 0
            local state = SnakeGameService:GetGameState()
            LeaderboardChangedSignal:Fire(state.leaderboard, state.snakes)
        end
    end)
    
    Players.PlayerAdded:Connect(function(p)
        local key = uid(p.UserId)
        playerDailyGifts[key] = loadGiftData(p.UserId)
        playerMoney[key] = loadMoney(p.UserId)
        playerFoodCounts[key] = 0
        
        task.delay(1, function()
            MoneyChangedSignal:FireTo(p, playerMoney[key])
        end)
        
        self:RequestRespawn(p)
        
        p.CharacterAdded:Connect(function()
            task.wait(0.5)
            local sn = snakes[uid(p.UserId)]
            if sn then
                SnakeSpawnedSignal:Fire(p.UserId, sn.body, assignSkinColor(p.UserId))
            end
        end)
    end)
    
    Players.PlayerRemoving:Connect(function(p)
        saveMoney(p.UserId)
        local key = uid(p.UserId)
        playerMoney[key] = nil
        playerFoodCounts[key] = nil
        playerDailyGifts[key] = nil
        snakes[key] = nil
    end)
    
    task.spawn(function()
        while true do
            task.wait(1)
            for _, p in ipairs(Players:GetPlayers()) do
                local d = playerDailyGifts[uid(p.UserId)]
                if d then
                    d.timePlayed = d.timePlayed + 1
                    if d.timePlayed % 5 == 0 then GiftUpdateSignal:FireTo(p, d) end
                end
                
                if os.time() % 60 == 0 then
                    saveMoney(p.UserId)
                end
            end
        end
    end)
end

function SnakeGameService:KnitStart() print("[SnakeGameService] 启动完成") end

return SnakeGameService