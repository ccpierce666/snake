local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Load libraries with fallback
local function GetModule(name)
    if ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild(name) then
        return require(ReplicatedStorage.Packages[name])
    else
        return require(ReplicatedStorage.Common[name])
    end
end

local Knit = GetModule("Knit")
local ProfileService = GetModule("ProfileService")

-- Define the default data structure
local ProfileTemplate = {
    Money = 0,
    Exp = 0,
    Items = {},
}

local ProfileStore = ProfileService.GetProfileStore(
    "PlayerData",
    ProfileTemplate
)

local PlayerDataService = Knit.CreateService {
    Name = "PlayerDataService",
    Client = {
        MoneyChanged = Knit.CreateSignal(),
    },
}

local Profiles = {}

function PlayerDataService:GetMoney(player)
    local profile = Profiles[player]
    if profile then
        return profile.Data.Money
    end
    return 0
end

function PlayerDataService.Client:GetMoney(player)
    return self.Server:GetMoney(player)
end

function PlayerDataService:AddMoney(player, amount)
    local profile = Profiles[player]
    if profile then
        profile.Data.Money = profile.Data.Money + amount
        self.Client.MoneyChanged:Fire(player, profile.Data.Money)
    end
end

local function PlayerAdded(player)
    local profile = ProfileStore:LoadProfileAsync("Player_" .. player.UserId)
    if profile ~= nil then
        profile:AddUserId(player.UserId)
        profile:Reconcile()
        
        profile:ListenToRelease(function()
            Profiles[player] = nil
            player:Kick()
        end)
        
        if player:IsDescendantOf(Players) then
            Profiles[player] = profile
        else
            profile:Release()
        end
    else
        player:Kick()
    end
end

function PlayerDataService:KnitInit()
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(PlayerAdded, player)
    end
    
    Players.PlayerAdded:Connect(PlayerAdded)
    
    Players.PlayerRemoving:Connect(function(player)
        local profile = Profiles[player]
        if profile then
            profile:Release()
        end
    end)
end

return PlayerDataService