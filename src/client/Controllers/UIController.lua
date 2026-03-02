local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Common.Knit)

local UIController = Knit.CreateController { Name = "UIController" }

function UIController:KnitStart()
    -- UI is now handled by SnakeGameController
end

function UIController:KnitInit()
end

return UIController
