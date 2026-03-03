local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Common = ReplicatedStorage:WaitForChild("Common")
local Roact = require(Common:WaitForChild("Roact"))
local Roui = require(Common:WaitForChild("Roui"))

local SpinWheelUI = {}

-- 轮盘配置 (8个扇区，对应 SnakeGameService 的配置)
local WHEEL_REWARDS = {
    { id = 1, text = "+2K",   icon = "🐍", color = Color3.fromRGB(255, 60, 60),   prob = "35%" },  -- Red
    { id = 2, text = "x100",  icon = "🪐", color = Color3.fromRGB(40, 40, 40),    prob = "1%" },   -- Black
    { id = 3, text = "+50K",  icon = "🐍", color = Color3.fromRGB(160, 60, 255),  prob = "5%" },   -- Purple
    { id = 4, text = "+5K",   icon = "🐍", color = Color3.fromRGB(80, 0, 180),    prob = "15%" },  -- Dark Purple
    { id = 5, text = "+25K",  icon = "🐍", color = Color3.fromRGB(60, 100, 255),  prob = "15%" },  -- Blue
    { id = 6, text = "+100K", icon = "🐍", color = Color3.fromRGB(0, 200, 255),   prob = "2%" },   -- Cyan
    { id = 7, text = "+10K",  icon = "🐍", color = Color3.fromRGB(100, 255, 100), prob = "15%" },  -- Green
    { id = 8, text = "+1M",   icon = "🐍", color = Color3.fromRGB(255, 160, 0),   prob = "0.5%" }, -- Orange
}

local function el(className, props, children)
    return Roact.createElement(className, props or {}, children or {})
end

-- 轮盘扇区组件
local function WheelSegment(props)
    local index = props.index
    local data = props.data
    local angle = (index - 1) * 45
    
    -- 使用三角形图片模拟扇区
    -- 假设图片是尖端向下的三角形 (▼)
    -- AnchorPoint (0.5, 1) 对应尖端
    -- Size Y = 0.5 (半径)
    -- Size X calculation: tan(22.5) * 2 * 0.5 = 0.414. Keep it slightly larger for overlap.
    
    return el("ImageLabel", {
        -- 使用一个实心三角形图片资源
        -- rbxassetid://6031243319 是一个倒三角 (Used in previous code as pointer)
        Image = "rbxassetid://6031243319", 
        Size = UDim2.new(0.45, 0, 0.5, 0), -- X轴稍微放大以覆盖缝隙
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 1), -- 尖端作为旋转中心
        BackgroundTransparency = 1,
        ImageColor3 = data.color,
        Rotation = angle,
        ZIndex = 2,
    }, {
        -- 内容容器，位于三角形宽头 (顶部)
        Content = el("Frame", {
            Size = UDim2.new(1, 0, 0.6, 0), -- 占据上半部分
            Position = UDim2.new(0, 0, 0, 0), -- 顶部对齐
            BackgroundTransparency = 1,
            ZIndex = 3,
        }, {
            ValueText = el("TextLabel", {
                Size = UDim2.new(1, 0, 0.5, 0),
                Position = UDim2.new(0, 0, 0.1, 0),
                BackgroundTransparency = 1,
                Text = data.text,
                TextColor3 = Color3.new(1, 1, 1),
                Font = Enum.Font.FredokaOne,
                TextScaled = true,
                TextStrokeTransparency = 0,
                ZIndex = 3,
            }),
            Icon = el("TextLabel", {
                Size = UDim2.new(1, 0, 0.5, 0),
                Position = UDim2.new(0, 0, 0.5, 0),
                BackgroundTransparency = 1,
                Text = data.icon,
                TextColor3 = Color3.new(1, 1, 1),
                TextSize = 24,
                Font = Enum.Font.FredokaOne,
                TextScaled = true,
                ZIndex = 3,
            })
        })
    })
end

-- Stateful Spin Wheel Component
local SpinWheelComponent = Roact.Component:extend("SpinWheelComponent")

function SpinWheelComponent:init()
    self.wheelRef = Roact.createRef()
    self.state = {
        isSpinning = false
    }
    
    self.startSpin = function()
        if self.state.isSpinning then return end
        
        local spinsLeft = self.props.state.spins or 0
        if spinsLeft <= 0 then
            print("No spins left!")
            return
        end

        self:setState({ isSpinning = true })
        
        -- 调用外部提供的 onSpin，传入回调以接收结果
        if self.props.onSpin then
            self.props.onSpin(function(success, rewardData)
                if success and rewardData then
                    self:animateWheel(rewardData)
                else
                    -- 失败重置
                    self:setState({ isSpinning = false })
                    print("Spin failed or no reward data")
                end
            end)
        else
            self:setState({ isSpinning = false })
        end
    end
end

