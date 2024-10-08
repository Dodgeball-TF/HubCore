stock void GetSteamId(int client, char[] steamID, int len) {
  GetClientAuthId(client, AuthId_Steam2, steamID, len);
}

stock bool IsValidPlayer(int client, bool alive = false) {
	if (client >= 1 &&
		client <= MaxClients &&
		IsClientConnected(client) &&
		IsClientInGame(client) &&
		!IsFakeClient(client) &&
		(alive == false || IsPlayerAlive(client)))
	{
		return true;
	}

	return false;
}

stock bool IsNullStringOrEmpty(const char[] str)
{
	return str[0] == 0;
}

// public void MakePlayerCommand(int client, char player_command[192]) 
// {
// 	LogPlayerEvent(client, "say", player_command);
// }