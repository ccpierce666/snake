-- SnakeGameUI - Roui + Roact implementation
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")

local Common = ReplicatedStorage:WaitForChild("Common")
local Roact = require(Common:WaitForChild("Roact"))
local Roui = require(Common:WaitForChild("Roui"))

local SnakeGameUI = {}
SnakeGameUI.Callbacks = {}   -- 控制器在 KnitStart 里注册回调

local gui = nil
local contentHandle = nil

-- 奖励配置表 (与服务器保持一致)
local GIFT_REWARDS = {
    { time = 30,   type = "Length", amount = 1000 },     -- 00:30  格1
    { time = 90,   type = "Length", amount = 3000 },     -- 01:30  格2
    { time = 180,  type = "Cash",   amount = 2000 },     -- 03:00  格3
    { time = 300,  type = "Length", amount = 5000 },     -- 05:00  格4
    { time = 600,  type = "Length", amount = 10000 },    -- 10:00  格5
    { time = 900,  type = "Cash",   amount = 5000 },     -- 15:00  格6
    { time = 1200, type = "Length", amount = 25000 },    -- 20:00  格7
    { time = 1800, type = "Length", amount = 30000 },    -- 30:00  格8
    { time = 2100, type = "Cash",   amount = 10000 },    -- 35:00  格9
    { time = 3000, type = "Length", amount = 100000 },   -- 50:00  格10
    { time = 4200, type = "Length", amount = 250000 },   -- 70:00  格11
    { time = 5400, type = "Length", amount = 1000000 },  -- 90:00  格12
}
local SKIN_ITEMS = {
    { id = 1, price = 0, color = Color3.fromRGB(255, 210, 60), name = "Classic" },
    { id = 2, price = 5000, color = Color3.fromRGB(240, 240, 240), name = "Ivory" },
    { id = 3, price = 10000, color = Color3.fromRGB(80, 160, 255), name = "Azure" },
    { id = 4, price = 25000, color = Color3.fromRGB(255, 140, 40), name = "Orange" },
    { id = 5, price = 50000, color = Color3.fromRGB(255, 70, 70), name = "Crimson" },
    { id = 6, price = 80000, color = Color3.fromRGB(180, 90, 255), name = "Violet" },
    { id = 7, price = 120000, color = Color3.fromRGB(30, 30, 30), name = "Shadow" },
    { id = 8, price = 180000, color = Color3.fromRGB(30, 190, 120), name = "Emerald" },
    { id = 9, price = 260000, color = Color3.fromRGB(160, 160, 160), name = "Monochrome" },
    { id = 10, price = 320000, color = Color3.fromRGB(255, 85, 20), name = "Magma" },
    { id = 11, price = 380000, color = Color3.fromRGB(40, 165, 255), name = "Ripple" },
    { id = 12, price = 450000, color = Color3.fromRGB(130, 95, 45), name = "Cobra" },
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
        local iconSize = props.IconSize or 26
        children.IconImage = el("ImageLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.new(0, iconSize, 0, iconSize),
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
            local name = e.name or "Player"
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
        Size = UDim2.new(1, 0, 0, 108),
    }, children)
end

