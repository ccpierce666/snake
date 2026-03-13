local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")

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
local speedStore = DataStoreService:GetDataStore("SnakeGameSpeed_v1")
local sizeStore = DataStoreService:GetDataStore("SnakeGameSize_v1")

-- Developer Product: 2x Speed (Robux 购买)
local PRODUCT_ID_2X_SPEED = 3552817506
-- Developer Product: 2x Size (Robux 购买)
local PRODUCT_ID_2X_SIZE = 3552878046
-- Developer Product: Kill All (Robux 购买)
local PRODUCT_ID_KILL_ALL = 3552907357
-- Developer Product: Revive（死亡后恢复长度）
local PRODUCT_ID_REVIVE = 3553463580
-- Developer Product: Revenge（杀死杀了你的人）
local PRODUCT_ID_REVENGE = 3553474649

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
local SpeedMultiplierChangedSignal = Knit.CreateSignal()  -- 2x 速度购买成功
local SizeMultiplierChangedSignal = Knit.CreateSignal()   -- 2x 体型购买成功
local KillAllSignal = Knit.CreateSignal()                 -- Kill All 购买后广播，通知所有客户端清除死亡蛇
local SnakeSyncSignal = Knit.CreateSignal()               -- 每 3 帧广播所有蛇头坐标（轻量，替代预测）

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
        SpeedMultiplierChanged = SpeedMultiplierChangedSignal,
        SizeMultiplierChanged = SizeMultiplierChangedSignal,
        KillAll = KillAllSignal,
        SnakeSync = SnakeSyncSignal,
    },
}

-- 游戏数据
local snakes = {}
local food = {}
local nextFoodId = 1
local syncFrameCounter = 0   -- 每 3 帧广播一次蛇头坐标
local playerMoney = {}
local playerSpins = {}
local playerDailyGifts = {}
local playerFoodCounts = {} -- 用于记录吃食物数量
local playerSkinColors = {} -- [userId] = Color3，玩家专属初始颜色
local playerSpeedMultiplier = {} -- [uid] = 1 或 2，Robux 购买的 2x 速度
local playerSizeMultiplier = {} -- [uid] = 1 或 2，Robux 购买的 2x 体型
local playerPendingRevive = {} -- [uid] = lostSize，死亡时暂存，购买 Revive 后恢复
local playerPendingRevenge = {} -- [uid] = killerUid，死亡时暂存，购买 Revenge 后杀死目标

