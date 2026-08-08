Safeguard_NotificationManager = {
  ShownNotificationTimestamps = {},
}

local NM = Safeguard_NotificationManager

local Compat = SafeguardReloaded_Compat

function NM:ShowNotificationToPlayer(playerWhoNotified, notificationType, arg1, arg2)
  if (not Safeguard_Settings.Options.EnableTextNotifications) then return end

  local notification = self:GetNotification(playerWhoNotified, notificationType, arg1, arg2)
  if (not notification) then
    return
  end

  local notificationKey = nil
  if (arg2 ~= nil) then
    notificationKey = string.format("%s!%d!%s!%s", playerWhoNotified, notificationType, arg1, arg2)
  elseif (arg1 ~= nil) then
    notificationKey = string.format("%s!%d!%s", playerWhoNotified, notificationType, arg1)
  else
    notificationKey = string.format("%s!%d", playerWhoNotified, notificationType)
  end

  local nowTimestamp = GetTime()
  if (self.ShownNotificationTimestamps[notificationKey] and nowTimestamp - self.ShownNotificationTimestamps[notificationKey] < 1) then return end
  self.ShownNotificationTimestamps[notificationKey] = nowTimestamp

  local r = 1.000
  local g = 1.000
  local b = 1.000
  UIErrorsFrame:AddMessage(notification, r, g, b)
  --print("[Safeguard] " .. notification)
  table.insert(Safeguard_EventManager.DebugLogs, string.format("%d - Notification: %s", time(), notification))
end

function NM:GetNotification(playerWhoNotified, notificationType, arg1, arg2)
  if (notificationType == SgEnum.NotificationType.PlayerDisconnected) then
    local prefix
    if (arg1 == UnitGUID("player")) then
      if (not Safeguard_Settings.Options.EnableTextNotificationsConnectionSelf) then
        return nil
      end

      prefix = "You have"
    else
      if (not Safeguard_Settings.Options.EnableTextNotificationsConnectionGroup) then
        return nil
      end

      prefix = string.format("%s has", UnitHelperFunctions.FindUnitNameByUnitGuid(arg1))
    end

    return string.format("%s disconnected.", prefix)
  end

  if (notificationType == SgEnum.NotificationType.PlayerReconnected) then
    local prefix
    if (arg1 == UnitGUID("player")) then
      if (not Safeguard_Settings.Options.EnableTextNotificationsConnectionSelf) then
        return nil
      end

      prefix = "You have"
    else
      if (not Safeguard_Settings.Options.EnableTextNotificationsConnectionGroup) then
        return nil
      end

      prefix = string.format("%s has", UnitHelperFunctions.FindUnitNameByUnitGuid(arg1))
    end

    return string.format("%s reconnected.", prefix)
  end

  if (notificationType == SgEnum.NotificationType.PlayerOffline) then
    if (not Safeguard_Settings.Options.EnableTextNotificationsConnectionGroup) then
      return nil
    end

    return string.format("%s has gone offline.", UnitHelperFunctions.FindUnitNameByUnitGuid(arg1))
  end

  if (notificationType == SgEnum.NotificationType.EnteredCombat) then
    local prefix
    if (playerWhoNotified == UnitName("player")) then
      if (not Safeguard_Settings.Options.EnableTextNotificationsCombatSelf) then
        return nil
      end

      prefix = "You"
    else
      if (not Safeguard_Settings.Options.EnableTextNotificationsCombatGroup or UnitInRaid("player")) then
        return nil
      end

      prefix = string.format("%s", playerWhoNotified)
    end

    return string.format("%s entered combat.", prefix)
  end

  if (notificationType == SgEnum.NotificationType.LoggingOut) then
    if (not Safeguard_Settings.Options.EnableTextNotificationsLogout or UnitInRaid("player")) then
      return nil
    end

    return string.format("%s is logging out.", playerWhoNotified)
  end

  if (notificationType == SgEnum.NotificationType.LogoutCancelled) then
    if (not Safeguard_Settings.Options.EnableTextNotificationsLogout or UnitInRaid("player")) then
      return nil
    end

    return string.format("%s has stopped logging out.", playerWhoNotified)
  end

  if (notificationType == SgEnum.NotificationType.LossOfControl) then
    local prefix
    if (playerWhoNotified == UnitName("player")) then
      if (not Safeguard_Settings.Options.EnableTextNotificationsLossOfControlSelf) then
        return nil
      end

      prefix = "You are"
    else
      if (not Safeguard_Settings.Options.EnableTextNotificationsLossOfControlGroup or UnitInRaid("player")) then
        return nil
      end

      prefix = string.format("%s is", playerWhoNotified)
    end

    local locTypeText = self:ConvertLossOfControlTypeToText(tonumber(arg1))
    if (arg2 ~= nil) then
      return string.format("%s %s for %ds.", prefix, locTypeText, arg2)
    else
      return string.format("%s %s.", prefix, locTypeText)
    end
  end

  if (notificationType == SgEnum.NotificationType.HealthLow) then
    local prefix
    if (playerWhoNotified == UnitName("player")) then 
      if (not Safeguard_Settings.Options.EnableTextNotificationsLowHealthSelf) then
        return nil
      end

      prefix = "Your"
    else
      if (not Safeguard_Settings.Options.EnableTextNotificationsLowHealthGroup or UnitInRaid("player")) then
        return nil
      end

      prefix = string.format("%s's", playerWhoNotified)
    end

    return string.format("%s health is low.", prefix)
  end

  if (notificationType == SgEnum.NotificationType.HealthCriticallyLow) then
    local prefix
    if (playerWhoNotified == UnitName("player")) then
      if (not Safeguard_Settings.Options.EnableTextNotificationsLowHealthSelf) then
        return nil
      end

      prefix = "Your"
    else
      if (not Safeguard_Settings.Options.EnableTextNotificationsLowHealthGroup or UnitInRaid("player")) then
        return nil
      end

      prefix = string.format("%s's", playerWhoNotified)
    end

    return string.format("%s health is critically low.", prefix)
  end

  if (notificationType == SgEnum.NotificationType.SpellCastStarted) then
    if (not Safeguard_Settings.Options.EnableTextNotificationsSpellcasts or UnitInRaid("player")) then
      return nil
    end

    return string.format("%s is casting %s.", playerWhoNotified, arg1)
  end

  if (notificationType == SgEnum.NotificationType.SpellCastInterrupted) then
    if (not Safeguard_Settings.Options.EnableTextNotificationsSpellcasts or UnitInRaid("player")) then
      return nil
    end

    return string.format("%s's %s cast has been stopped.", playerWhoNotified, arg1)
  end
  
  if (notificationType == SgEnum.NotificationType.AuraApplied) then
    local prefix
    if (playerWhoNotified == UnitName("player")) then
      if (not Safeguard_Settings.Options.EnableTextNotificationsAurasSelf) then
        return nil
      end

      prefix = "You are"
    else
      if (not Safeguard_Settings.Options.EnableTextNotificationsAurasGroup or UnitInRaid("player")) then
        return nil
      end

      prefix = string.format("%s is", playerWhoNotified)
    end

    return string.format("%s affected by %s.", prefix, arg1)
  end

  if (notificationType == SgEnum.NotificationType.PvpFlagged) then
    if (not Safeguard_Settings.Options.EnableTextNotificationsPvpFlagged) then
      return nil
    end

    return string.format("You are now pvp-flagged.")
  end

  if (notificationType == SgEnum.NotificationType.PvpUnflagged) then
    if (not Safeguard_Settings.Options.EnableTextNotificationsPvpFlagged) then
      return nil
    end
    
    return string.format("You are no longer pvp-flagged.")
  end

  if (notificationType == SgEnum.NotificationType.ExtraAttacksStored) then
    if (not Safeguard_Settings.Options.EnableTextNotificationsExtraAttacksStored) then
      return nil
    end
    
    return string.format("%s has %d extra attacks stored.", arg1, arg2)
  end

  print(Compat.ChatPrefix .. "No notification for notification type " .. tostring(notificationType))
  return nil
