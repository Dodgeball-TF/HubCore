enum Coinflip
{
	COINFLIP_HEAD,
	COINFLIP_TAIL
}

enum struct CreditPlayers
{
	Handle	 currentCreditsPerMinute;
	Coinflip currentCoinflip;
	int			 currentCoinflipAmount;
}

CreditPlayers creditPlayers[MAXPLAYERS + 1];

void					CreditsOnStart()
{
	RegConsoleCmd("sm_credits", CommandCredits, "Shows clients credits.");
	RegConsoleCmd("sm_coinflip", CommandCoinflip, "Coinflip.");

	// Create ConVars
	Hub_Credits_Minute									= CreateConVar("hub_credits_minute", "5", "How minutes when to give credits.");
	Hub_Credits_Amount									= CreateConVar("hub_credits_amount", "25", "How many credits to give per minute.");
	Hub_Credits_Coinflip_Multiplier			= CreateConVar("hub_credits_coinflip_multiplier", "1.2", "How much to multiply the coinflip amount by.");
	Hub_Credits_Kill_For_Credits				= CreateConVar("hub_credits_kill_for_credits", "0", "Get credits when you kill someone, either enabled or not.", _, true, 0.0, true, 1.0);
	Hub_Credits_Kill_For_Credits_Points = CreateConVar("hub_credits_kill_for_credits_points", "5", "How much points to give/extract when death.");

	HookConVarChange(Hub_Credits_Minute, CreditsMinuteChange);
	HookEvent("player_death", CreditsOnPlayerDeath);

	for (int i = 1; i <= MaxClients; i++)
	{
		CreditsBootstrapClient(i);
	}
}

void CreditsAskPluginLoad2() {}

/* Events */
public void CreditsMinuteChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (!IsValidPlayer(i)) continue;

		if (creditPlayers[i].currentCreditsPerMinute != INVALID_HANDLE)
		{
			CloseHandle(creditPlayers[i].currentCreditsPerMinute);
		}

		CreditsBootstrapClient(i);
	}
}

void CreditsOnClientDisconnect(int client)
{
	if (!IsValidPlayer(client)) return;

	CloseHandle(creditPlayers[client].currentCreditsPerMinute);
}

void CreditsOnClientPostAdminCheck(int client)
{
	CreditsBootstrapClient(client);
}

/* Timers */
public Action Timer_Credits(Handle timer, int client)
{
	int amount = Hub_Credits_Amount.IntValue;

	if (amount <= 0) return Plugin_Continue;

	AddPlayerCredits(client, amount);

	Cookie cookie			 = GetCookieByName(HUB_COOKIE_DISABLED_CREDIT_RECEIVED_MESSAGE);
	int		 cookieValue = GetCookieValue(client, cookie);

	if (cookieValue != 1)
		CPrintToChat(client, "%t", HUB_PHRASE_PLAYER_RECIEVE_CREDITS, amount);

	return Plugin_Continue;
}

/* Methods */
public void CreditsBootstrapClient(int client)
{
	if (!IsValidPlayer(client)) return;
	float minToSecond															= Hub_Credits_Minute.FloatValue * 60;
	creditPlayers[client].currentCreditsPerMinute = CreateTimer(minToSecond, Timer_Credits, client, TIMER_REPEAT);
}

