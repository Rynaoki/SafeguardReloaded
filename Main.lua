Safeguard_Settings = nil

Safeguard_EventManager = {
  DebugLogs = {},
  EventHandlers = {},
  PlayerFlags = {
    Pvp = nil
  },
}

local EM = Safeguard_EventManager

local Compat = SafeguardReloaded_Compat
local IntervalManager = Safeguard_IntervalManager
local MessageManager = Safeguard_MessageManager

local ADDON_NAME = Compat.AddonName
local CHAT_PREFIX = Compat.ChatPrefix

-- Slash Commands

SLASH_SAFEGUARDRELOADED1, SLASH_SAFEGUARDRELOADED2 = "/safeguardreloaded", "/sgr"
SLASH_SAFEGUARDRELOADED3, SLASH_SAFEGUARDRELOADED4 = "/safeguard", "/sg"
function SlashCmdList.SAFEGUARDRELOADED()
  Compat.OpenOptionsPanel(Safeguard_OptionWindow.Category, Safeguard_OptionWindow.name)
end

SLASH_SAFEGUARDRELOADEDDEBUG1, SLASH_SAFEGUARDRELOADEDDEBUG2 = "/safeguardreloadeddebug", "/sgrdebug"
SLASH_SAFEGUARDRELOADEDDEBUG3 = "/sgdebug"
function SlashCmdList.SAFEGUARDRELOADEDDEBUG()
  EM:Debug()
end

SLASH_SAFEGUARDRELOADEDTEST1, SLASH_SAFEGUARDRELOADEDTEST2 = "/safeguardreloadedtest", "/sgrtest"
SLASH_SAFEGUARDRELOADEDTEST3 = "/sgtest"
function SlashCmdList.SAFEGUARDRELOADEDTEST()
  EM:Test()
end

-- Opens the options panel from the minimap addon compartment. Referenced by the .toc.
function SafeguardReloaded_OnAddonCompartmentClick()
  Compat.OpenOptionsPanel(Safeguard_OptionWindow.Category, Safeguard_OptionWindow.name)
end

-- *** Locals ***

-- *** Event Handlers ***

local existingErrorHandler = geterrorhandler()
seterrorhandler(function(message)
  -- Note: This seems to only handle Lua errors, not the ADDON_ACTION_FORBIDDEN event.

  -- Settings are nil until ADDON_LOADED, so errors raised during load fall through
  -- to the default handler rather than erroring inside the error handler.
  if (Safeguard_Settings and Safeguard_Settings.Options.InterceptErrors and
      type(message) == "string" and message:find(ADDON_NAME, 1, true)) then
    print("\124cFFFF0000" .. CHAT_PREFIX .. "Intercepted error, please report this to the addon developer:\n" .. message);
    return
  end

  existingErrorHandler(message)
end)

function EM:OnEvent(_, event, ...)
  if self.EventHandlers[event] then
		self.EventHandlers[event](self, ...)
	end
end

local defaultOptions = {
  EnableChatMessages = true,
  EnableChatMessagesLogout = true,
  EnableChatMessagesLossOfControl = true,
  EnableChatMessagesLowHealth = true,
  EnableChatMessagesSpellCasts = true,
  EnableChatMessagesExtraAttacksStored = true,
  EnableChatMessagesLowMana = true,
  EnableLowHealthAlerts = true,
  -- Off by default: plenty of classes sit at low mana routinely and would rather
  -- not be told about it. Opt in and pick your own threshold.
  EnableLowManaAlerts = false,
  ThresholdForLowMana = 0.20,
  EnableLowHealthAlertScreenFlashing = true,
  EnableLowHealthAlertSounds = true,
  EnableTextNotifications = true,
  EnableTextNotificationsAurasSelf = true,
  EnableTextNotificationsAurasGroup = true,
  EnableTextNotificationsCombatSelf = true,
  EnableTextNotificationsCombatGroup = true,
  EnableTextNotificationsConnectionSelf = true,
  EnableTextNotificationsConnectionGroup = true,
  EnableTextNotificationsLogout = true,
  EnableTextNotificationsLossOfControlSelf = true,
  EnableTextNotificationsLossOfControlGroup = true,
  EnableTextNotificationsLowHealthSelf = true,
  EnableTextNotificationsLowHealthGroup = true,
  EnableTextNotificationsPvpFlagged = true,
  EnableTextNotificationsSpellcasts = true,
  EnableTextNotificationsExtraAttacksStored = true,
  InterceptErrors = true,
  ShowIconsOnRaidFrames = true,
  ShowPvpFlagTimerWindow = false,
  ThresholdForCriticallyLowHealth = 0.30,
  ThresholdForLowHealth = 0.50,
}

