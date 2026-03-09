-- SnakeGameUI - Roui + Roact implementation
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Common = ReplicatedStorage:WaitForChild("Common")
local Roact = require(Common:WaitForChild("Roact"))
local Roui = require(Common:WaitForChild("Roui"))

local SnakeGameUI = {}
SnakeGameUI.Callbacks = {}   -- 控制器在 KnitStart 里注册回调

local gui = nil
local contentHandle = nil

-- 奖励配置表 (与服务器保持一致)
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

local function el(className, props, children)
    return Roact.createElement(className, props or {}, children or {})
end

local function formatNumber(n)
    n = tonumber(n) or 0
    if n >= 1000000000000 then
        return string.format("%.3fT", n / 1000000000000)
    elseif n >= 1000000000 then
        return string.format("%.3fB", n / 1000000000)
    elseif n >= 1000000 then
        return string.format("%.3fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.3fK", n / 1000)
    else
        return tostring(math.floor(n))
    end
end

local function formatTime(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%02d:%02d", m, s)
end

-- 创建纯文字方形按钮
local function actionBtn(label, bgColor, props)
    props = props or {}
    local children = {
        UICorner = el("UICorner", { CornerRadius = UDim.new(0.3, 0) }),
        UIStroke = el("UIStroke", {
            Color = Color3.fromRGB(0, 0, 50),
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }),
    }
    
    if props.Children then
        for k, v in pairs(props.Children) do children[k] = v end
    end

    local buttonProps = {
        Size = props.Size or UDim2.new(0, 65, 0, 38),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        LayoutOrder = props.LayoutOrder,
        BackgroundColor3 = bgColor or Color3.fromRGB(255, 180, 50),
        BorderSizePixel = 0,
        Text = label,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.FredokaOne,
        TextSize = props.TextSize or 12,
        TextStrokeTransparency = 0,
        TextStrokeColor3 = Color3.new(0,0,0),
        Name = props.Name or label,
        AutoButtonColor = true,
    }
    
    if props.onActivated then
        buttonProps[Roact.Event.Activated] = props.onActivated
    end
    
    return el("TextButton", buttonProps, children)
end

local function menuBtn(label, bgColor, props)
    props = props or {}
    local children = {
        UICorner = el("UICorner", { CornerRadius = UDim.new(0, 16) }),
        UIStroke = el("UIStroke", {
            Color = Color3.new(0, 0, 0),
            Thickness = 1,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }),
    }

    if props.Icon then
        children.IconImage = el("ImageLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.new(0, 26, 0, 26),
            Image = props.Icon,
            ImageColor3 = Color3.new(1, 1, 1),
        })
    end
    
    if props.Children then
        for k, v in pairs(props.Children) do children[k] = v end
    end

    local btnProps = {
        Size = props.Size or UDim2.new(0, 42, 0, 42),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        LayoutOrder = props.LayoutOrder,
        BackgroundColor3 = bgColor or Color3.fromRGB(255, 180, 50),
        BorderSizePixel = 0,
        Text = label,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.FredokaOne,
        TextSize = props.TextSize or 10,
        TextStrokeTransparency = 0.5,
        Name = props.Name or label,
        TextYAlignment = Enum.TextYAlignment.Bottom,
        TextWrapped = true,
    }
    
    if props.onActivated then
        btnProps[Roact.Event.Activated] = props.onActivated
    end
    
    return el("TextButton", btnProps, children)
end

local function buildLeaderboard(state)
    local children = {}
    children.UIListLayout = el("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 2),
    })

    for i, e in ipairs(state.leaderboard or {}) do
        if i <= 4 then
            local name = "Player"
            for _, p in ipairs(Players:GetPlayers()) do
                if p.UserId == e.userId then name = p.Name break end
            end
            children["Row" .. i] = Roui.LeaderboardRow({
                Rank = i,
                Name = name:sub(1, 10),
                Score = formatNumber(e.score or 0),
                UserId = e.userId,
                Highlight = (e.userId == Players.LocalPlayer.UserId),
                LayoutOrder = i,
            })
        end
    end

    return Roui.Leaderboard({
        Position = UDim2.new(1, -160, 0, -34),
        Size = UDim2.new(0, 152, 0, 100),
    }, children)
