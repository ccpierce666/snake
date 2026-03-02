local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local SnakeGame3DView = {}

local gameFolder = nil
local snakeParts = {} -- [index] = Part
local activeFoodParts = {} -- [id] = Part
local ringDashes = {} -- 虚线圈的 Parts
local ringAngleOffset = 0

-- Cartoon colors
local SNAKE_BODY_COLOR = Color3.fromRGB(255, 180, 80)     -- Warm Orange
local SNAKE_HEAD_COLOR = SNAKE_BODY_COLOR
local FOOD_COLORS = {
    Color3.fromRGB(255, 220, 80),    -- Bright Yellow
    Color3.fromRGB(255, 150, 100),   -- Orange
    Color3.fromRGB(100, 220, 255),   -- Cyan
    Color3.fromRGB(100, 200, 100),   -- Green
    Color3.fromRGB(255, 100, 200),   -- Pink
    Color3.fromRGB(200, 150, 255),   -- Purple
}

local SNAKE_SPEED = 15
local GAME_TICK = 1/60
local RING_RADIUS = 5.5

local localPlayerSnakeState = nil
local snakePositions = {}

local localPlayerUserId = nil
local otherSnakes = {}

local function createPart(parent, color, size, shape, material)
    shape = shape or Enum.PartType.Ball
    material = material or Enum.Material.SmoothPlastic
    local part = Instance.new("Part")
    part.Shape = shape
    part.Size = Vector3.new(size, size, size)
    part.Color = color
    part.Material = material
    part.Anchored = true
    part.CanCollide = false
    part.CastShadow = false
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

