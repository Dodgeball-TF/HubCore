#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <dbi>
#include <hub-stock>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION		 "1.0.0"
#define PLUGIN_DESCRIPTION "Hub-Core is the core plugin for the hub plugins."

enum struct HubPlayers
{
	char steamID[32];
	char name[MAX_NAME_LENGTH];
	char ip[32];
	int	 credits;
}

HubPlayers hubPlayers[MAXPLAYERS + 1];

/* Database */
Database	 DB;

/* Public Data */
char			 logFile[256], databasePrefix[10] = "hub_";

/**
 * If we are connecting to the database.
 */
bool			 g_connectingToDatabase = false;

public Plugin myinfo =
{
	name				= "hub-core",
	author			= "Tolfx",
	description = PLUGIN_DESCRIPTION,
	version			= PLUGIN_VERSION,
	url					= "https://github.com/Dodgeball-TF/HubCore"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("hub-core");

	// Forwards
	// Natives
	CreateNative("GetPlayerCredits", Native_GetPlayerCredits);
	CreateNative("SetPlayerCredits", Native_SetPlayerCredits);
	CreateNative("AddPlayerCredits", Native_AddPlayerCredits);
	CreateNative("RemovePlayerCredits", Native_RemovePlayerCredits);

	return APLRes_Success;
}

public void OnPluginStart()
{
	// Load translations
	LoadTranslations("hub.phrases.txt");
	// Create convars

	// Reg admin commands

	// Connect to database

	BuildPath(Path_SM, logFile, sizeof(logFile), "logs/hub-core.log");
	g_connectingToDatabase = true;
	if (!SQL_CheckConfig("hub"))
	{
		LogToFile(logFile, "Database failure: Could not find Database conf \"hub\".");
		SetFailState("Database failure: Could not find Database conf \"hub\"");
		return;
	}

	Database.Connect(DatabaseConnectedCallback, "hub");
}

/* Player connections */
public void OnClientPostAdminCheck(int client)
{
	/* Do not check bots nor check player with lan steamid. */
	if (DB == INVALID_HANDLE)
	{
		return;
	}

	BootStrapClient(client);
}

public void OnClientDisconnect(int client)
{
	if (!IsValidPlayer(client)) return;

	// Remove the player from the hubPlayers array.
	hubPlayers[client].steamID = "";
	hubPlayers[client].name		 = "";
	hubPlayers[client].ip			 = "";
	hubPlayers[client].credits = 0;
}

/* Methods */
public int GetPlayerCredits(int client)
{
	if (client < 1 || client > MaxClients)
	{
		LogError("GetPlayerCredits: Invalid client %d.", client);
		return -1;
	}

	char steamID[32];
	GetSteamId(client, steamID, sizeof(steamID));

	char Query[256];
	Format(Query, sizeof(Query), "SELECT `credits` FROM `%scredits` WHERE `steamid` = '%s';", databasePrefix, steamID);

	DB.Query(GetPlayerCreditsCallback, Query, client);

	return hubPlayers[client].credits;
}

public int SetPlayerCredits(int client, int credits)
{
	if (client < 1 || client > MaxClients)
	{
		LogError("GetPlayerCredits: Invalid client %d.", client);
		return -1;
	}

	char steamID[32];
	GetSteamId(client, steamID, sizeof(steamID));

	char Query[256];
	Format(Query, sizeof(Query), "UPDATE `%scredits` SET `credits` = '%d' WHERE `steamid` = '%s';", databasePrefix, credits, steamID);

	DB.Query(ErrorCheckCallback, Query);

	hubPlayers[client].credits = credits;

	GetPlayerCredits(client);

	return 1;
}

public void BootStrapClient(int client)
{
	// Check if client is valid.
	if (!IsValidPlayer(client))
	{
		return;
	}

	char Query[256], ip[32], name[32];
	char steamID[32];

	GetClientIP(client, ip, sizeof(ip));
	GetSteamId(client, steamID, sizeof(steamID));
	GetClientName(client, name, sizeof(name));

	Format(Query, sizeof(Query), "INSERT INTO `%splayers` (`steamid`, `name`, `ip`) VALUES ('%s', '%s', '%s') ON DUPLICATE KEY UPDATE `name` = '%s', `ip` = '%s';", databasePrefix, steamID, name, ip, name, ip);
	DB.Query(ErrorCheckCallback, Query);

	hubPlayers[client].steamID = steamID;
	hubPlayers[client].name		 = name;
	hubPlayers[client].ip			 = ip;

	GetPlayerCredits(client);
}

