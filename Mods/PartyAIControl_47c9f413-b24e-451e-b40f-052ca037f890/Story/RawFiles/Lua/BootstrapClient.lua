Ext.Require("Shared.lua")

local Text = {
	EnableControl = Classes.TranslatedString:CreateFromKey("LLAICONTROL_UI_EnableControl", "Enable AI"),
	DisableControl = Classes.TranslatedString:CreateFromKey("LLAICONTROL_UI_DisableControl", "Disable AI"),
	EnableSummonControl = Classes.TranslatedString:CreateFromKey("LLAICONTROL_UI_EnableSummonControl", "Enable Automatic Summon AI"),
	DisableSummonControl = Classes.TranslatedString:CreateFromKey("LLAICONTROL_UI_DisableSummonControl", "Disable Automatic Summon AI"),
}

local _cursorCharacterHandle = nil

local function _CursorCharacterIsClient()
	local target = GameHelpers.Client.TryGetCursorCharacter()
	if target and target == Client:GetCharacter() then
		return true
	end
	return false
end

local function _CursorCharacterIsPlayer()
	local target = GameHelpers.Client.TryGetCursorCharacter()
	if target and GameHelpers.Character.IsPlayer(target) and not target.GMControl then
		return true
	end
	return false
end

UI.ContextMenu.Register.Action(Classes.ContextMenuAction:Create({
	ID = "LLPartyAIControl_ToggleControl",
	AutomaticallyAddToBuiltin = true,
	DisplayName = Text.EnableControl,
	SortName = Text.EnableControl,
	Icon = "Spawn Point",
	ShouldOpen = _CursorCharacterIsPlayer,
	OnUpdate = function (self)
		_cursorCharacterHandle = nil
		local target = GameHelpers.Client.TryGetCursorCharacter()
		if target then
			_cursorCharacterHandle = target.Handle
			if target:HasTag(AIManager.Vars.EnabledTag) then
				self.DisplayName = Text.DisableControl
				self.Icon = "Spawn Point_a"
			else
				self.DisplayName = Text.EnableControl
				self.Icon = "Spawn Point"
			end
		end
	end,
	Callback = function (cm, ui, id, actionID, handle, entry)
		if _cursorCharacterHandle then
			local target = GameHelpers.GetCharacter(_cursorCharacterHandle)
			if target then
				GameHelpers.Net.PostMessageToServer("LLPARTYAI_SetAIEnabled", {NetID=target.NetID, Enabled=not target:HasTag(AIManager.Vars.EnabledTag)})
			end
		end
	end
}))

UI.ContextMenu.Register.Action(Classes.ContextMenuAction:Create({
	ID = "LLPartyAIControl_ToggleSummonControl",
	AutomaticallyAddToBuiltin = true,
	DisplayName = Text.EnableSummonControl,
	SortName = Text.EnableSummonControl,
	Icon = "Monsters manager",
	ShouldOpen = _CursorCharacterIsClient,
	OnUpdate = function (self)
		_cursorCharacterHandle = nil
		local target = GameHelpers.Client.TryGetCursorCharacter()
		if target then
			_cursorCharacterHandle = target.Handle
			if target:HasTag(AIManager.Vars.EnabledSummonTag) then
				self.DisplayName = Text.DisableSummonControl
				self.Icon = "Monsters manager_a"
			else
				self.DisplayName = Text.EnableSummonControl
				self.Icon = "Monsters manager"
			end
		end
	end,
	Callback = function (cm, ui, id, actionID, handle, entry)
		if _cursorCharacterHandle then
			local target = GameHelpers.GetCharacter(_cursorCharacterHandle)
			if target then
				GameHelpers.Net.PostMessageToServer("LLPARTYAI_SetAISummonsEnabled", {NetID=target.NetID, Enabled=not target:HasTag(AIManager.Vars.EnabledSummonTag)})
			end
		end
	end
}))

Ext.RegisterNetListener("LLPARTYAI_SetArchetype", function (channel, payload, user)
	local data = Ext.Json.Parse(payload)
	local target = GameHelpers.GetCharacter(data.NetID)
	if target then
		---@cast target EclCharacter
		target.Archetype = data.Archetype
	end
end)