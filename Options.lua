Safeguard_OptionWindow = CreateFrame("Frame", "SafeguardReloadedOptionsFrame", UIParent)

local OW = Safeguard_OptionWindow

local Compat = SafeguardReloaded_Compat

local CHAT_PREFIX = Compat.ChatPrefix

-- *** Layout ***
-- Every control used to sit on a hand-picked x offset, and the offsets drifted
-- between sections: the You/Party pair sat at 280/350 in one block and 280/420 in
-- another, so no two rows lined up. Positions now come from these constants, which
-- means a new row lands in the right place without anyone measuring anything.

local INDENT_TOP = 8        -- a switch that owns a section
local INDENT_SUB = 30       -- a switch that depends on the one above it
local COLUMN_2 = 300        -- second column for paired sub-options
local GRID_SELF = 330       -- notification grid, "You" column centre
local GRID_GROUP = 400      -- notification grid, "Party" column centre
local ROW_STEP = 22
local SECTION_GAP = 14
local CHECKBOX_SIZE = 24
local CONTENT_BOTTOM_PAD = 20

-- Both threshold fields hold a two digit percentage and cap out at two letters, so
-- the moment a saved value is loaded they are full and the client rejects every
-- further keystroke. Nothing appears to happen when you type.
--
-- Selecting the contents on focus is what a short numeric field wants anyway: click
-- it, type the new number, and it replaces the old one. Enter and Escape both give
-- up focus, and leaving the field writes the value straight away rather than
-- waiting for the panel to be closed.
local function CreateThresholdEditBox(parent, xOffset, yPos, labelText)
  local editBox = CreateFrame("EditBox", nil, parent, BackdropTemplateMixin and "BackdropTemplate")
  editBox:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yPos - 2)
  editBox:SetSize(28, 20)
  editBox:SetFontObject(ChatFontNormal)
  editBox:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 })
  editBox:SetAutoFocus(false)
  editBox:SetMaxLetters(2)
  editBox:SetMultiLine(false)
  editBox:SetNumeric(true)
  editBox:SetTextInsets(5, 5, 0, 0)
  editBox:EnableMouse(true)

  editBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

  editBox:SetScript("OnEditFocusLost", function(self)
    self:HighlightText(0, 0)
    OW:SaveOptions()
  end)

  editBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

  editBox.Label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  editBox.Label:SetPoint("LEFT", editBox, "RIGHT", 8, 0)
  editBox.Label:SetText(labelText)

  return editBox
end

-- A checkbox and its label behave as one control. The label used to be a separate
-- font string, so only the 24 pixel box itself was clickable; extending the hit
-- rect to the right makes the whole row respond.
local function CreateCheckbox(parent, xOffset, yPos, labelText, subText)
  local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yPos)
  checkbox:SetSize(CHECKBOX_SIZE, CHECKBOX_SIZE)

  checkbox.Label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  checkbox.Label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
  checkbox.Label:SetText(labelText)

  local hitWidth = checkbox.Label:GetStringWidth() + 6

  if (subText) then
    checkbox.SubLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    checkbox.SubLabel:SetPoint("LEFT", checkbox.Label, "RIGHT", 6, 0)
    checkbox.SubLabel:SetText(subText)
  end

  checkbox:SetHitRectInsets(0, -hitWidth, 0, 0)

  -- Saving on click rather than only on panel close means a toggle takes effect
  -- immediately, which matters for the options that redraw something.
  checkbox:SetScript("OnClick", function() OW:SaveOptions() end)

  return checkbox
end

-- A checkbox with no label, used inside the notification grid where the row label
-- and the column heading already say what it is.
local function CreateGridCheckbox(parent, centreX, yPos)
  local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  checkbox:SetPoint("TOPLEFT", parent, "TOPLEFT", centreX - (CHECKBOX_SIZE / 2), yPos)
  checkbox:SetSize(CHECKBOX_SIZE, CHECKBOX_SIZE)
  checkbox:SetScript("OnClick", function() OW:SaveOptions() end)
  return checkbox
end

-- Marks a column that does not apply to a row, so the gap reads as deliberate
-- rather than as a checkbox somebody forgot.
local function CreateGridDash(parent, centreX, yPos)
  local dash = parent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  dash:SetPoint("TOPLEFT", parent, "TOPLEFT", centreX - 4, yPos - 6)
  dash:SetText("--")
  return dash
end

local function CreateSectionHeader(parent, yPos, titleText)
  local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header:SetPoint("TOPLEFT", parent, "TOPLEFT", INDENT_TOP, yPos)
  header:SetText(titleText)

  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(1, 1, 1, 0.12)
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
  line:SetPoint("RIGHT", parent, "RIGHT", -20, 0)

  return header
