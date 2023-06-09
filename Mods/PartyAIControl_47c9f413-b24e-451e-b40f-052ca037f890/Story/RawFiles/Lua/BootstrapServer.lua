Ext.Require("Shared.lua")

---@param target EsvCharacter
---@param enabled boolean
function AIManager.OverrideArchetype(target, enabled)
	if GetSettings().Global:FlagEquals("LLPARTYAI_ChangeArchetypeDisabled", true) then
		return
	end
	local archetype = "base"
	if enabled then
		archetype = "partyai"
	else
		local last = Osi.GetVarFixedString(target.MyGuid, "LLPARTYAI_LastArchetype")
		if not StringHelpers.IsNullOrEmpty(last) then
			archetype = last
			Osi.ClearVarObject(target.MyGuid, "LLPARTYAI_LastArchetype")
		end
	end
	if target.Archetype ~= archetype then
		Osi.SetVarFixedString(target.MyGuid, "LLPARTYAI_LastArchetype", target.Archetype)
		target.Archetype = archetype
		GameHelpers.Net.Broadcast("LLPARTYAI_SetArchetype", {NetID=target.NetID, Archetype=archetype})
	end
end

---@param target EsvCharacter
---@param enabled boolean
---@param skipUpdateStatus? boolean
---@param skipStatusText? boolean
function AIManager.SetControlEnabled(target, enabled, skipUpdateStatus, skipStatusText)
	if enabled then
		local displayStatusText = not skipStatusText and not target:HasTag(AIManager.Vars.EnabledTag)
		Osi.SetTag(target.MyGuid, AIManager.Vars.EnabledTag)
		if displayStatusText then
			Osi.CharacterStatusText(target.MyGuid, "LLPARTYAI_StatusText_Enabled")
		end
	else
		local displayStatusText = not skipStatusText and target:HasTag(AIManager.Vars.EnabledTag)
		Osi.ClearTag(target.MyGuid, AIManager.Vars.EnabledTag)
		if displayStatusText then
			Osi.CharacterStatusText(target.MyGuid, "LLPARTYAI_StatusText_Disabled")
		end
	end
	AIManager.OverrideArchetype(target, enabled)
	if not skipUpdateStatus then
		AIManager.UpdateStatus(target, enabled)
	end
end

---@param target EsvCharacter
---@param isEnabled boolean|nil
function AIManager.UpdateStatus(target, isEnabled)
	if isEnabled == nil then
		isEnabled = target:HasTag(AIManager.Vars.EnabledTag)
	end
	local hasStatus = target:GetStatus(AIManager.Vars.Status)
	if GameHelpers.Character.IsInCombat(target) and isEnabled then
		if not hasStatus then
			GameHelpers.Status.Apply(target, AIManager.Vars.Status, -1, true, target)
		end
	elseif hasStatus then
		GameHelpers.Status.Remove(target, AIManager.Vars.Status)
	end
end

---@param target EsvCharacter
---@param enabled boolean
---@param skipStatusText? boolean
function AIManager.SetSummonControlEnabled(target, enabled, skipStatusText)
	if enabled then
		local displayStatusText = not skipStatusText and not target:HasTag(AIManager.Vars.EnabledSummonTag)
		Osi.SetTag(target.MyGuid, AIManager.Vars.EnabledSummonTag)
		if displayStatusText then
			Osi.CharacterStatusText(target.MyGuid, "LLPARTYAI_StatusText_SummonsEnabled")
		end
	else
		local displayStatusText = not skipStatusText and target:HasTag(AIManager.Vars.EnabledSummonTag)
		Osi.ClearTag(target.MyGuid, AIManager.Vars.EnabledSummonTag)
		if displayStatusText then
			Osi.CharacterStatusText(target.MyGuid, "LLPARTYAI_StatusText_SummonsDisabled")
		end
	end
end

---@class LLPARTYAI_SetAIEnabled
---@field NetID NetId
---@field Enabled boolean

GameHelpers.Net.Subscribe("LLPARTYAI_SetAIEnabled", function (e, data)
	local target = GameHelpers.GetCharacter(data.NetID)
	assert(target ~= nil, "Failed to get character")
	AIManager.SetControlEnabled(target, data.Enabled == true)
end)

---@class LLPARTYAI_SetAISummonsEnabled
---@field NetID NetId
---@field Enabled boolean

GameHelpers.Net.Subscribe("LLPARTYAI_SetAISummonsEnabled", function (e, data)
	local target = GameHelpers.GetCharacter(data.NetID, "EsvCharacter")
	assert(target ~= nil, "Failed to get character")
	AIManager.SetSummonControlEnabled(target, data.Enabled == true)
end)

--Limit AI party member consumeable usage to 1 per turn, and the item must be in their inventory
Events.Osiris.ProcBlockUseOfItem:Subscribe(function (e)
	if not e.Character.CharacterControl and e.Character:GetStatus(AIManager.Vars.Status) and GameHelpers.Combat.IsActiveTurn(e.Character) then
		local settings = GetSettings()
		if settings.Global:FlagEquals("LLPARTYAI_LimitConsumableUsageDisabled", true) then
			return
		end
		local limit = settings.Global:GetVariable("ConsumableLimit", 1)
		if limit > 0 then
			if GameHelpers.Item.IsConsumable(e.Item) then
				if e.Character.NumConsumables >= limit then
					return e:PreventAction()
				end
				--Prevent magic pockets
				if settings.Global:FlagEquals("LLPARTYAI_BlockMagicPocketsConsumables", true) then
					local owner = GameHelpers.Item.GetOwner(e.Item)
					if owner and owner ~= e.Character then
						return e:PreventAction()
					end
				end
			end
		else
			return e:PreventAction()
		end
	end
end)

Events.Osiris.ObjectEnteredCombat:Subscribe(function (e)
	if e.Object:HasTag(AIManager.Vars.EnabledTag) then
		AIManager.UpdateStatus(e.Object, true)
	end
end, {MatchArgs={ObjectType="Character"}})

Events.Osiris.ObjectLeftCombat:Subscribe(function (e)
	if e.Object:HasTag(AIManager.Vars.EnabledTag) then
		AIManager.UpdateStatus(e.Object, false)
	end
end, {MatchArgs={ObjectType="Character"}})

Events.Osiris.ObjectWasTagged:Subscribe(function (e)
	for summon in GameHelpers.Character.GetSummons(e.Object) do
		AIManager.SetControlEnabled(summon, true)
	end
end, {MatchArgs={Tag=AIManager.Vars.EnabledSummonTag, ObjectType="Character"}})

Events.Osiris.ObjectLostTag:Subscribe(function (e)
	for summon in GameHelpers.Character.GetSummons(e.Object) do
		AIManager.SetControlEnabled(summon, false)
	end
end, {MatchArgs={Tag=AIManager.Vars.EnabledSummonTag, ObjectType="Character"}})

Events.SummonChanged:Subscribe(function (e)
	if not e.Summon:HasTag("TOTEM") and e.Owner and e.Owner:HasTag(AIManager.Vars.EnabledSummonTag) then
		AIManager.SetControlEnabled(e.Summon, true)
	end
end, {MatchArgs={IsDying=false, IsItem=false}})