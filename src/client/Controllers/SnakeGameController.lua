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

-- 统一 userId key 格式，与服务器保持一致
local function uid(userId) return "u" .. tostring(userId) end

print("[SnakeGameController] 模块加载")

function SnakeGameController:KnitStart()
    print("[SnakeGameController] KnitStart 开始")

    -- 1. 定义本地游戏状态 (Before UI Start)
    local ClientState = {
        score = 2,  -- 初始蛇身长度 = INITIAL_LENGTH
        money = 0,
        leaderboard = {},
        food = {},
        autoMode = false,
        giftData = { timePlayed = 0, claimed = {} }, -- 每日礼物数据
        showGiftPanel = false, -- 是否显示礼物面板
        spins = 0, -- 抽奖次数
        showSpinPanel = false, -- 是否显示抽奖面板
        speedMultiplier = 1, -- 1 或 2，Robux 购买的 2x 速度
        sizeMultiplier = 1,  -- 1 或 2，Robux 购买的 2x 体型
    }
    local lastScore = 0
    local lastUiUpdateAt = 0
    local UI_UPDATE_INTERVAL = 0.25 -- 节流：每秒最多 4 次，避免 Roact 重建导致按钮点不到
    local function safeUiUpdate()
        local now = os.clock()
        if now - lastUiUpdateAt < UI_UPDATE_INTERVAL then
            return
        end
        lastUiUpdateAt = now
        SnakeGameUI.Update(ClientState)
    end

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
            SnakeGame3DView.UpdateSnakeDirection(uid(Players.LocalPlayer.UserId), Vector3.new(0, 0, 0), false)
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
        -- SpinWheelUI.Update(ClientState)
    end

    -- 抽奖相关回调
    SpinWheelUI.Callbacks.onClose = function()
        ClientState.showSpinPanel = false
        -- 【临时禁用】SnakeGameUI.Update(ClientState)
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
                    -- 立即本地标记为已领取，无需等服务器推 GiftUpdate
                    if ClientState.giftData then
                        ClientState.giftData.claimed = ClientState.giftData.claimed or {}
                        ClientState.giftData.claimed[tostring(index)] = true
                    end
                    SnakeGameUI.Update(ClientState)
                else
                    warn("[Gift] 服务器返回领取失败，index=" .. tostring(index))
                end
            else
                warn("[Gift] 远程调用异常: " .. tostring(result))
            end
        end)
    end
    
    -- 死亡面板回调
    local function doRespawn()
        ClientState.isDead = false
        SnakeGameUI.Update(ClientState)
        pcall(function() SnakeGameService:RequestRespawn() end)
    end

    SnakeGameUI.Callbacks.onRespawn = doRespawn
    SnakeGameUI.Callbacks.onRevive  = function()
        -- 把本地记录的 lostSize 传给服务端，作为 playerPendingRevive 的可靠来源
        local size = ClientState.lostSize or 0
        pcall(function() SnakeGameService:RequestPurchaseRevive(size) end)
    end
    SnakeGameUI.Callbacks.onRevenge = function()
        -- 把凶手 uid 传给服务端，购买 Revenge 商品后立即杀死目标
        local targetUid = ClientState.killerUid or ""
        pcall(function() SnakeGameService:RequestPurchaseRevenge(targetUid) end)
    end

    SnakeGameUI.Callbacks.onPurchase2xSpeed = function()
        local svc = SnakeGameService or (Knit and Knit.GetService and Knit.GetService("SnakeGameService"))
        if not svc then
            warn("[SnakeGameController] 2x Speed: 服务未就绪")
            return
        end
        print("[SnakeGameController] 点击 2x Speed，请求购买...")
        pcall(function() svc:RequestPurchase2xSpeed() end)
    end

    SnakeGameUI.Callbacks.onPurchase2xSize = function()
        local svc = SnakeGameService or (Knit and Knit.GetService and Knit.GetService("SnakeGameService"))
        if not svc then
            warn("[SnakeGameController] 2x Size: 服务未就绪")
            return
        end
        print("[SnakeGameController] 点击 2x Size，请求购买...")
        pcall(function() svc:RequestPurchase2xSize() end)
    end

    SnakeGameUI.Callbacks.onPurchaseKillAll = function()
        local svc = SnakeGameService or (Knit and Knit.GetService and Knit.GetService("SnakeGameService"))
        if not svc then
            warn("[SnakeGameController] Kill All: 服务未就绪")
            return
        end
        print("[SnakeGameController] 点击 Kill All，请求购买...")
        pcall(function() svc:RequestPurchaseKillAll() end)
    end

    -- 3. 初始化 UI 和 3D 视图
    SnakeGameUI.Start()
    SnakeGame3DView.Init()
    SnakeGame3DView.SetClientStateRef(ClientState) -- 传递 ClientState 引用用于统一分数显示
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
        SnakeGameService.SnakeSpawned:Connect(function(userId, spawnPos, color, initDisplayLength)
            SnakeGame3DView.SpawnSnake(uid(userId), spawnPos, color, initDisplayLength)
            -- 本地玩家重生（Respawn 或 Revive 购买均触发此分支）→ 关闭死亡面板
            -- 只有 spawnPos 有效（非 nil/空）时才关闭，防止 CharacterAdded 误触发
            if userId == Players.LocalPlayer.UserId and spawnPos then
                ClientState.isDead = false
                SnakeGameUI.Update(ClientState)
            end
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
            local localId = uid(Players.LocalPlayer.UserId)

            -- 1. 更新所有蛇的逻辑长度和物理坐标
            for _, entry in ipairs(leaderboard) do
                local ukey = uid(entry.userId)  -- "u" + 数字 userId，与服务器 snakesData key 一致
                local score = entry.score or 0
                
                -- 获取该蛇的最新服务器坐标数据
                local serverSnake = snakesData and snakesData[ukey]
                local syncData = {
                    score = score,
                    displayLength = serverSnake and serverSnake.displayLength,
                    sizeMultiplier = serverSnake and serverSnake.sizeMultiplier,
                    playerName = serverSnake and serverSnake.playerName,
                }
                if serverSnake then
                    syncData.isMoving = serverSnake.isMoving
                    -- 本地玩家的方向由玩家输入驱动，不能被服务端广播覆盖
                    -- 否则当玩家刚改变方向、服务端还未收到更新时，会触发方向闪现
                    if ukey ~= localId then
                        syncData.dir = serverSnake.direction
                    end
                    if serverSnake.body then
                        syncData.body = serverSnake.body
                    end
                end
                if serverSnake and serverSnake.color then syncData.color = serverSnake.color end

                -- 更新 3D 渲染数据
                SnakeGame3DView.UpdateSnakeData(ukey, syncData)
                
                if ukey == localId then
                    -- 显示 displayLength（蛇身实际长度，初始为 INITIAL_LENGTH=2）而非 food score（从0开始）
                    local displayLen = entry.length or score
                    lastScore = displayLen
                    ClientState.score = displayLen
                end
            end

            -- 死亡面板显示时不刷新 UI，防止打断 Respawn 按钮点击
            if not ClientState.isDead then
                safeUiUpdate()
            end
        end)
    end

    -- 方向同步（其他玩家 + AI）：玩家转向/AI 决策时触发
    if SnakeGameService.DirectionChanged then
        SnakeGameService.DirectionChanged:Connect(function(userId, direction, isMoving, headPos)
            if userId ~= Players.LocalPlayer.UserId then
                local ukey = uid(userId)
                local syncData = { dir = direction, isMoving = isMoving }
                if headPos then
                    syncData.headPos = headPos
                end
                SnakeGame3DView.UpdateSnakeData(ukey, syncData)
            end
        end)
    end

    -- 坐标同步（每 3 帧）：服务端真实头部坐标，直接覆盖，消除预测漂移
    if SnakeGameService.SnakeSync then
        SnakeGameService.SnakeSync:Connect(function(headData)
            SnakeGame3DView.ApplyHeadSync(headData)
        end)
    end

    -- 金币更新（仅本地玩家收到）→ 直接从蛇头位置播放特效
    if SnakeGameService.MoneyChanged then
        SnakeGameService.MoneyChanged:Connect(function(money)
            ClientState.money = money
            if ClientState.isDead then return end
            local headPos = SnakeGame3DView.GetLocalHeadPos and SnakeGame3DView.GetLocalHeadPos()
            if not headPos then return end
            local camera = workspace.CurrentCamera
            local sp, onScr = camera:WorldToViewportPoint(headPos)
            if onScr then
                SnakeGameUI.PlayEatEffect(Vector2.new(sp.X, sp.Y))
            end
        end)
    end
    
    -- 2x 速度购买成功
    if SnakeGameService.SpeedMultiplierChanged then
        SnakeGameService.SpeedMultiplierChanged:Connect(function(mult)
            ClientState.speedMultiplier = mult or 1
            SnakeGame3DView.SetSpeedMultiplier(ClientState.speedMultiplier)
            safeUiUpdate()
        end)
    end

    if SnakeGameService.SizeMultiplierChanged then
        SnakeGameService.SizeMultiplierChanged:Connect(function(mult)
            ClientState.sizeMultiplier = mult or 1
            SnakeGame3DView.SetLocalSizeMultiplier(ClientState.sizeMultiplier)
            safeUiUpdate()
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
            -- SpinWheelUI.Update(ClientState)
            print("[SnakeGameController] 抽奖次数已更新: " .. tostring(ClientState.spins))
        end)
    end
    
    -- Kill All 信号（购买者触发，所有客户端清除被杀死蛇的 3D 尸体）
    if SnakeGameService.KillAll then
        SnakeGameService.KillAll:Connect(function(killedIds)
            if not killedIds then return end
            for _, numId in ipairs(killedIds) do
                SnakeGame3DView.RemoveSnake(uid(numId))
            end
            print("[SnakeGameController] KillAll: 清除", #killedIds, "条蛇")
        end)
    end

    -- 蛇死亡信号（服务器广播给所有客户端：所有人移除该蛇尸体，仅受害者显示 You are dead）
    if SnakeGameService.SnakeDied then
        SnakeGameService.SnakeDied:Connect(function(deathData)
            local victimUserId = deathData.victimUserId
            if not victimUserId then return end
            -- 所有客户端都移除死亡蛇的 3D 尸体，大蛇屏幕上小蛇尸体消失
            SnakeGame3DView.RemoveSnake(uid(victimUserId))
            -- 只有被吃的玩家自己才显示死亡界面，并需要点重生
            if victimUserId == Players.LocalPlayer.UserId then
                ClientState.isDead = true
                ClientState.killedBy = deathData.killedBy or "Unknown"
                ClientState.killerUid = deathData.killerUid or ""
                ClientState.lostSize = deathData.lostSize or 0
                SnakeGameUI.Update(ClientState)
            end
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
            -- 【临时禁用】SnakeGameUI.Update(ClientState)
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
                    local localNumId = Players.LocalPlayer.UserId
                    for _, entry in ipairs(state.leaderboard) do
                        if entry.userId == localNumId then
                            lastScore = entry.score or 0
                            ClientState.score = lastScore
                            break
                        end
                    end
                end

                -- 获取 2x 速度状态（已购买则持久化）
                local ok, mult = pcall(function() return SnakeGameService:GetSpeedMultiplier() end)
                if ok and mult and mult >= 2 then
                    ClientState.speedMultiplier = 2
                    SnakeGame3DView.SetSpeedMultiplier(2)
                end

                -- 获取 2x 体型状态（已购买则持久化）
                local ok2, sm = pcall(function() return SnakeGameService:GetSizeMultiplier() end)
                if ok2 and sm and sm >= 2 then
                    ClientState.sizeMultiplier = 2
                    SnakeGame3DView.SetLocalSizeMultiplier(2)
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
        if ClientState.isDead then return end
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

        local headPos = SnakeGame3DView.GetHeadPosition()
        if dir.Magnitude > 0.01 then
            SnakeGame3DView.UpdateSnakeDirection(uid(Players.LocalPlayer.UserId), dir, true)
            pcall(function() SnakeGameService:ChangeDirection(dir, headPos) end)
        else
            SnakeGame3DView.UpdateSnakeDirection(uid(Players.LocalPlayer.UserId), Vector3.new(0, 0, 0), false)
            pcall(function() SnakeGameService:ChangeDirection(Vector3.new(0, 0, 0), headPos) end)
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

    -- 手机触摸输入
    -- 左半屏：摇杆（控制蛇方向）
    -- 右半屏单指：拖动旋转镜头角度
    -- 右半屏双指：捏合缩放镜头距离
    local joystickTouchId  = nil
    local touchStartPos    = nil

    local cameraTouchId    = nil
    local cameraTouchLastPos = nil
    local cameraTouch2Id   = nil
    local cameraTouch2LastPos = nil
    local pinchStartDist   = nil

    local function screenLeft(pos)
        local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
        return vp and (pos.X < vp.X / 2) or false
    end

    UserInputService.TouchStarted:Connect(function(touchInput, processed)
        if ClientState.isDead then return end
        local isLeft = screenLeft(touchInput.Position)
        if isLeft then
            -- 左侧：摇杆，先到先得
            if joystickTouchId == nil then
                joystickTouchId = touchInput
                touchStartPos = touchInput.Position
            end
        else
            -- 右侧：第一个手指 = 旋转，第二个手指 = 配对捏合
            if cameraTouchId == nil then
                cameraTouchId = touchInput
                cameraTouchLastPos = touchInput.Position
            elseif cameraTouch2Id == nil then
                cameraTouch2Id = touchInput
                cameraTouch2LastPos = touchInput.Position
                -- 记录捏合起始距离
                local d = (cameraTouchLastPos - cameraTouch2LastPos).Magnitude
                pinchStartDist = d
            end
        end
    end)

    UserInputService.TouchMoved:Connect(function(touchInput, processed)
        if ClientState.isDead then return end

        -- 左侧摇杆：控制蛇方向
        if touchInput == joystickTouchId and touchStartPos then
            local delta = touchInput.Position - touchStartPos
            if delta.Magnitude < 10 then return end
            local maxDist = 100
            local normalizedX = math.clamp(delta.X / maxDist, -1, 1)
            local normalizedY = math.clamp(-delta.Y / maxDist, -1, 1)
            if math.sqrt(normalizedX^2 + normalizedY^2) > 0.1 then
                if isAutoMode then
                    isAutoMode = false
                    ClientState.autoMode = false
                    SnakeGameUI.Update(ClientState)
                end
                local cam = Workspace.CurrentCamera
                if cam then
                    local flatForward = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit
                    local flatRight   = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z).Unit
                    local combined = flatForward * normalizedY + flatRight * normalizedX
                    if combined.Magnitude > 0.01 then
                        local dir = combined.Unit
                        SnakeGame3DView.UpdateSnakeDirection(uid(Players.LocalPlayer.UserId), dir, true)
                        local hp = SnakeGame3DView.GetHeadPosition()
                        pcall(function() SnakeGameService:ChangeDirection(dir, hp) end)
                    end
                end
            end
            return
        end

        -- 右侧双指：捏合缩放（先处理，避免同时触发旋转）
        if touchInput == cameraTouch2Id and cameraTouchLastPos then
            cameraTouch2LastPos = touchInput.Position
            local currentDist = (cameraTouchLastPos - cameraTouch2LastPos).Magnitude
            if pinchStartDist and pinchStartDist > 1 then
                SnakeGame3DView.ZoomCameraOffset(currentDist / pinchStartDist)
                pinchStartDist = currentDist
            end
            return
        end

        -- 右侧单指：拖动旋转镜头（无第二手指）
        if touchInput == cameraTouchId and not cameraTouch2Id and cameraTouchLastPos then
            local prev = cameraTouchLastPos
            cameraTouchLastPos = touchInput.Position
            local delta = touchInput.Position - prev
            SnakeGame3DView.RotateCameraOffset(delta.X, delta.Y)
            return
        end

        -- 右侧第一手指在双指模式下移动时，同步更新其位置（用于距离计算）
        if touchInput == cameraTouchId and cameraTouch2Id and cameraTouchLastPos then
            local prevPos = cameraTouchLastPos
            cameraTouchLastPos = touchInput.Position
            if cameraTouch2LastPos then
                local currentDist = (cameraTouchLastPos - cameraTouch2LastPos).Magnitude
                if pinchStartDist and pinchStartDist > 1 then
                    SnakeGame3DView.ZoomCameraOffset(currentDist / pinchStartDist)
                    pinchStartDist = currentDist
                end
            end
        end
    end)

    UserInputService.TouchEnded:Connect(function(touchInput, processed)
        if touchInput == joystickTouchId then
            joystickTouchId = nil
            touchStartPos = nil
            SnakeGame3DView.UpdateSnakeDirection(uid(Players.LocalPlayer.UserId), Vector3.new(0, 0, 0), false)
            local hp = SnakeGame3DView.GetHeadPosition()
            pcall(function() SnakeGameService:ChangeDirection(Vector3.new(0, 0, 0), hp) end)
        elseif touchInput == cameraTouchId then
            cameraTouchId = cameraTouch2Id   -- 第二指升级为第一指
            cameraTouchLastPos = cameraTouch2LastPos
            cameraTouch2Id = nil
            cameraTouch2LastPos = nil
            pinchStartDist = nil
        elseif touchInput == cameraTouch2Id then
            cameraTouch2Id = nil
            cameraTouch2LastPos = nil
            pinchStartDist = nil
        end
    end)

    -- 8a. 礼物计时器（独立 1 秒定时器，不再占用每帧 Heartbeat）
    task.spawn(function()
        while true do
            task.wait(1)
            if ClientState.giftData then
                ClientState.giftData.timePlayed = (ClientState.giftData.timePlayed or 0) + 1
                if ClientState.showGiftPanel then
                    SnakeGameUI.Update(ClientState)
                end
            end
        end
    end)

    -- 8b. 自动寻路 Loop（保留 Heartbeat，但只处理寻路，不再做计时器）
    RunService.Heartbeat:Connect(function(dt)
        -- 自动寻路逻辑
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
            SnakeGame3DView.UpdateSnakeDirection(uid(Players.LocalPlayer.UserId), dir, true)
            pcall(function() SnakeGameService:ChangeDirection(dir, headPos) end)
        end
    end)

    -- 定期上报自身头部坐标，每 10 帧（约 6fps）纠正服务端累积偏差
    local syncPosCounter = 0
    RunService.Heartbeat:Connect(function()
        syncPosCounter = syncPosCounter + 1
        if syncPosCounter < 10 then return end
        syncPosCounter = 0
        local hp = SnakeGame3DView.GetHeadPosition()
        if hp then
            pcall(function() SnakeGameService:SyncPosition(hp) end)
        end
    end)

    print("[SnakeGameController] KnitStart 完成")
end

function SnakeGameController:KnitInit()
    print("[SnakeGameController] KnitInit")
end

return SnakeGameController