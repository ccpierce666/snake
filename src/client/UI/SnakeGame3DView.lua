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
    Color3.fromRGB(255, 50, 50),     -- Bright Red
    Color3.fromRGB(255, 150, 0),     -- Vivid Orange
    Color3.fromRGB(255, 220, 0),     -- Bright Yellow
    Color3.fromRGB(0, 180, 255),     -- Sky Blue
    Color3.fromRGB(160, 50, 255),    -- Vivid Purple
    Color3.fromRGB(255, 80, 200),    -- Hot Pink
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
    if currentLength < 100 then
        -- 0-100: 3x growth (0.6 -> 1.8)
        return 0.6 + (currentLength / 100) * 1.2
    elseif currentLength < 1000 then
        -- 100-1000: 2x growth (1.8 -> 3.6)
        return 1.8 + ((currentLength - 100) / 900) * 1.8
    elseif currentLength < 10000 then
        -- 1000-10000: Slow growth (3.6 -> 6.0)
        return 3.6 + ((currentLength - 1000) / 9000) * 2.4
    else
        -- 10000+: Cap at 8.0
        return math.min(8.0, 6.0 + ((currentLength - 10000) / 90000) * 2.0)
    end
end

local function createEnvironment(parent)
    local HALF = 240 -- Expand to 2x (120 * 2)
    
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
    makePart(Color3.fromRGB(150, 150, 150), Vector3.new(2048, 1, 2048), Vector3.new(0, -4, 0), Enum.Material.Plastic)

    -- 2. 游戏区域地面 (单一大平板 + 网格纹理)
    -- 使用更鲜亮、对比度更高的绿色 (Bright Lime Green)
    local floorColor = Color3.fromRGB(80, 230, 80)
    local floor = makePart(floorColor, Vector3.new(HALF*2, 1, HALF*2), Vector3.new(0, -0.5, 0), Enum.Material.SmoothPlastic)
    
    -- 添加网格纹理 (模拟 Baseplate)
    local texture = Instance.new("Texture")
    texture.Name = "GridTexture"
    texture.Texture = "rbxassetid://6372755229" -- Standard Baseplate Grid
    texture.Face = Enum.NormalId.Top
    texture.StudsPerTileU = 8 -- 格子大小
    texture.StudsPerTileV = 8
    texture.Transparency = 0.7 -- 淡淡的网格
    texture.Color3 = Color3.fromRGB(0, 60, 0) -- 深绿色网格线，增加层次感
    texture.Parent = floor

    -- 3. 围墙 - Low Poly 风格生成
    local function createLowPolyWallSegment(pos, angle, size)
        local segment = Instance.new("Model")
        segment.Name = "WallSegment"
        segment.Parent = parent
        
        -- 随机参数
        local height = 15 + math.random() * 5 -- 高度 15-20
        local width = size * 1.2 -- 宽度稍微重叠
        local depth = 8 + math.random() * 4 -- 厚度
        
        -- 颜色
        local cliffColor = Color3.fromRGB(180, 110, 60) -- Lighter Brown/Earth
        local grassColor = Color3.fromRGB(100, 240, 100) -- Bright Green
        
        -- 主体 (楔形) - 模拟山坡
        local basePart = Instance.new("Part")
        basePart.Name = "Base"
        basePart.Shape = Enum.PartType.Block -- 使用 Block 并旋转来模拟不规则
        basePart.Size = Vector3.new(width, height, depth)
        basePart.Color = cliffColor
        basePart.Material = Enum.Material.Plastic
        basePart.Anchored = true
        basePart.CanCollide = true
        basePart.Parent = segment
        
        -- 旋转和定位
        -- 基础位置向上偏移一半高度
        local cf = CFrame.new(pos) * CFrame.Angles(0, angle, 0) * CFrame.new(0, height/2 - 2, 0)
        
        -- 随机倾斜，制造不规则感
        local tiltX = math.rad(math.random(-5, 5))
        local tiltZ = math.rad(math.random(-5, 5))
        
        basePart.CFrame = cf * CFrame.Angles(tiltX, 0, tiltZ)
        
        -- 顶部草皮 (覆盖在上面)
        local topPart = Instance.new("Part")
        topPart.Name = "GrassTop"
        topPart.Size = Vector3.new(width * 1.1, 2, depth * 1.1)
        topPart.Color = grassColor
        topPart.Material = Enum.Material.SmoothPlastic
        topPart.Anchored = true
        topPart.CanCollide = false
        topPart.Parent = segment
        topPart.CFrame = basePart.CFrame * CFrame.new(0, height/2, 0)
        
        -- 额外的装饰石块 (偶发)
        if math.random() < 0.3 then
            local rock = Instance.new("Part")
            rock.Size = Vector3.new(4, 4, 4)
            rock.Shape = Enum.PartType.Ball
            rock.Color = Color3.fromRGB(100, 100, 100)
            rock.Material = Enum.Material.Slate
            rock.Anchored = true
            rock.CanCollide = false
            rock.Parent = segment
            rock.CFrame = cf * CFrame.new(math.random(-5,5), -height/3, depth/2 + 1)
        end
    end

    local function placeWalls(startPos, endPos)
        local vec = endPos - startPos
        local dist = vec.Magnitude
        local segmentSize = 15 -- 每段长度
        local count = math.ceil(dist / segmentSize)
        local step = vec / count
        
        -- 计算墙壁朝向的角度
        local angle = math.atan2(vec.X, vec.Z) + math.pi/2 
        
        for i = 0, count - 1 do
            local pos = startPos + step * (i + 0.5)
            createLowPolyWallSegment(pos, angle, segmentSize)
        end
    end
    
    -- 边界坐标
    local c1 = Vector3.new(-HALF, 0, -HALF)
    local c2 = Vector3.new(HALF, 0, -HALF)
    local c3 = Vector3.new(HALF, 0, HALF)
    local c4 = Vector3.new(-HALF, 0, HALF)
    
    -- 稍微向外偏移一点，避免遮挡游戏区域边缘
    local offset = 5
    
    placeWalls(c1 + Vector3.new(0,0,-offset), c2 + Vector3.new(0,0,-offset)) -- Top
    placeWalls(c2 + Vector3.new(offset,0,0), c3 + Vector3.new(offset,0,0)) -- Right
    placeWalls(c3 + Vector3.new(0,0,offset), c4 + Vector3.new(0,0,offset)) -- Bottom
    placeWalls(c4 + Vector3.new(-offset,0,0), c1 + Vector3.new(-offset,0,0)) -- Left
    
    print("[SnakeGame3D] Low Poly 围墙生成完成")
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

            -- 客户端强制边界限制 (视觉修正，防止穿墙)
            -- 围墙位置 240, 头部半径 bodySize * 0.75
            local visualRadius = bodySize * 0.75
            local limit = 240 - visualRadius - 0.2 -- 与服务器逻辑对齐 (留 0.2 缓冲)
            body[1] = Vector3.new(math.clamp(body[1].X, -limit, limit), 0, math.clamp(body[1].Z, -limit, limit))

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

        if value == 11 then size = 2.5; color = Color3.fromRGB(255, 0, 255)
        elseif value == 10 then size = 2.4; color = Color3.fromRGB(200, 0, 255)
        elseif value == 9 then size = 2.3; color = Color3.fromRGB(100, 0, 255)
        elseif value == 8 then size = 2.1; color = Color3.fromRGB(0, 100, 255)
        elseif value == 7 then size = 1.9; color = Color3.fromRGB(255, 0, 0) -- Level 7 now Red
        elseif value == 6 then size = 1.7; color = Color3.fromRGB(0, 200, 255) -- Level 6 now Light Blue
        elseif value == 5 then size = 1.5; color = Color3.fromRGB(255, 100, 0)
        elseif value == 4 then size = 1.2; color = Color3.fromRGB(255, 200, 0)
        elseif value == 3 then size = 0.9; color = Color3.fromRGB(255, 255, 0)
        elseif value == 2 then size = 0.7; color = Color3.fromRGB(255, 150, 200) -- Pink
        else size = 0.6; color = Color3.fromRGB(255, 255, 255) -- White
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