end

local function NextGiftWidget(props)
    local giftData = props.giftData or { timePlayed = 0, claimed = {} }
    local timePlayed = tonumber(giftData.timePlayed) or 0
    local claimed = giftData.claimed or {}
    local onActivated = props.onActivated
    
    local nextReward = nil
    local nextIndex = 0
    for i, reward in ipairs(GIFT_REWARDS) do
        if not claimed[tostring(i)] then
            nextReward = reward
            nextIndex = i
            break
        end
    end
    
    if not nextReward then 
        return el("Frame", { Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1 })
    end
    
    local timeLeft = math.max(0, nextReward.time - timePlayed)
    local canClaim = timeLeft <= 0
    
    -- 动态选择颜色：可领取时为绿色，否则为蓝色
    local buttonColor = canClaim and Color3.fromRGB(120, 220, 100) or Color3.fromRGB(60, 150, 255)
    
    return Roui.Button({
        Size = UDim2.new(0, 145, 0, 36),
        Color = buttonColor,
        Text = "",
        [Roact.Event.Activated] = onActivated,
    }, {
        -- 礼包图标
        GiftIcon = el("TextLabel", {
            Size = UDim2.new(0, 26, 0, 26),
            Position = UDim2.new(0, 5, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 1,
            Text = "🎁",
            TextSize = 22,
            Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            ZIndex = 2,
        }),
        
        -- 文字标签
        Label = Roui.Text({
            Text = canClaim and "GIFT!" or formatTime(timeLeft),
            Size = UDim2.new(1, -38, 1, 0),
            Position = UDim2.new(0, 34, 0, 0),
            TextSize = 11,
            Font = Enum.Font.FredokaOne,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 2,
        })
    })
end

local function DeathPanel(props)
    local killedBy = props.killedBy or "Unknown"
    local lostSize = props.lostSize or 0
    local onRespawn = props.onRespawn
    local onRevive = props.onRevive
    local onRevenge = props.onRevenge

    -- 无遮罩层，直接居中显示面板
    return el("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 100,
    }, {
        Panel = el("Frame", {
            Size = UDim2.new(0, 400, 0, 300),
            Position = UDim2.new(0.5, 0, 0.35, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(40, 40, 50),
            ZIndex = 101,
        }, {
            UICorner = el("UICorner", { CornerRadius = UDim.new(0, 16) }),
            UIStroke = el("UIStroke", { Thickness = 3, Color = Color3.new(0,0,0) }),
            
            -- Title
            Title = Roui.Text({
                Text = "You are DEAD",
                Size = UDim2.new(1, 0, 0, 60),
                Position = UDim2.new(0, 0, 0, 15),
                TextSize = 36,
                Font = Enum.Font.FredokaOne,
                TextColor3 = Color3.fromRGB(255, 60, 60),
                ZIndex = 2,
            }),
            
            -- Death Info
            DeathInfo = Roui.Text({
                Text = "You died to " .. killedBy .. " and lost " .. lostSize .. " Size!",
                Size = UDim2.new(0.9, 0, 0, 50),
                Position = UDim2.new(0.5, 0, 0, 75),
                AnchorPoint = Vector2.new(0.5, 0),
                TextSize = 18,
                Font = Enum.Font.FredokaOne,
                TextColor3 = Color3.new(1, 1, 1),
                TextWrapped = true,
                ZIndex = 2,
            }),
            
            -- Buttons Container
            ButtonContainer = el("Frame", {
                Size = UDim2.new(1, 0, 0, 120),
                Position = UDim2.new(0, 0, 1, -120),
                BackgroundTransparency = 1,
                ZIndex = 2,
            }, {
                UIListLayout = el("UIListLayout", {
                    FillDirection = Enum.FillDirection.Vertical,
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding = UDim.new(0, 10),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }),
                
                -- RESPAWN Button (Large, Blue)
                RespawnBtn = el("TextButton", {
                    Size = UDim2.new(0, 300, 0, 45),
                    BackgroundColor3 = Color3.fromRGB(60, 160, 255),
                    Text = "RESPAWN",
                    Font = Enum.Font.FredokaOne,
                    TextSize = 20,
                    TextColor3 = Color3.new(1, 1, 1),
                    BorderSizePixel = 0,
                    LayoutOrder = 1,
                    [Roact.Event.Activated] = onRespawn,
                }, {
                    UICorner = el("UICorner", { CornerRadius = UDim.new(0, 12) }),
                    UIStroke = el("UIStroke", { Thickness = 2, Color = Color3.new(0,0,0) }),
                }),
                
                -- REVIVE and REVENGE Row
                BottomRow = el("Frame", {
                    Size = UDim2.new(0, 300, 0, 40),
                    BackgroundTransparency = 1,
                    LayoutOrder = 2,
                }, {
                    UIListLayout = el("UIListLayout", {
                        FillDirection = Enum.FillDirection.Horizontal,
                        HorizontalAlignment = Enum.HorizontalAlignment.Center,
                        VerticalAlignment = Enum.VerticalAlignment.Center,
                        Padding = UDim.new(0, 10),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    }),
                    
                    -- REVIVE Button (Pink, with heart)
                    ReviveBtn = el("TextButton", {
                        Size = UDim2.new(0, 140, 0, 40),
                        BackgroundColor3 = Color3.fromRGB(255, 100, 180),
                        Text = "❤ REVIVE",
                        Font = Enum.Font.FredokaOne,
                        TextSize = 16,
                        TextColor3 = Color3.new(1, 1, 1),
                        BorderSizePixel = 0,
                        LayoutOrder = 1,
                        [Roact.Event.Activated] = onRevive,
                    }, {
                        UICorner = el("UICorner", { CornerRadius = UDim.new(0, 10) }),
                        UIStroke = el("UIStroke", { Thickness = 2, Color = Color3.new(0,0,0) }),
                    }),
                    
                    -- REVENGE Button (Red, with sword)
                    RevengeBtn = el("TextButton", {
                        Size = UDim2.new(0, 140, 0, 40),
                        BackgroundColor3 = Color3.fromRGB(255, 40, 40),
                        Text = "⚔ REVENGE",
                        Font = Enum.Font.FredokaOne,
                        TextSize = 16,
                        TextColor3 = Color3.new(1, 1, 1),
                        BorderSizePixel = 0,
                        LayoutOrder = 2,
                        [Roact.Event.Activated] = onRevenge,
                    }, {
                        UICorner = el("UICorner", { CornerRadius = UDim.new(0, 10) }),
                        UIStroke = el("UIStroke", { Thickness = 2, Color = Color3.new(0,0,0) }),
                    }),
                }),
            }),
        }),
    })
end

local function GiftPanel(props)
    local giftData = props.giftData or { timePlayed = 0, claimed = {} }
    local timePlayed = tonumber(giftData.timePlayed) or 0
    local claimed = giftData.claimed or {}
    local onClose = props.onClose
    local onClaim = props.onClaim
    
    local listItems = {}
    for i, reward in ipairs(GIFT_REWARDS) do
        local isClaimed = claimed[tostring(i)]
        local isUnlocked = timePlayed >= reward.time
        local canClaim = isUnlocked and not isClaimed
        
        local itemBgColor = Color3.fromRGB(80, 160, 240)
        local statusColor = Color3.fromRGB(220, 60, 60)
        local statusText = formatTime(math.max(0, reward.time - timePlayed))
        
        if isClaimed then
            statusText = "Claimed"
            statusColor = Color3.fromRGB(60, 60, 60)
        elseif canClaim then
            statusText = "Claim"
            statusColor = Color3.fromRGB(60, 220, 60)
        end
        
        local iconId = (reward.type == "Length") and "rbxassetid://89074978607958" or "rbxassetid://6034706260"
        
        listItems["Item"..i] = el("Frame", {
            BackgroundColor3 = itemBgColor,
            LayoutOrder = i,
        }, {
            UICorner = el("UICorner", { CornerRadius = UDim.new(0, 7) }),
            UIStroke = el("UIStroke", { Thickness = 1, Color = Color3.new(0,0,0) }),
            Icon = el("ImageLabel", {
                Size = UDim2.new(0, 24, 0, 24),
                Position = UDim2.new(0.5, 0, 0.03, 0),
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundTransparency = 1,
                Image = iconId,
                ZIndex = 2,
            }),
            Amount = Roui.Text({
                Text = "+" .. formatNumber(reward.amount),
                Size = UDim2.new(1, 0, 0, 12),
                Position = UDim2.new(0, 0, 0.48, 1),
                TextSize = 7,
                Font = Enum.Font.FredokaOne,
                ZIndex = 2,
            }),
            StatusBar = el("TextButton", {
                Size = UDim2.new(0.7, 0, 0.22, 0),
                Position = UDim2.new(0.5, 0, 0.92, 0),
                AnchorPoint = Vector2.new(0.5, 1),
                BackgroundColor3 = statusColor,
                BorderSizePixel = 0,
                Text = statusText,
                Font = Enum.Font.FredokaOne,
                TextSize = 5,
                TextColor3 = Color3.new(1,1,1),
                AutoButtonColor = canClaim,
                Active = true,
                ZIndex = 110, -- 顶层按钮
                [Roact.Event.Activated] = canClaim and (function()
                    print("[UI] Gift Claim Button Activated, index:", i)
                    if onClaim then onClaim(i) end
                end) or nil
            }, {
                UICorner = el("UICorner", { CornerRadius = UDim.new(0, 2) }),
                UIStroke = el("UIStroke", { Thickness = 1, Color = Color3.new(0,0,0) }),
            })
        })
    end
    
    local gridChildren = listItems
    gridChildren.Layout = el("UIGridLayout", {
        CellSize = UDim2.new(0, 54, 0, 56),
        CellPadding = UDim2.new(0, 3, 0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
    })
    gridChildren.UICorner = el("UICorner", { CornerRadius = UDim.new(0, 12) })
    gridChildren.UIStroke = el("UIStroke", { Thickness = 1, Color = Color3.new(0,0,0) })

    return Roui.Overlay({
        OnClose = onClose,
        Transparency = 1,
    }, {
        Panel = el("Frame", {
            Size = UDim2.new(0, 240, 0, 240),
            Position = UDim2.new(0.5, 0, 0.35, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(60, 180, 255),
            ZIndex = 101, -- 必须高于 Roui.Overlay 的 CloseOverlay (99)
        }, {
            UICorner = el("UICorner", { CornerRadius = UDim.new(0, 12) }),
            UIStroke = el("UIStroke", { Thickness = 2, Color = Color3.new(0,0,0) }),
            TitleBar = el("Frame", {
                Size = UDim2.new(1, 0, 0, 32),
                BackgroundTransparency = 1,
            }, {
                Title = Roui.Text({
                    Text = "GIFTS",
                    Size = UDim2.new(1, 0, 1, 0),
                    TextSize = 20,
                    Font = Enum.Font.FredokaOne,
                }),
                CloseBtn = el("TextButton", {
                    Text = "X",
                    Size = UDim2.new(0, 24, 0, 24),
                    Position = UDim2.new(1, -8, 0.5, 0),
                    AnchorPoint = Vector2.new(1, 0.5),
                    BackgroundColor3 = Color3.fromRGB(220, 60, 60),
                    BorderSizePixel = 0,
                    Font = Enum.Font.FredokaOne,
                    TextSize = 14,
                    TextColor3 = Color3.new(1,1,1),
                    [Roact.Event.Activated] = onClose,
                }, {
                    UICorner = el("UICorner", { CornerRadius = UDim.new(0, 4) }),
                    UIStroke = el("UIStroke", { Thickness = 1, Color = Color3.new(0,0,0) }),
                }),
            }),
            GridContainer = el("Frame", {
                Size = UDim2.new(1, -12, 1, -50),
                Position = UDim2.new(0.5, 0, 0, 40),
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundColor3 = Color3.fromRGB(40, 120, 200),
                BorderSizePixel = 0,
                ZIndex = 101,
            }, gridChildren)
        })
    })
end

local SnakeGameUIRoot = Roact.Component:extend("SnakeGameUIRoot")

function SnakeGameUIRoot:render()
    local state = self.props.state or {}
    local myId = "u" .. tostring(Players.LocalPlayer.UserId)
    local mySnake = state.snakes and state.snakes[myId]
    local score = state.score or (mySnake and mySnake.score) or 0
    local money = state.money or 0
    local giftData = state.giftData or { timePlayed = 0, claimed = {} }
    local autoMode = state.autoMode or false
    local speedMultiplier = state.speedMultiplier or 1
    local has2xSpeed = speedMultiplier >= 2
    local sizeMultiplier = state.sizeMultiplier or 1
    local has2xSize = sizeMultiplier >= 2

    local children = {}
    
    -- 不使用任何缩放，直接用固定像素
    -- children.UIScale = el("UIScale", { Scale = uiScale })

    children.LeftContainer = el("Frame", {
        Position = UDim2.new(0, 15, 0, 15),
        Size = UDim2.new(0, 140, 0, 160), -- 更小
        BackgroundTransparency = 1,
    }, {
        UIListLayout = el("UIListLayout", {
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
        }),
        
        -- Stats Container (Score + Money)
        StatsContainer = el("Frame", {
            Size = UDim2.new(0, 112, 0, 74),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
        }, {
            UIListLayout = el("UIListLayout", {
                Padding = UDim.new(0, 8),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            ScoreBar = Roui.StatBar({
                BackgroundColor3 = Color3.fromRGB(60, 160, 255), -- Blue
                Icon = "rbxassetid://89074978607958", -- Snake Icon
                Value = formatNumber(score),
                Size = UDim2.new(0, 112, 0, 32),
                LayoutOrder = 1,
            }),
            MoneyBar = Roui.StatBar({
                BackgroundColor3 = Color3.fromRGB(80, 220, 80), -- Green
                Icon = "rbxassetid://105300168575798", -- Cash Stack
                Value = formatNumber(money),
                Size = UDim2.new(0, 112, 0, 32),
                LayoutOrder = 2,
            }),
        }),

        -- Menu Buttons Grid (hidden)
        MenuGrid = el("Frame", {
            Size = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            Visible = false,
            LayoutOrder = 2,
        }, {}),
    })

    children.Leaderboard = buildLeaderboard(state)

    -- Gift widget hidden
    children.NextGiftWidgetCont = el("Frame", {
        Size = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1,
        Visible = false,
    }, {})

    children.BottomBar = el("Frame", {
        Position = UDim2.new(0.5, 0, 1, -40),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, 240, 0, 36),
        BackgroundTransparency = 1,
    }, {
        UIListLayout = el("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        -- Button 1: 2x Speed (Boost) - 未购买可点；已购买禁用
        BoostBtn = actionBtn(
            "2x Speed",
            has2xSpeed and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(255, 200, 0),
            { 
                Name = "BoostButton",  
                Size = UDim2.new(0, 52, 0, 32),
                TextSize = 11,
                LayoutOrder = 1, 
                onActivated = has2xSpeed and nil or SnakeGameUI.Callbacks.onPurchase2xSpeed
            }
        ),
        -- Button 2: Kill All (Bomb) - Red, Larger
        BombBtn = actionBtn("Kill All", Color3.fromRGB(255, 40, 40), { 
            Name = "BombButton",   
            Size = UDim2.new(0, 62, 0, 36),
            TextSize = 13,
            LayoutOrder = 2, 
            onActivated = nil
        }),
        -- Button 3: 2x Size - 未购买可点；已购买禁用
        SizeBtn = actionBtn("2x Size", has2xSize and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(40, 160, 255), { 
            Name = "MagnetButton", 
            Size = UDim2.new(0, 52, 0, 32),
            TextSize = 11,
            LayoutOrder = 3, 
            onActivated = has2xSize and nil or SnakeGameUI.Callbacks.onPurchase2xSize
        }),
        -- Button 4: Auto - Green/Red
        AutoBtn = actionBtn(
            autoMode and "Stop" or "Auto",
            autoMode and Color3.fromRGB(220, 80, 80) or Color3.fromRGB(80, 220, 80),
            { 
                Name = "AutoButton", 
                Size = UDim2.new(0, 52, 0, 32),
                TextSize = 11,
                LayoutOrder = 4, 
                onActivated = SnakeGameUI.Callbacks.onAutoToggle 
            }
        ),
    })

    if state.showGiftPanel then
        children.GiftPanel = Roact.createElement(GiftPanel, {
            giftData = giftData,
            onClose = SnakeGameUI.Callbacks.onToggleGiftPanel,
            onClaim = SnakeGameUI.Callbacks.onClaimGift,
        })
    end

    if state.isDead then
        children.DeathPanel = Roact.createElement(DeathPanel, {
            killedBy = state.killedBy or "Unknown",
            lostSize = state.lostSize or 0,
            onRespawn = SnakeGameUI.Callbacks.onRespawn,
            onRevive = SnakeGameUI.Callbacks.onRevive,
            onRevenge = SnakeGameUI.Callbacks.onRevenge,
        })
    end

    -- 调试：在底部显示当前在线时长
    children.DebugTime = Roui.Text({
        Text = "Time: " .. formatTime(giftData.timePlayed),
        Size = UDim2.new(0, 100, 0, 20),
        Position = UDim2.new(0, 10, 1, -30),
        TextSize = 14,
        TextColor3 = Color3.new(1,1,1),
        BackgroundTransparency = 0.5,
        BackgroundColor3 = Color3.new(0,0,0),
    })

    return el("Frame", {
        Name = "SnakeGameUI",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
    }, children)
end

function SnakeGameUI.Start()
    local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    if PlayerGui:FindFirstChild("SnakeGameUI") then PlayerGui.SnakeGameUI:Destroy() end
    gui = Instance.new("ScreenGui")
    gui.Name = "SnakeGameUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = PlayerGui
    local success, result = pcall(function()
        return Roact.mount(Roact.createElement(SnakeGameUIRoot, { state = {} }), gui)
    end)
    if success then contentHandle = result else warn("[SnakeGameUI] Start Failed:", result) end
end

function SnakeGameUI.Update(state)
    if not gui then return end
    if contentHandle then
        pcall(function() Roact.unmount(contentHandle) end)
        contentHandle = nil
    end
    local ok, result = pcall(function()
        return Roact.mount(Roact.createElement(SnakeGameUIRoot, { state = state or {} }), gui)
    end)
    if ok and result then contentHandle = result else warn("[SnakeGameUI] Update Failed:", tostring(result)) end
end

function SnakeGameUI.Stop()
    if contentHandle then pcall(function() Roact.unmount(contentHandle) end) end
    if gui then pcall(function() gui:Destroy() end) end
    contentHandle = nil
end

return SnakeGameUI