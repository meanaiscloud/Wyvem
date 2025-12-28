# Roblox Admin Panel

This folder contains Lua scripts for a Roblox Studio admin panel with 200+ commands, an AI-assisted helper, and a black/blue themed UI. Each script is separated so you can drop them into ReplicatedStorage/ServerScriptService/StarterPlayerScripts as needed.

## Files
- `AIConfig.lua`: Configuration for external AI text generation used for suggestions and smart replies.
- `AdminCommands.lua`: ModuleScript defining 200+ admin commands with metadata and execution logic.
- `ServerAdminController.lua`: ServerScript that wires commands, AI integration, and RemoteEvents.
- `LocalAdminPanel.lua`: LocalScript that renders the UI (black/blue aesthetic) and sends requests to the server.

## Installation (Roblox Studio)
1. Create a folder in **ReplicatedStorage** called `AdminPanel` and upload the four scripts there as ModuleScripts/LocalScripts as appropriate.
2. Place `ServerAdminController` as a **ServerScript** inside **ServerScriptService** and require `AdminCommands` and `AIConfig` from `ReplicatedStorage.AdminPanel`.
3. Place `LocalAdminPanel` as a **LocalScript** inside **StarterPlayerScripts** (or StarterGui) and adjust the references to your preferred `RemoteEvent` and `RemoteFunction` locations.
4. Create two networking objects in **ReplicatedStorage**:
   - `AdminCommandRequest` (RemoteEvent)
   - `AdminCommandResult` (RemoteEvent)
5. Add your OpenAI (or other provider) key in `AIConfig.lua`. The script uses HttpService; make sure **Enable Studio Access to API Services** is turned on.
6. Press Play. The UI toggles with the **Right Control** key and supports search, categorized commands, and AI-assisted input.

## Notes
- All commands check admin status server-side to avoid exploitation.
- Commands are structured to be easy to extend; add to the `baseCommands` table or the generated leaderstat/attribute commands.
- The design favors performance and uses lazy UI creation where possible; feel free to swap fonts or add icons.
- Ensure you set the `ADMIN_USER_IDS` list in `ServerAdminController.lua` to your Roblox account IDs.
