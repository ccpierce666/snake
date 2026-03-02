local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")

print("[SnakeGameService] 模块加载")

-- 游戏区域大小（世界坐标）
local GAME_AREA_SIZE = 120  -- 每边120 studs，总共 240x240 的游戏区域
local INITIAL_LENGTH = 5   -- 蛇的初始长度 (设为较短，视觉上约1-2节)
local SNAKE_SPEED = 15  -- studs/秒 (降低速度)
local SNAKE_RADIUS = 0.8  -- 蛇头部分的碰撞半径
local FOOD_RADIUS = 0.6
local GAME_TICK = 1/60  -- 60 FPS
local MONEY_PER_FOOD = 10 -- 每点食物价值对应的钞票数

local moneyStore = DataStoreService:GetDataStore("SnakeGameMoney_v1")
local giftStore = DataStoreService:GetDataStore("SnakeGameGifts_v1")
local spinStore = DataStoreService:GetDataStore("SnakeGameSpins_v1")

print("[SnakeGameService] 自由移动模式 - 游戏区域大小=" .. GAME_AREA_SIZE)

local Knit = _G.KnitInstance
if not Knit then
    -- 备用：从 ReplicatedStorage 加载
    Knit = require(ReplicatedStorage.Common.Knit)
end

print("[SnakeGameService] 获取 Knit 实例")

-- 创建信号
local FoodChangedSignal = Knit.CreateSignal()
local LeaderboardChangedSignal = Knit.CreateSignal()
local DirectionChangedSignal = Knit.CreateSignal()
local MoneyChangedSignal = Knit.CreateSignal()
local SnakeSpawnedSignal = Knit.CreateSignal()
local SnakeDiedSignal = Knit.CreateSignal()
local GiftUpdateSignal = Knit.CreateSignal() -- 每日礼物更新

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
    },
}

local snakes = {}
local food = {}
local nextFoodId = 1  -- 全局食物ID计数器
local playerMoney = {} -- [userId(string)] = 累计钞票总数
local playerSpins = {} -- [userId(string)] = 剩余抽奖次数
local playerDailyGifts = {} -- [userId(string)] = { lastDate="...", timePlayed=0, claimed={} }

-- 每日礼物奖励配置
local GIFT_REWARDS = {
    { time = 30, type = "Length", amount = 1000 },       -- 00:30
    { time = 90, type = "Length", amount = 3000 },       -- 01:30
    { time = 180, type = "Spin", amount = 1 },           -- 03:00
    { time = 300, type = "Length", amount = 5000 },      -- 05:00
    { time = 600, type = "Length", amount = 10000 },     -- 10:00
    { time = 900, type = "Spin", amount = 2 },           -- 15:00
    { time = 1200, type = "Length", amount = 25000 },    -- 20:00
    { time = 1800, type = "Length", amount = 30000 },    -- 30:00
    { time = 2100, type = "Spin", amount = 3 },          -- 35:00
    { time = 3000, type = "Length", amount = 100000 },   -- 50:00
    { time = 4200, type = "Length", amount = 250000 },   -- 70:00
    { time = 5400, type = "Length", amount = 1000000 },  -- 90:00
}

-- 非线性增长倍数系统
-- 根据当前身体长度计算增长倍数，使得小蛇增长慢，大蛇增长快
local function calculateGrowthMultiplier(currentLength)
    -- 递推逻辑：倍数 = 1 + (currentLength / 500000)^0.25
    -- 前期极慢增长（指数0.25更陡峭），中后期才快速加速
    -- 上限：倍数最高不超过 2.0（500000+ 段时稳定在 2.0）
    local maxLength = 500000
    local normalizedLength = math.min(currentLength, maxLength)
    local ratio = normalizedLength / maxLength  -- 0 到 1 之间
    local multiplier = 1.0 + (ratio ^ 0.25)     -- 1.0 到 2.0 之间（更平缓起始）
    return multiplier
end

local function saveMoney(userId)
    local money = playerMoney[tostring(userId)]
    if money then
        pcall(function()
            moneyStore:SetAsync("money_" .. tostring(userId), money)
        end)
    end
end

local function loadMoney(userId)
    local success, saved = pcall(function()
        return moneyStore:GetAsync("money_" .. tostring(userId))
    end)
    return (success and saved) or 0
end

local function saveGiftData(userId)
    local data = playerDailyGifts[tostring(userId)]
    if data then
        pcall(function()
            giftStore:SetAsync("gift_" .. tostring(userId), data)
        end)
    end
