#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <multicolors>
#include <dbi>
#include <hub>
#include <hub-stock>
#include <hub-enum>
#include <hub-defines>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION		 "1.0.0"
#define PLUGIN_DESCRIPTION "Hub-Shop"

bool		 canUseCore = false;

/* Database */
Database DB;

/* Public Data */
char		 logFile[256], databasePrefix[10] = "hub_";

enum struct PrepareBuying
{
	int itemId;
	int categoryId;
}

HubCategories		hubCategories[MAX_CATEGORIES];
HubItems				hubItems[MAX_CATEGORIES][MAX_ITEMS];
HubPlayersItems hubPlayersItems[MAXPLAYERS + 1][MAX_ITEMS];
PrepareBuying		prepareBuying[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name				= "hub-shop",
	author			= "Tolfx",
	description = PLUGIN_DESCRIPTION,
	version			= PLUGIN_VERSION,
	url					= "https://github.com/Dodgeball-TF/HubCore"
};

public void OnPluginStart()
{
	LoadTranslations("hub.phrases.txt");
	LoadTranslations("hub-shop.phrases.txt");

	// Reg Console Commands
	RegConsoleCmd("sm_shop", CommandShop, "Get our shop list", _);

	// Reg

	BuildPath(Path_SM, logFile, sizeof(logFile), "logs/hub-shop.log");
	if (!SQL_CheckConfig("hub"))
	{
		SetFailState("Database failure: Could not find Database conf \"hub\"");
		return;
	}

	Database.Connect(DatabaseConnectedCallback, "hub");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("hub-dummy");

	CreateNative("Hub_HasPlayerItemName", Native_Hub_HasPlayerItemName);

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

/* Player connections */
public void OnClientPostAdminCheck(int client)
{
	/* Do not check bots nor check player with lan steamid. */
	if (DB == INVALID_HANDLE)
	{
		return;
	}

	BootstrapShopClient(client);
}

public void OnClientDisconnect(int client)
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

void BootstrapShopClient(int client)
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
	Format(Query, sizeof(Query), "SELECT `id`, `name`, `description`, `type`, `price` FROM `%sitems` WHERE `categoryId` = '%d';", databasePrefix, categoryId);

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
	Menu menu				= new Menu(ShopMenuHandler);
	menu.ExitButton = true;

	menu.SetTitle("Shop");

	GetHubCategories();

	for (int i = 0; i < MAX_CATEGORIES; i++)
	{
		char str[8];
		IntToString(hubCategories[i].id, str, sizeof(str));
		if (strcmp(hubCategories[i].name, "") == 0) continue;
		menu.AddItem(str, hubCategories[i].name, ITEMDRAW_DEFAULT);
	}

	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

/* Menus */
public int ShopMenuHandler(Menu menu, MenuAction menuActions, int param1, int param2)
{
	switch (menuActions)
	{
		case MenuAction_Select:
		{
			char strOption[8];
			menu.GetItem(param2, strOption, sizeof(strOption));

			int categoryId									 = StringToInt(strOption);

			prepareBuying[param1].categoryId = categoryId;

			CreateDynamicItemMenu(param1, categoryId);
		}
	}
}

public void CreateDynamicItemMenu(int client, int categoryId)
{
	Menu menu				= new Menu(ItemMenuHandler);
	menu.ExitButton = true;

	menu.SetTitle(hubCategories[categoryId].name);

	int clientCredits = GetPlayerCredits(client);

	GetHubItems(categoryId);

	for (int i = 0; i < MAX_ITEMS; i++)
	{
		char str[8];
		int	 id = hubItems[categoryId][i].id;
		IntToString(i, str, sizeof(str));
		if (strcmp(hubItems[categoryId][i].name, "") == 0) continue;

		char betterName[128];
		Format(betterName, sizeof(betterName), "%s - %d", hubItems[categoryId][id].name, hubItems[categoryId][id].price);

		bool hasEnoughToBuy = clientCredits >= hubItems[categoryId][id].price;
		bool alreadyOwns		= hubPlayersItems[client][id].internal_OwnsItem;

		if (alreadyOwns)
		{
			Format(betterName, sizeof(betterName), "%s - %d (Owned)", hubItems[categoryId][id].name, hubItems[categoryId][id].price);
			menu.AddItem(str, betterName, ITEMDRAW_DISABLED);
			continue;
		}

		bool enable = hasEnoughToBuy;

		menu.AddItem(str, betterName, enable ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int ItemMenuHandler(Menu menu, MenuAction menuActions, int param1, int param2)
{
	switch (menuActions)
	{
		case MenuAction_Select:
		{
			char strOption[8];
			menu.GetItem(param2, strOption, sizeof(strOption));

			prepareBuying[param1].itemId = StringToInt(strOption);

			ConfirmBuyItemMenu(param1);
		}
	}
}

public void ConfirmBuyItemMenu(int client)
{
	Menu menu				= new Menu(ConfirmBuyItemMenuHandler);
	menu.ExitButton = true;

	int	 categoryId = prepareBuying[client].categoryId;
	int	 itemId			= prepareBuying[client].itemId;

	char betterName[128];
	Format(betterName, sizeof(betterName), "%t", HUB_PHRASE_SHOP_CONFIRM_BUY, hubItems[categoryId][itemId].name, hubItems[categoryId][itemId].price);

	menu.SetTitle(betterName);
	menu.AddItem("1", "Yes", ITEMDRAW_DEFAULT);
	menu.AddItem("2", "Cancel", ITEMDRAW_DEFAULT);

	menu.Display(client, MENU_TIME_FOREVER);
}

public int ConfirmBuyItemMenuHandler(Menu menu, MenuAction menuActions, int param1, int param2)
{
	switch (menuActions)
	{
		case MenuAction_Select:
		{
			char strOption[8];
			menu.GetItem(param2, strOption, sizeof(strOption));

			int option = StringToInt(strOption);

			if (option == 1)
			{
				int	 client						= param1;
				int	 cache_categoryId = prepareBuying[client].categoryId;
				int	 cahce_itemId			= prepareBuying[client].itemId;
				char cache_itemName[32];
				Format(cache_itemName, sizeof(cache_itemName), "%s", hubItems[cache_categoryId][cahce_itemId].name);
				StateSetPlayerItem state = SetHubPlayerItem(client);

				switch (state)
				{
					case GENERIC_ERROR:
					{
						CPrintToChat(client, "%t", HUB_PHRASE_SOMETHING_WENT_WRONG);
					}
					case ALREADY_HAS_ITEM:
					{
						CPrintToChat(client, "%t", HUB_PHRASE_YOU_ALREADY_OWN_THIS_ITEM, cache_itemName);
					}
					case NOT_ENOUGH_CREDITS:
					{
						CPrintToChat(client, "%t", HUB_PHRASE_YOU_DONT_HAVE_ENOUGH_CREDITS_TO_BUY_THIS, cache_itemName);
					}
					case PAID_FOR_ITEM:
					{
						CPrintToChat(client, "%t", HUB_PHRASE_SUCCESSFULLY_BOUGHT_ITEM, cache_itemName);
					}
				}
			}
		}
	}
}

// Natives
public int Native_Hub_HasPlayerItemName(Handle plugin, int numParams)
{
	// First param is client we want to check, second is the name of the item.
	if (numParams != 2)
	{
		LogError("Hub_HasPlayerItemName: Invalid number of params %d.", numParams);
		return -1;
	}

	int	 client = GetNativeCell(0);
	char name[32];
	GetNativeString(1, name, sizeof(name));

	// We now want to check if the player has the item.
	for (int i = 0; i < MAX_ITEMS; i++)
	{
		if (strcmp(hubItems[0][i].name, name) == 0)
		{
			if (hubPlayersItems[client][i].internal_OwnsItem)
			{
				return 1;
			}
		}
	}

	return 0;
}

/* Database Callbacks */
public void DatabaseConnectedCallback(Database db, const char[] error, any data)
{
	if (db == INVALID_HANDLE)
	{
		SetFailState("Database failure: %s.", error);
		return;
	}

	DB = db;

	for (int i = 0; i < MAXPLAYERS + 1; i++)
	{
		BootstrapShopClient(i);
	}

	GetHubCategories();
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
		char query[256];
		Format(query, sizeof(query), "SELECT `id`, `name`, `description`, `type`, `price` FROM `%sitems` WHERE `categoryId` = '%d';", databasePrefix, hubCategories[j].id);
		DB.Query(GetHubItemsCallback, query, j);
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

public void ErrorCheckCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		LogToFile(logFile, "Query Failed: %s", error);
	}
}