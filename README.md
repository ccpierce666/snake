# Roblox Snake Game Project

This project uses **Rojo**, **Wally**, **Knit**, **ProfileService**, **Iris**, and **Roact**.

## Setup Instructions

Since `wally` and `rojo` commands were not available in the environment, the project structure has been created but dependencies are missing.

1.  **Install Tools:**
    *   Install [Rojo](https://rojo.space/) (VS Code extension + CLI).
    *   Install [Wally](https://wally.run/) (Package manager).

2.  **Install Dependencies:**
    Open a terminal in this folder and run:
    ```bash
    wally install
    ```
    This will download `Knit`, `ProfileService`, `Iris`, `Roact` into a `Packages` folder.

3.  **Sync to Roblox:**
    *   Open Roblox Studio.
    *   Run the Rojo plugin to sync.
    *   This will populate `ServerScriptService` and `StarterPlayerScripts` with the code we wrote.

## Project Structure

*   `src/server`: Server-side code (Knit Services).
    *   `Runtime.server.lua`: Bootstraps Knit.
    *   `Services/PlayerDataService.lua`: Handles player data (Money, Exp).
    *   `Services/GameService.lua`: Main game loop.
*   `src/client`: Client-side code (Knit Controllers).
    *   `Runtime.client.lua`: Bootstraps Knit.
    *   `Controllers/UIController.lua`: Manages UI.
    *   `UI/DebugWindow.lua`: **Iris** example (Immediate Mode UI).
    *   `UI/CoinDisplay.lua`: **Roact** example (Declarative UI).
*   `src/shared`: Shared modules.

## UI Comparison

*   **Iris (`src/client/UI/DebugWindow.lua`):** Used for the debug window. Notice how simple and procedural the code is.
*   **Roact (`src/client/UI/CoinDisplay.lua`):** Used for the coin display. Notice the component structure (`init`, `didMount`, `render`) which is better for complex, state-driven UIs.