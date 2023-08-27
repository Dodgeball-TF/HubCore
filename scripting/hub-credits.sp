#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <hub>
#include <hub-stock>
#include <multicolors>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION		 "1.0.0"
#define PLUGIN_DESCRIPTION "Hub-Credits"

ConVar Hub_Credits_Minute;
ConVar Hub_Credits_Amount;
ConVar Hub_Credits_Coinflip_Multiplier;

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

	// Create ConVars
	Hub_Credits_Minute							= CreateConVar("hub_credits_minute", "5", "How many credits to give per minute.");
	Hub_Credits_Amount							= CreateConVar("hub_credits_amount", "100", "How many credits to give per minute.");
	Hub_Credits_Coinflip_Multiplier = CreateConVar("hub_credits_coinflip_multiplier", "1.2", "How much to multiply the coinflip amount by.");

	HookConVarChange(Hub_Credits_Minute, Credits_Minute_Change);

	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		BootStrapClient(i);
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

		BootStrapClient(i);
	}
}

public void OnClientDisconnect(int client)
{
	if (!IsValidPlayer(client)) return;

	CloseHandle(players[client].currentCreditsPerMinute);
}

public void OnClientPostAdminCheck(int client)
{
	BootStrapClient(client);
}

/* Timers */
public Action Timer_Credits(Handle timer, int client)
{
	if (!canUseCore) return Plugin_Continue;
	int amount = Hub_Credits_Amount.IntValue;

	if (amount <= 0) return Plugin_Continue;

	LogMessage("Giving %i credits to %i", amount, client);

	AddPlayerCredits(client, amount);

	CPrintToChat(client, "%t", "Hub_Player_Recieve_Credits", amount);

	return Plugin_Continue;
}

/* Methods */
public void BootStrapClient(int client)
{
	if (!IsValidPlayer(client)) return;
	float minToSecond												= Hub_Credits_Minute.FloatValue * 60;
	players[client].currentCreditsPerMinute = CreateTimer(minToSecond, Timer_Credits, client, TIMER_REPEAT);
}

public void DecideCoinflip(int client)
{
	if (!IsValidPlayer(client)) return;

	int amount = players[client].currentCoinflipAmount;

	if (amount <= 0) return;

	int currentAmount = GetPlayerCredits(client);

	if (amount > currentAmount)
	{
		CPrintToChat(client, "%t", "Hub_Credits_Coinflip_Not_Enough_Credits");
		return;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	int random = GetRandomInt(0, 1);

	if (random == players[client].currentCoinflip)
	{
		float newAmount = amount * Hub_Credits_Coinflip_Multiplier.FloatValue;
		AddPlayerCredits(client, RoundToCeil(newAmount));
		CPrintToChatAll("%t", "Hub_Credits_Coinflip_Win", RoundToCeil(newAmount), name);
	}
	else
	{
		RemovePlayerCredits(client, amount);
		CPrintToChatAll("%t", "Hub_Credits_Coinflip_Lose", amount, name);
	}

	// Clean up
	players[client].currentCoinflip				= INVALID_HANDLE;
	players[client].currentCoinflipAmount = INVALID_HANDLE;
}

/* Commands */
public Action Cmd_Credits(int client, int args)
{
	if (!canUseCore) return Plugin_Handled;

	int	 credits = GetPlayerCredits(client);

	char name[32];
	GetClientName(client, name, sizeof(name));

	// Send message back to client
	CPrintToChatAll("%t", "Hub_Player_Credits", credits, name);

	return Plugin_Handled;
}

public Action Cmd_Coinflip(int client, int args)
{
	if (!canUseCore) return Plugin_Handled;

	if (args < 1)
	{
		CPrintToChat(client, "%t", "Hub_Credits_Coinflip_Usage");
		return Plugin_Handled;
	}

	int currentAmount = GetPlayerCredits(client);
	int amount				= GetCmdArgInt(1);

	// Can't bet more than you have
	if (amount > currentAmount)
	{
		CPrintToChat(client, "%t", "Hub_Credits_Coinflip_Not_Enough_Credits");
		return Plugin_Handled;
	}

	players[client].currentCoinflipAmount = amount;

	DisplayCoinflipMenu(client);

	return Plugin_Handled;
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