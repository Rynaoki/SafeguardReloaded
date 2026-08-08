Safeguard_MessageManager = {
  -- Deliberately kept as "Safeguard" so group members still running the original
  -- addon can exchange messages with SafeguardReloaded users.
  AddonMessagePrefix = "Safeguard",
  SentMessageTimestamps = {},
}

local MM = Safeguard_MessageManager

local Compat = SafeguardReloaded_Compat

local CHAT_PREFIX = Compat.ChatPrefix

function MM:OnChatMessageAddonEvent(prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID)
  if (prefix ~= self.AddonMessagePrefix) then return end
  --print("OnChatMessageAddonEvent. " .. tostring(prefix) ..  ", " .. tostring(text) ..  ", " .. tostring(channel) ..  ", " .. tostring(sender) ..  ", " .. tostring(target) ..  ", " .. tostring(zoneChannelID) ..  ", " .. tostring(localID) ..  ", " .. tostring(name) ..  ", " .. tostring(instanceID) ..  ".")
  --print(string.format("%d - ReceivedMessage: %s, %s", time(), text,  sender))
  table.insert(Safeguard_EventManager.DebugLogs, string.format("%d - ReceivedMessage: %s, %s", time(), text,  sender))

  if (channel ~= "WHISPER" and channel ~= "PARTY" and channel ~= "RAID" and channel ~= "INSTANCE_CHAT") then return end

  local senderPlayer, senderRealm = strsplit("-", sender, 2)
  local senderUnitId, senderGuid = UnitHelperFunctions.FindUnitIdAndGuidByUnitName(senderPlayer)

  if (not senderUnitId or not senderGuid) then
    table.insert(Safeguard_EventManager.DebugLogs, string.format("%d - Failed to find UnitId or Guid for message sender: %s", time(), senderPlayer))
    return
  end

  local shouldUpdateRaidFrames = false
  if (not Safeguard_PlayerStates[senderGuid]) then
    local connectionInfo = ConnectionInfo.New(true, GetTime())
    Safeguard_PlayerStates[senderGuid] = PlayerState.New(connectionInfo, nil)
    shouldUpdateRaidFrames = true
  elseif (not Safeguard_PlayerStates[senderGuid].ConnectionInfo) then
    Safeguard_PlayerStates[senderGuid].ConnectionInfo = ConnectionInfo.New(true, GetTime())
    shouldUpdateRaidFrames = true
  else
    if (not Safeguard_PlayerStates[senderGuid].ConnectionInfo.IsConnected) then
      Safeguard_NotificationManager:ShowNotificationToPlayer(UnitName("player"), SgEnum.NotificationType.PlayerReconnected, senderGuid)
      shouldUpdateRaidFrames = true

      if (senderUnitId == "player") then -- If the player was disconnected, act like all other players in the group had been connected the whole time.
        for k,v in pairs(Safeguard_PlayerStates) do
          if (v.ConnectionInfo) then
            v.ConnectionInfo.LastMessageTimestamp = GetTime()
          end
        end
      end
    end

    Safeguard_PlayerStates[senderGuid].ConnectionInfo.IsConnected = true
    Safeguard_PlayerStates[senderGuid].ConnectionInfo.LastMessageTimestamp = GetTime()
  end

  local addonMessageType, arg1, arg2 = strsplit("!", text, 3)
  addonMessageType = tonumber(addonMessageType)

  if (addonMessageType == SgEnum.AddonMessageType.Heartbeat) then
    local isInCombat = Safeguard_HelperFunctions.NumberToBool(tonumber(arg1))
    shouldUpdateRaidFrames = shouldUpdateRaidFrames or Safeguard_PlayerStates[senderGuid].IsInCombat ~= isInCombat
    Safeguard_PlayerStates[senderGuid].IsInCombat = isInCombat
  elseif (addonMessageType == SgEnum.AddonMessageType.EnteredCombat) then
    shouldUpdateRaidFrames = shouldUpdateRaidFrames or Safeguard_PlayerStates[senderGuid].IsInCombat ~= true
    Safeguard_PlayerStates[senderGuid].IsInCombat = true
  elseif (addonMessageType == SgEnum.AddonMessageType.ExitedCombat) then
    shouldUpdateRaidFrames = shouldUpdateRaidFrames or Safeguard_PlayerStates[senderGuid].IsInCombat ~= false
    Safeguard_PlayerStates[senderGuid].IsInCombat = false
  elseif (addonMessageType == SgEnum.AddonMessageType.PlayerConnectionCheck) then
    if (arg1 == UnitGUID("player")) then
      self:SendHeartbeatMessage()
    end

    C_Timer.After(1, function()
      Safeguard_IntervalManager:CheckPlayerConnectionAndMarkIfDisconnected(arg1)
    end)
  end

  if (shouldUpdateRaidFrames) then
    Safeguard_RaidFramesManager:UpdateRaidFrames()
  end
  
  if(senderUnitId == "player" or UnitInRaid("player")) then return end

  local notificationType = Safeguard_NotificationManager:ConvertAddonMessageTypeToNotificationType(addonMessageType)
  if (notificationType) then
    Safeguard_NotificationManager:ShowNotificationToPlayer(senderPlayer, notificationType, arg1, arg2)
  end
