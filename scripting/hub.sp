#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <dbi>
#include <hub-stock>
#include <hub-enum>
#include <hub-defines>
#include <clientprefs>
#include <multicolors>
#include <FootPrint>
#include <trails-chroma>
#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION		 "2.0.0"
#define PLUGIN_DESCRIPTION "Hub is the core plugin for the hub plugins."

HubPlayers			hubPlayers[MAXPLAYERS + 1];

// Credits
ConVar					Hub_Credits_Minute;
ConVar					Hub_Credits_Amount;
ConVar					Hub_Credits_Coinflip_Multiplier;
// Get credits when you kill someone, either enabled or not.
// When a player gets killed we take their points
ConVar					Hub_Credits_Kill_For_Credits;
ConVar					Hub_Credits_Kill_For_Credits_Points;

// Shop
HubCategories		hubCategories[MAX_CATEGORIES];
HubItems				hubItems[MAX_CATEGORIES][MAX_ITEMS];
HubPlayersItems hubPlayersItems[MAXPLAYERS + 1][MAX_ITEMS];
PrepareBuying		prepareBuying[MAXPLAYERS + 1];

/* Database */
Database				DB;

/* Public Data */
char						logFile[256], databasePrefix[10] = "hub_";

char						preferenceData[][] = {
	 HUB_COOKIE_DISABLED_CREDIT_KILL_REWARD_MESSAGE,
	 HUB_COOKIE_DISABLED_CREDIT_RECEIVED_MESSAGE,
	 HUB_COOKIE_TRAIL_HIDING
};

#include "hub/core.sp"
#include "hub/cookies.sp"
#include "hub/credits.sp"
#include "hub/shop.sp"
#include "hub/menu.sp"

/**
 * If we are connecting to the database.
 */
// bool			 g_connectingToDatabase = false;
public Plugin myinfo =
{
	name				= "hub",
	author			= "Tolfx",
	description = PLUGIN_DESCRIPTION,
	version			= PLUGIN_VERSION,
	url					= "https://github.com/Dodgeball-TF/HubCore"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("hub");

	// Plugins Loading
	CoreAskPluginLoad2();
	CreditsAskPluginLoad2();
	ShopAskPluginLoad2();

	return APLRes_Success;
}

public void OnPluginStart()
{
	// Load translations
	LoadTranslations("hub.phrases.txt");

	// Plugins Loading
	CoreOnStart();
	CookieOnStart();
	CreditsOnStart();
	ShopOnStart();
	MenuOnStart();
}

/* Player connections */
public void OnClientPostAdminCheck(int client)
{
	/* Do not check bots nor check player with lan steamid. */
	if (DB == INVALID_HANDLE)
	{
		return;
	}

	// Is client valid
	if (!IsValidPlayer(client))
	{
		return;
	}

	CoreBootstrapClient(client);
	CreditsOnClientPostAdminCheck(client);
	ShopOnClientPostAdminCheck(client);
	CookieOnClientPostAdminCheck(client);
}

public void OnClientDisconnect(int client)
{
	if (!IsValidPlayer(client)) return;

	// Remove the player from the hubPlayers array.
	hubPlayers[client].steamID = "";
	hubPlayers[client].name		 = "";
	hubPlayers[client].ip			 = "";
	hubPlayers[client].credits = 0;

	// Add each plugin own callback too
	CreditsOnClientDisconnect(client);
	ShopOnClientDisconnect(client);
}

public void ErrorCheckCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogToFile(logFile, "Query Failed: %s", error);
	}
}