local function hideCharacter(player)
    if player and player.Character then
        for _, part in ipairs(player.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.Transparency = 1
                part.CanCollide = false
            elseif part:IsA("Decal") then
                part.Transparency = 1
            end
        end
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Anchored = true
            hrp.CFrame = CFrame.new(0, 100, 0)
        end
    end
end

local function calculateBodySize(currentLength)
    -- 对应 UPDATE_LOG.md 的四个阶段
    if currentLength < 10000 then
        -- 早期: 0.6 (最小码) -> 1.5 (极慢增长)
        return 0.6 + (currentLength / 10000) * 0.9
    elseif currentLength < 100000 then
        -- 中期: 1.5 -> 3.0 (逐步加速)
        return 1.5 + ((currentLength - 10000) / 90000) * 1.5
    elseif currentLength < 500000 then
        -- 后期: 3.0 -> 8.0 (快速膨胀)
        return 3.0 + ((currentLength - 100000) / 400000) * 5.0
    else
        -- 超期: 8.0 固定 (身体不变大)
        return 8.0
    end
end

local function createEnvironment(parent)
    local HALF = 120
    local floorColor  = Color3.fromRGB(144, 218, 144)
    local wallColor   = Color3.fromRGB(80, 160, 80)

    local function makePart(color, size, pos, material)
        local p = Instance.new("Part")
        p.Anchored    = true
        p.CanCollide  = true
        p.CastShadow  = false
        p.TopSurface  = Enum.SurfaceType.Smooth
        p.BottomSurface = Enum.SurfaceType.Smooth
        p.Color    = color
        p.Material = material or Enum.Material.SmoothPlastic
        p.Size     = size
        p.Position = pos
        p.Parent   = parent
        return p
    end

    -- 1. 灰色大底板 (模拟 Baseplate，完全消除 Z-fight)
    makePart(Color3.fromRGB(150, 150, 150), Vector3.new(2048, 1, 2048), Vector3.new(0, -2, 0), Enum.Material.Plastic)

    -- 2. 绿色游戏区域地面 (抬高，确保覆盖底板)
    makePart(floorColor, Vector3.new(HALF*2, 1, HALF*2), Vector3.new(0, -0.5, 0))

    -- 四面围墙
    local wH, wT = 6, 2
    makePart(wallColor, Vector3.new(HALF*2+wT*2, wH, wT), Vector3.new(0, wH/2, -HALF-wT/2))
    makePart(wallColor, Vector3.new(HALF*2+wT*2, wH, wT), Vector3.new(0, wH/2,  HALF+wT/2))
    makePart(wallColor, Vector3.new(wT, wH, HALF*2),       Vector3.new(-HALF-wT/2, wH/2, 0))
    makePart(wallColor, Vector3.new(wT, wH, HALF*2),       Vector3.new( HALF+wT/2, wH/2, 0))
end

function SnakeGame3DView.Init()
    if gameFolder then return end
    print("[SnakeGame3D] 初始化3D视图")

    gameFolder = Instance.new("Folder")
    gameFolder.Name = "SnakeGame3DAssets"
    gameFolder.Parent = workspace

    -- 客户端创建地面和围墙
    createEnvironment(gameFolder)

    -- 增加：高频率角色隐藏循环，确保彻底不显示默认角色
    task.spawn(function()
        while true do
            task.wait(1.0)
            local char = Players.LocalPlayer.Character
            if char then
                hideCharacter(Players.LocalPlayer)
            end
        end
    end)

    -- 创建虚线圈 (20段)
    for i = 1, 20 do
        local p = createPart(gameFolder, Color3.new(1,1,1), 0.2, Enum.PartType.Block, Enum.Material.Neon)
        p.Size = Vector3.new(0.8, 0.2, 0.4)
        p.Transparency = 0.3
        table.insert(ringDashes, {part=p, angle=(i/20)*math.pi*2})
    end

    -- 渲染循环 (Heartbeat)
    RunService.Heartbeat:Connect(function()
        -- 1. 更新本地预测
        if localPlayerSnakeState and localPlayerSnakeState.isMoving and #localPlayerSnakeState.body > 0 then
            local head = localPlayerSnakeState.body[1]
            local dir = localPlayerSnakeState.targetDirection

            if dir.Magnitude > 0.1 then
                localPlayerSnakeState.direction = dir
                local newHead = head + dir * SNAKE_SPEED * GAME_TICK

                table.insert(localPlayerSnakeState.body, 1, newHead)
                
                -- 完全由服务器驱动生长，本地不再预测
                table.remove(localPlayerSnakeState.body)
            end
        end

        -- 更新其他玩家的蛇位置
        for _, s in pairs(otherSnakes) do
            if s.alive and s.isMoving and s.targetDirection.Magnitude > 0.1 then
                s.direction = s.targetDirection
                local head = s.body[1]
                local newHead = head + s.direction * SNAKE_SPEED * GAME_TICK
                table.insert(s.body, 1, newHead)
                table.remove(s.body)
            end
        end

        -- 更新虚线圈 (顺时针旋转，贴地)
        if localPlayerSnakeState and localPlayerSnakeState.body and #localPlayerSnakeState.body > 0 then
            local head = localPlayerSnakeState.body[1]
            ringAngleOffset = ringAngleOffset - 0.025
            
            -- 动态计算圈的大小 (同步服务器 PICKUP_RADIUS 逻辑)
            local currentScore = localPlayerSnakeState.logicalLength or #localPlayerSnakeState.body
            local bodySize = calculateBodySize(currentScore)
            local currentRingRadius = 5.5 + (bodySize * 0.8) -- 稍微比蛇身大一点

            for _, dash in ipairs(ringDashes) do
                local a = dash.angle + ringAngleOffset
                local x = head.X + math.cos(a) * currentRingRadius
                local z = head.Z + math.sin(a) * currentRingRadius
                dash.part.CFrame = CFrame.new(x, 0.45, z) * CFrame.Angles(0, -(a + math.pi / 2), 0)
                -- 调整虚线的大小
                dash.part.Size = Vector3.new(0.8 + bodySize * 0.1, 0.2, 0.4 + bodySize * 0.05)
            end
        else
            for _, dash in ipairs(ringDashes) do
                dash.part.Position = Vector3.new(0, -50, 0)
            end
        end

        -- 2. 渲染蛇
        snakePositions = {}

        local function addSnakeRenderPoints(body, isLocal, bodySize)
            if not body or #body == 0 then return end

            local spacing = bodySize * 0.6

            table.insert(snakePositions, {
                pos = body[1],
                isHead = true,
                color = isLocal and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(100, 100, 255),
            })

            local accumulatedDist = 0

            for i = 2, #body do
                local p1 = body[i-1]
                local p2 = body[i]
                local vec = p2 - p1
                local segmentDist = vec.Magnitude
                accumulatedDist = accumulatedDist + segmentDist

                while accumulatedDist >= spacing do
                    accumulatedDist = accumulatedDist - spacing
                    local dir = vec.Unit
                    local pos = p2 - dir * accumulatedDist

                    table.insert(snakePositions, {
                        pos = pos,
                        isHead = false,
                        color = isLocal and Color3.fromRGB(100, 220, 100) or Color3.fromRGB(50, 50, 200),
                    })
                end
            end
        end

        local currentLength = localPlayerSnakeState and (localPlayerSnakeState.logicalLength or #localPlayerSnakeState.body) or 0
        local bodySize = calculateBodySize(currentLength)

        if localPlayerSnakeState then
            addSnakeRenderPoints(localPlayerSnakeState.body, true, bodySize)
        end

        for _, s in pairs(otherSnakes) do
            local otherBodySize = calculateBodySize(s.logicalLength or #s.body)
            addSnakeRenderPoints(s.body, false, otherBodySize)
        end

        local needed = #snakePositions

        while #snakeParts < needed do
            local part = createPart(gameFolder, SNAKE_BODY_COLOR, bodySize, Enum.PartType.Ball, Enum.Material.SmoothPlastic)
            table.insert(snakeParts, part)
        end

        for i = 1, #snakeParts do
            if i <= needed and snakePositions[i] then
                local pos = snakePositions[i]
                snakeParts[i].Position = pos.pos + Vector3.new(0, 0.4, 0)
                local isHead = pos.isHead
                snakeParts[i].Color = isHead and SNAKE_HEAD_COLOR or SNAKE_BODY_COLOR
                local sz = isHead and (bodySize * 1.5) or bodySize
                snakeParts[i].Size = Vector3.new(sz, sz, sz)
                snakeParts[i].Transparency = 0
            else
                snakeParts[i].Transparency = 1
                snakeParts[i].Position = Vector3.new(0, -10000, 0)
            end
        end

        -- 3. 相机跟随蛇头 (原版方式)
        if #snakeParts > 0 then
            local headPart = snakeParts[1]
            local cam = Workspace.CurrentCamera
            if cam then
                if cam.CameraSubject ~= headPart then
                    cam.CameraType = Enum.CameraType.Custom
                    cam.CameraSubject = headPart
                end
            end
        end
    end)
end

function SnakeGame3DView.SpawnSnake(userId, body, color)
    userId = tostring(userId)
    local localUserId = tostring(Players.LocalPlayer.UserId)
    
    -- Ensure body is a table
    if typeof(body) == "Vector3" then
        body = {body}
    end

    if userId == localUserId then
        local p = Players:GetPlayerByUserId(tonumber(userId))
        if p then hideCharacter(p) end

        localPlayerSnakeState = {
            body = body,
            direction = Vector3.new(1, 0, 0),
            targetDirection = Vector3.new(0, 0, 0),
            isMoving = false,
            growQueue = 0,
            alive = true
        }
    else
        local p = Players:GetPlayerByUserId(tonumber(userId))
        if p then hideCharacter(p) end

        otherSnakes[userId] = {
            body = body,
            direction = Vector3.new(1, 0, 0),
            targetDirection = Vector3.new(0, 0, 0),
            isMoving = false,
            alive = true
        }
    end
end

-- New function to sync snake data from controller
function SnakeGame3DView.UpdateSnakeData(userId, data)
    userId = tostring(userId)
    local localUserId = tostring(Players.LocalPlayer.UserId)
    
    local snake = (userId == localUserId) and localPlayerSnakeState or otherSnakes[userId]
    
    -- Spawn if not exists
    if not snake then
        local body = {Vector3.new(0,0,0)}
        if data.body then
             body = data.body
        elseif data.pos then
             body = {data.pos}
        end
        SnakeGame3DView.SpawnSnake(userId, body)
        snake = (userId == localUserId) and localPlayerSnakeState or otherSnakes[userId]
    end
    
    -- Update Direction, logical length AND body length
    if snake then
        if data.dir then
            snake.targetDirection = data.dir
            snake.isMoving = data.isMoving
        end
        if data.score then
            snake.logicalLength = data.score
        end
        -- 核心修复：同步服务器的身体节数，确保生长后长度增加
        if data.body then
            if userId ~= localUserId then
                snake.body = data.body
            else
                -- 对于本地蛇，如果服务器更长（说明发生了生长），则采纳服务器的长度
                if #data.body > #snake.body then
                    snake.body = data.body
                end
            end
        end
    end
end

function SnakeGame3DView.RemoveSnake(userId)
    userId = tostring(userId)
    if userId == tostring(Players.LocalPlayer.UserId) then
        localPlayerSnakeState = nil
    else
        otherSnakes[userId] = nil
    end
end

function SnakeGame3DView.UpdateFood(foodList)
    if not gameFolder then SnakeGame3DView.Init() end

    local newActiveParts = {}

    for _, data in ipairs(foodList) do
        local id = data.id
        local part = activeFoodParts[id]

        local value = data.value
        local size = 1.0
        local color = FOOD_COLORS[1]

        if value == 11 then size = 4.2; color = Color3.fromRGB(255, 0, 255)
        elseif value == 10 then size = 4.0; color = Color3.fromRGB(200, 0, 255)
        elseif value == 9 then size = 3.8; color = Color3.fromRGB(100, 0, 255)
        elseif value == 8 then size = 3.5; color = Color3.fromRGB(0, 100, 255)
        elseif value == 7 then size = 3.2; color = Color3.fromRGB(0, 200, 255)
        elseif value == 6 then size = 2.8; color = Color3.fromRGB(255, 0, 0)
        elseif value == 5 then size = 2.4; color = Color3.fromRGB(255, 100, 0)
        elseif value == 4 then size = 2.0; color = Color3.fromRGB(255, 200, 0)
        elseif value == 3 then size = 1.5; color = Color3.fromRGB(255, 255, 0)
        elseif value == 2 then size = 1.2; color = Color3.fromRGB(150, 255, 100)
        else size = 1.0; color = Color3.fromRGB(100, 255, 100)
        end

        if not part then
            part = createPart(gameFolder, color, size, Enum.PartType.Ball, Enum.Material.Neon)
            activeFoodParts[id] = part
        end

        part.Position = data.pos
        part.Color = color
        part.Size = Vector3.new(size, size, size)
        newActiveParts[id] = part
    end

    for id, part in pairs(activeFoodParts) do
        if not newActiveParts[id] then
            part:Destroy()
        end
    end
    activeFoodParts = newActiveParts
end

function SnakeGame3DView.Grow(amount)
    if localPlayerSnakeState then
        localPlayerSnakeState.growQueue = (localPlayerSnakeState.growQueue or 0) + amount
    end
end

function SnakeGame3DView.GetHeadPosition()
    if localPlayerSnakeState and localPlayerSnakeState.body and #localPlayerSnakeState.body > 0 then
        return localPlayerSnakeState.body[1]
    end
    return nil
end

function SnakeGame3DView.UpdateSnakeDirection(userId, direction, isMoving)
   -- Legacy wrapper, prefer UpdateSnakeData
   SnakeGame3DView.UpdateSnakeData(userId, {dir=direction, isMoving=isMoving})
end

function SnakeGame3DView.Cleanup()
    pcall(function() RunService:UnbindFromRenderStep("SnakeGameRender") end)

    if gameFolder then
        gameFolder:Destroy()
        gameFolder = nil
    end
    snakeParts = {}
    activeFoodParts = {}
    ringDashes = {}

    if Workspace.CurrentCamera then
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    end
end

return SnakeGame3DView