function EM.EventHandlers.ADDON_LOADED(self, addonName, ...)
  if (addonName ~= ADDON_NAME) then return end

  local floatingCombatTextIsEnabled = Compat.GetCVar("enableFloatingCombatText") == "1"

  local settings = _G["SAFEGUARDRELOADED_SETTINGS"]
  if (type(settings) ~= "table") then
    -- Carry settings over when the original Safeguard is still installed alongside
    -- this fork, so upgrading players do not start from scratch.
    local legacySettings = _G["SAFEGUARD_SETTINGS"]
    if (type(legacySettings) == "table" and type(legacySettings.Options) == "table") then
      settings = CopyTable(legacySettings)
      print(CHAT_PREFIX .. "Imported your settings from the original Safeguard addon.")
    else
      settings = { Options = {} }
    end

    _G["SAFEGUARDRELOADED_SETTINGS"] = settings
  end

  if (type(settings.Options) ~= "table") then settings.Options = {} end

  for option, defaultValue in pairs(defaultOptions) do
    if (settings.Options[option] == nil) then settings.Options[option] = defaultValue end
  end

  -- Not part of defaultOptions because the default mirrors the player's current cvar.
  if (settings.Options.ForceFloatingCombatText == nil) then
    settings.Options.ForceFloatingCombatText = floatingCombatTextIsEnabled
  end

  Safeguard_Settings = settings

  C_ChatInfo.RegisterAddonMessagePrefix(MessageManager.AddonMessagePrefix)

  Safeguard_OptionWindow:Initialize()
  Safeguard_PvpFlagTimerWindow:Initialize()
  SafeguardReloaded_NotificationFrame:Initialize()
end

function EM.EventHandlers.CHAT_MSG_ADDON(self, prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID)
  MessageManager:OnChatMessageAddonEvent(prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID)
end

-- Spell names in the combat log come through in the client's language, so a table
-- keyed by English names only ever matches on an English client. Resolving the
-- name from a spell id at load time gives the right string on every locale, and
-- because every rank of a spell shares one name, a single id covers all ranks.
--
-- The lookup maps every name the client might report back to the English one. All
-- messages and notifications then use the English name regardless of client
-- language, which keeps a sentence like "My Hearthstone cast has been stopped."
-- in one language and means a group of mixed-locale clients reads the same text.
--
-- The English names are kept as keys too, so an entry whose id cannot be resolved
-- on this client still matches the way it always did. Passing a falsy id is
-- allowed and means "English only" for that spell.
local function BuildSpellNameLookup(entries)
  local lookup = {}

  for englishName, spellId in pairs(entries) do
    lookup[englishName] = englishName

    if (spellId) then
      local localisedName = Compat.GetSpellName(spellId)
      if (localisedName) then lookup[localisedName] = englishName end
    end
  end

  return lookup
end

-- Classic Era spell ids, verified against the Classic database on Wowhead. Where a
-- spell has several ranks any one of them will do, since the lookup only uses the
-- id to read the name and every rank shares it. For consumables the id is the
-- buff that lands on the player, not the spell the item casts, because that is
-- what SPELL_AURA_APPLIED reports.
local AurasToNotify = BuildSpellNameLookup({
  ["Blessing of Protection"] = 1022,
  ["Divine Intervention"] = 19752,
  ["Divine Protection"] = 498,
  ["Divine Shield"] = 642,
  ["Feign Death"] = 5384,
  ["Ice Block"] = 11958,
  ["Invulnerability"] = 3169,  -- from Limited Invulnerability Potion
  ["Light of Elune"] = 6724,
  ["Petrification"] = 17624,   -- from Flask of Petrification
  ["Vanish"] = 1856,
})

local SpellsToNotifyOnCastStart = BuildSpellNameLookup({
  ["Hearthstone"] = 8690,
})

local combatLogHostileEvents = { }
do
    local hostileEventPrefixes = { "RANGE", "SPELL", "SPELL_BUILDING", "SPELL_PERIODIC", "SWING" }
    local hostileEventSuffixes = { "DAMAGE", "DRAIN", "INSTAKILL", "LEECH", "MISSED" }
    for _, prefix in pairs(hostileEventPrefixes) do
        for _, suffix in pairs(hostileEventSuffixes) do
          combatLogHostileEvents[prefix .. "_" .. suffix] = true
        end
    end