-- AI 蛇
local AI_TARGET_COUNT = 3
local aiNextId = -1000
local aiKeys = {} -- [key] = true
local aiNamePool = {
    "Alex","Bella","Chris","Daisy","Ethan","Fiona","Gavin","Hazel","Ivy","Jack",
    "Kara","Liam","Mia","Noah","Olivia","Piper","Quinn","Ryan","Sofia","Tyler",
    "Uma","Violet","Wyatt","Xander","Yara","Zoe","Leo","Nina","Owen","Ruby",
    "Sam","Tina","Vince","Will","Yuki","Aiden","Coco","Duke","Elsa","Flynn",
    "Gigi","Hank","Jade","Kiki","Lola","Max","Nova","Rex","Skye","Zane",
}

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
            local numId = uidNum(k)
            local name = s.playerName
            if not name then
                local p = (numId and numId > 0) and Players:GetPlayerByUserId(numId) or nil
                name = (p and p.Name) or "AI"
            end
            table.insert(list, { 
                userId = numId,  -- 客户端需要数字 userId（用于头像加载等；AI 为负数）
                name = name,
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

local function loadSpeedMultiplier(userId)
    local success, saved = pcall(function() return speedStore:GetAsync("speed_" .. tostring(userId)) end)
    if success and saved == 2 then
        return 2
    end
    return 1
end

local function saveSpeedMultiplier(userId)
    local key = uid(userId)
    local m = playerSpeedMultiplier[key]
    if m and m == 2 then
        pcall(function() speedStore:SetAsync("speed_" .. tostring(userId), 2) end)
    end
end

local function loadSizeMultiplier(userId)
    local success, saved = pcall(function() return sizeStore:GetAsync("size_" .. tostring(userId)) end)
    if success and saved == 2 then
        return 2
    end
    return 1
end

local function saveSizeMultiplier(userId)
    local key = uid(userId)
    local m = playerSizeMultiplier[key]
    if m and m == 2 then
        pcall(function() sizeStore:SetAsync("size_" .. tostring(userId), 2) end)
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
    
    local visualSize = calculateVisualBodySize(s.score) * (playerSizeMultiplier[uid(userId)] or 1)
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
        -- 关键：不要把 diff 叠加到 infinity（AI 连续吃会导致尾巴永远不动）
        -- growthPending 表示“还差多少帧长度”，取 max 即可，避免每次吃都无限累积。
        s.growthPending = math.max((s.growthPending or 0), diff)
        -- AI：限制连续生长窗口，避免尾巴长时间停在出生点形成超长直线
        if s.isAI then
            s.growthPending = math.min(s.growthPending, 90)
        end
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

function SnakeGameService:ChangeDirection(player, direction, clientHeadPos)
    local s = snakes[uid(player.UserId)]
    if not s then return end
    -- 死亡时忽略方向输入，不自动复活（玩家需在死亡面板点击 Respawn）
    if not s.alive then return end

    -- 用客户端上报的头部坐标纠正服务端位置（消除网络延迟导致的位置偏差）
    if clientHeadPos and s.body and #s.body > 0 then
        local drift = (clientHeadPos - s.body[1]).Magnitude
        if drift < 10 then   -- 超过 10 studs 视为异常，忽略
            s.body[1] = clientHeadPos
        end
    end

    local head = s.body and s.body[1]
    if direction.Magnitude > 0.1 then
        s.targetDirection = direction.Unit
        s.isMoving = true
        DirectionChangedSignal:Fire(player.UserId, s.targetDirection, true, head)
    else
        s.isMoving = false
        DirectionChangedSignal:Fire(player.UserId, s.targetDirection, false, head)
    end
end

-- 客户端定期上报自身头部位置，纠正服务端累积的位置偏差
function SnakeGameService:SyncPosition(player, clientHeadPos)
    local s = snakes[uid(player.UserId)]
    if not s or not s.alive or not s.body or #s.body == 0 then return end
    if not clientHeadPos then return end
    local drift = (clientHeadPos - s.body[1]).Magnitude
    if drift < 10 then
        s.body[1] = clientHeadPos
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
    SnakeSpawnedSignal:Fire(player.UserId, body, assignSkinColor(player.UserId), INITIAL_LENGTH)
    
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
            body = s.body, direction = s.targetDirection or s.direction, isMoving = s.isMoving,
            score = s.score, alive = s.alive,
            displayLength = s.displayLength or #s.body,
            sizeMultiplier = playerSizeMultiplier[k] or 1,
            playerName = s.playerName,
            isAI = s.isAI or false,
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
function SnakeGameService.Client:ChangeDirection(p, d, headPos) self.Server:ChangeDirection(p, d, headPos) end
function SnakeGameService.Client:SyncPosition(p, headPos) self.Server:SyncPosition(p, headPos) end
function SnakeGameService.Client:RequestRespawn(p) self.Server:RequestRespawn(p) end

function SnakeGameService:RequestRevive(player, lostSize)
    local score = math.max(INITIAL_LENGTH, tonumber(lostSize) or 0)
    local sizeMult = playerSizeMultiplier[uid(player.UserId)] or 1

    -- 按 score 计算目标视觉节数（与 AddSnakeLength 同一套公式）
    local function calcTargetSegments(sc)
        if sc < 300      then return 2 + math.floor(sc / 50)
        elseif sc < 1000 then return 8  + math.floor((sc - 300)  / 100)
        elseif sc < 2000 then return 15 + math.floor((sc - 1000) / 200)
        else                  return 20 + math.floor((sc - 2000) / 300)
        end
    end

    local visualSize    = calculateVisualBodySize(score) * sizeMult
    local spacing       = visualSize * 0.6
    local speedPerFrame = SNAKE_SPEED * GAME_TICK   -- 0.25
    local targetSegs    = calcTargetSegments(score)
    local targetFrames  = math.ceil((targetSegs * spacing) / speedPerFrame)
    targetFrames = math.max(targetFrames, INITIAL_LENGTH)

    -- 直接生成正确长度的 body（蛇尾向 -X 方向排列）
    local pos  = Vector3.new((math.random() * 2 - 1) * 80, 0, (math.random() * 2 - 1) * 80)
    local body = { pos }
    for i = 1, targetFrames - 1 do
        table.insert(body, pos - Vector3.new(speedPerFrame * i, 0, 0))
    end

    snakes[uid(player.UserId)] = {
        body               = body,
        direction          = Vector3.new(1, 0, 0),
        targetDirection    = Vector3.new(0, 0, 0),
        isMoving           = false,
        score              = score,
        alive              = true,
        growthPending      = 0,
        pendingGrowthScore = 0,
        displayLength      = score,
    }

    SnakeSpawnedSignal:Fire(player.UserId, body, assignSkinColor(player.UserId), score)
    local state = self:GetGameState()
    LeaderboardChangedSignal:Fire(state.leaderboard, state.snakes)
    print("[SnakeGameService] Revive: score=" .. score .. " frames=" .. targetFrames)
end
function SnakeGameService.Client:RequestRevive(p, lostSize) self.Server:RequestRevive(p, lostSize) end
function SnakeGameService.Client:GetSpeedMultiplier(p)
    return playerSpeedMultiplier[uid(p.UserId)] or 1
end
function SnakeGameService.Client:RequestPurchase2xSpeed(p) self.Server:RequestPurchase2xSpeed(p) end
function SnakeGameService.Client:GetSizeMultiplier(p)
    return playerSizeMultiplier[uid(p.UserId)] or 1
end
function SnakeGameService.Client:RequestPurchase2xSize(p) self.Server:RequestPurchase2xSize(p) end
function SnakeGameService.Client:RequestPurchaseKillAll(p) self.Server:RequestPurchaseKillAll(p) end

-- 注意：本项目的 Knit 实现会为 Service 上的公开方法创建 RemoteFunction（Call_Service_Method）。
-- 因此需要提供同名的 Service 方法供客户端 InvokeServer 调用。
function SnakeGameService:GetGiftData(player)
    return playerDailyGifts[uid(player.UserId)] or loadGiftData(player.UserId)
end

function SnakeGameService:GetSpins(player)
    return playerSpins[uid(player.UserId)] or 0
end


function SnakeGameService:GetSpeedMultiplier(player)
    return playerSpeedMultiplier[uid(player.UserId)] or 1
end
function SnakeGameService:GetSizeMultiplier(player)
    return playerSizeMultiplier[uid(player.UserId)] or 1
end

function SnakeGameService:RequestPurchase2xSpeed(player)
    local key = uid(player.UserId)
    if (playerSpeedMultiplier[key] or 1) >= 2 then
        return false, "Already purchased"
    end
    print("[SnakeGameService] 弹出 2x Speed 购买窗口, Player=" .. (player and player.Name or "?"))
    MarketplaceService:PromptProductPurchase(player, PRODUCT_ID_2X_SPEED)
    return true
end

function SnakeGameService:RequestPurchase2xSize(player)
    local key = uid(player.UserId)
    if (playerSizeMultiplier[key] or 1) >= 2 then
        return false, "Already purchased"
    end
    print("[SnakeGameService] 弹出 2x Size 购买窗口, Player=" .. (player and player.Name or "?"))
    MarketplaceService:PromptProductPurchase(player, PRODUCT_ID_2X_SIZE)
    return true
end

function SnakeGameService:RequestPurchaseKillAll(player)
    print("[SnakeGameService] 弹出 Kill All 购买窗口, Player=" .. (player and player.Name or "?"))
    MarketplaceService:PromptProductPurchase(player, PRODUCT_ID_KILL_ALL)
    return true
end

function SnakeGameService:RequestPurchaseRevive(player, clientLostSize)
    -- 客户端传来的 lostSize 作为最可靠的来源（来自服务端广播的死亡数据）
    local size = tonumber(clientLostSize) or 0
    local key = uid(player.UserId)
    if size > 0 then
        playerPendingRevive[key] = size
        print("[SnakeGameService] RequestPurchaseRevive: player=" .. player.Name .. " lostSize=" .. size)
    else
        -- 也尝试从已存的 pendingRevive 读取
        size = playerPendingRevive[key] or 0
        print("[SnakeGameService] RequestPurchaseRevive: player=" .. player.Name .. " stored lostSize=" .. size)
    end
    MarketplaceService:PromptProductPurchase(player, PRODUCT_ID_REVIVE)
    return true
end
function SnakeGameService.Client:RequestPurchaseRevive(p, clientLostSize) self.Server:RequestPurchaseRevive(p, clientLostSize) end

function SnakeGameService:RequestPurchaseRevenge(player, clientKillerUid)
    -- 客户端传来的 killerUid 作为最可靠的来源（来自服务端广播的死亡数据）
    local key = uid(player.UserId)
    if clientKillerUid and clientKillerUid ~= "" then
        playerPendingRevenge[key] = tostring(clientKillerUid)
        print("[SnakeGameService] RequestPurchaseRevenge: player=" .. player.Name .. " target=" .. clientKillerUid)
    else
        print("[SnakeGameService] RequestPurchaseRevenge: player=" .. player.Name .. " stored target=" .. tostring(playerPendingRevenge[key]))
    end
    MarketplaceService:PromptProductPurchase(player, PRODUCT_ID_REVENGE)
    return true
end
function SnakeGameService.Client:RequestPurchaseRevenge(p, clientKillerUid) self.Server:RequestPurchaseRevenge(p, clientKillerUid) end

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
            body = s.body, direction = s.targetDirection or s.direction, isMoving = s.isMoving,
            score = s.score, alive = s.alive,
            displayLength = s.displayLength or #s.body,
            sizeMultiplier = playerSizeMultiplier[k] or 1,
            playerName = s.playerName,
            isAI = s.isAI or false,
            color = playerSkinColors[k],
        }
    end
    return state
end

local function killSnake(vKey, vSnake, kKey, kSnake)
    local lostLength = vSnake.displayLength or #vSnake.body
    vSnake.alive = false
    local vPid = uidNum(vKey)
    if vPid and vPid > 0 then
        playerPendingRevive[uid(vPid)] = lostLength
        playerPendingRevenge[uid(vPid)] = kKey
    end
    local killerName = (kSnake and kSnake.playerName) or "Unknown"
    SnakeDiedSignal:Fire({
        victimUserId = uidNum(vKey),
        killedBy = killerName,
        killerUid = kKey,
        lostSize = lostLength,
    })
end

local function moveSnakes()
    -- ══ 阶段1：AI转向 + 计算所有蛇的新头部位置（暂不插入身体） ══
    local nextHeads = {}  -- [k] = Vector3（仅 isMoving = true 的蛇）
    local headRadii = {}  -- [k] = number（所有存活蛇的头球半径，与客户端渲染一致）

    -- 先为所有存活蛇预计算头球半径，确保阶段2不会遇到 nil
    for k, s in pairs(snakes) do
        if s.alive and s.body and #s.body > 0 then
            local vs = calculateVisualBodySize(s.score or 0) * (playerSizeMultiplier[k] or 1)
            headRadii[k] = vs * 0.75
        end
    end

    for k, s in pairs(snakes) do
        if not (s.alive and s.isMoving and s.body and #s.body > 0) then continue end

        -- AI 自动寻路
        if s.isAI then
            local now = os.clock()
            local head = s.body[1]
            if not s.aiNextThinkAt or now >= s.aiNextThinkAt then
                s.aiNextThinkAt = now + 0.15 + math.random() * 0.15
                local best, bestDist = nil, math.huge
                for i = 1, #food do
                    local f = food[i]
                    local d = (f.pos - head).Magnitude
                    if d < bestDist then bestDist = d; best = f end
                end
                local desired
                if best then
                    local jitter = Vector3.new((math.random()-0.5)*18, 0, (math.random()-0.5)*18)
                    local v = best.pos + jitter - head
                    if v.Magnitude > 0.1 then desired = v.Unit end
                end
                if not desired then
                    desired = Vector3.new(math.random()*2-1, 0, math.random()*2-1)
                    if desired.Magnitude > 0.1 then desired = desired.Unit end
                end
                s.aiDesiredDirection = desired
                local bd = desired or s.targetDirection
                if bd and bd.Magnitude > 0.1 then
                    DirectionChangedSignal:Fire(uidNum(k), bd, true, head)
                end
            end
            local desired = s.aiDesiredDirection or s.targetDirection
            local cur = s.targetDirection or Vector3.new(1, 0, 0)
            if desired and desired.Magnitude > 0.1 then
                s.aiWobbleT = (s.aiWobbleT or 0) + 0.12
                local wobble = Vector3.new(math.cos(s.aiWobbleT), 0, math.sin(s.aiWobbleT))
                local nd = desired + wobble * 0.18
                if nd.Magnitude > 0.1 then nd = nd.Unit end
                local newDir = cur:Lerp(nd, 0.14)
                if newDir.Magnitude > 0.1 then s.targetDirection = newDir.Unit end
                s.isMoving = true
            end
        end

        local head = s.body[1]
        local mult = playerSpeedMultiplier[k] or 1
        local nh = head + s.targetDirection * SNAKE_SPEED * GAME_TICK * mult
        local limit = WALL_POSITION - (headRadii[k] or 0.5) - 0.2
        nh = Vector3.new(math.clamp(nh.X, -limit, limit), 0, math.clamp(nh.Z, -limit, limit))
        nextHeads[k] = nh
    end

    -- ══ 阶段2：头对头碰撞检测（用 nextHead 位置，消除顺序依赖） ══
    -- 用两条蛇"本帧将落点"做对比，比 body[1] 早 1 帧检测到，
    -- 避免因服务端同步延迟导致客户端视觉上看到"穿透"
    local killed = {}  -- [k] = true，本帧已判死

    for k, s in pairs(snakes) do
        if not (s.alive and nextHeads[k]) then continue end
        if killed[k] then continue end

        for otherK, otherSnake in pairs(snakes) do
            if otherK == k then continue end
            if not (otherSnake.alive and otherSnake.body and #otherSnake.body > 0) then continue end
            if killed[otherK] then continue end

            -- 双方都有 nextHead 时用双方落点；对方静止则用其当前头部
            local myNext    = nextHeads[k]
            local otherNext = nextHeads[otherK] or otherSnake.body[1]
            local dist = (myNext - otherNext).Magnitude
            local threshold = headRadii[k] + (headRadii[otherK] or 0)
            if dist >= threshold then continue end

            local myScore    = s.score or 0
            local otherScore = otherSnake.score or 0

            if myScore > otherScore then
                killSnake(otherK, otherSnake, k, s)
                SnakeGameService:AddSnakeLength(uidNum(k), otherSnake.displayLength or #otherSnake.body)
                killed[otherK] = true
            elseif otherScore > myScore then
                killSnake(k, s, otherK, otherSnake)
                SnakeGameService:AddSnakeLength(uidNum(otherK), s.displayLength or #s.body)
                killed[k] = true
                break
            else
                -- 同等大小：两条都死，k < otherK 保证只执行一次
                if k < otherK then
                    killSnake(k, s, otherK, otherSnake)
                    killSnake(otherK, otherSnake, k, s)
                    killed[k]      = true
                    killed[otherK] = true
                end
                break
            end
        end
    end

    -- ══ 阶段3：插入新头、食物检测、尾巴移除 ══
    for k, s in pairs(snakes) do
        if not (s.alive and s.isMoving and nextHeads[k]) then continue end

        local nextHead = nextHeads[k]
        table.insert(s.body, 1, nextHead)

        -- 食物检测（拾取范围保持原有逻辑）
        local radius = calculateSnakeRadius(s.score) * (playerSizeMultiplier[k] or 1)
        local pickupRange = 6 + radius
        local foodEaten = false
        for i = #food, 1, -1 do
            local f = food[i]
            if (nextHead - f.pos).Magnitude < pickupRange then
                if s.isAI then
                    local now = os.clock()
                    if (s.aiEatCooldownUntil or 0) > now then continue end
                    s.aiEatCooldownUntil = now + 0.45
                end
                local growth = FOOD_GROWTH_MAP[f.value or 1] or 2
                SnakeGameService:AddSnakeLength(uidNum(k), growth)
                if not s.isAI then
                    playerMoney[k] = (playerMoney[k] or 0) + 1
                    local pid = uidNum(k)
                    local p = (pid and pid > 0) and Players:GetPlayerByUserId(pid) or nil
                    if p then MoneyChangedSignal:FireTo(p, playerMoney[k]) end
                end
                table.remove(food, i)
                foodEaten = true
                if s.isAI then break end
            end
        end
        if foodEaten then
            FoodChangedSignal:Fire(food)
            local state = getGameStatePrivate()
            LeaderboardChangedSignal:Fire(state.leaderboard, state.snakes)
        end

        -- 尾巴逻辑（生长中不移除尾巴）
        if (s.growthPending or 0) > 0 then
            s.growthPending = s.growthPending - 1
        else
            table.remove(s.body)
        end
    end
end

-- 旧单循环占位，已被三阶段逻辑取代，保留此注释便于 diff 追踪
local function moveSnakes_UNUSED()
    for k, s in pairs(snakes) do
        -- k 是 "uXXXXXX" 格式；需要数字 userId 时用 uidNum(k)
        if s.alive and s.isMoving then
            -- AI 自动寻路吃食物（类似 Auto 功能）
            if s.isAI and s.body and #s.body > 0 then
                local now = os.clock()
                local head = s.body[1]

                -- 低频思考：避免每帧锁死直线目标
                if not s.aiNextThinkAt or now >= s.aiNextThinkAt then
                    s.aiNextThinkAt = now + 0.15 + math.random() * 0.15 -- 0.15~0.30s

                    -- 选一个目标食物（优先近的，但加入抖动偏移）
                    local best = nil
                    local bestDist = math.huge
                    for i = 1, #food do
                        local f = food[i]
                        local d = (f.pos - head).Magnitude
                        if d < bestDist then
                            bestDist = d
                            best = f
                        end
                    end

                    local desired = nil
                    if best then
                        -- 给目标点加一点随机偏移，避免完全直线
                        local jitter = Vector3.new((math.random() - 0.5) * 18, 0, (math.random() - 0.5) * 18)
                        local aim = best.pos + jitter
                        local v = (aim - head)
                        if v.Magnitude > 0.1 then
                            desired = v.Unit
                        end
                    end

                    if not desired then
                        -- 没食物/太近：随机游走方向（持续一小段时间）
                        desired = Vector3.new(math.random()*2-1, 0, math.random()*2-1)
                        if desired.Magnitude > 0.1 then desired = desired.Unit end
                    end

                    s.aiDesiredDirection = desired

                    -- 事件驱动：AI 决策方向时广播给所有客户端，用于位置校正
                    -- 触发频率 0.15~0.30s，比每帧广播少 40~80 倍
                    local broadcastDir = desired or s.targetDirection
                    if broadcastDir and broadcastDir.Magnitude > 0.1 then
                        DirectionChangedSignal:Fire(uidNum(k), broadcastDir, true, head)
                    end
                end

                -- 转向速率限制：逐渐转向 desired，形成曲线而不是直线拉扯
                local desired = s.aiDesiredDirection or s.targetDirection
                local cur = s.targetDirection or Vector3.new(1, 0, 0)
                if desired and desired.Magnitude > 0.1 then
                    -- 给 AI 加一点“摆动”，让轨迹更像真人手感，不是完美直线
                    s.aiWobbleT = (s.aiWobbleT or 0) + 0.12
                    local wobble = Vector3.new(math.cos(s.aiWobbleT), 0, math.sin(s.aiWobbleT))
                    local newDesired = (desired + wobble * 0.18)
                    if newDesired.Magnitude > 0.1 then newDesired = newDesired.Unit end

                    local turn = 0.14 -- 稍慢一些，轨迹更弯
                    local newDir = (cur:Lerp(newDesired, turn))
                    if newDir.Magnitude > 0.1 then
                        s.targetDirection = newDir.Unit
                    end
                    s.isMoving = true
                end
            end
            local head = s.body[1]
            local mult = playerSpeedMultiplier[k] or 1
            local nextHead = head + s.targetDirection * SNAKE_SPEED * GAME_TICK * mult
            
            -- 计算视觉大小和半径（2x Size 在原成长基础上再乘以 2）
            local visualSize = calculateVisualBodySize(s.score or 0) * (playerSizeMultiplier[k] or 1)
            local visualRadius = visualSize * 0.75

            local limit = WALL_POSITION - visualRadius - 0.2

            nextHead = Vector3.new(math.clamp(nextHead.X, -limit, limit), 0, math.clamp(nextHead.Z, -limit, limit))
            table.insert(s.body, 1, nextHead)
            
            -- 食物检测
            local radius = calculateSnakeRadius(s.score) * (playerSizeMultiplier[k] or 1)
            local pickupRange = 6 + radius
            
            local foodEaten = false
            for i = #food, 1, -1 do
                local f = food[i]
                local dist = (nextHead - f.pos).Magnitude
                if dist < pickupRange then
                    -- AI：限制吞食频率，避免持续生长导致尾巴“钉在出生点”
                    if s.isAI then
                        local now = os.clock()
                        if (s.aiEatCooldownUntil or 0) > now then
                            -- 跳过本次吞食
                            continue
                        end
                        s.aiEatCooldownUntil = now + 0.45 -- 更像真人：每秒最多 ~2 次吞食
                    end

                    local growth = FOOD_GROWTH_MAP[f.value or 1] or 2
                    SnakeGameService:AddSnakeLength(uidNum(k), growth)
                    
                    -- 每吃 1 个食物获得 1 金钱 (1:1)（AI 不累计金钱）
                    if not s.isAI then
                        playerMoney[k] = (playerMoney[k] or 0) + 1
                        local pid = uidNum(k)
                        local p = (pid and pid > 0) and Players:GetPlayerByUserId(pid) or nil
                        if p then MoneyChangedSignal:FireTo(p, playerMoney[k]) end
                    end
                    
                    table.remove(food, i)
                    foodEaten = true

                    -- AI：每次只吃 1 个，避免瞬间扫一片导致长直线
                    if s.isAI then
                        break
                    end
                end
            end
            
            -- 如果吃了食物，更新排行榜
            if foodEaten then
                FoodChangedSignal:Fire(food)
                local state = getGameStatePrivate()
                LeaderboardChangedSignal:Fire(state.leaderboard, state.snakes)
            end
            
            -- 蛇与蛇碰撞检测：只检测头对头，撞身体直接穿过
            for otherK, otherSnake in pairs(snakes) do
                if otherK ~= k and otherSnake.alive and #otherSnake.body > 0 then
                    local otherScore = otherSnake.score or 0
                    local currentScore = s.score or 0
                    local otherHeadRadius = calculateSnakeRadius(otherScore) * (playerSizeMultiplier[otherK] or 1)
                    local headCollisionDist = radius + otherHeadRadius

                    -- 只检测头对头
                    local otherHead = otherSnake.body[1]
                    local dist = (nextHead - otherHead).Magnitude
                    if dist < headCollisionDist then
                        local killerSnake, victimKey, victimSnake, killerKey

                        if currentScore > otherScore then
                            -- 当前蛇更大：对方死
                            killerKey   = k
                            killerSnake = s
                            victimKey   = otherK
                            victimSnake = otherSnake
                        elseif otherScore > currentScore then
                            -- 对方更大：当前蛇死
                            killerKey   = otherK
                            killerSnake = otherSnake
                            victimKey   = k
                            victimSnake = s
                        else
                            -- 大小相同：两条都死
                            local function killSnake(vKey, vSnake, kKey, kSnake)
                                local lostLength = vSnake.displayLength or #vSnake.body
                                vSnake.alive = false
                                -- 记录死前长度，供 Revive 产品使用
                                local vPid = uidNum(vKey)
                                if vPid and vPid > 0 then
                                    playerPendingRevive[uid(vPid)] = lostLength
                                    -- 记录凶手 uid，供 Revenge 产品使用
                                    playerPendingRevenge[uid(vPid)] = kKey
                                end
                                local killerName = (kSnake and kSnake.playerName) or "Unknown"
                                SnakeDiedSignal:Fire({
                                    victimUserId = uidNum(vKey),
                                    killedBy = killerName,
                                    killerUid = kKey,
                                    lostSize = lostLength,
                                })
                            end
                            -- 避免重复处理（只在当前蛇的 key 更小时执行，防止双向各触发一次）
                            if k < otherK then
                                killSnake(k, s, otherK, otherSnake)
                                killSnake(otherK, otherSnake, k, s)
                                -- 无人获得奖励（同归于尽）
                            end
                            break
                        end

                        if killerKey and victimKey then
                            local lostLength = victimSnake.displayLength or #victimSnake.body
                            victimSnake.alive = false

                            -- 记录死前长度，供 Revive 产品使用；记录凶手，供 Revenge 产品使用
                            local victimPid = uidNum(victimKey)
                            if victimPid and victimPid > 0 then
                                playerPendingRevive[uid(victimPid)] = lostLength
                                playerPendingRevenge[uid(victimPid)] = killerKey
                            end

                            local killerPid = uidNum(killerKey)
                            local killerPlayer = (killerPid and killerPid > 0) and Players:GetPlayerByUserId(killerPid) or nil
                            local killerName = (killerSnake and killerSnake.playerName) or (killerPlayer and killerPlayer.Name) or "Unknown"
                            local victim = (victimPid and victimPid > 0) and Players:GetPlayerByUserId(victimPid) or nil
                            local victimName = (victimSnake and victimSnake.playerName) or (victim and victim.Name) or "Unknown"

                            SnakeDiedSignal:Fire({
                                victimUserId = uidNum(victimKey),
                                killedBy = killerName,
                                killerUid = killerKey,
                                lostSize = lostLength,
                            })
                            print("[SnakeGameService] " .. victimName .. " died to " .. killerName .. " (head-to-head), lost " .. lostLength)

                            SnakeGameService:AddSnakeLength(uidNum(killerKey), lostLength)
                            break
                        end
                    end
                end
            end
            
            -- AI 和真实玩家使用完全相同的尾巴逻辑：
            -- growthPending > 0 时只减计数，不移除尾巴（蛇头插入 = 蛇体延长）
            -- growthPending == 0 时正常移除尾巴（蛇尾跟着往前走）
            if (s.growthPending or 0) > 0 then
                s.growthPending = s.growthPending - 1
            else
                table.remove(s.body)
            end
        end
    end
end

function SnakeGameService:KnitInit()
    -- 禁止 Roblox 自动加载玩家角色（蛇游戏不需要默认角色形象）
    Players.CharacterAutoLoads = false

    -- 核心修复：删除默认 Baseplate 防止闪烁
    local baseplate = workspace:FindFirstChild("Baseplate")
    if baseplate then baseplate:Destroy() end

    local function spawnAiSnake()
        -- pick name (avoid duplicates among alive AI)
        local used = {}
        for k, s in pairs(snakes) do
            if s.alive and s.isAI and s.playerName then
                used[s.playerName] = true
            end
        end
        local name = nil
        for _ = 1, 20 do
            local n = aiNamePool[math.random(1, #aiNamePool)]
            if not used[n] then name = n break end
        end
        name = name or ("AI" .. tostring(math.random(100,999)))

        aiNextId -= 1
        local numId = aiNextId
        local key = uid(numId)
        aiKeys[key] = true

        local pos = Vector3.new((math.random()*2-1)*120, 0, (math.random()*2-1)*120)
        snakes[key] = {
            body = { pos },
            direction = Vector3.new(1, 0, 0),
            targetDirection = Vector3.new(math.random()*2-1, 0, math.random()*2-1).Unit,
            isMoving = true,
            score = 0,
            alive = true,
            growthPending = 0,
            pendingGrowthScore = 0,
            displayLength = INITIAL_LENGTH,
            playerName = name,
            isAI = true,
        }

        playerMoney[key] = nil
        playerFoodCounts[key] = 0
        playerSpeedMultiplier[key] = 1
        playerSizeMultiplier[key] = 1
        assignSkinColor(numId)

        -- 广播生成（客户端用 key 渲染）
        SnakeSpawnedSignal:Fire(numId, snakes[key].body, playerSkinColors[key], INITIAL_LENGTH)
    end

    local function maintainAiSnakes()
        local aliveCount = 0
        for k, s in pairs(snakes) do
            if s.isAI then
                if not s.alive then
                    -- 移除死亡 AI，腾位置
                    snakes[k] = nil
                    aiKeys[k] = nil
                    playerSkinColors[k] = nil
                    playerSpeedMultiplier[k] = nil
                    playerSizeMultiplier[k] = nil
                else
                    aliveCount += 1
                end
            end
        end
        while aliveCount < AI_TARGET_COUNT do
            spawnAiSnake()
            aliveCount += 1
        end
    end

    RunService.Heartbeat:Connect(function()
        maintainAiSnakes()
        moveSnakes()
        -- 提高生成速度：每次检查多次，以便快速达到高上限
        if #food < MAX_FOOD then
            for _ = 1, 5 do
                spawnFood()
                if #food >= MAX_FOOD then break end
            end
        end
        
        -- 每 2 帧广播一次所有蛇头坐标 + 方向（轻量数据，服务端真实值）
        -- 客户端直接用此数据更新坐标，不做预测漂移
        syncFrameCounter = syncFrameCounter + 1
        if syncFrameCounter >= 2 then
            syncFrameCounter = 0
            local headData = {}
            for k, s in pairs(snakes) do
                if s.alive and s.body and #s.body > 0 then
                    headData[k] = { h = s.body[1], d = s.targetDirection or s.direction }
                end
            end
            SnakeSyncSignal:Fire(headData)
        end
    end)
    
    local function grant2xSpeed(player)
        if not player then return end
        local key = uid(player.UserId)
        playerSpeedMultiplier[key] = 2
        saveSpeedMultiplier(player.UserId)
        SpeedMultiplierChangedSignal:FireTo(player, 2)
    end

    local function grant2xSize(player)
        if not player then return end
        local key = uid(player.UserId)
        playerSizeMultiplier[key] = 2
        saveSizeMultiplier(player.UserId)
        SizeMultiplierChangedSignal:FireTo(player, 2)
        -- 立即广播一次，确保所有客户端实时看到体型变大（在原成长基础上再 *2）
        local state = getGameStatePrivate()
        LeaderboardChangedSignal:Fire(state.leaderboard, state.snakes)
    end

    local function grantKillAll(player)
        if not player then return end
        local buyerKey = uid(player.UserId)
        local killedIds = {}
        -- 标记所有非购买者的存活蛇为死亡
        for k, s in pairs(snakes) do
            if k ~= buyerKey and s.alive then
                s.alive = false
                table.insert(killedIds, uidNum(k))  -- 传数字 id
            end
        end
        -- 广播给所有客户端：清除这些蛇的 3D 尸体，并刷新排行榜
        KillAllSignal:Fire(killedIds)
        local state = getGameStatePrivate()
        LeaderboardChangedSignal:Fire(state.leaderboard, state.snakes)
        print("[SnakeGameService] KillAll by", player.Name, "killed", #killedIds, "snakes")
    end

    -- Developer Product 正确回调：ProcessReceipt
    -- 说明：购买成功后必须由服务器返回 PurchaseGranted 才会结算；这里才是权威点。
    local function grantRevenge(player)
        if not player then return end
        local key = uid(player.UserId)
        local targetKey = playerPendingRevenge[key]
        -- 防二次触发
        if not targetKey then
            print("[SnakeGameService] grantRevenge: skip, no pending target for", player.Name)
            -- 目标丢失也要给买家复活，避免面板永远不关
            SnakeGameService:RequestRespawn(player)
            return
        end
        playerPendingRevenge[key] = nil

        local targetSnake = snakes[targetKey]
        local targetPid = uidNum(targetKey)
        local targetName = "Unknown"

        if not targetSnake or not targetSnake.alive then
            print("[SnakeGameService] grantRevenge: target", targetKey, "already dead or gone")
        else
            -- 杀死目标蛇（与头对头碰撞的死亡路径一致）
            local lostLength = targetSnake.displayLength or #targetSnake.body
            targetName = targetSnake.playerName or "Unknown"
            targetSnake.alive = false

            -- 记录目标死前长度（供其购买 Revive）；记录凶手（供其购买 Revenge 反 Revenge）
            if targetPid and targetPid > 0 then
                playerPendingRevive[uid(targetPid)] = lostLength
                playerPendingRevenge[uid(targetPid)] = key
            end

            SnakeDiedSignal:Fire({
                victimUserId = targetPid,
                killedBy = player.Name .. " (Revenge)",
                killerUid = key,
                lostSize = lostLength,
            })

            print("[SnakeGameService] Revenge: " .. player.Name .. " killed " .. targetName)
        end

        -- 复仇者重生（关闭死亡面板）
        SnakeGameService:RequestRespawn(player)
    end

    local function grantRevive(player)
        if not player then return end
        local key = uid(player.UserId)
        local lostSize = playerPendingRevive[key]
        -- 如果没有待恢复数据（已被之前的调用消耗，或从未设置），跳过，防止二次触发（Studio 里 ProcessReceipt 和 PromptProductPurchaseFinished 都会触发）
        if not lostSize or lostSize <= 0 then
            print("[SnakeGameService] grantRevive: skip, no pendingRevive for", player.Name)
            return
        end
        playerPendingRevive[key] = nil  -- 用完即清，防止二次触发
        SnakeGameService:RequestRevive(player, lostSize)
        print("[SnakeGameService] Revive granted to", player.Name, "restoring", lostSize, "size")
    end

    MarketplaceService.ProcessReceipt = function(receiptInfo)
        local pid = receiptInfo.ProductId
        if pid ~= PRODUCT_ID_2X_SPEED and pid ~= PRODUCT_ID_2X_SIZE and pid ~= PRODUCT_ID_KILL_ALL and pid ~= PRODUCT_ID_REVIVE and pid ~= PRODUCT_ID_REVENGE then
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
        if not player then
            return Enum.ProductPurchaseDecision.NotProcessedYet
        end
        if pid == PRODUCT_ID_2X_SPEED then
            grant2xSpeed(player)
        elseif pid == PRODUCT_ID_2X_SIZE then
            grant2xSize(player)
        elseif pid == PRODUCT_ID_KILL_ALL then
            grantKillAll(player)
        elseif pid == PRODUCT_ID_REVIVE then
            grantRevive(player)
        elseif pid == PRODUCT_ID_REVENGE then
            grantRevenge(player)
        end
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    -- 兼容：某些环境里仍会触发 PromptProductPurchaseFinished（参数可能是 Player 或 userId）
    MarketplaceService.PromptProductPurchaseFinished:Connect(function(playerOrUserId, productId, success)
        if (productId ~= PRODUCT_ID_2X_SPEED and productId ~= PRODUCT_ID_2X_SIZE and productId ~= PRODUCT_ID_KILL_ALL and productId ~= PRODUCT_ID_REVIVE and productId ~= PRODUCT_ID_REVENGE) or not success then return end
        local player = nil
        if typeof(playerOrUserId) == "Instance" and playerOrUserId:IsA("Player") then
            player = playerOrUserId
        elseif type(playerOrUserId) == "number" then
            player = Players:GetPlayerByUserId(playerOrUserId)
        end
        if productId == PRODUCT_ID_2X_SPEED then
            grant2xSpeed(player)
        elseif productId == PRODUCT_ID_2X_SIZE then
            grant2xSize(player)
        elseif productId == PRODUCT_ID_KILL_ALL then
            grantKillAll(player)
        elseif productId == PRODUCT_ID_REVIVE then
            grantRevive(player)
        elseif productId == PRODUCT_ID_REVENGE then
            grantRevenge(player)
        end
    end)

    Players.PlayerAdded:Connect(function(p)
        local key = uid(p.UserId)
        playerDailyGifts[key] = loadGiftData(p.UserId)
        playerMoney[key] = loadMoney(p.UserId)
        playerFoodCounts[key] = 0
        playerSpeedMultiplier[key] = loadSpeedMultiplier(p.UserId)
        playerSizeMultiplier[key] = loadSizeMultiplier(p.UserId)
        
        task.delay(1, function()
            MoneyChangedSignal:FireTo(p, playerMoney[key])
        end)
        
        self:RequestRespawn(p)
        
        p.CharacterAdded:Connect(function()
            task.wait(0.5)
            local sn = snakes[uid(p.UserId)]
            -- 只有蛇存活时才通知客户端，避免死亡后角色自动重生把死亡面板关掉
            if sn and sn.alive then
                SnakeSpawnedSignal:Fire(p.UserId, sn.body, assignSkinColor(p.UserId), sn.displayLength or INITIAL_LENGTH)
            end
        end)
    end)
    
    Players.PlayerRemoving:Connect(function(p)
        saveMoney(p.UserId)
        saveSpeedMultiplier(p.UserId)
        saveSizeMultiplier(p.UserId)
        local key = uid(p.UserId)
        playerMoney[key] = nil
        playerFoodCounts[key] = nil
        playerDailyGifts[key] = nil
        playerSpeedMultiplier[key] = nil
        playerSizeMultiplier[key] = nil
        playerSkinColors[key] = nil
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