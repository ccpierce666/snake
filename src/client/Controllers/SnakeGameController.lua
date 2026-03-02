local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Common = ReplicatedStorage:WaitForChild("Common")
local Knit = require(Common.Knit)

local SnakeGameUI = require(script.Parent.Parent.UI.SnakeGameUI)
local SnakeGame3DView = require(script.Parent.Parent.UI.SnakeGame3DView)

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
    }
    local lastScore = 0

    -- 2. 定义自动寻路逻辑 & 回调 (Before UI Start)
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

    -- 3. 初始化 UI 和 3D 视图
    -- 此时 SnakeGameUI.Callbacks.onAutoToggle 已经定义，SnakeGameUI.Start() 渲染的按钮将带有正确的点击事件
    SnakeGameUI.Start()
    SnakeGame3DView.Init()

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

    -- 排行榜更新
    if SnakeGameService.LeaderboardChanged then
        SnakeGameService.LeaderboardChanged:Connect(function(leaderboard)
            ClientState.leaderboard = leaderboard

            -- 检测本地分数变化，驱动蛇的生长
            local localId = tostring(Players.LocalPlayer.UserId)
            for _, entry in ipairs(leaderboard) do
                if tostring(entry.userId) == localId then
                    local newScore = entry.score or 0
                    if newScore > lastScore then
                        local diff = newScore - lastScore
                        SnakeGame3DView.Grow(diff)
                    end
                    lastScore = newScore
                    ClientState.score = newScore
                    break
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

    -- 6. 获取初始状态（带重试）
    task.spawn(function()
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
        -- 如果开启了自动模式，WASD 也会打断自动模式（可选，或者禁止 WASD）
        -- 这里假设 WASD 优先，如果用户操作，可以暂时覆盖或者不处理
        -- 目前逻辑：如果 isAutoMode 为 true，WASD 也会发送方向，但 Heartbeat 可能会覆盖它
        -- 建议：WASD 按下时，自动关闭自动模式
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
            -- 本地立即更新方向（客户端预测）
            SnakeGame3DView.UpdateSnakeDirection(tostring(Players.LocalPlayer.UserId), dir, true)
            -- 发给服务器
            pcall(function() SnakeGameService:ChangeDirection(dir) end)
        else
            -- 无按键按下 → 停止移动
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

    -- 8. 自动寻路 Loop
    RunService.Heartbeat:Connect(function(dt)
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