end

local knownHostileUnits = {} -- <GUID, _>
local unitsWithExtraAttacksStored = {} -- <GUID, amount>

function EM.EventHandlers.COMBAT_LOG_EVENT_UNFILTERED(self)
  local timestamp, event, hideCaster, sourceGuid, sourceName, sourceFlags, sourceRaidFlags, destGuid, destName, destFlags, destRaidflags = CombatLogGetCurrentEventInfo()
  --print("COMBAT_LOG_EVENT_UNFILTERED. " .. tostring(event))

  if (event == "SPELL_AURA_APPLIED") then
    local spellId, spellName, spellSchool, auraType = select(12, CombatLogGetCurrentEventInfo())
    -- The lookup returns the English name for whatever the client reported, so the
    -- text stays in one language rather than mixing an English sentence with a
    -- translated spell name.
    local watchedSpell = AurasToNotify[spellName]
    if (watchedSpell) then
      Safeguard_NotificationManager:ShowNotificationToPlayer(destName, SgEnum.NotificationType.AuraApplied, watchedSpell)
    end
  elseif (event == "SPELL_CAST_FAILED") then
    -- Note: SPELL_CAST_FAILED events are not triggered for other players' failed spell casts.
    local _, spellName = select(12, CombatLogGetCurrentEventInfo())
    local watchedSpell = SpellsToNotifyOnCastStart[spellName]
    if (watchedSpell) then
      -- GetGroupChatChannel covers party, raid and instance groups; the previous
      -- UnitInParty check was false in a raid, so nothing was ever announced there.
      if (sourceGuid == UnitGUID("player") and Compat.GetGroupChatChannel()) then
        MessageManager:SendMessageToGroup(SgEnum.AddonMessageType.SpellCastInterrupted, watchedSpell)
      end
    end
  elseif (event == "SPELL_CAST_START") then
    local _, spellName = select(12, CombatLogGetCurrentEventInfo())
    local watchedSpell = SpellsToNotifyOnCastStart[spellName]
    if (watchedSpell) then
      -- GetGroupChatChannel covers party, raid and instance groups; the previous
      -- UnitInParty check was false in a raid, so nothing was ever announced there.
      if (sourceGuid == UnitGUID("player") and Compat.GetGroupChatChannel()) then
        MessageManager:SendMessageToGroup(SgEnum.AddonMessageType.SpellCastStarted, watchedSpell)
      end

      if (sourceGuid ~= UnitGUID("player") and UnitHelperFunctions.IsUnitGuidInOurPartyOrRaid(sourceGuid)) then
        Safeguard_NotificationManager:ShowNotificationToPlayer(sourceName, SgEnum.NotificationType.SpellCastStarted, watchedSpell)
      end
    end
  elseif (event == "SPELL_EXTRA_ATTACKS") then
    local spellId, spellName, spellSchool, amount = select(12, CombatLogGetCurrentEventInfo())

    if (not unitsWithExtraAttacksStored[sourceGuid]) then
      unitsWithExtraAttacksStored[sourceGuid] = amount
    else
      unitsWithExtraAttacksStored[sourceGuid] = unitsWithExtraAttacksStored[sourceGuid] + amount
    end

    if (unitsWithExtraAttacksStored[sourceGuid] > 4) then
      unitsWithExtraAttacksStored[sourceGuid] = 4
    else
      C_Timer.After(0.25, function() -- This is on a timer because there is no point in notifying the player if the attacks occur immediately after the enemy stores them.
        EM:CheckToNotifyForExtraAttacks(sourceGuid, sourceName)
      end)
    end
  end

  if (combatLogHostileEvents[event]) then
    local playerGuid = UnitGUID("player")
    if (sourceGuid == playerGuid) then
      knownHostileUnits[destGuid] = true
    elseif (destGuid == playerGuid) then
      knownHostileUnits[sourceGuid] = true
    end
  end

  if (string.match(event, "SWING")) then
    if (unitsWithExtraAttacksStored[sourceGuid]) then
      unitsWithExtraAttacksStored[sourceGuid] = 0
    end
  end
end