end

function MM:SendMessageToGroup(addonMessageType, arg1, arg2)
  local addonMessage = tostring(addonMessageType)
  if (arg2 ~= nil) then
    addonMessage = string.format("%s!%s!%s", addonMessageType, arg1, arg2)
  elseif (arg1 ~= nil) then
    addonMessage = string.format("%s!%s", addonMessageType, arg1)
  end

  local nowTimestamp = GetTime()
  if (self.SentMessageTimestamps[addonMessage] and nowTimestamp - self.SentMessageTimestamps[addonMessage] < 1) then return end
  self.SentMessageTimestamps[addonMessage] = nowTimestamp

  -- Sending to the wrong channel silently drops the message, so resolve the channel
  -- the player is actually in rather than always assuming PARTY/RAID.
  local groupChannel = Compat.GetGroupChatChannel()

  local addonMessageChatType = "WHISPER"
  if (groupChannel) then
    if (Safeguard_Settings.Options.EnableChatMessages) then
      local chatMessage = self:ConvertAddonMessageToChatMessage(addonMessageType, arg1, arg2)
      if (chatMessage) then SendChatMessage(CHAT_PREFIX .. chatMessage, groupChannel) end
    end

    addonMessageChatType = groupChannel
  end

  if (addonMessageType == SgEnum.AddonMessageType.HealthCriticallyLow or
      addonMessageType == SgEnum.AddonMessageType.HealthLow or
      addonMessageType == SgEnum.AddonMessageType.ExtraAttacksStored) then
    -- Other players with the addon can detect these events independently.
    return
  end

  local target = nil
  if (addonMessageChatType == "WHISPER") then target = UnitName("player") end

  --print(string.format("%d - SendMessage: %s", time(), addonMessage))
  table.insert(Safeguard_EventManager.DebugLogs, string.format("%d - SendMessage: %s", time(), addonMessage))

  -- Note: I tried using ChatThrottleLib but messages were more likely to not be sent. I tested C_ChatInfo.SendAddonMessage with many messages and have found that 
  -- if messages are sent too quickly then they won't be sent, but the player won't be disconnected.
  C_ChatInfo.SendAddonMessage(MM.AddonMessagePrefix, addonMessage, addonMessageChatType, target)
end

--

function MM:ConvertAddonMessageToChatMessage(addonMessageType, arg1, arg2)
  if (addonMessageType == SgEnum.AddonMessageType.LoggingOut and Safeguard_Settings.Options.EnableChatMessagesLogout) then
    return "I am logging out."
  end

  if (addonMessageType == SgEnum.AddonMessageType.LogoutCancelled and Safeguard_Settings.Options.EnableChatMessagesLogout) then
    return "I have stopped logging out."
  end

  if (addonMessageType == SgEnum.AddonMessageType.LossOfControl and Safeguard_Settings.Options.EnableChatMessagesLossOfControl) then
    local locTypeText = Safeguard_NotificationManager:ConvertLossOfControlTypeToText(tonumber(arg1))
    
    if (arg2 ~= nil) then
      return string.format("I am %s for %ds.", locTypeText, arg2)
    else
      return string.format("I am %s.", locTypeText)
    end
  end

  if (addonMessageType == SgEnum.AddonMessageType.HealthCriticallyLow and Safeguard_Settings.Options.EnableChatMessagesLowHealth) then
    return string.format("Help, my health is at %d%%!", arg1)
  end

  if (addonMessageType == SgEnum.AddonMessageType.SpellCastStarted and Safeguard_Settings.Options.EnableChatMessagesSpellCasts) then
    return string.format("I am casting %s.", arg1)
  end

  if (addonMessageType == SgEnum.AddonMessageType.SpellCastInterrupted and Safeguard_Settings.Options.EnableChatMessagesSpellCasts) then
    return string.format("My %s cast has been stopped.", arg1)
  end

  if (addonMessageType == SgEnum.AddonMessageType.ExtraAttacksStored and Safeguard_Settings.Options.EnableChatMessagesExtraAttacksStored) then
    return string.format("%s has %d extra attacks stored.", arg1, arg2)
  end

  return nil
end

function MM:SendHeartbeatMessage()
  self:SendMessageToGroup(SgEnum.AddonMessageType.Heartbeat, Safeguard_HelperFunctions.BoolToNumber(UnitAffectingCombat("player")))
end