local function NextGiftWidget(props)
    local giftData = props.giftData or { timePlayed = 0, claimed = {} }
    local timePlayed = tonumber(giftData.timePlayed) or 0
    local claimed = giftData.claimed or {}
    local onActivated = props.onActivated

    local nextReward = nil
    for i, reward in ipairs(GIFT_REWARDS) do
        if not claimed[tostring(i)] then
            nextReward = reward
            break
        end
    end

    if not nextReward then
        return el("Frame", { Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1 })
    end

    local timeLeft = math.max(0, nextReward.time - timePlayed)
    local canClaim = timeLeft <= 0

    -- 可领取时用绿色，否则用蓝色（与截图一致）
    local pillColor  = canClaim and Color3.fromRGB(90, 200, 80) or Color3.fromRGB(50, 140, 255)
    local labelText  = canClaim and "Claim Gift!" or ("Gift in " .. formatTime(timeLeft))

    -- 整体容器：填满父容器宽度，高 36px
    local WIDGET_H = 36
    local ICON_SIZE = 42

    return el("Frame", {
        Size = UDim2.new(1, 0, 0, WIDGET_H),
        BackgroundTransparency = 1,
        ClipsDescendants = false,
    }, {
        -- ── 胶囊背景 ──────────────────────────────────────────────
        Pill = el("TextButton", {
            Size = UDim2.new(1, -16, 1, 0),
            Position = UDim2.new(0, 16, 0, 0),
            BackgroundColor3 = pillColor,
            AutoButtonColor = true,
            Text = "",
            ZIndex = 2,
            [Roact.Event.Activated] = onActivated,
        }, {
            UICorner = el("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
            UIStroke = el("UIStroke", {
                Color = Color3.fromRGB(0, 0, 0),
                Thickness = 2,
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            }),
            -- 倒计时 / Claim 文字
            Label = el("TextLabel", {
                Size = UDim2.new(1, -36, 1, 0),
                Position = UDim2.new(0, 32, 0, 0),
                BackgroundTransparency = 1,
                Text = labelText,
                Font = Enum.Font.FredokaOne,
                TextSize = 14,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Center,
                ZIndex = 3,
            }, {
                UIStroke = el("UIStroke", {
                    Color = Color3.fromRGB(0, 0, 80),
                    Thickness = 1.5,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                }),
            }),
        }),

        -- ── 礼物图标 ─────────────────────────────────────────────
        GiftImg = el("ImageLabel", {
            Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE),
            Position = UDim2.new(0, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundTransparency = 1,
            Image = "rbxthumb://type=Asset&id=139988932455302&w=420&h=420",
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 4,
        }),
    })
end

local function DeathPanel(props)
    local killedBy = props.killedBy or "Unknown"
    local lostSize = props.lostSize or 0
    local onRespawn = props.onRespawn
    local onRevive = props.onRevive
    local onRevenge = props.onRevenge

    return el("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        ZIndex = 900,
    }, {
        -- 全屏遮罩：盖住所有游戏 UI
        Overlay = el("Frame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.45,
            ZIndex = 900,
            Active = true,
        }),

        -- 顶部标题文字
        TitleLine = el("TextLabel", {
            Size = UDim2.new(1, 0, 0, 50),
            Position = UDim2.new(0, 0, 0, 18),
            BackgroundTransparency = 1,
            RichText = true,
            Text = 'You are <font color="#FF4444"><b>DEAD</b></font>',
            Font = Enum.Font.FredokaOne,
            TextSize = 36,
            TextColor3 = Color3.new(1, 1, 1),
            TextStrokeTransparency = 0.2,
            TextStrokeColor3 = Color3.new(0, 0, 0),
            ZIndex = 902,
        }),
        SubLine = el("TextLabel", {
            Size = UDim2.new(0.9, 0, 0, 36),
            Position = UDim2.new(0.5, 0, 0, 60),
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundTransparency = 1,
            RichText = true,
            Text = 'You died to <font color="#DD88FF"><b>' .. killedBy .. '</b></font> and lost <font color="#FFEE44"><b>' .. lostSize .. '</b></font> Size!',
            Font = Enum.Font.FredokaOne,
            TextSize = 22,
            TextColor3 = Color3.new(1, 1, 1),
            TextStrokeTransparency = 0.2,
            TextStrokeColor3 = Color3.new(0, 0, 0),
            TextWrapped = true,
            ZIndex = 902,
        }),

        Container = el("Frame", {
            Size = UDim2.new(0, 320, 0, 140),
            Position = UDim2.new(0.5, 0, 0.65, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            ZIndex = 901,
            ClipsDescendants = false,
        }, {
            Layout = el("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                VerticalAlignment = Enum.VerticalAlignment.Top,
                Padding = UDim.new(0, 10),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),

            -- ── RESPAWN 大按钮 ──
            RespawnBtn = el("TextButton", {
                Size = UDim2.new(1, 0, 0, 62),
                BackgroundColor3 = Color3.fromRGB(50, 170, 255),
                Text = "",
                BorderSizePixel = 0,
                LayoutOrder = 1,
                ZIndex = 902,
                [Roact.Event.Activated] = onRespawn,
            }, {
                UICorner = el("UICorner", { CornerRadius = UDim.new(0, 18) }),
                UIStroke = el("UIStroke", { Thickness = 3, Color = Color3.new(0,0,0) }),
                Label = el("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 36),
                    Position = UDim2.new(0, 0, 0, 4),
                    BackgroundTransparency = 1,
                    Text = "RESPAWN",
                    Font = Enum.Font.FredokaOne,
                    TextSize = 30,
                    TextColor3 = Color3.new(1, 1, 1),
                    TextStrokeTransparency = 0.4,
                    TextStrokeColor3 = Color3.new(0, 0, 0),
                    ZIndex = 903,
                }),
                SubLabel = el("TextLabel", {
                    Size = UDim2.new(1, 0, 0, 20),
                    Position = UDim2.new(0, 0, 0, 38),
                    BackgroundTransparency = 1,
                    Text = "(Start from 0 Size)",
                    Font = Enum.Font.FredokaOne,
                    TextSize = 14,
                    TextColor3 = Color3.fromRGB(200, 235, 255),
                    ZIndex = 903,
                }),
            }),

            -- ── REVIVE + REVENGE 并排行 ──
            BottomRow = el("Frame", {
                Size = UDim2.new(1, 0, 0, 58),
                BackgroundTransparency = 1,
                LayoutOrder = 2,
                ClipsDescendants = false,
            }, {
                Layout = el("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding = UDim.new(0, 10),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }),

                ReviveWrapper = el("Frame", {
                    Size = UDim2.new(0, 148, 0, 50),
                    BackgroundTransparency = 1,
                    LayoutOrder = 1,
                    ClipsDescendants = false,
                }, {
                    Btn = el("TextButton", {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundColor3 = Color3.fromRGB(210, 100, 220),
                        Text = "",
                        BorderSizePixel = 0,
                        ZIndex = 902,
                        [Roact.Event.Activated] = onRevive,
                    }, {
                        UICorner = el("UICorner", { CornerRadius = UDim.new(0, 14) }),
                        UIStroke = el("UIStroke", { Thickness = 3, Color = Color3.new(0,0,0) }),
                        Icon = el("TextLabel", {
                            Size = UDim2.new(0, 36, 1, 0),
                            Position = UDim2.new(0, 6, 0, 0),
                            BackgroundTransparency = 1,
                            Text = "❤",
                            Font = Enum.Font.FredokaOne,
                            TextSize = 26,
                            TextColor3 = Color3.fromRGB(255, 80, 100),
                            ZIndex = 903,
                        }),
                        Label = el("TextLabel", {
                            Size = UDim2.new(1, -46, 1, 0),
                            Position = UDim2.new(0, 42, 0, 0),
                            BackgroundTransparency = 1,
                            Text = "REVIVE",
                            Font = Enum.Font.FredokaOne,
                            TextSize = 20,
                            TextColor3 = Color3.new(1, 1, 1),
                            TextStrokeTransparency = 0.4,
                            TextStrokeColor3 = Color3.new(0, 0, 0),
                            ZIndex = 903,
                        }),
                    }),
                    SizeBadge = el("TextLabel", {
                        Size = UDim2.new(0, 72, 0, 20),
                        Position = UDim2.new(0, 4, 0, -11),
                        BackgroundTransparency = 1,
                        Text = "+" .. lostSize .. " Size",
                        Font = Enum.Font.FredokaOne,
                        TextSize = 14,
                        TextColor3 = Color3.fromRGB(100, 255, 100),
                        TextStrokeTransparency = 0.3,
                        TextStrokeColor3 = Color3.new(0, 0, 0),
                        ZIndex = 905,
                    }),
                }),

                RevengeWrapper = el("Frame", {
                    Size = UDim2.new(0, 148, 0, 50),
                    BackgroundTransparency = 1,
                    LayoutOrder = 2,
                    ClipsDescendants = false,
                }, {
                    Btn = el("TextButton", {
                        Size = UDim2.new(1, 0, 1, 0),
                        BackgroundColor3 = Color3.fromRGB(255, 65, 50),
                        Text = "",
                        BorderSizePixel = 0,
                        ZIndex = 902,
                        [Roact.Event.Activated] = onRevenge,
                    }, {
                        UICorner = el("UICorner", { CornerRadius = UDim.new(0, 14) }),
                        UIStroke = el("UIStroke", { Thickness = 3, Color = Color3.new(0,0,0) }),
                        Icon = el("TextLabel", {
                            Size = UDim2.new(0, 36, 1, 0),
                            Position = UDim2.new(0, 6, 0, 0),
                            BackgroundTransparency = 1,
                            Text = "🗡",
                            Font = Enum.Font.FredokaOne,
                            TextSize = 24,
                            TextColor3 = Color3.fromRGB(255, 210, 60),
                            ZIndex = 903,
                        }),
                        Label = el("TextLabel", {
                            Size = UDim2.new(1, -46, 1, 0),
                            Position = UDim2.new(0, 42, 0, 0),
                            BackgroundTransparency = 1,
                            Text = "REVENGE",
                            Font = Enum.Font.FredokaOne,
                            TextSize = 20,
                            TextColor3 = Color3.new(1, 1, 1),
                            TextStrokeTransparency = 0.4,
                            TextStrokeColor3 = Color3.new(0, 0, 0),
                            ZIndex = 903,
                        }),
                    }),
                    KillBadge = el("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 20),
                        Position = UDim2.new(0, 0, 0, -11),
                        BackgroundTransparency = 1,
                        Text = "KILL " .. killedBy,
                        Font = Enum.Font.FredokaOne,
                        TextSize = 13,
                        TextXAlignment = Enum.TextXAlignment.Right,
                        TextColor3 = Color3.fromRGB(255, 230, 60),
                        TextStrokeTransparency = 0.3,
                        TextStrokeColor3 = Color3.new(0, 0, 0),
                        ZIndex = 905,
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
        
        local iconId = (reward.type == "Cash") and "rbxassetid://105300168575798" or "rbxassetid://89074978607958"
        
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

local function SkinPanel(props)
    local onClose = props.onClose
    local onSelect = props.onSelect
    local skinData = props.skinData or {}
    local equippedSkinId = tonumber(skinData.equippedSkinId) or 1
    local ownedMap = {}
    for _, id in ipairs(skinData.ownedSkins or {}) do
        ownedMap[tonumber(id)] = true
    end
    ownedMap[1] = true

    local gridChildren = {}
    for _, item in ipairs(SKIN_ITEMS) do
        local isEquipped = equippedSkinId == item.id
        local isOwned = ownedMap[item.id] == true
        local label = isEquipped and "EQUIP" or (isOwned and "USE" or ("$" .. formatNumber(item.price)))
        local statusColor = isEquipped and Color3.fromRGB(70, 220, 70) or Color3.fromRGB(60, 160, 255)
        gridChildren["Skin" .. item.id] = el("TextButton", {
            BackgroundColor3 = item.color,
            BorderSizePixel = 0,
            LayoutOrder = item.id,
            AutoButtonColor = true,
            Text = "",
            [Roact.Event.Activated] = function()
                if onSelect then
                    onSelect(item.id)
                end
            end,
        }, {
            UICorner = el("UICorner", { CornerRadius = UDim.new(0, 6) }),
            UIStroke = el("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0) }),
            Name = el("TextLabel", {
                Size = UDim2.new(0.9, 0, 0, 12),
                Position = UDim2.new(0.5, 0, 0, 2),
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundTransparency = 1,
                Text = item.name or ("Skin " .. tostring(item.id)),
                Font = Enum.Font.FredokaOne,
                TextSize = 8,
                TextColor3 = Color3.new(1, 1, 1),
                TextStrokeTransparency = 0.35,
                TextStrokeColor3 = Color3.new(0, 0, 0),
            }),
            Status = el("TextLabel", {
                Size = UDim2.new(0.88, 0, 0, 16),
                Position = UDim2.new(0.5, 0, 1, -4),
                AnchorPoint = Vector2.new(0.5, 1),
                BackgroundColor3 = statusColor,
                BorderSizePixel = 0,
                Text = label,
                Font = Enum.Font.FredokaOne,
                TextSize = 10,
                TextColor3 = Color3.new(1, 1, 1),
                TextStrokeTransparency = 0.35,
                TextStrokeColor3 = Color3.new(0, 0, 0),
            }, {
                UICorner = el("UICorner", { CornerRadius = UDim.new(0, 3) }),
                UIStroke = el("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0) }),
            }),
        })
    end
    gridChildren.Layout = el("UIGridLayout", {
        CellSize = UDim2.new(0, 64, 0, 52),
        CellPadding = UDim2.new(0, 4, 0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Top,
    })

    return Roui.Overlay({
        OnClose = onClose,
        Transparency = 1,
    }, {
        Panel = el("Frame", {
            Size = UDim2.new(0, 300, 0, 232),
            Position = UDim2.new(0.5, 0, 0.38, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(60, 180, 255),
            ZIndex = 101,
        }, {
            UICorner = el("UICorner", { CornerRadius = UDim.new(0, 10) }),
            UIStroke = el("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0) }),
            Title = el("TextLabel", {
                Size = UDim2.new(1, -40, 0, 30),
                Position = UDim2.new(0, 10, 0, 4),
                BackgroundTransparency = 1,
                Text = "SKINS",
                Font = Enum.Font.FredokaOne,
                TextSize = 22,
                TextColor3 = Color3.new(1, 1, 1),
                TextStrokeTransparency = 0.25,
                TextStrokeColor3 = Color3.new(0, 0, 0),
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            CloseBtn = el("TextButton", {
                Text = "X",
                Size = UDim2.new(0, 24, 0, 24),
                Position = UDim2.new(1, -8, 0, 8),
                AnchorPoint = Vector2.new(1, 0),
                BackgroundColor3 = Color3.fromRGB(220, 60, 60),
                BorderSizePixel = 0,
                Font = Enum.Font.FredokaOne,
                TextSize = 14,
                TextColor3 = Color3.new(1, 1, 1),
                [Roact.Event.Activated] = onClose,
            }, {
                UICorner = el("UICorner", { CornerRadius = UDim.new(0, 4) }),
                UIStroke = el("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0) }),
            }),
            Grid = el("Frame", {
                Size = UDim2.new(1, -16, 1, -44),
                Position = UDim2.new(0, 8, 0, 36),
                BackgroundColor3 = Color3.fromRGB(40, 120, 200),
                BorderSizePixel = 0,
            }, {
                UICorner = el("UICorner", { CornerRadius = UDim.new(0, 8) }),
                UIStroke = el("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0) }),
                Items = el("Frame", {
                    Size = UDim2.new(1, -6, 1, -6),
                    Position = UDim2.new(0, 3, 0, 3),
                    BackgroundTransparency = 1,
                }, gridChildren),
            }),
        }),
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
    local skinData = state.skinData or { equippedSkinId = 1, ownedSkins = { 1 } }
    local autoMode = state.autoMode or false
    local speedMultiplier = state.speedMultiplier or 1
    local has2xSpeed = speedMultiplier >= 2
    local sizeMultiplier = state.sizeMultiplier or 1
    local has2xSize = sizeMultiplier >= 2

    -- 获取 Roblox 顶栏高度（IgnoreGuiInset=true 时需手动偏移）
    local insetTop = GuiService:GetGuiInset()
    local insetY = insetTop.Y

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
                Name = "SnakeScoreBar",
                BackgroundColor3 = Color3.fromRGB(60, 160, 255), -- Blue
                Icon = "rbxassetid://89074978607958", -- Snake Icon
                Value = formatNumber(score),
                Size = UDim2.new(0, 112, 0, 32),
                LayoutOrder = 1,
            }),
            MoneyBar = Roui.StatBar({
                Name = "SnakeMoneyBar",
                BackgroundColor3 = Color3.fromRGB(80, 220, 80), -- Green
                Icon = "rbxassetid://105300168575798", -- Cash Stack
                Value = formatNumber(money),
                Size = UDim2.new(0, 112, 0, 32),
                LayoutOrder = 2,
            }),
        }),

        -- Menu Buttons Grid
        MenuGrid = el("Frame", {
            Size = UDim2.new(0, 160, 0, 150),
            BackgroundTransparency = 1,
            LayoutOrder = 2,
        }, {
            UIGridLayout = el("UIGridLayout", {
                CellSize = UDim2.new(0, 70, 0, 70),
                CellPadding = UDim2.new(0, 10, 0, 10),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            SkinBtn = menuBtn("", Color3.fromRGB(228, 139, 68), {
                Name = "SkinButton",
                Size = UDim2.new(0, 26, 0, 26),
                IconSize = 22,
                Icon = "rbxassetid://94001317361506",
                onActivated = SnakeGameUI.Callbacks.onToggleSkin,
                LayoutOrder = 3,
                Children = {
                    UICorner = el("UICorner", { CornerRadius = UDim.new(0, 2) }),
                },
            }),
        }),
    })

    -- 右侧栏：排行榜 + Gift 按钮，垂直堆叠
    children.RightColumn = el("Frame", {
        Position = UDim2.new(1, -8, 0, -34),
        AnchorPoint = Vector2.new(1, 0),
        Size = UDim2.new(0, 160, 0, 160),
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        ZIndex = 10,
    }, {
        UIListLayout = el("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 6),
        }),
        Leaderboard = el("Frame", {
            Size = UDim2.new(1, 0, 0, 108),
            BackgroundTransparency = 1,
            LayoutOrder = 1,
        }, {
            Inner = buildLeaderboard(state),
        }),
        GiftCont = el("Frame", {
            Size = UDim2.new(1, 0, 0, 36),
            BackgroundTransparency = 1,
            ClipsDescendants = false,
            LayoutOrder = 2,
        }, {
            Widget = Roact.createElement(NextGiftWidget, {
                giftData = giftData,
                onActivated = SnakeGameUI.Callbacks.onToggleGiftPanel,
            }),
        }),
    })

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
            onActivated = SnakeGameUI.Callbacks.onPurchaseKillAll
        }),
        -- Button 3: 2x Size - 未购买可点；已购买禁用
        SizeBtn = actionBtn("2x Size", has2xSize and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(40, 160, 255), { 
            Name = "MagnetButton", 
            Size = UDim2.new(0, 52, 0, 32),
            TextSize = 11,
            LayoutOrder = 3, 
            onActivated = has2xSize and nil or SnakeGameUI.Callbacks.onPurchase2xSize
        }),
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

    if state.showSkinPanel then
        children.SkinPanel = Roact.createElement(SkinPanel, {
            skinData = skinData,
            onClose = SnakeGameUI.Callbacks.onToggleSkin,
            onSelect = SnakeGameUI.Callbacks.onSelectSkin,
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

    -- （调试时间框已移除，避免遮挡游戏画面）

    -- 把普通游戏 UI 拆进 SafeArea（偏移顶部 inset，避免被系统栏遮挡）
    -- DeathPanel / GiftPanel 留在根层，从 (0,0) 全屏覆盖
    local deathPanel  = children.DeathPanel
    local giftPanel   = children.GiftPanel
    local skinPanel   = children.SkinPanel
    children.DeathPanel = nil
    children.GiftPanel  = nil
    children.SkinPanel  = nil

    local rootChildren = {
        SafeArea = el("Frame", {
            Position = UDim2.new(0, 0, 0, insetY),
            Size = UDim2.new(1, 0, 1, -insetY),
            BackgroundTransparency = 1,
            ClipsDescendants = false,
        }, children),
    }
    if deathPanel then rootChildren.DeathPanel = deathPanel end
    if giftPanel  then rootChildren.GiftPanel  = giftPanel  end
    if skinPanel  then rootChildren.SkinPanel  = skinPanel  end

    return el("Frame", {
        Name = "SnakeGameUI",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
    }, rootChildren)
end

-- ======================================================
-- 吃食物特效：钞票 + 长度飞向对应 StatBar，伴有音效
-- ======================================================
local eatSound = nil
local function getEatSound()
    if eatSound then return eatSound end
    eatSound = Instance.new("Sound")
    -- biu~ 激光射出音效
    eatSound.SoundId       = "rbxassetid://12221967"
    eatSound.Volume        = 0.6
    eatSound.PlaybackSpeed = 1.8   -- 加快播放速度，biubiubiu 感
    eatSound.RollOffMaxDistance = 0
    eatSound.Parent        = SoundService
    return eatSound
end

-- startScreenPos : Vector2（食物 WorldToViewportPoint 结果）
-- foodValue      : number（食物分值，用于显示 +X）
-- 读取 StatBar 的屏幕中心坐标，等布局完成后再读
local function getBarCenter(name, fallbackX, fallbackY)
    local inst = gui and gui:FindFirstChild(name, true)
    if inst then
        local ap = inst.AbsolutePosition
        local as = inst.AbsoluteSize
        if as.X > 0 and as.Y > 0 then
            return Vector2.new(ap.X + as.X * 0.5, ap.Y + as.Y * 0.5)
        end
    end
    -- 兜底：基于固定布局像素
    -- LeftContainer pos=(15,15)，ScoreBar size=(112,32) → center≈(71,31)
    -- MoneyBar 在 ScoreBar 下方 padding8 → center≈(71,71)
    return Vector2.new(fallbackX, fallbackY)
end

function SnakeGameUI.PlayEatEffect(startScreenPos)
    if not gui then return end
    local sx, sy = startScreenPos.X, startScreenPos.Y

    -- 等下一帧渲染完毕，AbsolutePosition 才有有效值
    task.spawn(function()
        RunService.Heartbeat:Wait()

        -- 钞票图标 → 飞向 MoneyBar（绿色钱条）
        local moneyCenter = getBarCenter("SnakeMoneyBar", 71, 71)
        -- 蛇身长图标 → 飞向 ScoreBar（蓝色长度条）
        local scoreCenter = getBarCenter("SnakeScoreBar", 71, 31)

        -- startOffX/Y：图标的出发点相对蛇头的偏移，让两条轨迹从起点就分叉
        local function spawnFlyIcon(assetId, targetPos, startOffX, startOffY)
            startOffX = startOffX or 0
            startOffY = startOffY or 0
            local img = Instance.new("ImageLabel")
            img.Size                   = UDim2.new(0, 32, 0, 32)
            img.Position               = UDim2.new(0, sx - 16 + startOffX, 0, sy - 16 + startOffY)
            img.BackgroundTransparency = 1
            img.Image                  = assetId
            img.ZIndex                 = 250
            img.Parent                 = gui

            -- 飞行：Quad In（越来越快冲向目标）
            local duration = 0.7
            TweenService:Create(img,
                TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                { Position = UDim2.new(0, targetPos.X - 16, 0, targetPos.Y - 16) }
            ):Play()
            -- 后半段才开始淡出（前半段完整可见）
            task.delay(duration * 0.5, function()
                if not img.Parent then return end
                TweenService:Create(img,
                    TweenInfo.new(duration * 0.5, Enum.EasingStyle.Linear),
                    { ImageTransparency = 1 }
                ):Play()
            end)

            task.delay(duration + 0.1, function()
                if img and img.Parent then img:Destroy() end
            end)
        end

        -- 🐍 蛇图标：从蛇头偏上出发 → 飞向长度条（ScoreBar，上方）
        spawnFlyIcon("rbxassetid://89074978607958",  scoreCenter, -20, -28)
        -- 💵 钞票图标：从蛇头偏下出发 → 飞向金钱条（MoneyBar，下方）
        spawnFlyIcon("rbxassetid://105300168575798", moneyCenter,  20,  28)

        -- 音效
        local s = getEatSound()
        if s then s:Play() end
    end)
end

function SnakeGameUI.Start()
    -- 预加载礼物图标，确保显示时不出现空白
    task.spawn(function()
        pcall(function()
            ContentProvider:PreloadAsync({ "rbxassetid://139988932455302" })
        end)
    end)

    local PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    if PlayerGui:FindFirstChild("SnakeGameUI") then PlayerGui.SnakeGameUI:Destroy() end
    gui = Instance.new("ScreenGui")
    gui.Name = "SnakeGameUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.IgnoreGuiInset = true
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
