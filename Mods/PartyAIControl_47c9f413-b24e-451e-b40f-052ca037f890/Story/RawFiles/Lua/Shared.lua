AIManager = {
	Vars = {
		Status = "LLPARTYAI_AI_CONTROL",
		EnabledTag = "LLPARTYAI_Enabled",
		EnabledSummonTag = "LLPARTYAI_Summons_Enabled",
	}
}

Mods.LeaderLib.Import(Mods.LLPartyAIControl)

---@return ModSettings
function GetSettings()
	return SettingsManager.GetMod(ModuleUUID, true, true)
end

local _ISCLIENT = Ext.IsClient()

---@param profile? Guid
function LLPARTYAI_Settings_ClearAllTags(profile)
	if _ISCLIENT then
		GameHelpers.Net.PostMessageToServer("LLPARTYAI_Settings_ClearAllTags", {Profile=Client.Profile})
	else
		for player in GameHelpers.Character.GetPlayers() do
			if not profile or Osi.GetUserProfileID(player.ReservedUserID) == profile then
				AIManager.SetControlEnabled(player, false)
				--Clear manual control placed on summons
				if not player:HasTag(AIManager.Vars.EnabledSummonTag) then
					for _,handle in pairs(player.SummonHandles) do
						local summon = GameHelpers.GetObjectFromHandle(handle, "EsvCharacter")
						if summon and GameHelpers.Ext.ObjectIsCharacter(summon) then
							AIManager.SetControlEnabled(summon, false)
						end
					end
				end
			end
		end
	end
end

if not _ISCLIENT then
	GameHelpers.Net.Subscribe("LLPARTYAI_Settings_ClearAllTags", function (e, data)
		LLPARTYAI_Settings_ClearAllTags(data.Profile)
	end)
end