end

local function CreateRowLabel(parent, xOffset, yPos, labelText)
  local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, yPos - 6)
  label:SetText(labelText)
  return label
end

-- Greys a control out instead of leaving it looking active but doing nothing,
-- which is the usual reason someone thinks a setting is broken.
local function SetControlEnabled(control, enabled)
  if (not control) then return end

  if (control.SetEnabled) then
    control:SetEnabled(enabled and true or false)
  elseif (enabled) then
    control:Enable()
  else
    control:Disable()
  end

  if (control.Label) then
    control.Label:SetFontObject(enabled and "GameFontHighlight" or "GameFontDisable")
  end
  if (control.SubLabel) then
    control.SubLabel:SetFontObject(enabled and "GameFontHighlightSmall" or "GameFontDisableSmall")
  end
end

local function SetLabelEnabled(label, enabled)
  if (not label) then return end
  label:SetFontObject(enabled and "GameFontHighlight" or "GameFontDisable")
end

function OW:Initialize()
  if (self.Initialized) then return end

  self.Header = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  self.Header:SetPoint("TOPLEFT", 14, -12)
  self.Header:SetText("SafeguardReloaded")

  -- Sits on the title's baseline rather than on a line of its own, so the credit
  -- line costs no vertical space.
  self.Subheader = self:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  self.Subheader:SetPoint("BOTTOMLEFT", self.Header, "BOTTOMRIGHT", 12, 1)
  self.Subheader:SetText("v" .. tostring(Compat.GetAddOnMetadata("Version")) ..
    "  by Rynaoki  |  based on Safeguard by Tollski")

  -- The panel is taller than the canvas on smaller resolutions, and without a
  -- scroll frame the last rows were simply unreachable.
  local scrollFrame = CreateFrame("ScrollFrame", nil, self, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -40)
  scrollFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -28, 10)
  self.ScrollFrame = scrollFrame

  local content = CreateFrame("Frame", nil, scrollFrame)
  content:SetSize(1, 1)
  scrollFrame:SetScrollChild(content)
  self.Content = content

  -- The canvas has no size yet while the addon is loading, so the scroll child
  -- takes its width from the scroll frame whenever that changes.
  scrollFrame:SetScript("OnSizeChanged", function(_, width)
    if (width and width > 0) then content:SetWidth(width) end
  end)

  local yPos = 0

  -- *** Low health alerts ***

  CreateSectionHeader(content, yPos, "Low health alerts")
  yPos = yPos - ROW_STEP

  self.cbEnableLowHealthAlerts = CreateCheckbox(content, INDENT_TOP, yPos, "Enable low health alerts")
  yPos = yPos - ROW_STEP

  self.ebLowHealthThreshold = CreateThresholdEditBox(content, INDENT_SUB, yPos, "Low health threshold %")
  self.ebCriticalHealthThreshold = CreateThresholdEditBox(content, COLUMN_2, yPos, "Critically low threshold %")
  yPos = yPos - ROW_STEP

  self.cbEnableLowHealthAlertScreenFlashing = CreateCheckbox(content, INDENT_SUB, yPos, "Flash the screen")
  self.cbEnableLowHealthAlertSounds = CreateCheckbox(content, COLUMN_2 - 6, yPos, "Play an alert sound")
  yPos = yPos - ROW_STEP - SECTION_GAP

  -- *** Low mana alerts ***

  CreateSectionHeader(content, yPos, "Low mana alerts")
  yPos = yPos - ROW_STEP

  self.cbEnableLowManaAlerts = CreateCheckbox(content, INDENT_TOP, yPos, "Enable low mana alerts")
  yPos = yPos - ROW_STEP

  self.ebLowManaThreshold = CreateThresholdEditBox(content, INDENT_SUB, yPos, "Low mana threshold %")
  yPos = yPos - ROW_STEP - SECTION_GAP

  -- *** Chat messages ***

  CreateSectionHeader(content, yPos, "Chat messages to your group")
  yPos = yPos - ROW_STEP

  self.cbEnableChatMessages = CreateCheckbox(content, INDENT_TOP, yPos, "Enable chat messages")
  yPos = yPos - ROW_STEP

  self.cbEnableChatMessagesLogout = CreateCheckbox(content, INDENT_SUB, yPos, "You are logging out")
  self.cbEnableChatMessagesLowHealth = CreateCheckbox(content, COLUMN_2, yPos, "Your health is critically low")
  yPos = yPos - ROW_STEP

  self.cbEnableChatMessagesLossOfControl = CreateCheckbox(content, INDENT_SUB, yPos, "You are crowd controlled")
  self.cbEnableChatMessagesLowMana = CreateCheckbox(content, COLUMN_2, yPos, "You are low on mana")
  yPos = yPos - ROW_STEP

  self.cbEnableChatMessagesSpellCasts = CreateCheckbox(content, INDENT_SUB, yPos, "You cast certain spells", "(e.g. Hearthstone)")
  self.cbEnableChatMessagesExtraAttacksStored = CreateCheckbox(content, COLUMN_2, yPos, "An enemy stores extra attacks")
  yPos = yPos - ROW_STEP - SECTION_GAP

  -- *** Onscreen notifications ***

  CreateSectionHeader(content, yPos, "Onscreen notifications")
  yPos = yPos - ROW_STEP

  self.cbEnableTextNotifications = CreateCheckbox(content, INDENT_TOP, yPos, "Enable onscreen notifications")
  yPos = yPos - ROW_STEP

  self.fsGridHeaderSelf = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  self.fsGridHeaderSelf:SetPoint("TOPLEFT", content, "TOPLEFT", GRID_SELF - 12, yPos - 4)
  self.fsGridHeaderSelf:SetText("You")

  self.fsGridHeaderGroup = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  self.fsGridHeaderGroup:SetPoint("TOPLEFT", content, "TOPLEFT", GRID_GROUP - 16, yPos - 4)
  self.fsGridHeaderGroup:SetText("Party")
  yPos = yPos - 18

  self.NotificationRows = {}

  -- Each entry is { label, selfControl, groupControl }. A nil control means the
  -- column does not apply and gets a dash instead.
  local function AddNotificationRow(labelText, selfKey, groupKey)
    local row = {
      Label = CreateRowLabel(content, INDENT_SUB, yPos, labelText),
      SelfKey = selfKey,
      GroupKey = groupKey,
    }

    if (selfKey) then
      row.SelfControl = CreateGridCheckbox(content, GRID_SELF, yPos)
    else
      CreateGridDash(content, GRID_SELF, yPos)
    end

    if (groupKey) then
      row.GroupControl = CreateGridCheckbox(content, GRID_GROUP, yPos)
    else
      CreateGridDash(content, GRID_GROUP, yPos)
    end

    table.insert(self.NotificationRows, row)
    yPos = yPos - ROW_STEP
    return row
  end

  AddNotificationRow("Entering combat", "EnableTextNotificationsCombatSelf", "EnableTextNotificationsCombatGroup")
  AddNotificationRow("Disconnect or go offline *", "EnableTextNotificationsConnectionSelf", "EnableTextNotificationsConnectionGroup")
  AddNotificationRow("Logging out *", nil, "EnableTextNotificationsLogout")
  self.RowLowHealth = AddNotificationRow("Low health", "EnableTextNotificationsLowHealthSelf", "EnableTextNotificationsLowHealthGroup")
  self.RowLowMana = AddNotificationRow("Low mana", "EnableTextNotificationsLowManaSelf", "EnableTextNotificationsLowManaGroup")
  AddNotificationRow("Casting certain spells", nil, "EnableTextNotificationsSpellcasts")
  AddNotificationRow("Threat-altering buffs", "EnableTextNotificationsAurasSelf", "EnableTextNotificationsAurasGroup")
  AddNotificationRow("Crowd controlled *", "EnableTextNotificationsLossOfControlSelf", "EnableTextNotificationsLossOfControlGroup")
  AddNotificationRow("Flagged for PvP", "EnableTextNotificationsPvpFlagged", nil)
  AddNotificationRow("Extra attacks stored", "EnableTextNotificationsExtraAttacksStored", nil)

  self.fsNotificationsFootnote = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  self.fsNotificationsFootnote:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT_SUB, yPos - 4)
  self.fsNotificationsFootnote:SetText("*  requires the other player to have Safeguard or SafeguardReloaded installed.")
  yPos = yPos - ROW_STEP - SECTION_GAP

  -- *** Interface ***

  CreateSectionHeader(content, yPos, "Interface")
  yPos = yPos - ROW_STEP

  self.cbShowIconsOnRaidFrames = CreateCheckbox(content, INDENT_TOP, yPos, "Show icons on raid frames")
  self.cbShowPvpFlagTimerWindow = CreateCheckbox(content, COLUMN_2, yPos, "Show the PvP flag timer")
  yPos = yPos - ROW_STEP

  self.cbForceFloatingCombatText = CreateCheckbox(content, INDENT_TOP, yPos, "Force \"Floating Combat Text\" on")
  self.cbInterceptErrors = CreateCheckbox(content, COLUMN_2, yPos, "Print addon errors to chat")
  yPos = yPos - ROW_STEP

  content:SetHeight(-yPos + CONTENT_BOTTOM_PAD)

  self.Initialized = true
