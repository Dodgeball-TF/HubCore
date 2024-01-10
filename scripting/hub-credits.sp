#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <hub>
#include <hub-stock>
#include <hub-defines>
#include <multicolors>
#include <clientprefs>
#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION		 "1.1.0"
#define PLUGIN_DESCRIPTION "Hub-Credits"

ConVar Hub_Credits_Minute;
ConVar Hub_Credits_Amount;
ConVar Hub_Credits_Coinflip_Multiplier;
// Get credits when you kill someone, either enabled or not.
// When a player gets killed we take their points
ConVar Hub_Credits_Kill_For_Credits;
ConVar Hub_Credits_Kill_For_Credits_Points;

Handle DisableCreditKillRewardMessage = null;
int		 PlayersDisabledCreditKillRewardMessage[MAXPLAYERS + 1];

Handle DisableCreditRecievedMessage = null;
int		 PlayersDisabledCreditRecievedMessage[MAXPLAYERS + 1];

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

CreditPlayers players[MAXPLAYERS + 1];

bool					canUseCore = false;

public Plugin myinfo =
{
	name				= "hub-credits",
	author			= "Tolfx",
	description = PLUGIN_DESCRIPTION,
	version			= PLUGIN_VERSION,
	url					= "https://github.com/Dodgeball-TF/HubCore"
};

public void OnPluginStart()
{
	LoadTranslations("hub.phrases.txt");

	RegConsoleCmd("sm_credits", Cmd_Credits, "Shows clients credits.");
	RegConsoleCmd("sm_coinflip", Cmd_Coinflip, "Coinflip.");
	RegConsoleCmd("sm_reward_message", CommandKillRewardMessage, "Disables/enables kill reward message");
	RegConsoleCmd("sm_credit_recieved_message", CommandRecievedCreditMessage, "Disables/enables recieved credit message");

	// Create ConVars
	Hub_Credits_Minute									= CreateConVar("hub_credits_minute", "5", "How minutes when to give credits.");
	Hub_Credits_Amount									= CreateConVar("hub_credits_amount", "25", "How many credits to give per minute.");
	Hub_Credits_Coinflip_Multiplier			= CreateConVar("hub_credits_coinflip_multiplier", "1.2", "How much to multiply the coinflip amount by.");
	Hub_Credits_Kill_For_Credits				= CreateConVar("hub_credits_kill_for_credits", "1", "Get credits when you kill someone, either enabled or not.", _, true, 0.0, true, 1.0);
	Hub_Credits_Kill_For_Credits_Points = CreateConVar("hub_credits_kill_for_credits_points", "25", "How much points to give/extract when death.");

	DisableCreditKillRewardMessage			= RegClientCookie("disable_credit_kill_reward_message", "Disable credit kill reward message", CookieAccess_Protected);
	DisableCreditRecievedMessage				= RegClientCookie("disable_credit_recieved_message", "Disables if a player wants to see how many coins they just recieved", CookieAccess_Protected);

	HookConVarChange(Hub_Credits_Minute, Credits_Minute_Change);
	HookEvent("player_death", OnPlayerDeath);

	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		BootstrapClient(i);
		if (AreClientCookiesCached(i))
			OnClientCookiesCached(i);
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("hub-credits");
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	canUseCore = LibraryExists("hub-core");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual("hub-core", name))
	{
		canUseCore = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual("hub-core", name))
	{
		canUseCore = false;
	}
}

/* Events */
public void Credits_Minute_Change(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!canUseCore) return;

	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (!IsValidPlayer(i)) continue;

		if (players[i].currentCreditsPerMinute != INVALID_HANDLE)
		{
			CloseHandle(players[i].currentCreditsPerMinute);
		}

		BootstrapClient(i);
	}
}

public void OnClientDisconnect(int client)
{
	if (!IsValidPlayer(client)) return;

	CloseHandle(players[client].currentCreditsPerMinute);
}

public void OnClientPostAdminCheck(int client)
{
	BootstrapClient(client);
	OnClientCookiesCached(client);
}

/* Timers */
public Action Timer_Credits(Handle timer, int client)
{
	if (!canUseCore) return Plugin_Continue;
	int amount = Hub_Credits_Amount.IntValue;

	if (amount <= 0) return Plugin_Continue;

	AddPlayerCredits(client, amount);

	if (PlayersDisabledCreditRecievedMessage[client] != 1)
		CPrintToChat(client, "%t", HUB_PHRASE_PLAYER_RECIEVE_CREDITS, amount);

	return Plugin_Continue;
}