local playerWasInParty = false
function EM.EventHandlers.GROUP_ROSTER_UPDATE(self)
  --print("GROUP_ROSTER_UPDATE.")
  self:UpdateGroupMemberInfo()

  local playerIsInParty = UnitInParty("player")
  if (playerIsInParty and playerIsInParty ~= playerWasInParty) then
    MessageManager:SendMessageToGroup(SgEnum.AddonMessageType.AddonInfo, Compat.GetAddOnMetadata("Version"))
  end

  playerWasInParty = playerIsInParty
end

function EM.EventHandlers.LOSS_OF_CONTROL_ADDED(self, unitId, effectIndex)
  --print("LOSS_OF_CONTROL_ADDED." .. tostring(unitId) .. "," .. tostring(effectIndex))

  if (unitId ~= "player") then return end -- From what I've seen, this event only fires for the player anyway.

  local lossOfControlData = C_LossOfControl.GetActiveLossOfControlDataByUnit(unitId, effectIndex)
  --Safeguard_HelperFunctions.PrintKeysAndValuesFromTable(lossOfControlData)

  local locType = SgEnum.LossOfControlType.Unknown
  if (lossOfControlData.locType == "CONFUSE") then
    locType = SgEnum.LossOfControlType.Confuse
  elseif (lossOfControlData.locType == "DISARM") then
    locType = SgEnum.LossOfControlType.Disarm
  elseif (lossOfControlData.locType == "FEAR_MECHANIC") then
    locType = SgEnum.LossOfControlType.FearMechanic
  elseif (lossOfControlData.locType == "ROOT") then
    locType = SgEnum.LossOfControlType.Root
  elseif (lossOfControlData.locType == "SCHOOL_INTERRUPT") then
    locType = SgEnum.LossOfControlType.SchoolInterrupt
  elseif (lossOfControlData.locType == "SILENCE") then
    locType = SgEnum.LossOfControlType.Silence
  elseif (lossOfControlData.locType == "STUN") then
    locType = SgEnum.LossOfControlType.Stun
  elseif (lossOfControlData.locType == "STUN_MECHANIC") then
    locType = SgEnum.LossOfControlType.StunMechanic
  else
    table.insert(Safeguard_EventManager.DebugLogs, string.format("%d - No LossOfControlType for: %s", time(), lossOfControlData.locType))
  end

  local timeRemaining = lossOfControlData.timeRemaining
  if (timeRemaining ~= nil) then timeRemaining = math.floor(timeRemaining + 0.5) end

  Safeguard_NotificationManager:ShowNotificationToPlayer(UnitName("player"), SgEnum.NotificationType.LossOfControl, locType, timeRemaining)
  MessageManager:SendMessageToGroup(SgEnum.AddonMessageType.LossOfControl, locType, timeRemaining)
end

function EM.EventHandlers.PLAYER_ENTERING_WORLD(self, isLogin, isReload)
  --print("PLAYER_ENTERING_WORLD. " .. tostring(isLogin) ..  ", " .. tostring(isReload))

  self:UpdateGroupMemberInfo()
  self.PlayerFlags.Pvp = UnitIsPVP("player")
  
  if (isLogin or isReload) then
    IntervalManager:CheckCombatInterval()
    IntervalManager:CheckGroupConnectionsInterval()
    IntervalManager:SendHeartbeatInterval()
  else
    Safeguard_PlayerStates = {}
    MessageManager:SendHeartbeatMessage()
  end

  if (Safeguard_Settings.Options.ForceFloatingCombatText and Compat.GetCVar("enableFloatingCombatText") ~= "1") then
    print(CHAT_PREFIX .. "Enabling floating combat text.")
    Compat.SetCVar("enableFloatingCombatText", 1)
  end
end

function EM.EventHandlers.PLAYER_FLAGS_CHANGED(self, unitId)
  if (unitId ~= "player" or UnitIsPVP("player") == self.PlayerFlags.Pvp) then return end

  local playerHadPvpEnabled = self.PlayerFlags.Pvp
  self.PlayerFlags.Pvp = UnitIsPVP("player")
  if (playerHadPvpEnabled == nil) then return end

  local notificationType = SgEnum.NotificationType.PvpFlagged
  if (not self.PlayerFlags.Pvp) then notificationType = SgEnum.NotificationType.PvpUnflagged end
  Safeguard_NotificationManager:ShowNotificationToPlayer(UnitName("player"), notificationType)
end

function EM.EventHandlers.PLAYER_LEAVING_WORLD(self)
  --print("PLAYER_LEAVING_WORLD.")

  --This message only seems to actually get sent when reloading, not when going through instance portals.
  MessageManager:SendHeartbeatMessage()