end

-- Sub-options are greyed out when the switch they depend on is off. The panel used
-- to carry "(Requires Low Health Alerts)" as static text next to a control that
-- still looked live; the state now shows itself.
function OW:UpdateDependentStates()
  local healthAlerts = self.cbEnableLowHealthAlerts:GetChecked()
  SetControlEnabled(self.ebLowHealthThreshold, healthAlerts)
  SetControlEnabled(self.ebCriticalHealthThreshold, healthAlerts)
  SetControlEnabled(self.cbEnableLowHealthAlertScreenFlashing, healthAlerts)
  SetControlEnabled(self.cbEnableLowHealthAlertSounds, healthAlerts)

  local manaAlerts = self.cbEnableLowManaAlerts:GetChecked()
  SetControlEnabled(self.ebLowManaThreshold, manaAlerts)

  local chatMessages = self.cbEnableChatMessages:GetChecked()
  SetControlEnabled(self.cbEnableChatMessagesLogout, chatMessages)
  SetControlEnabled(self.cbEnableChatMessagesLowHealth, chatMessages)
  SetControlEnabled(self.cbEnableChatMessagesLossOfControl, chatMessages)
  SetControlEnabled(self.cbEnableChatMessagesSpellCasts, chatMessages)
  SetControlEnabled(self.cbEnableChatMessagesExtraAttacksStored, chatMessages)
  -- Needs both the chat switch and the feature it reports on.
  SetControlEnabled(self.cbEnableChatMessagesLowMana, chatMessages and manaAlerts)

  local notifications = self.cbEnableTextNotifications:GetChecked()
  for i = 1, #self.NotificationRows do
    local row = self.NotificationRows[i]

    -- The low health and low mana rows report on a feature that can itself be off.
    local rowEnabled = notifications
    if (row == self.RowLowHealth) then rowEnabled = notifications and healthAlerts end
    if (row == self.RowLowMana) then rowEnabled = notifications and manaAlerts end

    SetLabelEnabled(row.Label, rowEnabled)
    SetControlEnabled(row.SelfControl, rowEnabled)
    SetControlEnabled(row.GroupControl, rowEnabled)
  end
