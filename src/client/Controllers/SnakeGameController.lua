local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Common = ReplicatedStorage:WaitForChild("Common")
local Knit = require(Common.Knit)

local SnakeGameUI = require(script.Parent.Parent.UI.SnakeGameUI)
local SnakeGame3DView = require(script.Parent.Parent.UI.SnakeGame3DView)
local SpinWheelUI = require(script.Parent.Parent.UI.SpinWheelUI)

local SnakeGameController = Knit.CreateController { Name = "SnakeGameController" }

print("[SnakeGameController] 模块加载")

function SnakeGameController:KnitStart()
    print("[SnakeGameController] KnitStart 开始")

    -- 1. 定义本地游戏状态 (Before UI Start)
    local ClientState = {
        score = 0,
        money = 0,
        leaderboard = {},
        food = {},
        autoMode = false,
        giftData = { timePlayed = 0, claimed = {} }, -- 每日礼物数据
        showGiftPanel = false, -- 是否显示礼物面板
        spins = 0, -- 抽奖次数
        showSpinPanel = false, -- 是否显示抽奖面板
    }
    local lastScore = 0

    -- 2. 定义回调逻辑 (Before UI Start)
    local isAutoMode = false
    local autoTimer = 0
    local SnakeGameService -- Will be fetched later

    SnakeGameUI.Callbacks.onAutoToggle = function()
        isAutoMode = not isAutoMode
        ClientState.autoMode = isAutoMode
        SnakeGameUI.Update(ClientState)
        print("[SnakeGameController] 自动模式切换为:", isAutoMode)

        -- 如果关闭自动模式，立即停止移动
        if not isAutoMode then
            SnakeGame3DView.UpdateSnakeDirection(tostring(Players.LocalPlayer.UserId), Vector3.new(0, 0, 0), false)
            if SnakeGameService then
                pcall(function() SnakeGameService:ChangeDirection(Vector3.new(0, 0, 0)) end)
            end
        end
    end

    SnakeGameUI.Callbacks.onToggleGiftPanel = function()
        ClientState.showGiftPanel = not ClientState.showGiftPanel
        SnakeGameUI.Update(ClientState)
    end

    SnakeGameUI.Callbacks.onToggleSpin = function()
        print("[SnakeGameController] 切换抽奖面板，当前状态:", ClientState.showSpinPanel)
        ClientState.showSpinPanel = not ClientState.showSpinPanel
        print("[SnakeGameController] 新状态:", ClientState.showSpinPanel)
        SpinWheelUI.Update(ClientState)
    end

    -- 抽奖相关回调
    SpinWheelUI.Callbacks.onClose = function()
        ClientState.showSpinPanel = false
        SnakeGameUI.Update(ClientState)
    end

    SpinWheelUI.Callbacks.onSpin = function(callback)
        if not SnakeGameService then 
            if callback then callback(false, "Service not ready") end
            return 
        end
        print("[SnakeGameController] 发起抽奖请求")
        task.spawn(function()
            local success, reward = pcall(function()
                return SnakeGameService:Spin()
            end)
            if success and reward then
                print("[Spin] 抽奖成功: " .. tostring(reward.reward))
                if callback then callback(true, reward) end
            else
                warn("[Spin] 抽奖失败: " .. tostring(reward))
                if callback then callback(false, reward) end
            end
        end)
    end

    SnakeGameUI.Callbacks.onClaimGift = function(index)
        print("[SnakeGameController] 点击领取礼物, 索引:", index)
        if not SnakeGameService then 
            warn("[SnakeGameController] SnakeGameService 尚未就绪")
            return 
        end
        
        -- 调用服务器领取
        task.spawn(function()
            print("[SnakeGameController] 发起服务器请求: ClaimGift(" .. tostring(index) .. ")")
            local success, result, msg = pcall(function()
                return SnakeGameService:ClaimGift(index)
            end)
            
            if success then
                if result then
                    print("[Gift] 领取成功: " .. index)
                    -- 等待一下，让服务器发送 GiftUpdate 信号
                    task.wait(0.3)
                    SnakeGameUI.Update(ClientState)
                else
                    warn("[Gift] 服务器返回领取失败: " .. tostring(msg or "原因未知"))
                end
            else
                warn("[Gift] 远程调用异常: " .. tostring(result))
            end
        end)
    end

    -- 3. 初始化 UI 和 3D 视图
    SnakeGameUI.Start()
    SnakeGame3DView.Init()
    -- SpinWheelUI 不需要 Start()，它在 Update() 时动态创建

    -- 4. 获取客户端服务
    SnakeGameService = Knit.GetService("SnakeGameService")
    if not SnakeGameService then
        warn("[SnakeGameController] 无法获取 SnakeGameService！")
        return
    end
    print("[SnakeGameController] 已获取 SnakeGameService")

    -- 5. 连接服务器信号

    -- 蛇生成
    if SnakeGameService.SnakeSpawned then
        SnakeGameService.SnakeSpawned:Connect(function(userId, spawnPos, color)
            print("[SnakeGameController] SnakeSpawned:", userId, spawnPos)
            SnakeGame3DView.SpawnSnake(userId, spawnPos, color)
        end)
    end

    -- 蛇死亡
    if SnakeGameService.SnakeDied then
        SnakeGameService.SnakeDied:Connect(function(userId)
            SnakeGame3DView.RemoveSnake(userId)
        end)
    end

    -- 食物更新
    if SnakeGameService.FoodChanged then
        SnakeGameService.FoodChanged:Connect(function(food)
            ClientState.food = food
            SnakeGame3DView.UpdateFood(food)
        end)
    end

    -- 排行榜更新 (现在也包含全量位置同步)
    if SnakeGameService.LeaderboardChanged then
        SnakeGameService.LeaderboardChanged:Connect(function(leaderboard, snakesData)
            ClientState.leaderboard = leaderboard
            local localId = tostring(Players.LocalPlayer.UserId)

            -- 1. 更新所有蛇的逻辑长度和物理坐标
            for _, entry in ipairs(leaderboard) do
                local uid = tostring(entry.userId)
                local score = entry.score or 0
                
                -- 获取该蛇的最新服务器坐标数据
                local serverSnake = snakesData and snakesData[uid]
                local syncData = { score = score }
                if serverSnake and serverSnake.body then
                    syncData.body = serverSnake.body
                end

                -- 更新 3D 渲染数据
                SnakeGame3DView.UpdateSnakeData(uid, syncData)
                
                if uid == localId then
                    lastScore = score
                    ClientState.score = score
                end
            end

            SnakeGameUI.Update(ClientState)
        end)
    end

    -- 方向同步（其他玩家）
    if SnakeGameService.DirectionChanged then
        SnakeGameService.DirectionChanged:Connect(function(userId, direction, isMoving)
            local localId = Players.LocalPlayer.UserId
            if userId ~= localId then
                SnakeGame3DView.UpdateSnakeDirection(userId, direction, isMoving)
            end
        end)
    end

    -- 金币更新
    if SnakeGameService.MoneyChanged then
        SnakeGameService.MoneyChanged:Connect(function(money)
            ClientState.money = money
            SnakeGameUI.Update(ClientState)
        end)
    end
    
    -- 每日礼物更新
    if SnakeGameService.GiftUpdate then
        SnakeGameService.GiftUpdate:Connect(function(data)
            ClientState.giftData = data
            SnakeGameUI.Update(ClientState)
        end)
    end
    
    -- 抽奖次数更新
    if SnakeGameService.SpinsChanged then
        SnakeGameService.SpinsChanged:Connect(function(spinsLeft)
            ClientState.spins = spinsLeft or 0
            SpinWheelUI.Update(ClientState)
            print("[SnakeGameController] 抽奖次数已更新: " .. tostring(ClientState.spins))
        end)
    end

    -- 6. 获取初始状态（带重试）
    task.spawn(function()
        -- 获取礼物数据
        local successGift, giftData = pcall(function()
            return SnakeGameService:GetGiftData()
        end)
        if successGift and giftData then
            ClientState.giftData = giftData
            SnakeGameUI.Update(ClientState)
        end

        -- 获取抽奖次数将通过 SpinsChanged 信号在线获取，初始为 0
        -- ClientState.spins 初始值已设为 0

        for i = 1, 10 do
            local success, state = pcall(function()
                return SnakeGameService:GetGameState()
            end)

            if success and state and state.snakes then
                print("[SnakeGameController] 获取初始状态成功 (第" .. i .. "次)")

                -- 初始化所有蛇
                for userId, s in pairs(state.snakes) do
                    if s.alive and s.body and #s.body > 0 then
                        SnakeGame3DView.SpawnSnake(userId, s.body[1])
                        SnakeGame3DView.UpdateSnakeDirection(userId, s.targetDirection or Vector3.new(0,0,0), s.isMoving or false)
                    end
                end

                -- 初始化食物
                if state.food then
                    ClientState.food = state.food
                    SnakeGame3DView.UpdateFood(state.food)
                end

                -- 初始化排行榜
                if state.leaderboard then
                    ClientState.leaderboard = state.leaderboard
                    local localId = tostring(Players.LocalPlayer.UserId)
                    for _, entry in ipairs(state.leaderboard) do
                        if tostring(entry.userId) == localId then
                            lastScore = entry.score or 0
                            ClientState.score = lastScore
                            break
                        end
                    end
                end

                SnakeGameUI.Update(ClientState)
                break
            else
                print("[SnakeGameController] 获取初始状态失败 (第" .. i .. "次)，1秒后重试...")
                task.wait(1)
            end
        end
    end)

    -- 7. WASD 输入处理（相对摄像机方向）
    local keysPressed = { W = false, A = false, S = false, D = false }

    local function sendDirection()
        if isAutoMode then
             isAutoMode = false
             ClientState.autoMode = false
             SnakeGameUI.Update(ClientState)
             print("[SnakeGameController] 用户操作，自动模式关闭")
        end

        local fw, rt = 0, 0
        if keysPressed.W then fw = fw + 1 end
        if keysPressed.S then fw = fw - 1 end
        if keysPressed.D then rt = rt + 1 end
        if keysPressed.A then rt = rt - 1 end

        local dir = Vector3.new(0, 0, 0)
        if fw ~= 0 or rt ~= 0 then
            local cam = Workspace.CurrentCamera
            if cam then
                local look = cam.CFrame.LookVector
                local right = cam.CFrame.RightVector
                local flatForward = Vector3.new(look.X, 0, look.Z).Unit
                local flatRight   = Vector3.new(right.X, 0, right.Z).Unit
                local combined = flatForward * fw + flatRight * rt
                if combined.Magnitude > 0.01 then
                    dir = combined.Unit
                end
            else
                dir = Vector3.new(rt, 0, -fw).Unit
            end
        end

        if dir.Magnitude > 0.01 then
            SnakeGame3DView.UpdateSnakeDirection(tostring(Players.LocalPlayer.UserId), dir, true)
            pcall(function() SnakeGameService:ChangeDirection(dir) end)
        else
            SnakeGame3DView.UpdateSnakeDirection(tostring(Players.LocalPlayer.UserId), Vector3.new(0, 0, 0), false)
            pcall(function() SnakeGameService:ChangeDirection(Vector3.new(0, 0, 0)) end)
        end
    end

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.W then keysPressed.W = true; sendDirection()
        elseif input.KeyCode == Enum.KeyCode.A then keysPressed.A = true; sendDirection()
        elseif input.KeyCode == Enum.KeyCode.S then keysPressed.S = true; sendDirection()
        elseif input.KeyCode == Enum.KeyCode.D then keysPressed.D = true; sendDirection()
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.W then keysPressed.W = false; sendDirection()
        elseif input.KeyCode == Enum.KeyCode.A then keysPressed.A = false; sendDirection()
        elseif input.KeyCode == Enum.KeyCode.S then keysPressed.S = false; sendDirection()
        elseif input.KeyCode == Enum.KeyCode.D then keysPressed.D = false; sendDirection()
        end
    end)

    -- 8. 自动寻路 & 计时器 Loop
    local tickTimer = 0
    RunService.Heartbeat:Connect(function(dt)
        -- A. 礼物计时器逻辑 (本地预测增加时间，但不刷新 UI，只在服务器信号时更新)
        if ClientState.giftData then
            tickTimer = tickTimer + dt
            if tickTimer >= 1.0 then
                tickTimer = tickTimer - 1.0
                ClientState.giftData.timePlayed = (ClientState.giftData.timePlayed or 0) + 1
                -- 每秒刷新 UI 以更新倒计时
                SnakeGameUI.Update(ClientState)
            end
        end

        -- B. 自动寻路逻辑
        if not isAutoMode or not ClientState.food or #ClientState.food == 0 then return end

        autoTimer = autoTimer + dt
        if autoTimer < 0.15 then return end
        autoTimer = 0

        local headPos = SnakeGame3DView.GetHeadPosition()
        if not headPos then return end

        local nearest, minDist = nil, math.huge
        for _, f in ipairs(ClientState.food) do
            local pos = f.pos
            if pos then
                local d = (pos - headPos).Magnitude
                if d < minDist then
                    minDist = d
                    nearest = pos
                end
            end
        end

        if nearest then
            local dir = (nearest - headPos).Unit
            SnakeGame3DView.UpdateSnakeDirection(tostring(Players.LocalPlayer.UserId), dir, true)
            pcall(function() SnakeGameService:ChangeDirection(dir) end)
        end
    end)

    print("[SnakeGameController] KnitStart 完成")
end

function SnakeGameController:KnitInit()
    print("[SnakeGameController] KnitInit")
end

return SnakeGameController