Ext.Require("Shared.lua")

---@param target EsvCharacter
---@param enabled boolean
function AIManager.OverrideArchetype(target, enabled)
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
---@param skipUpdateStatus boolean|nil
function AIManager.SetControlEnabled(target, enabled, skipUpdateStatus)
	if enabled then
		Osi.SetTag(target.MyGuid, AIManager.Vars.EnabledTag)
	else
		Osi.ClearTag(target.MyGuid, AIManager.Vars.EnabledTag)
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

Ext.RegisterNetListener("LLPARTYAI_SetAIEnabled", function (channel, payload, user)
	local data = Ext.Json.Parse(payload)
	local target = GameHelpers.GetCharacter(data.NetID)
	AIManager.SetControlEnabled(target, data.Enabled == true)
end)

Ext.RegisterNetListener("LLPARTYAI_SetAISummonsEnabled", function (channel, payload, user)
	local data = Ext.Json.Parse(payload)
	local target = GameHelpers.GetCharacter(data.NetID, "EsvCharacter")
	if data.Enabled then
		Osi.SetTag(target.MyGuid, AIManager.Vars.EnabledSummonTag)
	else
		Osi.ClearTag(target.MyGuid, AIManager.Vars.EnabledSummonTag)
		for summon in GameHelpers.Character.GetSummons(target) do
			AIManager.SetControlEnabled(summon, false)
		end
	end
end)

--Limit AI party member consumeable usage to 1 per turn, and the item must be in their inventory
Events.Osiris.ProcBlockUseOfItem:Subscribe(function (e)
	if e.Character:HasTag(AIManager.Vars.EnabledTag) then
		if GameHelpers.Item.IsConsumable(e.Item) then
			if e.Character.NumConsumables > 0 then
				return e:PreventAction()
			end
			local owner = GameHelpers.Item.GetOwner(e.Item)
			if owner and owner ~= e.Character then
				return e:PreventAction()
			end
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
	if e.Owner:HasTag(AIManager.Vars.EnabledSummonTag) then
		AIManager.SetControlEnabled(e.Summon, true)
	end
end, {MatchArgs={IsDying=false, IsItem=false}})