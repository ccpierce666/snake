local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = _G.KnitInstance
if not Knit then
    Knit = require(ReplicatedStorage.Common.Knit)
end

print("[Client SnakeGameService] 获取 Knit 实例")

-- 创建本地信号
local FoodChangedSignal = Knit.CreateSignal()
local LeaderboardChangedSignal = Knit.CreateSignal()
local DirectionChangedSignal = Knit.CreateSignal()
local MoneyChangedSignal = Knit.CreateSignal()
local SnakeSpawnedSignal = Knit.CreateSignal()
local SnakeDiedSignal = Knit.CreateSignal()
local GiftUpdateSignal = Knit.CreateSignal()
local SpeedMultiplierChangedSignal = Knit.CreateSignal()
local SizeMultiplierChangedSignal = Knit.CreateSignal()
local KillAllSignal = Knit.CreateSignal()
local SnakeSyncSignal = Knit.CreateSignal()

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
        SpeedMultiplierChanged = SpeedMultiplierChangedSignal,
        SizeMultiplierChanged = SizeMultiplierChangedSignal,
        KillAll = KillAllSignal,
        SnakeSync = SnakeSyncSignal,
    },
}

-- 暴露信号到根，方便Controller调用
SnakeGameService.FoodChanged = FoodChangedSignal
SnakeGameService.LeaderboardChanged = LeaderboardChangedSignal
SnakeGameService.DirectionChanged = DirectionChangedSignal
SnakeGameService.MoneyChanged = MoneyChangedSignal
SnakeGameService.SnakeSpawned = SnakeSpawnedSignal
SnakeGameService.SnakeDied = SnakeDiedSignal
SnakeGameService.GiftUpdate = GiftUpdateSignal
SnakeGameService.SpeedMultiplierChanged = SpeedMultiplierChangedSignal
SnakeGameService.SizeMultiplierChanged = SizeMultiplierChangedSignal
SnakeGameService.KillAll = KillAllSignal
SnakeGameService.SnakeSync = SnakeSyncSignal

-- 声明服务器方法（客户端代理会拦截这些调用）
function SnakeGameService:GetGameState()
    -- 客户端版本只是占位符，实际调用会被 Knit 代理转发到服务器
end

function SnakeGameService:ChangeDirection(direction)
    -- 客户端版本只是占位符，实际调用会被 Knit 代理转发到服务器
end

function SnakeGameService:RequestRespawn()
    -- 客户端版本只是占位符，实际调用会被 Knit 代理转发到服务器
end

function SnakeGameService:RequestRevive(lostSize)
    -- 客户端版本只是占位符，实际调用会被 Knit 代理转发到服务器
end

function SnakeGameService:GetSpeedMultiplier()
end

function SnakeGameService:RequestPurchase2xSpeed()
    -- 客户端版本只是占位符，实际调用会被 Knit 代理转发到服务器
end

function SnakeGameService:GetSizeMultiplier()
end

function SnakeGameService:RequestPurchase2xSize()
    -- 客户端版本只是占位符，实际调用会被 Knit 代理转发到服务器
end

function SnakeGameService:RequestPurchaseKillAll()
    -- 客户端版本只是占位符，实际调用会被 Knit 代理转发到服务器
end

function SnakeGameService:RequestPurchaseRevive(lostSize)
    -- 客户端版本只是占位符，实际调用会被 Knit 代理转发到服务器
end

function SnakeGameService:RequestPurchaseRevenge(killerUid)
    -- 客户端版本只是占位符，实际调用会被 Knit 代理转发到服务器
end

function SnakeGameService:GetGiftData()
end

function SnakeGameService:ClaimGift(index)
end

function SnakeGameService:KnitStart()
    print("[Client SnakeGameService] KnitStart")
end

return SnakeGameService