Cookie CookieDisableCreditKillRewardMessage;
Cookie CookieDisableCreditReceivedMessage;

enum struct CookieStruct
{
	Cookie cookie;
	char	 name[128];
	int		 playerValues[MAXPLAYERS + 1];
}

static CookieStruct AvailableCookies[32];

void								CookieOnStart()
{
	CookieDisableCreditKillRewardMessage = new Cookie("credit_kill_reward", "Disable credit kill reward message", CookieAccess_Protected);
	CookieDisableCreditReceivedMessage	 = new Cookie("credit_received", "Disables if a player wants to see how many coins they just recieved", CookieAccess_Protected);

	CreateCookieStruct(CookieDisableCreditKillRewardMessage, HUB_COOKIE_DISABLED_CREDIT_KILL_REWARD_MESSAGE, 0);
	CreateCookieStruct(CookieDisableCreditReceivedMessage, HUB_COOKIE_DISABLED_CREDIT_RECEIVED_MESSAGE, 1);

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && IsValidPlayer(client) && AreClientCookiesCached(client))
			OnClientCookiesCached(client);
	}
}

void CookieOnClientPostAdminCheck(int client)
{
	OnClientCookiesCached(client);
}

public void OnClientCookiesCached(int client)
{
	// Refresh all cookies
	for (int i = 0; i < sizeof(AvailableCookies); i++)
	{
		Cookie cookie = AvailableCookies[i].cookie;
		if (cookie == null)
			continue;
		// Get value just to check
		char value[8];
		cookie.Get(client, value, 8);
		AvailableCookies[i].playerValues[client] = StringToInt(value);
	}
}

public void CreateCookieStruct(Cookie cookie, char name[128], int index)
{
	CookieStruct cookieStruct;
	cookieStruct.cookie			= cookie;
	cookieStruct.name				= name;

	AvailableCookies[index] = cookieStruct;
}

public Cookie
	GetCookieByName(char[] name)
{
	for (int i = 0; i < sizeof(AvailableCookies); i++)
	{
		if (StrEqual(name, AvailableCookies[i].name))
			return AvailableCookies[i].cookie;
	}
	return null;
}

public int GetCookieValue(int client, Cookie cookie)
{
	char value[8];
	GetClientCookie(client, cookie, value, 8);
	return StringToInt(value);
}

public void SetCookieValue(int client, Cookie cookie, char[] value)
{
	SetClientCookie(client, cookie, value);
}