end

function OW:LoadOptions()
  if (not self.Initialized) then return end

  local options = Safeguard_Settings.Options

  self.cbEnableChatMessages:SetChecked(options.EnableChatMessages)
  self.cbEnableChatMessagesLogout:SetChecked(options.EnableChatMessagesLogout)
  self.cbEnableChatMessagesLowHealth:SetChecked(options.EnableChatMessagesLowHealth)
  self.cbEnableChatMessagesSpellCasts:SetChecked(options.EnableChatMessagesSpellCasts)
  self.cbEnableChatMessagesLossOfControl:SetChecked(options.EnableChatMessagesLossOfControl)
  self.cbEnableChatMessagesExtraAttacksStored:SetChecked(options.EnableChatMessagesExtraAttacksStored)
  self.cbEnableChatMessagesLowMana:SetChecked(options.EnableChatMessagesLowMana)

  self.cbEnableLowHealthAlerts:SetChecked(options.EnableLowHealthAlerts)
  self.ebLowHealthThreshold:SetNumber(options.ThresholdForLowHealth * 100)
  self.ebCriticalHealthThreshold:SetNumber(options.ThresholdForCriticallyLowHealth * 100)
  self.cbEnableLowHealthAlertScreenFlashing:SetChecked(options.EnableLowHealthAlertScreenFlashing)
  self.cbEnableLowHealthAlertSounds:SetChecked(options.EnableLowHealthAlertSounds)

  self.cbEnableLowManaAlerts:SetChecked(options.EnableLowManaAlerts)
  self.ebLowManaThreshold:SetNumber(options.ThresholdForLowMana * 100)

  self.cbEnableTextNotifications:SetChecked(options.EnableTextNotifications)
  for i = 1, #self.NotificationRows do
    local row = self.NotificationRows[i]
    if (row.SelfControl) then row.SelfControl:SetChecked(options[row.SelfKey]) end
    if (row.GroupControl) then row.GroupControl:SetChecked(options[row.GroupKey]) end
  end

  self.cbForceFloatingCombatText:SetChecked(options.ForceFloatingCombatText)
  self.cbShowIconsOnRaidFrames:SetChecked(options.ShowIconsOnRaidFrames)
  self.cbShowPvpFlagTimerWindow:SetChecked(options.ShowPvpFlagTimerWindow)
  self.cbInterceptErrors:SetChecked(options.InterceptErrors)

  self.OptionsLoaded = true
  self:UpdateDependentStates()