/* Natives */
public int Native_GetPlayerCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
	{
		LogError("GetPlayerCredits: Invalid client %d.", client);
		return 0;
	}

	GetPlayerCredits(client);

	return hubPlayers[client]
		.credits;
}

public int Native_SetPlayerCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
	{
		LogError("SetPlayerCredits: Invalid client %d.", client);
		return 0;
	}

	int credits = GetNativeCell(2);

	if (credits < 0)
	{
		LogError("SetPlayerCredits: Invalid credits %d.", credits);
		return 0;
	}

	SetPlayerCredits(client, credits);

	return 1;
}

public int Native_AddPlayerCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
	{
		LogError("AddPlayerCredits: Invalid client %d.", client);
		return 0;
	}

	int credits = GetNativeCell(2);

	if (credits < 0)
	{
		LogError("AddPlayerCredits: Invalid credits %d.", credits);
		return 0;
	}

	int currentCredits = GetPlayerCredits(client);

	SetPlayerCredits(client, currentCredits + credits);

	return 1;
}

public int Native_RemovePlayerCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
	{
		LogError("RemovePlayerCredits: Invalid client %d.", client);
		return 0;
	}

	int credits = GetNativeCell(2);

	if (credits < 0)
	{
		LogError("RemovePlayerCredits: Invalid credits %d.", credits);
		return 0;
	}

	int currentCredits = GetPlayerCredits(client);

	SetPlayerCredits(client, currentCredits - credits);

	return 1;
}

/* Database Callbacks */
public void DatabaseConnectedCallback(Database db, const char[] error, any data)
{
	if (db == INVALID_HANDLE)
	{
		LogToFile(logFile, "Database failure: %s.", error);
		g_connectingToDatabase = false;
		SetFailState("Database failure: %s.", error);
		return;
	}

	LogToFile(logFile, "Database connected.");

	DB = db;

	// This plugin will be a hub plugin, this means it will handle a lot of stuff, mainly now we want a
	// ground base for players to connect to the server, and then we can build on top of that.
	// so lets make a table for players to connect to the server.
	// We will need a unique id when they join, so we will use their steamid. We should
	// also store their name, and their ip address.

	char query[256];

	Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%splayers` (`steamid` VARCHAR(32) NOT NULL, `name` VARCHAR(32) NOT NULL, `ip` VARCHAR(32) NOT NULL, PRIMARY KEY (`steamid`)) ENGINE = InnoDB;", databasePrefix);
	DB.Query(ErrorCheckCallback, query);

	// This plugin will also handle "credits" for players, we will need a table to store these credits for each player,
	Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%scredits` (`steamid` VARCHAR(32) NOT NULL, `credits` INT NOT NULL, PRIMARY KEY (`steamid`)) ENGINE = InnoDB;", databasePrefix);
	DB.Query(ErrorCheckCallback, query);

	// We also want a table for keep times of events, such as when last time they used /daily
	Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%stimes` (`steamid` VARCHAR(32) NOT NULL, `daily` INT NOT NULL, PRIMARY KEY (`steamid`)) ENGINE = InnoDB;", databasePrefix);
	DB.Query(ErrorCheckCallback, query);

	g_connectingToDatabase = false;

	// Bootstrap all players in the server.
	for (int i = 1; i <= MaxClients; i++)
	{
		BootStrapClient(i);
	}
}

public void GetPlayerCreditsCallback(Database db, DBResultSet results, const char[] error, int data)
{
	if (results == null)
	{
		LogToFile(logFile, "Query Failed: %s", error);
		// We failed to get the credits, so lets just set it to 0.
		hubPlayers[data].credits = 0;
		// We should try to make a query to create a new row for this player.
		char query[256];
		Format(query, sizeof(query), "INSERT INTO `%scredits` (`steamid`, `credits`) VALUES ('%s', '0');", databasePrefix, hubPlayers[data].steamID);
		DB.Query(ErrorCheckCallback, query);
		return;
	}

	// if we have no rows, then we need to create a new row for this player.
	if (!results.MoreRows)
	{
		// We failed to get the credits, so lets just set it to 0.
		hubPlayers[data].credits = 0;
		// We should try to make a query to create a new row for this player.
		char query[256];
		Format(query, sizeof(query), "INSERT INTO `%scredits` (`steamid`, `credits`) VALUES ('%s', '0');", databasePrefix, hubPlayers[data].steamID);
		DB.Query(ErrorCheckCallback, query);
		return;
	}

	int client	= data;
	int credits = 0;

	while (results.FetchRow())
	{
		credits = results.FetchInt(0);
	}

	hubPlayers[client].credits = credits;
}

public void ErrorCheckCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogToFile(logFile, "Query Failed: %s", error);
	}
}