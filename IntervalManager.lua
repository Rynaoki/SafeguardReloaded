Safeguard_IntervalManager = {}

local IM = Safeguard_IntervalManager

local groupUnitIds = { "player" }
for i = 1, 40 do
  if i <= 4 then
    groupUnitIds[#groupUnitIds + 1] = "party" .. i
  end
  groupUnitIds[#groupUnitIds + 1] = "raid" .. i
end

function IM:CheckCombatInterval()
  local shouldUpdateRaidFrames = false
  for i = 1, #groupUnitIds do
    local guid = UnitGUID(groupUnitIds[i])
    if (guid and
        UnitIsConnected(groupUnitIds[i]) and
        (not Safeguard_PlayerStates[guid] or
        not Safeguard_PlayerStates[guid].ConnectionInfo or
        not Safeguard_PlayerStates[guid].ConnectionInfo.IsConnected)) then
      local isInCombat = UnitAffectingCombat(groupUnitIds[i])
      if (not Safeguard_PlayerStates[guid]) then
        Safeguard_PlayerStates[guid] = PlayerState.New(nil, isInCombat)
      else
        if (isInCombat ~= Safeguard_PlayerStates[guid].IsInCombat) then
          shouldUpdateRaidFrames = true

          if (isInCombat) then
            Safeguard_NotificationManager:ShowNotificationToPlayer(UnitName(groupUnitIds[i]), SgEnum.NotificationType.EnteredCombat)
          end
        end

        Safeguard_PlayerStates[guid].IsInCombat = isInCombat
      end
    end
	end

  if (shouldUpdateRaidFrames) then
    Safeguard_RaidFramesManager:UpdateRaidFrames()
  end
  
  C_Timer.After(5, function()
    IM:CheckCombatInterval()
  end)
end

function IM:CheckGroupConnectionsInterval()
  local playerGuid = UnitGUID("player")
  if (Safeguard_PlayerStates[playerGuid] and
      Safeguard_PlayerStates[playerGuid].ConnectionInfo and
      Safeguard_PlayerStates[playerGuid].ConnectionInfo.IsConnected == true) then

    for i = 1, #groupUnitIds do
      local guid = UnitGUID(groupUnitIds[i])
      if (guid and
          not UnitIsConnected(groupUnitIds[i]) and
          Safeguard_PlayerStates[guid]) then
        Safeguard_PlayerStates[guid] = nil
        Safeguard_RaidFramesManager:UpdateRaidFrames()
        Safeguard_NotificationManager:ShowNotificationToPlayer(UnitName("player"), SgEnum.NotificationType.PlayerOffline, guid)
      end

      if (guid and
          Safeguard_PlayerStates[guid] and
          Safeguard_PlayerStates[guid].ConnectionInfo and
          GetTime() - Safeguard_PlayerStates[guid].ConnectionInfo.LastMessageTimestamp > 13 and
          Safeguard_PlayerStates[guid].ConnectionInfo.IsConnected == true) then
        Safeguard_MessageManager:SendMessageToGroup(SgEnum.AddonMessageType.PlayerConnectionCheck, guid)

        if (guid == playerGuid) then
          C_Timer.After(1, function()
            Safeguard_IntervalManager:CheckPlayerConnectionAndMarkIfDisconnected(guid)
          end)
        end
      end
    end
  end

  C_Timer.After(5, function()
    IM:CheckGroupConnectionsInterval()
  end)
end

function IM:CheckPlayerConnectionAndMarkIfDisconnected(guid)
  if (Safeguard_PlayerStates[guid] and
      Safeguard_PlayerStates[guid].ConnectionInfo and
      GetTime() - Safeguard_PlayerStates[guid].ConnectionInfo.LastMessageTimestamp > 14 and
      Safeguard_PlayerStates[guid].ConnectionInfo.IsConnected == true) then
    Safeguard_PlayerStates[guid].ConnectionInfo.IsConnected = false
    Safeguard_RaidFramesManager:UpdateRaidFrames()
    Safeguard_NotificationManager:ShowNotificationToPlayer(UnitName("player"), SgEnum.NotificationType.PlayerDisconnected, guid)
  end
end

function IM:SendHeartbeatInterval()
  local guid = UnitGUID("player")

  local timeSinceLastSentMessage = nil
  if (Safeguard_PlayerStates[guid] and Safeguard_PlayerStates[guid].ConnectionInfo) then
    timeSinceLastSentMessage = GetTime() - Safeguard_PlayerStates[guid].ConnectionInfo.LastMessageTimestamp
  end

  local delay = 10
  if (timeSinceLastSentMessage == nil or timeSinceLastSentMessage >= (10 - 0.01)) then
    Safeguard_MessageManager:SendHeartbeatMessage()
  else
    delay = 10 - timeSinceLastSentMessage
  end
  
  C_Timer.After(delay, function()
    IM:SendHeartbeatInterval()
  end)
end