end

function OW:SaveOptions()
  if (not self.OptionsLoaded) then return end

  if (self.ebLowHealthThreshold:GetNumber() < 2) then
    self.ebLowHealthThreshold:SetNumber(2)
  end

  if (self.ebCriticalHealthThreshold:GetNumber() < 1) then
    self.ebCriticalHealthThreshold:SetNumber(1)
  end
  if (self.ebCriticalHealthThreshold:GetNumber() >= self.ebLowHealthThreshold:GetNumber()) then
    self.ebCriticalHealthThreshold:SetNumber(self.ebLowHealthThreshold:GetNumber() - 1)
  end

  -- Unlike health there is no second mana threshold to stay below, so 1 to 99 is the
  -- only constraint. The two letter cap on the field already rules out 100.
  if (self.ebLowManaThreshold:GetNumber() < 1) then
    self.ebLowManaThreshold:SetNumber(1)
  end

  local options = Safeguard_Settings.Options

  local shouldUpdateRaidFrames = options.ShowIconsOnRaidFrames ~= self.cbShowIconsOnRaidFrames:GetChecked()
  local shouldUpdatePvpFlagTimerWindow = not options.ShowPvpFlagTimerWindow and self.cbShowPvpFlagTimerWindow:GetChecked()

  options.EnableChatMessages = self.cbEnableChatMessages:GetChecked()
  options.EnableChatMessagesLogout = self.cbEnableChatMessagesLogout:GetChecked()
  options.EnableChatMessagesLowHealth = self.cbEnableChatMessagesLowHealth:GetChecked()
  options.EnableChatMessagesSpellCasts = self.cbEnableChatMessagesSpellCasts:GetChecked()
  options.EnableChatMessagesLossOfControl = self.cbEnableChatMessagesLossOfControl:GetChecked()
  options.EnableChatMessagesExtraAttacksStored = self.cbEnableChatMessagesExtraAttacksStored:GetChecked()
  options.EnableChatMessagesLowMana = self.cbEnableChatMessagesLowMana:GetChecked()

  options.EnableLowHealthAlerts = self.cbEnableLowHealthAlerts:GetChecked()
  options.ThresholdForLowHealth = self.ebLowHealthThreshold:GetNumber() / 100
  options.ThresholdForCriticallyLowHealth = self.ebCriticalHealthThreshold:GetNumber() / 100
  options.EnableLowHealthAlertScreenFlashing = self.cbEnableLowHealthAlertScreenFlashing:GetChecked()
  options.EnableLowHealthAlertSounds = self.cbEnableLowHealthAlertSounds:GetChecked()

  options.EnableLowManaAlerts = self.cbEnableLowManaAlerts:GetChecked()
  options.ThresholdForLowMana = self.ebLowManaThreshold:GetNumber() / 100

  options.EnableTextNotifications = self.cbEnableTextNotifications:GetChecked()
  for i = 1, #self.NotificationRows do
    local row = self.NotificationRows[i]
    if (row.SelfControl) then options[row.SelfKey] = row.SelfControl:GetChecked() end
    if (row.GroupControl) then options[row.GroupKey] = row.GroupControl:GetChecked() end
  end

  options.ForceFloatingCombatText = self.cbForceFloatingCombatText:GetChecked()
  options.ShowIconsOnRaidFrames = self.cbShowIconsOnRaidFrames:GetChecked()
  options.ShowPvpFlagTimerWindow = self.cbShowPvpFlagTimerWindow:GetChecked()
  options.InterceptErrors = self.cbInterceptErrors:GetChecked()

  if (options.ForceFloatingCombatText and Compat.GetCVar("enableFloatingCombatText") ~= "1") then
    print(CHAT_PREFIX .. "Enabling floating combat text.")
    Compat.SetCVar("enableFloatingCombatText", 1)
  end
  if (shouldUpdateRaidFrames) then Safeguard_RaidFramesManager:UpdateRaidFrames() end
  if (shouldUpdatePvpFlagTimerWindow) then Safeguard_PvpFlagTimerWindow:Update() end

  self:UpdateDependentStates()
end

OW:SetScript("OnShow", function(self)
  OW:LoadOptions()
end)

OW.name = "SafeguardReloaded"
OW.OnCommit = function() OW:SaveOptions() end
OW.OnRefresh = function() OW:LoadOptions() end

OW.Category = Compat.RegisterOptionsPanel(OW, OW.name)
