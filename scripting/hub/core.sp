
void CoreOnStart()
{
	// Load translations
	LoadTranslations("hub.phrases.txt");

	BuildPath(Path_SM, logFile, sizeof(logFile), "logs/hub.log");
	// g_connectingToDatabase = true;
	if (!SQL_CheckConfig("hub"))
	{
		LogToFile(logFile, "Database failure: Could not find Database conf \"hub\".");
		SetFailState("Database failure: Could not find Database conf \"hub\"");
		return;
	}

	Database.Connect(DatabaseConnectedCallback, "hub");
}

void CoreAskPluginLoad2()
{
	CreateNative("GetPlayerCredits", Native_GetPlayerCredits);
	CreateNative("SetPlayerCredits", Native_SetPlayerCredits);
	CreateNative("AddPlayerCredits", Native_AddPlayerCredits);
	CreateNative("RemovePlayerCredits", Native_RemovePlayerCredits);
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

	// Added because it doesn't really update unlessed called again.
	// Not entirely sure but a fix for now.
	GetPlayerCredits(client);

	return 1;
}

public int RemovePlayerCredits(int client, int credits)
{
	if (!IsValidPlayer(client))
	{
		LogError("RemovePlayerCredits: Invalid client %d.", client);
		return 0;
	}

	int currentCredits = GetPlayerCredits(client);

	SetPlayerCredits(client, currentCredits - credits);

	return 1;
}

public int AddPlayerCredits(int client, int credits)
{
	if (!IsValidPlayer(client))
	{
		LogError("AddPlayerCredits: Invalid client %d.", client);
		return 0;
	}

	int currentCredits = GetPlayerCredits(client);

	SetPlayerCredits(client, currentCredits + credits);

	return 1;
}

public void CoreBootstrapClient(int client)
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

public void DatabaseConnectedCallback(Database db, const char[] error, any data)
{
	if (db == INVALID_HANDLE)
	{
		LogToFile(logFile, "Database failure: %s.", error);
		// g_connectingToDatabase = false;
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

	// This plugin should also handle the items that players can buy, so we will need a table for that.
	// So we will have a table for "items" amd "categories" for the items.
	// We have categories that has an ID and name only, then items that have unique id, name, description, type, categoryId and price
	// We will also need a table for every item that a player has, so we can keep track of what they have.
	Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%scategories` (`id` INT NOT NULL AUTO_INCREMENT, `name` VARCHAR(32) NOT NULL, PRIMARY KEY (`id`)) ENGINE = InnoDB;", databasePrefix);
	DB.Query(ErrorCheckCallback, query);

	Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%sitems` (`id` INT NOT NULL AUTO_INCREMENT, `name` VARCHAR(32) NOT NULL, `description` VARCHAR(128) NOT NULL, `type` VARCHAR(32) NOT NULL, `categoryId` INT NOT NULL, `price` INT NOT NULL, PRIMARY KEY (`id`)) ENGINE = InnoDB;", databasePrefix);
	DB.Query(ErrorCheckCallback, query);

	// We should also include if is equiped or not. Default of it should be false.
	Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS `%splayer_items` (`steamid` VARCHAR(32) NOT NULL, `itemId` INT NOT NULL, `equiped` BOOLEAN NOT NULL DEFAULT FALSE, PRIMARY KEY (`steamid`, `itemId`)) ENGINE = InnoDB;", databasePrefix);
	DB.Query(ErrorCheckCallback, query);

	// Bootstrap all players in the server.
	for (int i = 1; i <= MaxClients; i++)
	{
		CoreBootstrapClient(i);
		ShopBootstrapClient(i);
		CreditsBootstrapClient(i);
	}

	GetHubCategories();
}

/* Database Callbacks */
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