Safeguard_PlayerStates = {} --<guid, PlayerState>

PlayerState = {}
function PlayerState.New(connectionInfo, isInCombat)
  return {
    ConnectionInfo = connectionInfo,
    IsInCombat = isInCombat,
  }
end

ConnectionInfo = {}
function ConnectionInfo.New(isConnected, lastMessageTimestamp)
  return {
    IsConnected = isConnected,
    LastMessageTimestamp = lastMessageTimestamp,
  }
end