end

function EM.EventHandlers.PLAYER_REGEN_DISABLED(self)
  --print("PLAYER_REGEN_DISABLED")

  MessageManager:SendMessageToGroup(SgEnum.AddonMessageType.EnteredCombat)
  Safeguard_NotificationManager:ShowNotificationToPlayer(UnitName("player"), SgEnum.NotificationType.EnteredCombat)
end

function EM.EventHandlers.PLAYER_REGEN_ENABLED(self)
  --print("PLAYER_REGEN_ENABLED")

  MessageManager:SendMessageToGroup(SgEnum.AddonMessageType.ExitedCombat)
end

local healthStatus = {}

function EM.EventHandlers.UNIT_HEALTH(self, unitId)
  --print("UNIT_HEALTH: " .. unitId)

  if (not Safeguard_Settings.Options.EnableLowHealthAlerts) then return end

  local updateIsForPlayer = unitId == "player"
  local updateIsForParty = unitId:match("party")
  if (not updateIsForPlayer and not updateIsForParty) then return end

  local health = UnitHealth(unitId)
  local maxHealth = UnitHealthMax(unitId)
  
  if (maxHealth == 0) then return end

  local healthPercentage = health / maxHealth

  local newHealthStatus = nil
  if (health == 0) then
    newHealthStatus = 0
  elseif (healthPercentage <= Safeguard_Settings.Options.ThresholdForCriticallyLowHealth) then
    newHealthStatus = 1
  elseif (healthPercentage <= Safeguard_Settings.Options.ThresholdForLowHealth) then
    newHealthStatus = 2
  else
    newHealthStatus = 3
  end

  local oldHealthStatus = healthStatus[unitId]
  if (newHealthStatus == oldHealthStatus) then return end

  if (newHealthStatus == 1) then
    Safeguard_NotificationManager:ShowNotificationToPlayer(UnitName(unitId), SgEnum.NotificationType.HealthCriticallyLow, math.floor(healthPercentage * 100))

    if (updateIsForPlayer) then
      if (Safeguard_Settings.Options.EnableLowHealthAlertSounds) then
        self:PlaySound("alert2")
      end

      MessageManager:SendMessageToGroup(SgEnum.AddonMessageType.HealthCriticallyLow, math.floor(healthPercentage * 100))

      if (Safeguard_Settings.Options.EnableLowHealthAlertScreenFlashing) then
        Safeguard_FlashFrame:PlayAnimation(9999, 1.5, 1.0)
      end
    end
  elseif (newHealthStatus == 2) then
    if (oldHealthStatus == nil or oldHealthStatus > newHealthStatus) then
      Safeguard_NotificationManager:ShowNotificationToPlayer(UnitName(unitId), SgEnum.NotificationType.HealthLow, math.floor(healthPercentage * 100))
      
      if (updateIsForPlayer) then
        if (Safeguard_Settings.Options.EnableLowHealthAlertSounds) then
          self:PlaySound("alert3")
        end

        MessageManager:SendMessageToGroup(SgEnum.AddonMessageType.HealthLow, math.floor(healthPercentage * 100))
      end
    end

    if (updateIsForPlayer and Safeguard_Settings.Options.EnableLowHealthAlertScreenFlashing) then
      Safeguard_FlashFrame:PlayAnimation(9999, 2.0, 0.75)
    end
  elseif (updateIsForPlayer) then
    Safeguard_FlashFrame:StopAnimation()
  end

  healthStatus[unitId] = newHealthStatus
end

local manaIsLow = {}

-- UNIT_POWER_UPDATE fires constantly, so the disabled case has to be the first thing
-- checked. With the option off this costs one table lookup per event.
function EM.EventHandlers.UNIT_POWER_UPDATE(self, unitId, powerType)
  if (not Safeguard_Settings.Options.EnableLowManaAlerts) then return end
  if (powerType ~= "MANA") then return end

  local updateIsForPlayer = unitId == "player"
  local updateIsForParty = unitId:match("party")
  if (not updateIsForPlayer and not updateIsForParty) then return end

  local maxMana = UnitPowerMax(unitId, Compat.ManaPowerType)
  if (maxMana == 0) then return end

  local manaPercentage = UnitPower(unitId, Compat.ManaPowerType) / maxMana
  local isLow = manaPercentage <= Safeguard_Settings.Options.ThresholdForLowMana

  -- Only the crossing into low mana is interesting. Storing the state means a unit
  -- hovering either side of the threshold is not announced over and over.
  if (isLow == manaIsLow[unitId]) then return end
  manaIsLow[unitId] = isLow

  if (not isLow) then return end

  local manaPercent = math.floor(manaPercentage * 100)
  Safeguard_NotificationManager:ShowNotificationToPlayer(UnitName(unitId), SgEnum.NotificationType.ManaLow, manaPercent)

  if (updateIsForPlayer) then
    MessageManager:SendMessageToGroup(SgEnum.AddonMessageType.ManaLow, manaPercent)
  end
