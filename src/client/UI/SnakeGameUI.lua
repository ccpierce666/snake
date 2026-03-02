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
    if n >= 1000000 then
        return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n / 1000)
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
local function menuBtn(label, bgColor, props)
    props = props or {}
    local children = {
        UICorner = el("UICorner", { CornerRadius = UDim.new(0, 16) }),
        UIStroke = el("UIStroke", {
            Color = Color3.new(0, 0, 0),
            Thickness = 3,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }),
    }

    if props.Icon then
        children.IconImage = el("ImageLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, 0, 0.4, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.new(0, 40, 0, 40),
            Image = props.Icon,
            ImageColor3 = Color3.new(1, 1, 1),
        })
    end
    
    if props.Children then
        for k, v in pairs(props.Children) do children[k] = v end
    end

    return el("TextButton", {
        Size = props.Size or UDim2.new(0, 80, 0, 80),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        LayoutOrder = props.LayoutOrder,
        BackgroundColor3 = bgColor or Color3.fromRGB(255, 180, 50),
        BorderSizePixel = 0,
        Text = label,
        TextColor3 = Color3.new(1, 1, 1),
        Font = Enum.Font.FredokaOne,
        TextSize = props.TextSize or 16,
        TextStrokeTransparency = 0.5,
        Name = props.Name or label,
        MouseButton1Click = props.onActivated,
        TextYAlignment = Enum.TextYAlignment.Bottom,
        TextWrapped = true,
    }, children)
end

