-- 快速生成Hill模型脚本
-- 在Roblox Studio的Server脚本或Command Bar中运行此代码
-- 将此脚本放在ServerScriptService或任何Server位置

local function generateHillModel()
    print("[HillGenerator] 开始生成Hill模型...")
    
    -- 清理旧的hill模型（如果存在）
    local oldHill = workspace:FindFirstChild("hill")
    if oldHill then
        print("[HillGenerator] 删除旧的Hill模型...")
        oldHill:Destroy()
        task.wait(0.1)
    end
    
    -- 创建新的Hill模型
    local hill = Instance.new("Model")
    hill.Name = "hill"
    hill.Parent = workspace
    
    -- 参数配置
    local HILL_WIDTH = 40
    local HILL_HEIGHT = 25
    local HILL_DEPTH = 40
    
    -- 颜色配置（卡通风格）
    local PRIMARY_COLOR = Color3.fromRGB(120, 200, 100)   -- 亮绿
    local SECONDARY_COLOR = Color3.fromRGB(100, 180, 80)  -- 深绿
    local ACCENT_COLOR = Color3.fromRGB(255, 255, 200)    -- 浅黄（高光）
    
    -- 1. 主体部分 - 球形（模拟圆顶）
    local main = Instance.new("Part")
    main.Name = "MainBody"
    main.Shape = Enum.PartType.Ball
    main.Size = Vector3.new(HILL_WIDTH, HILL_HEIGHT, HILL_DEPTH)
    main.Color = PRIMARY_COLOR
    main.Material = Enum.Material.SmoothPlastic
    main.CanCollide = true
    main.Anchored = true
    main.Parent = hill
    main.Position = Vector3.new(0, HILL_HEIGHT/2, 0)
    
    -- 2. 基础底座 - 立方体
    local base = Instance.new("Part")
    base.Name = "Base"
    base.Shape = Enum.PartType.Block
    base.Size = Vector3.new(HILL_WIDTH + 5, 2, HILL_DEPTH + 5)
    base.Color = SECONDARY_COLOR
    base.Material = Enum.Material.SmoothPlastic
    base.CanCollide = false
    base.Anchored = true
    base.Parent = hill
    base.Position = Vector3.new(0, HILL_HEIGHT/2 - 2, 0)
    
    -- 3. 高光装饰 - 小球体（卡通效果）
    local highlight = Instance.new("Part")
    highlight.Name = "Highlight"
    highlight.Shape = Enum.PartType.Ball
    highlight.Size = Vector3.new(HILL_WIDTH * 0.3, HILL_HEIGHT * 0.25, HILL_DEPTH * 0.3)
    highlight.Color = ACCENT_COLOR
    highlight.Material = Enum.Material.SmoothPlastic
    highlight.Transparency = 0.3
    highlight.CanCollide = false
    highlight.Anchored = true
    highlight.Parent = hill
    highlight.Position = Vector3.new(-HILL_WIDTH/4, HILL_HEIGHT * 0.8, -HILL_DEPTH/4)
    
    -- 4. 详细装饰 - 可选的纹理块
    local decoration1 = Instance.new("Part")
    decoration1.Name = "Decoration1"
    decoration1.Shape = Enum.PartType.Block
    decoration1.Size = Vector3.new(8, 6, 4)
    decoration1.Color = Color3.fromRGB(80, 150, 60)
    decoration1.Material = Enum.Material.SmoothPlastic
    decoration1.CanCollide = false
    decoration1.Anchored = true
    decoration1.Parent = hill
    decoration1.Position = Vector3.new(HILL_WIDTH/3, HILL_HEIGHT/3, -HILL_DEPTH/3)
    
    local decoration2 = Instance.new("Part")
    decoration2.Name = "Decoration2"
    decoration2.Shape = Enum.PartType.Block
    decoration2.Size = Vector3.new(6, 5, 6)
    decoration2.Color = Color3.fromRGB(80, 150, 60)
    decoration2.Material = Enum.Material.SmoothPlastic
    decoration2.CanCollide = false
    decoration2.Anchored = true
    decoration2.Parent = hill
    decoration2.Position = Vector3.new(-HILL_WIDTH/4, HILL_HEIGHT/4, HILL_DEPTH/3)
    
    -- 5. 添加UICorner用于圆角效果（如果是Part）
    if main:IsA("BasePart") then
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = main
    end
    
    -- 6. 设置模型的主要Pivot点
    hill:PivotTo(CFrame.new(0, HILL_HEIGHT/2, 0))
    
    print("[HillGenerator] Hill模型生成成功!")
    print("[HillGenerator] 模型位置: workspace.hill")
    print("[HillGenerator] 模型大小: " .. HILL_WIDTH .. "x" .. HILL_HEIGHT .. "x" .. HILL_DEPTH)
    print("[HillGenerator] 模型颜色: RGB(" .. PRIMARY_COLOR.R*255 .. ", " .. PRIMARY_COLOR.G*255 .. ", " .. PRIMARY_COLOR.B*255 .. ")")
    
    return hill
end

-- 运行生成函数
local hillModel = generateHillModel()

-- 测试输出
local testFind = workspace:FindFirstChild("hill")
if testFind then
    print("[HillGenerator] ✓ 验证成功: 可以找到hill模型")
else
    print("[HillGenerator] ✗ 验证失败: 找不到hill模型")
end