end


hooksecurefunc("CancelLogout", function()
	--print("CancelLogout")

  MessageManager:SendMessageToGroup(SgEnum.AddonMessageType.LogoutCancelled)
end)

hooksecurefunc("Logout", function()
	--print("Logout")
  if (UnitAffectingCombat("player")) then return end

  MessageManager:SendMessageToGroup(SgEnum.AddonMessageType.LoggingOut)
end)

hooksecurefunc("Quit", function()
	--print("Quit")
  if (UnitAffectingCombat("player")) then return end

  MessageManager:SendMessageToGroup(SgEnum.AddonMessageType.LoggingOut)
end)

-- Register each event for which we have an event handler.
EM.Frame = CreateFrame("Frame")
for eventName,_ in pairs(EM.EventHandlers) do
	  EM.Frame:RegisterEvent(eventName)
end
EM.Frame:SetScript("OnEvent", function(_, event, ...) EM:OnEvent(_, event, ...) end)


-- Helper Functions

-- function EM:GetPlayerRelationship(unitId)
--   if (unitId == "player") then
--     return SgEnum.PlayerRelationshipType.Player
--   end

--   if (unitId:match("party")) then
--     return SgEnum.PlayerRelationshipType.Party
--   end

--   return SgEnum.PlayerRelationshipType.None
-- end

function EM:CheckToNotifyForExtraAttacks(sourceGuid, sourceName)
  if (unitsWithExtraAttacksStored[sourceGuid] > 0) then
    local shouldNotify = knownHostileUnits[sourceGuid]

    local unitId = nil
    local isTankingEnemy = nil
    if (not shouldNotify) then
      unitId = UnitHelperFunctions.FindUnitIdByUnitGuid(sourceGuid)
      if (unitId) then
        local name, type, difficultyIndex, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceMapId, lfgID = GetInstanceInfo()
        if ((type == "party" or type == "raid") and not UnitIsFriend("player", unitId)) then
          shouldNotify = true
        else
          local isTanking, status, threatpct, rawthreatpct, threatvalue = Compat.GetDetailedThreatSituation("player", unitId)
          isTankingEnemy = isTanking

          if (threatpct ~= nil) then
            shouldNotify = true
          end
        end
      end
    end

    if (shouldNotify) then
      Safeguard_NotificationManager:ShowNotificationToPlayer(UnitName("player"), SgEnum.NotificationType.ExtraAttacksStored, sourceName, unitsWithExtraAttacksStored[sourceGuid])

      if (isTankingEnemy ~= false) then
        if (not unitId) then unitId = UnitHelperFunctions.FindUnitIdByUnitGuid(sourceGuid) end
        if (unitId) then
          local classification = UnitClassification(unitId)
          if (classification == "worldboss" or classification == "rareelite" or classification == "elite") then
            if (isTankingEnemy == nil) then
              isTankingEnemy = Compat.GetDetailedThreatSituation("player", unitId)
            end

            if (isTankingEnemy) then
              MessageManager:SendMessageToGroup(SgEnum.AddonMessageType.ExtraAttacksStored, sourceName, unitsWithExtraAttacksStored[sourceGuid])
            end
          end
        end
      end
    end
  end
end

-- Alerts play on the Dialog channel, so the dialog cvars are forced on for the
-- moment the sound is playing and put back afterwards.
--
-- Two alerts inside that window used to corrupt the player's settings: dropping
-- from full health through both thresholds fires alert3 and then alert2 in quick
-- succession, and the second call read the values the first call had already
-- forced, took 1/1 to be the player's own settings, and wrote those back for good.
-- Dialog volume then sat at maximum until the player noticed and fixed it by hand.
--
-- The originals are therefore captured once, on the first alert of a burst, and
-- only the most recently scheduled restore is allowed to run.
local savedDialogCVars = nil
local dialogRestoreToken = 0