end

local function loadGiftData(userId)
    local success, saved = pcall(function()
        return giftStore:GetAsync("gift_" .. tostring(userId))
    end)
    
    local today = os.date("%Y-%m-%d")
    if success and saved and saved.lastDate == today then
        return saved
    else
        -- 新的一天，或者没有数据，重置
        return { lastDate = today, timePlayed = 0, claimed = {} }
    end
end

local function saveSpins(userId)
    local spins = playerSpins[tostring(userId)]
    if spins then
        pcall(function()
            spinStore:SetAsync("spins_" .. tostring(userId), spins)
        end)
    end
end

local function loadSpins(userId)
    local success, saved = pcall(function()
        return spinStore:GetAsync("spins_" .. tostring(userId))
    end)
    return (success and saved) or 0
end

function SnakeGameService:ClaimGift(player, index)
    local uid = tostring(player.UserId)
    local data = playerDailyGifts[uid]
    
    if not data then return false, "No data" end
    
    local reward = GIFT_REWARDS[index]
    if not reward then return false, "Invalid reward" end
    
    -- 检查是否已领取
    if data.claimed[tostring(index)] then
        return false, "Already claimed"
    end
    
    -- 检查时间是否足够
    if data.timePlayed < reward.time then
        return false, "Not enough time"
    end
    
    -- 发放奖励
    data.claimed[tostring(index)] = true
    
    if reward.type == "Length" then
        -- 增加蛇的长度（物理长度和UI长度）
        local s = snakes[player.UserId]
        if s and s.alive then
            -- 1. 增加UI显示长度
            s.displayLength = (s.displayLength or #s.body) + reward.amount
            
            -- 2. 增加物理生长 (这里简单处理，每20分长1节)
            -- 也可以直接长 reward.amount 节，但那样蛇会瞬间变得巨大，可能卡顿
            -- 这里选择稍微平滑一点，或者直接给物理长度
            -- 考虑到数值很大(1M)，直接给物理长度会让服务器爆炸。
            -- 策略：只增加 score/displayLength，物理长度按原有规则慢慢长，或者给一定比例的物理增长
            
            -- 修改：让它加入待生长队列
            local physicalGrowth = math.ceil(reward.amount / 50) -- 50:1 比例，避免过大
            if physicalGrowth < 1 then physicalGrowth = 1 end
            s.growthPending = (s.growthPending or 0) + physicalGrowth
            
            s.score = s.score + reward.amount
            LeaderboardChangedSignal:Fire(getLeaderboard())
        end
    elseif reward.type == "Spin" then
        playerSpins[uid] = (playerSpins[uid] or 0) + reward.amount
        saveSpins(player.UserId)
    end
    
    saveGiftData(player.UserId)
    GiftUpdateSignal:FireTo(player, data)
    
    print("[Gift] Player " .. player.Name .. " claimed gift " .. index)
    return true
end

function SnakeGameService.Client:ClaimGift(player, index)
    return self.Server:ClaimGift(player, index)
end

function SnakeGameService.Client:GetGiftData(player)
    return playerDailyGifts[tostring(player.UserId)]
end

local function randomPosition()
    local halfArea = GAME_AREA_SIZE * 0.8 -- 缩小生成范围，避免出生在边界
    local x = (math.random() * 2 - 1) * halfArea
    local z = (math.random() * 2 - 1) * halfArea
    return Vector3.new(x, 0, z)
end

local function createSnake(player)
    local headPos = randomPosition()
    local body = { headPos }
    -- 蛇的身体从头部向后延伸
    local baseDir = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
    for i = 1, INITIAL_LENGTH - 1 do
        local segPos = headPos - baseDir * SNAKE_RADIUS * 2 * i
        table.insert(body, segPos)
    end
    return {
        body = body,  -- 蛇的身体是一个Vector3的列表
        direction = Vector3.new(1, 0, 0),  -- 初始方向
        targetDirection = Vector3.new(0, 0, 0),  -- 目标方向（默认不移动）
        isMoving = false,  -- 是否应该移动
        score = 0,
        kills = 0,
        alive = true,
        growthPending = 0, -- 待增长的长度（物理身体）
        pendingGrowthScore = 0, -- 累积的未转化为长度的分数（用于控制增长速度）
        displayLength = #body, -- 初始化UI显示长度为物理身体长度
    }
end

local function randomEmptyPosition()
    for _ = 1, 10 do
        local pos = randomPosition()
        -- 简单的碰撞检查：检查是否距离任何蛇的身体足够远
        local isSafe = true
        for _, s in pairs(snakes) do
            if s.alive and #s.body > 0 then
                local headDist = (pos - s.body[1]).Magnitude
                if headDist < FOOD_RADIUS + SNAKE_RADIUS + 2 then
                    isSafe = false
                    break
                end
            end
        end
        if isSafe then return pos end
    end
    return randomPosition()
end

local function spawnFood()
    local pos = randomEmptyPosition()
    
    -- 新食物价值体系：2的倍数 (2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048)
    -- 等级对应：1=2, 2=4, 3=8, 4=16, 5=32, 6=64, 7=128, 8=256, 9=512, 10=1024, 11=2048
    local rand = math.random()
    local value = 1  -- 等级（用于颜色和概率控制）
    
    -- 概率递减表（等级越高，概率越低）
    if rand < 0.0001 then value = 11       -- 0.01% 等级11 -> 2048增长
    elseif rand < 0.0005 then value = 10   -- 0.04% 等级10 -> 1024增长
    elseif rand < 0.002 then value = 9     -- 0.15% 等级9 -> 512增长
    elseif rand < 0.008 then value = 8     -- 0.6% 等级8 -> 256增长
    elseif rand < 0.025 then value = 7     -- 1.7% 等级7 -> 128增长（64以后概率很小）
    elseif rand < 0.06 then value = 6      -- 3.5% 等级6 -> 64增长
    elseif rand < 0.12 then value = 5      -- 6% 等级5 -> 32增长
    elseif rand < 0.22 then value = 4      -- 10% 等级4 -> 16增长
    elseif rand < 0.35 then value = 3      -- 13% 等级3 -> 8增长
    elseif rand < 0.50 then value = 2      -- 15% 等级2 -> 4增长
    else value = 1 end                     -- 50% 等级1 -> 2增长
    
    local id = nextFoodId
    nextFoodId = nextFoodId + 1
    table.insert(food, { id = id, pos = pos, value = value })
    
    -- 广播食物变化
    FoodChangedSignal:Fire(food)
end

local function getLeaderboard()
    local list = {}
    for userId, s in pairs(snakes) do
        if s.alive then
            local display = s.displayLength or #s.body
            local physical = #s.body + (s.growthPending or 0)
            table.insert(list, { 
                userId = userId, 
                score = s.score, 
                kills = s.kills, 
                length = display, 
                physicalLength = physical 
            })
        end
    end
    table.sort(list, function(a, b) return a.score > b.score end)
    return list
end

-- 实时获取当前游戏状态（不再广播，而是客户端主动拉取）
local function getGameState()
    local state = {
        snakes = {},
        food = food,
        leaderboard = getLeaderboard(),
        playerCount = #Players:GetPlayers(),
    }
    for userId, s in pairs(snakes) do
        state.snakes[tostring(userId)] = {
            body = s.body,
            direction = s.direction,
            targetDirection = s.targetDirection,
            isMoving = s.isMoving,
            score = s.score,
            kills = s.kills,
            alive = s.alive,
        }
    end
    return state
end

local function checkCollisionWithBounds(headPos)
    -- 检查是否超出游戏区域
    if math.abs(headPos.X) > GAME_AREA_SIZE or math.abs(headPos.Z) > GAME_AREA_SIZE then
        return true
    end
    return false
end

local function checkCollisionWithSelf(playerId, headPos)
    local s = snakes[playerId]
    if not s or not s.alive then return false end
    
    -- 跳过蛇头的后几个节段（因为刚加入的新节段在尾部）
    for i = 4, #s.body do
        -- 忽略Y轴差异
        local dist = math.sqrt((headPos.X - s.body[i].X)^2 + (headPos.Z - s.body[i].Z)^2)
        if dist < SNAKE_RADIUS * 2 then
            return true
        end
    end
    return false
end

local function checkCollisionWithOthers(playerId, headPos)
    local s = snakes[playerId]
    if not s or not s.alive then return false end
    
    for otherId, other in pairs(snakes) do
        if otherId ~= playerId and other.alive and #other.body > 0 then
            -- 检查碰撞
            for i, seg in ipairs(other.body) do
                -- 忽略Y轴差异
                local dist = math.sqrt((headPos.X - seg.X)^2 + (headPos.Z - seg.Z)^2)
                if dist < SNAKE_RADIUS * 2 then
                    return true, i
                end
            end
        end
    end
    return false
end

local function checkCollision(playerId, headPos)
    local s = snakes[playerId]
    if not s or not s.alive then return end

    -- 只有被比自己大的蛇的头部撞到才会死亡
    for otherId, other in pairs(snakes) do
        if otherId ~= playerId and other.alive then
            local otherHead = other.body[1]
            -- 忽略Y轴
            local dist = math.sqrt((headPos.X - otherHead.X)^2 + (headPos.Z - otherHead.Z)^2)
            
            -- 头对头碰撞半径
            if dist < SNAKE_RADIUS * 2 then
                local myLen = #s.body
                local otherLen = #other.body
                
                -- 如果对方比我长，我死
                if otherLen > myLen then
                    print("[SnakeGameService] 玩家 " .. playerId .. " 被更大的蛇 " .. otherId .. " (长:"..otherLen..") 吃掉")
                    s.alive = false
                    -- 变成食物 (尸体每节价值 3，每5个节点生成一个以避免食物过多)
                    for i = 1, #s.body, 5 do 
                        local id = nextFoodId
                        nextFoodId = nextFoodId + 1
                        table.insert(food, { id = id, pos = s.body[i], value = 3 }) 
                    end
                    FoodChangedSignal:Fire(food)
                    LeaderboardChangedSignal:Fire(getLeaderboard())
                    SnakeDiedSignal:Fire(playerId, myLen, 0)
                    return
                end
            end
        end
    end
end

local function moveSnakes()
    local stateChanged = false
    for playerId, s in pairs(snakes) do
        if s.alive and #s.body > 0 and s.isMoving then
            -- 只有在按下按键（isMoving=true）时才移动
            -- 更新方向
            if s.targetDirection.Magnitude > 0.1 then
                s.direction = s.targetDirection
            end

            local head = s.body[1]
            local newHead = head + s.direction * SNAKE_SPEED * GAME_TICK
            
            -- 限制在地图边界内（撞墙不死，只是停住）
            local limit = GAME_AREA_SIZE - 1
            newHead = Vector3.new(
                math.clamp(newHead.X, -limit, limit),
                0,
                math.clamp(newHead.Z, -limit, limit)
            )

            checkCollision(playerId, newHead)
            if s.alive then
                table.insert(s.body, 1, newHead)
                
                -- 检查食物碰撞：圈内所有食物全部吸取 (半径与客户端虚线圈一致，稍微放大以容忍延迟误差)
                local PICKUP_RADIUS = 7.0 -- 从 5.5 增加到 7.0，增强吸附感，解决延迟导致的"穿过未吃"
                local foundFoodList = {}
                for i, f in ipairs(food) do
                    local fPos = f.pos or f
                    if type(fPos) ~= "userdata" then fPos = f.pos end
                    local dist = math.sqrt((newHead.X - fPos.X)^2 + (newHead.Z - fPos.Z)^2)
                    if dist < PICKUP_RADIUS then
                        table.insert(foundFoodList, i)
                    end
                end
                
                if #foundFoodList > 0 then
                    local totalVal = 0
                    local addedPhysicalGrowth = 0
                    
                    -- 食物值对应的增长长度（UI显示值）
                    -- 最小的是3，接着是6，12，24，56，224，512，1024这样
                    local foodGrowthMap = {
                        [1] = 3,
                        [2] = 6,
                        [3] = 12,
                        [4] = 24,
                        [5] = 56,
                        [6] = 224,
                        [7] = 512,
                        [8] = 1024,
                        [9] = 2048,
                        [10] = 4096,
                        [11] = 8192,
                    }
                    
                    -- 确保 displayLength 初始化
                    s.displayLength = s.displayLength or #s.body
                    
                    for i = #foundFoodList, 1, -1 do
                        local foodItem = food[foundFoodList[i]]
                        local val = foodItem.value or 1
                        totalVal = totalVal + val
                        
                        -- 1. UI长度：直接增加
                        local growth = foodGrowthMap[val] or 3
                        s.displayLength = s.displayLength + growth
                        
                        -- 2. 物理增长：积分制 (20分 = 1节)
                        -- 使用 growth 作为分数值
                        s.pendingGrowthScore = (s.pendingGrowthScore or 0) + growth
                        
                        -- 循环检查是否可以增加物理长度
                        while true do
                            local currentPhysicalLen = #s.body + (s.growthPending or 0) + addedPhysicalGrowth
                            local cost = 20 -- 默认成本 (长度 < 100)
                            
                            if currentPhysicalLen >= 1000 then
                                cost = 200 -- 后期成本 (长度 >= 1000)
                            elseif currentPhysicalLen >= 100 then
                                cost = 180 -- 中期成本 (长度 100-999)
                            end
                            
                            if s.pendingGrowthScore >= cost then
                                s.pendingGrowthScore = s.pendingGrowthScore - cost
                                addedPhysicalGrowth = addedPhysicalGrowth + 1
                            else
                                break
                            end
                        end
                        
                        table.remove(food, foundFoodList[i])
                    end
                    
                    s.score = s.score + totalVal
                    s.growthPending = (s.growthPending or 0) + addedPhysicalGrowth
                    
                    FoodChangedSignal:Fire(food)
                    LeaderboardChangedSignal:Fire(getLeaderboard())
                    
                    local uid = tostring(playerId)
                    local earned = totalVal * MONEY_PER_FOOD
                    playerMoney[uid] = (playerMoney[uid] or 0) + earned
                    local playerObj = Players:GetPlayerByUserId(tonumber(playerId))
                    if playerObj then
                        MoneyChangedSignal:FireTo(playerObj, playerMoney[uid])
                    end
                    
                    print("[SnakeGameService] 玩家 " .. playerId .. " 吸取 " .. #foundFoodList .. " 个食物 | 价值+" .. totalVal .. " UI长度+" .. (s.displayLength - (#s.body)) .. " 物理长度+" .. addedPhysicalGrowth .. " | 物理总长=" .. (#s.body + (s.growthPending or 0)))
                end
                
                -- 处理生长
                if (s.growthPending or 0) > 0 then
                    s.growthPending = s.growthPending - 1
                    -- 不移除尾部 -> 变长
                else
                    table.remove(s.body)  -- 移除尾部
                end
                
                stateChanged = true
            else
                print("[SnakeGameService] 玩家 " .. playerId .. " 死亡")
                stateChanged = true
            end
        end
    end
    return stateChanged
end

local lastTimeUpdate = 0

local function gameLoop()
    moveSnakes()
    -- 保持食物数量在 300 个 (铺满地图)
    while #food < 300 do
        spawnFood()
    end
    
    -- 更新每日在线时长 (每秒更新一次)
    local now = tick()
    if now - lastTimeUpdate >= 1.0 then
        lastTimeUpdate = now
        for _, player in ipairs(Players:GetPlayers()) do
            local uid = tostring(player.UserId)
            local data = playerDailyGifts[uid]
            if data then
                data.timePlayed = data.timePlayed + 1
                -- 每5秒同步一次给客户端 (或者只在打开UI时同步，这里简单点常驻同步)
                if data.timePlayed % 5 == 0 then
                    GiftUpdateSignal:FireTo(player, data)
                end
            end
        end
    end
end

local function onChangeDirection(player, direction)
    print("[Server] 收到方向: " .. tostring(player.Name) .. " -> " .. tostring(direction) .. " magnitude: " .. tostring(direction.Magnitude))
    local s = snakes[player.UserId]
    if not s then
        print("[Server] 警告：找不到玩家的蛇")
        return
    end
    if not s.alive then
        print("[Server] 蛇已死亡，收到移动请求 -> 自动复活")
        -- 重新创建蛇
        snakes[player.UserId] = createSnake(player)
        s = snakes[player.UserId]
        SnakeSpawnedSignal:Fire(player.UserId, s.body[1], Color3.new(math.random(), math.random(), math.random()))
        
        -- 如果方向有效，立即应用
        if direction.Magnitude > 0.1 then
            s.targetDirection = direction.Unit
            s.isMoving = true
            DirectionChangedSignal:Fire(player.UserId, s.targetDirection, true)
        end
        return
    end
    if direction.Magnitude > 0.1 then
        s.targetDirection = direction.Unit
        s.isMoving = true  -- 有输入时，标记为移动状态
        print("[Server] ✅ 更新蛇的移动状态: direction=" .. tostring(s.targetDirection) .. " isMoving=true")
        DirectionChangedSignal:Fire(player.UserId, s.targetDirection, true)
    else
        s.isMoving = false  -- 无输入时，停止移动
        print("[Server] 停止移动")
        DirectionChangedSignal:Fire(player.UserId, s.targetDirection, false)
    end
end

local function onRequestRespawn(player)
    snakes[player.UserId] = createSnake(player)
    local s = snakes[player.UserId]
    SnakeSpawnedSignal:Fire(player.UserId, s.body[1], Color3.new(math.random(), math.random(), math.random()))
end

function SnakeGameService:KnitInit()
    print("[SnakeGameService] KnitInit 开始")
    
    -- 隐藏/删除默认 Baseplate，防止与自定义地面 Z-fight
    local baseplate = workspace:FindFirstChild("Baseplate")
    if baseplate then
        baseplate:Destroy()
    end
    
    -- 启动游戏循环
    RunService.Heartbeat:Connect(gameLoop)
    print("[SnakeGameService] 游戏循环已启动")
    
    -- 为现有玩家创建蛇并加载数据
    for _, player in ipairs(Players:GetPlayers()) do
        snakes[player.UserId] = createSnake(player)
        local uid = tostring(player.UserId)
        playerMoney[uid] = loadMoney(player.UserId)
        playerDailyGifts[uid] = loadGiftData(player.UserId)
        playerSpins[uid] = loadSpins(player.UserId)
        print("[SnakeGameService] 为玩家 " .. player.Name .. " 创建蛇，钞票=" .. playerMoney[uid])
    end
    
    -- 生成初始食物
    for _ = 1, 300 do spawnFood() end
    print("[SnakeGameService] KnitInit 完成，已生成初始食物")
    
    -- 监听新玩家加入
    Players.PlayerAdded:Connect(function(player)
        snakes[player.UserId] = createSnake(player)
        local s = snakes[player.UserId]
        local uid = tostring(player.UserId)
        
        playerMoney[uid] = loadMoney(player.UserId)
        playerDailyGifts[uid] = loadGiftData(player.UserId)
        playerSpins[uid] = loadSpins(player.UserId)
        
        print("[SnakeGameService] 玩家 " .. player.Name .. " 加入，钞票=" .. playerMoney[uid])
        
        -- 稍等 Knit 信号就绪后发送初始数据
        task.wait(2)
        MoneyChangedSignal:FireTo(player, playerMoney[uid])
        GiftUpdateSignal:FireTo(player, playerDailyGifts[uid])
        SnakeSpawnedSignal:Fire(player.UserId, s.body[1], Color3.new(math.random(), math.random(), math.random()))
    end)
    
    -- 玩家离开时保存数据
    Players.PlayerRemoving:Connect(function(player)
        saveMoney(player.UserId)
        saveGiftData(player.UserId)
        saveSpins(player.UserId)
        
        snakes[player.UserId] = nil
        playerMoney[tostring(player.UserId)] = nil
        playerDailyGifts[tostring(player.UserId)] = nil
        playerSpins[tostring(player.UserId)] = nil
        
        SnakeDiedSignal:Fire(player.UserId, 0, 0) -- 通知客户端清理
        print("[SnakeGameService] 玩家 " .. player.Name .. " 离开，已保存数据")
    end)
    
    -- 服务器关闭时保存所有玩家数据
    game:BindToClose(function()
        for _, player in ipairs(Players:GetPlayers()) do
            saveMoney(player.UserId)
            saveGiftData(player.UserId)
            saveSpins(player.UserId)
        end
    end)
end

-- 实时查询游戏状态（客户端主动拉取）
function SnakeGameService:GetGameState(player)
    local state = getGameState()
    -- 每10次请求打印一次日志，避免刷屏
    if math.random(1, 10) == 1 then
        print("[SnakeGameService] GetGameState 被调用 - 玩家: " .. (player and player.Name or "unknown") .. " 蛇数量: " .. #(state.snakes or {}))
    end
    return state
end

function SnakeGameService:GetPlayerMoney(player)
    return playerMoney[tostring(player.UserId)] or 0
end

function SnakeGameService:ChangeDirection(player, direction)
    onChangeDirection(player, direction)
end

function SnakeGameService:RequestRespawn(player)
    local snakeInstance = snakes[player.UserId]
    if not snakeInstance or not snakeInstance.alive then
        snakes[player.UserId] = createSnake(player)
        print("[Server] 玩家 " .. player.Name .. " 重生")
    end
end

function SnakeGameService:KnitStart()
    print("[SnakeGameService] KnitStart 完成")
end

return SnakeGameService