public void DecideCoinflip(int client)
{
	if (!IsValidPlayer(client)) return;

	int amount = creditPlayers[client].currentCoinflipAmount;

	if (amount <= 0) return;

	int currentAmount = GetPlayerCredits(client);

	if (amount > currentAmount)
	{
		CPrintToChat(client, "%t", HUB_PHRASE_CREDITS_COINFLIP_NOT_ENOUGH_CREDITS);
		return;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	int random = GetRandomInt(0, 1);

	if (random == view_as<int>(creditPlayers[client].currentCoinflip))
	{
		float newAmount = amount * Hub_Credits_Coinflip_Multiplier.FloatValue;
		AddPlayerCredits(client, RoundToCeil(newAmount));
		CPrintToChatAll("%t", HUB_PHRASE_CREDITS_COINFLIP_WIN, RoundToCeil(newAmount), name);
	}
	else
	{
		RemovePlayerCredits(client, amount);
		CPrintToChatAll("%t", HUB_PHRASE_CREDITS_COINFLIP_LOSE, amount, name);
	}

	creditPlayers[client].currentCoinflip				= view_as<Coinflip>(INVALID_HANDLE);
	creditPlayers[client].currentCoinflipAmount = view_as<int>(INVALID_HANDLE);
}

/* Commands */
public Action CommandCredits(int client, int args)
{
	int	 credits = GetPlayerCredits(client);

	char name[32];
	GetClientName(client, name, sizeof(name));

	// Send message back to client
	CPrintToChatAll("%t", HUB_PHRASE_PLAYER_CREDITS, credits, name);

	return Plugin_Handled;
}

public Action CommandCoinflip(int client, int args)
{
	if (args < 1)
	{
		CPrintToChat(client, "%t", HUB_PHRASE_CREDITS_COINFLIP_USAGE);
		return Plugin_Handled;
	}

	int currentAmount = GetPlayerCredits(client);
	int amount				= GetCmdArgInt(1);

	// Can't bet more than you have
	if (amount > currentAmount)
	{
		CPrintToChat(client, "%t", HUB_PHRASE_CREDITS_COINFLIP_NOT_ENOUGH_CREDITS);
		return Plugin_Handled;
	}

	creditPlayers[client].currentCoinflipAmount = amount;

	DisplayCoinflipMenu(client);

	return Plugin_Handled;
}

// Hooks
public void CreditsOnPlayerDeath(Event hEvent, char[] strEventName, bool bDontBroadcast)
{
	int client	 = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));

	if (!IsValidPlayer(client) || !IsValidPlayer(attacker)) return;

	if (client == attacker) return;

	if (Hub_Credits_Kill_For_Credits.BoolValue)
	{
		int amount = GetPlayerCredits(client);

		if (amount <= 0) return;

		int	 points = Hub_Credits_Kill_For_Credits_Points.IntValue;

		char attackerName[MAX_NAME_LENGTH];
		GetClientName(attacker, attackerName, sizeof(attackerName));
		char clientName[MAX_NAME_LENGTH];
		GetClientName(client, clientName, sizeof(clientName));

		// If player doesn't have enough credits, we take all of them
		if (amount < points)
		{
			RemovePlayerCredits(client, points);
			AddPlayerCredits(attacker, points);
		}
		else
		{
			RemovePlayerCredits(client, points);
			AddPlayerCredits(attacker, points);
		}

		Cookie creditMessageCookie = GetCookieByName(HUB_COOKIE_DISABLED_CREDIT_KILL_REWARD_MESSAGE);
		int		 attackerValue			 = GetCookieValue(attacker, creditMessageCookie);
		int		 clientValue				 = GetCookieValue(client, creditMessageCookie);

		if (attackerValue != 1)
			CPrintToChat(client, "%t", HUB_CREDITS_EARNED_POINTS_DIED, points, attackerName);

		if (clientValue != 1)
			CPrintToChat(attacker, "%t", HUB_PHRASE_EARNED_POINTS_KILLED, points, clientName);
	}
}

/* Menus */
void DisplayCoinflipMenu(int client)
{
	Menu hMenu = new Menu(CoinflipMenuHandler);

	hMenu.SetTitle("Coinflip");
	hMenu.AddItem("0", "Heads", ITEMDRAW_DEFAULT);
	hMenu.AddItem("1", "Tails", ITEMDRAW_DEFAULT);

	hMenu.ExitButton = true;

	hMenu.Display(client, MENU_TIME_FOREVER);
}

public int CoinflipMenuHandler(Menu menu, MenuAction menuActions, int param1, int param2)
{
	switch (menuActions)
	{
		case MenuAction_Select:
		{
			char strOption[8];
			menu.GetItem(param2, strOption, sizeof(strOption));

			int iOption = StringToInt(strOption);

			switch (iOption)
			{
				case 0:
				{
					creditPlayers[param1].currentCoinflip = COINFLIP_HEAD;
					DecideCoinflip(param1);
				}

				case 1:
				{
					creditPlayers[param1].currentCoinflip = COINFLIP_TAIL;
					DecideCoinflip(param1);
				}
			}
		}
	}

	return 1;
}