end

function NM:ConvertAddonMessageTypeToNotificationType(addonMessageType)
  if (addonMessageType == SgEnum.AddonMessageType.PlayerDisconnected) then
    return SgEnum.NotificationType.PlayerDisconnected
  end
  if (addonMessageType == SgEnum.AddonMessageType.EnteredCombat) then
    return SgEnum.NotificationType.EnteredCombat
  end
  if (addonMessageType == SgEnum.AddonMessageType.LoggingOut) then
    return SgEnum.NotificationType.LoggingOut
  end
  if (addonMessageType == SgEnum.AddonMessageType.LogoutCancelled) then
    return SgEnum.NotificationType.LogoutCancelled
  end
  if (addonMessageType == SgEnum.AddonMessageType.LossOfControl) then
    return SgEnum.NotificationType.LossOfControl
  end
  if (addonMessageType == SgEnum.AddonMessageType.HealthLow) then
    return SgEnum.NotificationType.HealthLow
  end
  if (addonMessageType == SgEnum.AddonMessageType.HealthCriticallyLow) then
    return SgEnum.NotificationType.HealthCriticallyLow
  end
  if (addonMessageType == SgEnum.AddonMessageType.SpellCastStarted) then
    return SgEnum.NotificationType.SpellCastStarted
  end
  if (addonMessageType == SgEnum.AddonMessageType.SpellCastInterrupted) then
    return SgEnum.NotificationType.SpellCastInterrupted
  end

  return nil
end

function NM:ConvertLossOfControlTypeToText(lossOfControlType)
  if (lossOfControlType == SgEnum.LossOfControlType.Confuse) then
    return "confused"
  elseif (lossOfControlType == SgEnum.LossOfControlType.Disarm) then
    return "disarmed"
  elseif (lossOfControlType == SgEnum.LossOfControlType.FearMechanic) then
    return "feared"
  elseif (lossOfControlType == SgEnum.LossOfControlType.Root) then
    return "immobilized"
  elseif (lossOfControlType == SgEnum.LossOfControlType.SchoolInterrupt) then
    return "partially silenced"
  elseif (lossOfControlType == SgEnum.LossOfControlType.Silence) then
    return "silenced"
  elseif (lossOfControlType == SgEnum.LossOfControlType.Stun) then
    return "stunned"
  elseif (lossOfControlType == SgEnum.LossOfControlType.StunMechanic) then
    return "stunned"
  end

  return "crowd controlled"
end