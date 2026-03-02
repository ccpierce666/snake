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

local function el(className, props, children)
    return Roact.createElement(className, props or {}, children or {})
end

local function merge(a, b)
    local out = {}
    for k, v in pairs(a or {}) do out[k] = v end
    for k, v in pairs(b or {}) do out[k] = v end
    return out
end

local function formatNumber(n)
    n = tonumber(n) or 0
    if n >= 1000000 then
        return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then
        return string.format("%.1fK", n / 1000)
    else
        return tostring(n)
    end
end

-- 创建纯文字方形按钮（不用 emoji）
local function menuBtn(label, bgColor, props)
    props = props or {}
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
        TextSize = props.TextSize or 20,
        TextStrokeTransparency = 0.5,
        Name = props.Name or label,
        MouseButton1Click = props.onActivated,   -- 直接绑定，无需 DescendantAdded
    }, {
        UICorner = el("UICorner", { CornerRadius = UDim.new(0, 16) }),
        UIStroke = el("UIStroke", {
            Color = Color3.new(0, 0, 0),
            Thickness = 3,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }),
    })
end

local function buildLeaderboard(state)
    local entries = {}
    for i, e in ipairs(state.leaderboard or {}) do
        if i <= 10 then
            local name = "Player"
            for _, p in ipairs(Players:GetPlayers()) do
                if p.UserId == e.userId then name = p.Name break end
            end
            entries["Row" .. i] = Roui.LeaderboardRow({
                Rank = i,
                Name = name:sub(1, 10),
                Score = formatNumber(e.score or 0),
                Highlight = (e.userId == Players.LocalPlayer.UserId),
            })
        end
    end

    return Roui.Leaderboard({
        Position = UDim2.new(1, -200, 0, 20),
        Size = UDim2.new(0, 180, 0, 300),
    }, {
        UICorner = el("UICorner", { CornerRadius = UDim.new(0, 8) }),
        UIStroke = el("UIStroke", { Thickness = 3, Color = Color3.new(0,0,0) }),
        Title = el("Frame", {
            Size = UDim2.new(1, 0, 0, 32),
            BackgroundColor3 = Color3.fromRGB(60, 70, 120),
        }, {
            UICorner = el("UICorner", { CornerRadius = UDim.new(0, 8) }),
            Text = Roui.Text({ Text = "排行榜", Size = UDim2.new(1, 0, 1, 0), TextSize = 16, Font = Enum.Font.FredokaOne }),
        }),
        List = el("Frame", {
            Position = UDim2.new(0, 5, 0, 35),
            Size = UDim2.new(1, -10, 1, -40),
            BackgroundTransparency = 1,
        }, merge(entries, {
            UIListLayout = el("UIListLayout", {
                Padding = UDim.new(0, 4),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
        })),
    })
end

local SnakeGameUIRoot = Roact.Component:extend("SnakeGameUIRoot")

function SnakeGameUIRoot:init()
    self.state = { gameState = {} }
end

function SnakeGameUIRoot:render()
    local state = self.props.state or {}
    local myId = tostring(Players.LocalPlayer.UserId)
    local mySnake = state.snakes and state.snakes[myId]
    local score = state.score or (mySnake and mySnake.score) or 0
    local money = state.money or 0

    local children = {}

    local autoMode = state.autoMode or false

    -- 左侧容器（分数 + 按钮）
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

        -- 1. 分数栏
        ScoreBar = Roui.StatBar({
            BackgroundColor3 = Color3.fromRGB(160, 100, 240),
            Icon = "S",
            Value = formatNumber(score),
            LayoutOrder = 1,
        }),

        -- 2. 金币栏
        MoneyBar = Roui.StatBar({
            BackgroundColor3 = Color3.fromRGB(100, 220, 100),
            Icon = "$",
            Value = formatNumber(money),
            LayoutOrder = 2,
        }),

        Spacer1 = el("Frame", { Size = UDim2.new(0, 0, 0, 10), BackgroundTransparency = 1, LayoutOrder = 3 }),

        -- 3. 功能按钮（2x2）
        MenuGrid = el("Frame", {
            Size = UDim2.new(0, 180, 0, 180),
            BackgroundTransparency = 1,
            LayoutOrder = 4,
        }, {
            UIGridLayout = el("UIGridLayout", {
                CellSize = UDim2.new(0, 80, 0, 80),
                CellPadding = UDim2.new(0, 10, 0, 10),
            }),

            ShopBtn  = menuBtn("商店", Color3.fromRGB(255, 180, 50),  { Name = "ShopButton" }),
            SkinBtn  = menuBtn("皮肤", Color3.fromRGB(100, 200, 255), { Name = "SkinButton" }),
            SpinBtn  = menuBtn("旋转", Color3.fromRGB(180, 100, 240), { Name = "SpinButton" }),
            DailyBtn = menuBtn("每日", Color3.fromRGB(100, 180, 240), { Name = "DailyButton" }),
        }),

    })

    -- 右侧排行榜
    children.Leaderboard = buildLeaderboard(state)

    -- 底部道具按钮行（居中）
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

        BoostBtn  = menuBtn("加速", Color3.fromRGB(80, 200, 120),  { Name = "BoostButton",  Size = UDim2.new(0, 80, 0, 80), LayoutOrder = 1 }),
        BombBtn   = menuBtn("核弹", Color3.fromRGB(255, 80, 80),   { Name = "BombButton",   Size = UDim2.new(0, 80, 0, 80), LayoutOrder = 2 }),
        MagnetBtn = menuBtn("磁铁", Color3.fromRGB(100, 150, 255), { Name = "MagnetButton", Size = UDim2.new(0, 80, 0, 80), LayoutOrder = 3 }),
        AutoBtn   = menuBtn(
            autoMode and "停止" or "自动",
            autoMode and Color3.fromRGB(220, 80, 80) or Color3.fromRGB(60, 180, 100),
            { Name = "AutoButton", Size = UDim2.new(0, 80, 0, 80), LayoutOrder = 4,
              onActivated = SnakeGameUI.Callbacks.onAutoToggle }
        ),
    })

    return el("Frame", {
        Name = "SnakeGameUI",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
    }, children)
end

function SnakeGameUI.Start()
    local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

    if PlayerGui:FindFirstChild("SnakeGameUI") then
        PlayerGui.SnakeGameUI:Destroy()
    end

    gui = Instance.new("ScreenGui")
    gui.Name = "SnakeGameUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = PlayerGui

    local success, result = pcall(function()
        return Roact.mount(
            Roact.createElement(SnakeGameUIRoot, { state = {} }),
            gui
        )
    end)

    if success then
        contentHandle = result
        print("[SnakeGameUI] Started OK")
    else
        warn("[SnakeGameUI] Start Failed:", result)
    end
end

function SnakeGameUI.Update(state)
    if not gui then return end

    -- 销毁旧的内容
    if contentHandle and typeof(contentHandle) == "Instance" then
        pcall(function() contentHandle:Destroy() end)
    end
    contentHandle = nil

    -- 重新挂载新的状态
    local success, result = pcall(function()
        return Roact.mount(
            Roact.createElement(SnakeGameUIRoot, { state = state or {} }),
            gui
        )
    end)
    if success then
        contentHandle = result
    else
        warn("[SnakeGameUI] Update Failed:", result)
    end
end

function SnakeGameUI.Stop()
    if contentHandle then
        Roact.unmount(contentHandle)
        contentHandle = nil
    end
    if gui then
        gui:Destroy()
        gui = nil
    end
end

return SnakeGameUI