function SpinWheelComponent:animateWheel(rewardData)
    local wheel = self.wheelRef:getValue()
    if not wheel then return end
    
    -- 找到目标索引
    local targetIndex = 1
    if rewardData.id then
        targetIndex = rewardData.id
    else
        -- Fallback by matching amount or text if id missing
        for i, v in ipairs(WHEEL_REWARDS) do
            if v.text == rewardData.reward or v.amount == rewardData.amount then
                targetIndex = i
                break
            end
        end
    end
    
    -- 计算目标角度
    -- 指针在上方 (0度)
    -- 扇区1中心在0度。
    -- 如果我们要指向扇区N (角度 (N-1)*45)，我们需要将轮盘旋转 -((N-1)*45)。
    -- 为了旋转效果，多转几圈 (5圈 = 1800度)
    -- 目标 Rotation = CurrentRotation - (360 * 5 + TargetAngleOffset)
    -- 或者简单的： - (360 * 5 + (targetIndex - 1) * 45)
    
    -- 增加一点随机偏移 (+- 15度) 让它看起来不那么机械? 暂时不用，保持精准。
    
    local segmentAngle = 45
    local targetAngle = (targetIndex - 1) * segmentAngle
    local currentRot = wheel.Rotation
    
    -- 确保总是顺时针旋转 (Rotation 增加)
    -- 目标是到达 -targetAngle (模360)，即 360 - targetAngle
    -- 例如 targetAngle=45 (扇区2)，我们需要转到 -45 (315)。
    -- 0 -> 360 -> ... -> 360*8 + (360-45) = 360*9 - 45
    -- 或者简单点: 360 * 8 - targetAngle.
    
    local endRot = (360 * 8) - targetAngle
    
    -- 如果当前已经有旋转，基于当前旋转继续增加
    -- 我们可以重置为 currentRot % 360，但是这样会跳变。
    -- 最好是 currentRot + (360 * 8) + (target - (currentRot % 360))?
    -- 简单做法：总是从 currentRot 开始加
    
    local currentMod = currentRot % 360
    local targetMod = (360 - targetAngle) % 360
    local diff = targetMod - currentMod
    if diff < 0 then diff = diff + 360 end
    
    endRot = currentRot + (360 * 8) + diff
    
    local tweenInfo = TweenInfo.new(
        4, -- 4秒
        Enum.EasingStyle.Quart,
        Enum.EasingDirection.Out
    )
    
    local tween = TweenService:Create(wheel, tweenInfo, { Rotation = endRot })
    tween:Play()
    
    tween.Completed:Connect(function()
        self:setState({ isSpinning = false })
        print("Spin Complete! Reward:", rewardData.reward)
        -- 这里可以弹出一个 Congratulations 窗口，暂时先打印
    end)
end