local function buildLeaderboard(state)
    local children = {}
    for i, e in ipairs(state.leaderboard or {}) do
        if i <= 10 then
            local name = "Player"
            for _, p in ipairs(Players:GetPlayers()) do
                if p.UserId == e.userId then name = p.Name break end
            end
            children["Row" .. i] = Roui.LeaderboardRow({
                Rank = i,
                Name = name:sub(1, 10),
                Score = formatNumber(e.score or 0),
                Highlight = (e.userId == Players.LocalPlayer.UserId),
                LayoutOrder = i,
            })
        end
    end

    children.UICorner = el("UICorner", { CornerRadius = UDim.new(0, 8) })
    children.UIStroke = el("UIStroke", { Thickness = 3, Color = Color3.new(0,0,0) })
    children.Title = el("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(60, 70, 120),
        ZIndex = 2,
    }, {
        UICorner = el("UICorner", { CornerRadius = UDim.new(0, 8) }),
        Text = Roui.Text({ Text = "排行榜", Size = UDim2.new(1, 0, 1, 0), TextSize = 16, Font = Enum.Font.FredokaOne }),
    })

    return Roui.Leaderboard({
        Position = UDim2.new(1, -200, 0, 20),
        Size = UDim2.new(0, 180, 0, 300),
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
    
    return el("TextButton", {
        Size = UDim2.new(0, 160, 0, 40),
        BackgroundColor3 = canClaim and Color3.fromRGB(100, 220, 100) or Color3.fromRGB(60, 60, 80),
        Text = "",
        AutoButtonColor = true,
        BorderSizePixel = 0,
        [Roact.Event.Activated] = onActivated,
    }, {
        UICorner = el("UICorner", { CornerRadius = UDim.new(0, 8) }),
        UIStroke = el("UIStroke", { Thickness = 2, Color = Color3.new(0,0,0) }),
        Icon = el("ImageLabel", {
            Size = UDim2.new(0, 24, 0, 24),
            Position = UDim2.new(0, 8, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 1,
            Image = "rbxassetid://6034261141",
            ZIndex = 2,
        }),
        Label = Roui.Text({
            Text = canClaim and "CLAIM GIFT!" or ("Gift in " .. formatTime(timeLeft)),
            Size = UDim2.new(1, -40, 1, 0),
            Position = UDim2.new(0, 35, 0, 0),
            TextSize = 16,
            Font = Enum.Font.FredokaOne,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 2,
        })
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
        
        local iconId = (reward.type == "Length") and "rbxassetid://6034509993" or "rbxassetid://6034706260"
        
        listItems["Item"..i] = el("Frame", {
            BackgroundColor3 = itemBgColor,
            LayoutOrder = i,
        }, {
            UICorner = el("UICorner", { CornerRadius = UDim.new(0, 10) }),
            UIStroke = el("UIStroke", { Thickness = 2, Color = Color3.new(0,0,0) }),
            Icon = el("ImageLabel", {
                Size = UDim2.new(0, 45, 0, 45),
                Position = UDim2.new(0.5, 0, 0.1, 0),
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundTransparency = 1,
                Image = iconId,
                ZIndex = 2,
            }),
            Amount = Roui.Text({
                Text = "+" .. formatNumber(reward.amount),
                Size = UDim2.new(1, 0, 0, 20),
                Position = UDim2.new(0, 0, 0.5, 5),
                TextSize = 16,
                Font = Enum.Font.FredokaOne,
                ZIndex = 2,
            }),
            StatusBar = el("TextButton", {
                Size = UDim2.new(0.9, 0, 0.22, 0),
                Position = UDim2.new(0.5, 0, 0.92, 0),
                AnchorPoint = Vector2.new(0.5, 1),
                BackgroundColor3 = statusColor,
                BorderSizePixel = 0,
                Text = statusText,
                Font = Enum.Font.FredokaOne,
                TextSize = 14,
                TextColor3 = Color3.new(1,1,1),
                AutoButtonColor = canClaim,
                Active = true,
                ZIndex = 110, -- 顶层按钮
                [Roact.Event.Activated] = canClaim and (function()
                    print("[UI] Gift Claim Button Activated, index:", i)
                    if onClaim then onClaim(i) end
                end) or nil
            }, {
                UICorner = el("UICorner", { CornerRadius = UDim.new(0, 6) }),
                UIStroke = el("UIStroke", { Thickness = 1.5, Color = Color3.new(0,0,0) }),
            })
        })
    end
    
    local gridChildren = listItems
    gridChildren.Layout = el("UIGridLayout", {
        CellSize = UDim2.new(0, 110, 0, 115),
        CellPadding = UDim2.new(0, 12, 0, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
    })
    gridChildren.UICorner = el("UICorner", { CornerRadius = UDim.new(0, 12) })
    gridChildren.UIStroke = el("UIStroke", { Thickness = 2, Color = Color3.new(0,0,0) })

    return Roui.Overlay({
        OnClose = onClose,
    }, {
        Panel = el("Frame", {
            Size = UDim2.new(0, 520, 0, 480),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(60, 180, 255),
            ZIndex = 101, -- 必须高于 Roui.Overlay 的 CloseOverlay (99)
        }, {
            UICorner = el("UICorner", { CornerRadius = UDim.new(0, 16) }),
            UIStroke = el("UIStroke", { Thickness = 4, Color = Color3.new(0,0,0) }),
            TitleBar = el("Frame", {
                Size = UDim2.new(1, 0, 0, 50),
                BackgroundTransparency = 1,
            }, {
                Title = Roui.Text({
                    Text = "GIFTS",
                    Size = UDim2.new(1, 0, 1, 0),
                    TextSize = 36,
                    Font = Enum.Font.FredokaOne,
                }),
                CloseBtn = el("TextButton", {
                    Text = "X",
                    Size = UDim2.new(0, 32, 0, 32),
                    Position = UDim2.new(1, -10, 0.5, 0),
                    AnchorPoint = Vector2.new(1, 0.5),
                    BackgroundColor3 = Color3.fromRGB(220, 60, 60),
                    BorderSizePixel = 0,
                    Font = Enum.Font.FredokaOne,
                    TextSize = 20,
                    TextColor3 = Color3.new(1,1,1),
                    [Roact.Event.Activated] = onClose,
                }, {
                    UICorner = el("UICorner", { CornerRadius = UDim.new(0, 6) }),
                    UIStroke = el("UIStroke", { Thickness = 2, Color = Color3.new(0,0,0) }),
                }),
            }),
            GridContainer = el("Frame", {
                Size = UDim2.new(1, -20, 1, -70),
                Position = UDim2.new(0.5, 0, 0, 60),
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
    local myId = tostring(Players.LocalPlayer.UserId)
    local mySnake = state.snakes and state.snakes[myId]
    local score = state.score or (mySnake and mySnake.score) or 0
    local money = state.money or 0
    local giftData = state.giftData or { timePlayed = 0, claimed = {} }
    local autoMode = state.autoMode or false

    local children = {}

    children.LeftContainer = el("Frame", {
        Position = UDim2.new(0, 20, 0, 20),
        Size = UDim2.new(0, 300, 0, 600),
        BackgroundTransparency = 1,
    }, {
        UIListLayout = el("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
        }),
        ScoreBar = Roui.StatBar({
            BackgroundColor3 = Color3.fromRGB(160, 100, 240),
            Icon = "S",
            Value = formatNumber(score),
            LayoutOrder = 1,
        }),
        MoneyBar = Roui.StatBar({
            BackgroundColor3 = Color3.fromRGB(100, 220, 100),
            Icon = "$",
            Value = formatNumber(money),
            LayoutOrder = 2,
        }),
        MenuGrid = el("Frame", {
            Size = UDim2.new(0, 180, 0, 180),
            BackgroundTransparency = 1,
            LayoutOrder = 3,
        }, {
            UIGridLayout = el("UIGridLayout", {
                CellSize = UDim2.new(0, 80, 0, 80),
                CellPadding = UDim2.new(0, 10, 0, 10),
            }),
            ShopBtn  = menuBtn("商店", Color3.fromRGB(255, 180, 50),  { Name = "ShopButton", Icon = "rbxassetid://6034509993" }),
            SkinBtn  = menuBtn("皮肤", Color3.fromRGB(100, 200, 255), { Name = "SkinButton", Icon = "rbxassetid://6034817279" }),
            SpinBtn  = menuBtn("旋转", Color3.fromRGB(180, 100, 240), { Name = "SpinButton", Icon = "rbxassetid://6034706260" }),
            DailyBtn = menuBtn("每日", Color3.fromRGB(100, 180, 240), { 
                Name = "DailyButton", 
                Icon = "rbxassetid://6034261141",
                onActivated = SnakeGameUI.Callbacks.onToggleGiftPanel 
            }),
        }),
    })

    children.Leaderboard = buildLeaderboard(state)

    children.NextGiftWidgetCont = el("Frame", {
        Position = UDim2.new(1, -200, 0, 330),
        Size = UDim2.new(0, 180, 0, 50),
        BackgroundTransparency = 1,
    }, {
        Widget = NextGiftWidget({ 
            giftData = giftData,
            onActivated = SnakeGameUI.Callbacks.onToggleGiftPanel 
        })
    })

    children.BottomBar = el("Frame", {
        Position = UDim2.new(0.5, 0, 1, -110),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, 380, 0, 90),
        BackgroundTransparency = 1,
    }, {
        UIListLayout = el("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
        BoostBtn  = menuBtn("加速", Color3.fromRGB(80, 200, 120),  { Name = "BoostButton",  Size = UDim2.new(0, 80, 0, 80), LayoutOrder = 1, Icon = "rbxassetid://6035288286" }),
        BombBtn   = menuBtn("核弹", Color3.fromRGB(255, 80, 80),   { Name = "BombButton",   Size = UDim2.new(0, 80, 0, 80), LayoutOrder = 2, Icon = "rbxassetid://6034309323" }),
        MagnetBtn = menuBtn("磁铁", Color3.fromRGB(100, 150, 255), { Name = "MagnetButton", Size = UDim2.new(0, 80, 0, 80), LayoutOrder = 3, Icon = "rbxassetid://6034633237" }),
        AutoBtn   = menuBtn(
            autoMode and "停止" or "自动",
            autoMode and Color3.fromRGB(220, 80, 80) or Color3.fromRGB(60, 180, 100),
            { Name = "AutoButton", Size = UDim2.new(0, 80, 0, 80), LayoutOrder = 4, Icon = "rbxassetid://6034287959",
              onActivated = SnakeGameUI.Callbacks.onAutoToggle }
        ),
    })

    if state.showGiftPanel then
        children.GiftPanel = Roact.createElement(GiftPanel, {
            giftData = giftData,
            onClose = SnakeGameUI.Callbacks.onToggleGiftPanel,
            onClaim = SnakeGameUI.Callbacks.onClaimGift,
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
    if contentHandle and typeof(contentHandle) == "Instance" then
        pcall(function() contentHandle:Destroy() end)
    end
    contentHandle = nil
    local success, result = pcall(function()
        return Roact.mount(Roact.createElement(SnakeGameUIRoot, { state = state or {} }), gui)
    end)
    if success and result then contentHandle = result else warn("[SnakeGameUI] Update Failed:", tostring(result)) end
end

function SnakeGameUI.Stop()
    if contentHandle then pcall(function() contentHandle:Destroy() end) end
    if gui then pcall(function() gui:Destroy() end) end
end

return SnakeGameUI