function EM:PlaySound(soundFile)
  if (not savedDialogCVars) then
    savedDialogCVars = {
      EnableDialog = Compat.GetCVar("Sound_EnableDialog"),
      DialogVolume = Compat.GetCVar("Sound_DialogVolume"),
    }
  end

  Compat.SetCVar("Sound_EnableDialog", 1)
  Compat.SetCVar("Sound_DialogVolume", 1)

  PlaySoundFile("Interface\\AddOns\\" .. ADDON_NAME .. "\\resources\\" .. soundFile .. ".mp3", "Dialog")

  dialogRestoreToken = dialogRestoreToken + 1
  local token = dialogRestoreToken

  C_Timer.After(1, function()
    -- A later alert has extended the window and owns the restore now.
    if (token ~= dialogRestoreToken or not savedDialogCVars) then return end

    Compat.SetCVar("Sound_EnableDialog", savedDialogCVars.EnableDialog)
    Compat.SetCVar("Sound_DialogVolume", savedDialogCVars.DialogVolume)
    savedDialogCVars = nil
  end)
end

function EM:UpdateGroupMemberInfo()
  -- Populate list of unit GUIDs in player's party/raid.
  local playerGuid = UnitGUID("player")
  local unitGuidsInGroup = { }

  unitGuidsInGroup[playerGuid] = "player"
  for i = 1, 4 do
    local unitId = "party" .. i
    local guid = UnitGUID(unitId)
    if (guid and guid ~= playerGuid) then
      unitGuidsInGroup[guid] = unitId
    end
  end
  for i = 1, 40 do
    local unitId = "raid" .. i
    local guid = UnitGUID(unitId)
    if (guid and guid ~= playerGuid) then
      unitGuidsInGroup[guid] = unitId
    end
  end
  
  -- Perform actions for units who are in the group.
  for k,v in pairs(unitGuidsInGroup) do
  end
  
  -- Perform actions for units who left the group.
  for k,v in pairs(Safeguard_PlayerStates) do
    if (not unitGuidsInGroup[k]) then
      Safeguard_PlayerStates[k] = nil
    end
  end
end

function EM:Test()
  print(CHAT_PREFIX .. "Test")

  -- print(UnitDetailedThreatSituation("player", "target"))
  -- local possibleEnemyUnitIds = UnitHelperFunctions.GetPossibleEnemyUnitIds()
  -- local unitsTargettingMe = {}
  -- for i = 1, #possibleEnemyUnitIds do
  --   local guid = UnitGUID(possibleEnemyUnitIds[i])
  --   if (guid and not unitsTargettingMe[guid]) then
  --     local isTanking, status, threatpct, rawthreatpct, threatvalue = UnitDetailedThreatSituation("player", possibleEnemyUnitIds[i])
  --     if (isTanking) then
  --       unitsTargettingMe[guid] = true
  --     end
  --   end
	-- end

  -- local unitsTargettingMeCount = 0
  -- for k,v in pairs(unitsTargettingMe) do
  --   unitsTargettingMeCount = unitsTargettingMeCount + 1
  -- end

  -- print(unitsTargettingMeCount)

  -- local nameplateMaxDistance = GetCVar("nameplateMaxDistance")
  -- print(nameplateMaxDistance)
  -- --SetCVar("nameplateMaxDistance", 40) -- max is 20 in vanilla

  MessageManager:SendMessageToGroup(SgEnum.AddonMessageType.AddonInfo, Compat.GetAddOnMetadata("Version"))
  print(CHAT_PREFIX .. "Version " .. tostring(Compat.GetAddOnMetadata("Version")))

  -- Sample notifications, so the onscreen styling can be judged without waiting for
  -- something to actually go wrong.
  local playerName = UnitName("player")
  Safeguard_NotificationManager:ShowNotificationToPlayer(playerName, SgEnum.NotificationType.HealthCriticallyLow, 12)
  Safeguard_NotificationManager:ShowNotificationToPlayer(playerName, SgEnum.NotificationType.LossOfControl, SgEnum.LossOfControlType.Stun, 4)
end

function EM:Debug()
  local startIndex = #self.DebugLogs - 50
  if (startIndex < 1) then startIndex = 1 end
  for i = startIndex, #self.DebugLogs do
    print(i .. " - " .. self.DebugLogs[i])
  end
end
