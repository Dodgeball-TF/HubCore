
enum struct PrepareBuying
{
	int itemId;
	int categoryId;
}

void ShopOnStart()
{
	LoadTranslations("hub-shop.phrases.txt");

	// Reg Console Commands
	RegConsoleCmd("sm_shop", CommandShop, "Get our shop list", _);
	RegConsoleCmd("sm_store", CommandShop, "Get our shop list", _);
}

void ShopAskPluginLoad2()
{
	CreateNative("Hub_HasPlayerItemName", Native_Hub_HasPlayerItemName);
}

/* Player connections */
void ShopOnClientPostAdminCheck(int client)
{
	ShopBootstrapClient(client);
}

void ShopOnClientDisconnect(int client)
{
	if (!IsValidPlayer(client)) return;

	PrepareBuying prepareBuying_;
	prepareBuying[client] = prepareBuying_;
	for (int i = 0; i < MAX_ITEMS; i++)
	{
		hubPlayersItems[client][i].itemId						 = 0;
		hubPlayersItems[client][i].steamID					 = "";
		hubPlayersItems[client][i].internal_OwnsItem = false;
	}
}

/* Methods */
void GetHubCategories()
{
	char Query[256];
	Format(Query, sizeof(Query), "SELECT `id`, `name` FROM `%scategories`;", databasePrefix);

	DB.Query(GetHubCategoriesCallback, Query);
}

void ShopBootstrapClient(int client)
{
	if (!IsValidPlayer(client))
	{
		return;
	}

	// Get the players items.
	GetHubPlayerItems(client);
}

void GetHubItems(int categoryId)
{
	char Query[256];
	Format(Query, sizeof(Query), "SELECT `id`, `name`, `description`, `type`, `price` FROM `%sitems` WHERE `categoryId` = '%d' ORDER BY `price` ASC;", databasePrefix, categoryId);

	DB.Query(GetHubItemsCallback, Query, categoryId);
}

void GetHubPlayerItems(int client)
{
	if (client < 1 || client > MaxClients)
	{
		LogError("GetHubPlayerItem: Invalid client %d.", client);
		return;
	}

	char steamID[32];
	GetSteamId(client, steamID, sizeof(steamID));

	char Query[256];
	Format(Query, sizeof(Query), "SELECT `itemId` FROM `%splayer_items` WHERE `steamid` = '%s';", databasePrefix, steamID);

	DB.Query(GetHubPlayerItemCallback, Query, client);
}

StateSetPlayerItem SetHubPlayerItem(int client, bool drawMoney = true)
{
	if (client < 1 || client > MaxClients)
	{
		LogError("SetHubPlayerItem: Invalid client %d.", client);
		return GENERIC_ERROR;
	}

	int itemId		 = prepareBuying[client].itemId;
	int categoryId = prepareBuying[client].categoryId;

	if (drawMoney)
	{
		// Find category id for item.

		// Check if player already has item.
		for (int i = 0; i < MAX_ITEMS; i++)
		{
			if (hubPlayersItems[client][i].itemId == itemId)
			{
				if (hubPlayersItems[client][i].internal_OwnsItem)
				{
					LogError("SetHubPlayerItem: Player already has item %d.", itemId);
					return ALREADY_HAS_ITEM;
				}
			}
		}

		// Check if player has enough credits.
		int credits = GetPlayerCredits(client);

		if (credits < hubItems[categoryId][itemId].price)
		{
			LogError("SetHubPlayerItem: Player does not have enough credits to buy item %d.", itemId);
			return NOT_ENOUGH_CREDITS;
		}

		// Remove credits from player.
		SetPlayerCredits(client, credits - hubItems[categoryId][itemId].price);
	}

	char steamID[32];
	GetSteamId(client, steamID, sizeof(steamID));

	char Query[256];
	Format(Query, sizeof(Query), "INSERT INTO `%splayer_items` (`steamid`, `itemId`) VALUES ('%s', '%d') ON DUPLICATE KEY UPDATE `itemId` = '%d';", databasePrefix, steamID, itemId, itemId);

	DB.Query(ErrorCheckCallback, Query);

	// Set the item in the array.
	hubPlayersItems[client][itemId].itemId						= itemId;
	hubPlayersItems[client][itemId].steamID						= steamID;
	hubPlayersItems[client][itemId].internal_OwnsItem = true;

	PrepareBuying prepareBuying_;
	prepareBuying[client] = prepareBuying_;

	return PAID_FOR_ITEM;
}

/* Commands */
public Action CommandShop(int client, int args)
{
	ShowShopMenu(client);
	return Plugin_Handled;
}

// Natives
public int Native_Hub_HasPlayerItemName(Handle plugin, int numParams)
{
	int	 client = GetNativeCell(1);
	char category[32];
	GetNativeString(2, category, sizeof(category));
	char name[32];
	GetNativeString(3, name, sizeof(name));

	// Get the category id.
	int categoryId = -1;
	for (int i = 0; i < MAX_CATEGORIES; i++)
	{
		if (strcmp(hubCategories[i].name, category) == 0)
		{
			categoryId = hubCategories[i].id;
			break;
		}
	}

	// We now want to check if the player has the item.
	for (int i = 0; i < MAX_ITEMS; i++)
	{
		if (strcmp(hubItems[categoryId][i].name, name) == 0)
		{
			if (hubPlayersItems[client][i].internal_OwnsItem)
			{
				return 1;
			}
		}
	}

	return 0;
}

public void GetHubCategoriesCallback(Database db, DBResultSet results, const char[] error, int data)
{
	if (results == null)
	{
		LogToFile(logFile, "Query Failed: %s", error);
		return;
	}

	int	 i = 0;
	char name[32];

	while (results.FetchRow())
	{
		hubCategories[i].id = results.FetchInt(0);
		results.FetchString(1, name, sizeof(name));
		hubCategories[i].name = name;
		i++;
	}

	// Now we have the categories, we can get the items for each category.
	for (int j = 0; j < i; j++)
	{
		GetHubItems(hubCategories[j].id);
	}
}

public void GetHubItemsCallback(Database db, DBResultSet results, const char[] error, int data)
{
	if (results == null)
	{
		LogToFile(logFile, "Query Failed: %s", error);
		return;
	}

	int	 i = data;
	int	 j = 0;

	char name[32], description[128], type[32];

	while (results.FetchRow())
	{
		int id						 = results.FetchInt(0);
		hubItems[i][id].id = id;
		results.FetchString(1, name, sizeof(name));
		hubItems[i][id].name = name;
		results.FetchString(2, description, sizeof(description));
		hubItems[i][id].description = description;
		results.FetchString(3, type, sizeof(type));
		hubItems[i][id].type	= type;
		hubItems[i][id].price = results.FetchInt(4);
		j++;
	}
}

public void GetHubPlayerItemCallback(Database db, DBResultSet results, const char[] error, int data)
{
	if (results == null)
	{
		LogToFile(logFile, "Query Failed: %s", error);
		return;
	}

	int	 client = data;
	int	 i			= 0;
	char steamID[32];
	char name[32];

	GetClientName(client, name, sizeof(name));
	GetSteamId(client, steamID, sizeof(steamID));

	while (results.FetchRow())
	{
		int itemId																				= results.FetchInt(0);
		hubPlayersItems[client][itemId].itemId						= itemId;
		hubPlayersItems[client][itemId].steamID						= steamID;
		hubPlayersItems[client][itemId].internal_OwnsItem = true;
		i++;
	}
}