/* Methods */
public void BootstrapClient(int client)
{
	if (!IsValidPlayer(client)) return;
	float minToSecond												= Hub_Credits_Minute.FloatValue * 60;
	players[client].currentCreditsPerMinute = CreateTimer(minToSecond, Timer_Credits, client, TIMER_REPEAT);
}

public void OnClientCookiesCached(int client)
{
	char disabledKillReward[8];
	GetClientCookie(client, DisableCreditKillRewardMessage, disabledKillReward, 8);
	char disabledRecievedMessage[8];
	GetClientCookie(client, DisableCreditRecievedMessage, disabledRecievedMessage, 8);

	if (!IsNullStringOrEmpty(disabledKillReward))
		PlayersDisabledCreditKillRewardMessage[client] = StringToInt(disabledKillReward);
	else
		PlayersDisabledCreditKillRewardMessage[client] = 0;

	if (!IsNullStringOrEmpty(disabledRecievedMessage))
		PlayersDisabledCreditRecievedMessage[client] = StringToInt(disabledRecievedMessage);
	else
		PlayersDisabledCreditRecievedMessage[client] = 0;
}

public void DecideCoinflip(int client)
{
	if (!IsValidPlayer(client)) return;

	int amount = players[client].currentCoinflipAmount;

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

	if (random == view_as<int>(players[client].currentCoinflip))
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

	players[client].currentCoinflip				= view_as<Coinflip>(INVALID_HANDLE);
	players[client].currentCoinflipAmount = view_as<int>(INVALID_HANDLE);
}

/* Commands */
public Action Cmd_Credits(int client, int args)
{
	if (!canUseCore) return Plugin_Handled;

	int	 credits = GetPlayerCredits(client);

	char name[32];
	GetClientName(client, name, sizeof(name));

	// Send message back to client
	CPrintToChatAll("%t", HUB_PHRASE_PLAYER_CREDITS, credits, name);

	return Plugin_Handled;
}

public Action Cmd_Coinflip(int client, int args)
{
	if (!canUseCore) return Plugin_Handled;

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

	players[client].currentCoinflipAmount = amount;

	DisplayCoinflipMenu(client);

	return Plugin_Handled;
}

public Action CommandKillRewardMessage(int client, int args)
{
	char disabledKillReward[8];
	GetClientCookie(client, DisableCreditKillRewardMessage, disabledKillReward, 8);

	int valueKillReward = StringToInt(disabledKillReward);

	if (valueKillReward == 0)
	{
		PlayersDisabledCreditKillRewardMessage[client] = 1;
		SetClientCookie(client, DisableCreditKillRewardMessage, "1");
		CPrintToChat(client, "%t", HUB_PHRASE_CREDITS_KILL_REWARD_MESSAGE_DISABLED);
	}
	else
	{
		PlayersDisabledCreditKillRewardMessage[client] = 0;
		SetClientCookie(client, DisableCreditKillRewardMessage, "0");
		CPrintToChat(client, "%t", HUB_PHRASE_CREDITS_KILL_REWARD_MESSAGE_ENABLED);
	}

	return Plugin_Handled;
}

public Action CommandRecievedCreditMessage(int client, int args)
{
	char disabledRecievedMessage[8];
	GetClientCookie(client, DisableCreditRecievedMessage, disabledRecievedMessage, 8);

	int valueRecievedMessage = StringToInt(disabledRecievedMessage);

	if (valueRecievedMessage == 0)
	{
		PlayersDisabledCreditRecievedMessage[client] = 1;
		SetClientCookie(client, DisableCreditRecievedMessage, "1");
		CPrintToChat(client, "%t", HUB_PHRASE_CREDITS_RECIEVED_MESSAGE_DISABLED);
	}
	else
	{
		PlayersDisabledCreditRecievedMessage[client] = 0;
		SetClientCookie(client, DisableCreditRecievedMessage, "0");
		CPrintToChat(client, "%t", HUB_PHRASE_CREDITS_RECIEVED_MESSAGE_ENABLED);
	}

	return Plugin_Handled;
}

// Hooks
public void OnPlayerDeath(Event hEvent, char[] strEventName, bool bDontBroadcast)
{
	if (!canUseCore) return;

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

		if (PlayersDisabledCreditKillRewardMessage[client] != 1)
			CPrintToChat(client, "%t", HUB_CREDITS_EARNED_POINTS_DIED, points, attackerName);

		if (PlayersDisabledCreditKillRewardMessage[attacker] != 1)
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
					players[param1].currentCoinflip = COINFLIP_HEAD;
					DecideCoinflip(param1);
				}

				case 1:
				{
					players[param1].currentCoinflip = COINFLIP_TAIL;
					DecideCoinflip(param1);
				}
			}
		}
	}
}