function SpinWheelComponent:render()
    local state = self.props.state or {}
    local spinsLeft = state.spins or 0
    local onClose = self.props.onClose
    local isSpinning = self.state.isSpinning
    
    local segments = {}
    for i, reward in ipairs(WHEEL_REWARDS) do
        table.insert(segments, el(WheelSegment, {
            index = i,
            data = reward
        }))
    end
    
    -- 装饰边框
    table.insert(segments, el("UIStroke", {
        Color = Color3.fromRGB(255, 215, 0),
        Thickness = 8,
    }))
    table.insert(segments, el("UICorner", { CornerRadius = UDim.new(1, 0) }))

    -- Hub (中心圆)
    table.insert(segments, el("Frame", {
        Size = UDim2.new(0, 80, 0, 80), -- 稍微加大以遮挡三角形尖端
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 5,
    }, {
        el("UICorner", { CornerRadius = UDim.new(1, 0) }),
        el("UIStroke", { Thickness = 4, Color = Color3.fromRGB(255, 215, 0) }),
        el("TextLabel", {
            Text = "SPIN",
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Font = Enum.Font.FredokaOne,
            TextColor3 = Color3.new(0,0,0),
            TextSize = 18,
            ZIndex = 6,
        })
    }))

    return el("ScreenGui", {
        DisplayOrder = 200,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
    }, {
        Overlay = el("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.5,
            Active = true,
        }, {
            MainPanel = el("Frame", {
                Size = UDim2.new(0, 600, 0, 700),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
            }, {
                Title = el("TextLabel", {
                    Text = "🎡 LUCKY WHEEL",
                    Size = UDim2.new(1, 0, 0, 60),
                    Position = UDim2.new(0, 0, 0, -80),
                    BackgroundTransparency = 1,
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    Font = Enum.Font.FredokaOne,
                    TextSize = 48,
                    TextStrokeTransparency = 0,
                }, {
                    Gradient = el("UIGradient", {
                        Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)),
                            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 0)),
                        }),
                        Rotation = 90,
                    })
                }),

                -- 轮盘容器
                WheelContainer = el("Frame", {
                    [Roact.Ref] = self.wheelRef,
                    Size = UDim2.new(0, 450, 0, 450),
                    Position = UDim2.new(0.5, 0, 0.45, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.fromRGB(30, 30, 30),
                    ClipsDescendants = true,
                    ZIndex = 2,
                }, segments),

                Pointer = el("ImageLabel", {
                    -- Image = "rbxassetid://6031243319", -- 暂时不用图片
                    BackgroundTransparency = 1,
                    Size = UDim2.new(0, 60, 0, 60),
                    Position = UDim2.new(0.5, 0, 0.45, -230),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    ZIndex = 10,
                }, {
                    Arrow = el("Frame", {
                        Size = UDim2.new(0, 40, 0, 40),
                        Position = UDim2.new(0.5, 0, 0.5, 15),
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = Color3.new(1, 1, 1),
                        Rotation = 45,
                        BorderSizePixel = 0,
                    }, {
                        el("UIStroke", { Thickness = 3, Color = Color3.new(0,0,0) })
                    })
                }),

                ButtonsContainer = el("Frame", {
                    Size = UDim2.new(1, 0, 0, 100),
                    Position = UDim2.new(0.5, 0, 1, 0),
                    AnchorPoint = Vector2.new(0.5, 1),
                    BackgroundTransparency = 1,
                }, {
                    UIListLayout = el("UIListLayout", {
                        FillDirection = Enum.FillDirection.Horizontal,
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        VerticalAlignment = Enum.VerticalAlignment.Center,
                        Padding = UDim.new(0, 20),
                    }),

                    AddSpinsBtn = el("TextButton", {
                        Text = "+10 SPINS",
                        Size = UDim2.new(0, 120, 0, 50),
                        BackgroundColor3 = Color3.fromRGB(255, 160, 0),
                        TextColor3 = Color3.new(1, 1, 1),
                        Font = Enum.Font.FredokaOne,
                        TextSize = 20,
                    }, {
                        el("UICorner", { CornerRadius = UDim.new(0, 10) }),
                        el("UIStroke", { Thickness = 3, Color = Color3.new(1,1,1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
                    }),

                    SpinBtn = el("TextButton", {
                        Text = isSpinning and "..." or (spinsLeft > 0 and "SPIN" or "BUY"),
                        Size = UDim2.new(0, 160, 0, 70),
                        BackgroundColor3 = (isSpinning or spinsLeft <= 0) and Color3.fromRGB(150, 150, 150) or Color3.fromRGB(0, 160, 255),
                        TextColor3 = Color3.new(1, 1, 1),
                        Font = Enum.Font.FredokaOne,
                        TextSize = 32,
                        AutoButtonColor = not isSpinning,
                        [Roact.Event.Activated] = self.startSpin
                    }, {
                        el("UICorner", { CornerRadius = UDim.new(0, 15) }),
                        el("UIStroke", { Thickness = 4, Color = Color3.new(1,1,1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
                        CountBadge = el("TextLabel", {
                            Text = "x" .. spinsLeft,
                            Size = UDim2.new(0, 40, 0, 40),
                            Position = UDim2.new(1, -10, 0, -10),
                            AnchorPoint = Vector2.new(0.5, 0.5),
                            BackgroundColor3 = Color3.fromRGB(255, 50, 50),
                            TextColor3 = Color3.new(1, 1, 1),
                            Font = Enum.Font.FredokaOne,
                            TextSize = 18,
                            Visible = (spinsLeft > 0)
                        }, {
                            el("UICorner", { CornerRadius = UDim.new(1, 0) }),
                            el("UIStroke", { Thickness = 2, Color = Color3.new(1,1,1) }),
                        })
                    }),

                    CloseBtn = el("TextButton", {
                        Text = "CLOSE",
                        Size = UDim2.new(0, 100, 0, 50),
                        BackgroundColor3 = Color3.fromRGB(255, 60, 60),
                        TextColor3 = Color3.new(1, 1, 1),
                        Font = Enum.Font.FredokaOne,
                        TextSize = 20,
                        [Roact.Event.Activated] = function()
                            if not isSpinning and onClose then onClose() end
                        end
                    }, {
                        el("UICorner", { CornerRadius = UDim.new(0, 10) }),
                        el("UIStroke", { Thickness = 3, Color = Color3.new(1,1,1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
                    }),
                })
            })
        })
    })
end

-- 模块接口
local activeHandle = nil
local activeScreenGui = nil

function SpinWheelUI.Update(state)
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    
    if state.showSpinPanel then
        local element = Roact.createElement(SpinWheelComponent, {
            state = state,
            onClose = SpinWheelUI.Callbacks.onClose,
            onSpin = SpinWheelUI.Callbacks.onSpin
        })

        if activeHandle and activeScreenGui and activeScreenGui.Parent then
            Roact.update(activeHandle, element)
        else
            if activeHandle then Roact.unmount(activeHandle) end
            if activeScreenGui then activeScreenGui:Destroy() end

            activeHandle = Roact.mount(element, playerGui, "SpinWheelGUI")
            activeScreenGui = playerGui:FindFirstChild("SpinWheelGUI")
        end
    else
        if activeHandle then Roact.unmount(activeHandle) activeHandle = nil end
        if activeScreenGui then activeScreenGui:Destroy() activeScreenGui = nil end
    end
end

SpinWheelUI.Callbacks = {
    onClose = function() end,
    onSpin = function() end
}

return SpinWheelUI