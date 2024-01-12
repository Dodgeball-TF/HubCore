#define MENU_SHOP				 "shop"
#define MENU_PREFERENCES "preferences"
#define MENU_INVENTORY	 "inventory"
#define MENU_GAMBLING		 "gambling"

void MenuOnStart()
{
	RegConsoleCmd("sm_hub", CommandHub, "Opens the hub menu");
}

public Action CommandHub(int client, int args)
{
	ShowHubMenu(client);
	return Plugin_Handled;
}

void ShowHubMenu(int client)
{
	Menu menu = new Menu(MenuHandlerHub, MenuAction_Select | MenuAction_End | MenuAction_DrawItem | MenuAction_DisplayItem);

	menu.SetTitle("%t", "Hub_Menu_Title");

	menu.AddItem(MENU_SHOP, "Hub_Menu_Shop");
	menu.AddItem(MENU_PREFERENCES, "Hub_Menu_Preferences");
	menu.AddItem(MENU_INVENTORY, "Hub_Menu_Inventory");

	menu.Display(client, MENU_TIME_FOREVER);
}

void ShowShopMenu(int client)
{
	Menu menu						= new Menu(MenuHandlerShop);
	menu.ExitButton			= true;
	menu.ExitBackButton = true;

	int	 credits				= GetPlayerCredits(client);

	char title[256];
	Format(title, sizeof(title), "%t", HUB_PHRASE_SHOP_TITLE, credits);

	menu.SetTitle(title);

	GetHubCategories();

	for (int i = 0; i < MAX_CATEGORIES; i++)
	{
		char str[8];
		IntToString(hubCategories[i].id, str, sizeof(str));
		if (strcmp(hubCategories[i].name, "") == 0) continue;
		menu.AddItem(str, hubCategories[i].name, ITEMDRAW_DEFAULT);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

void ShowPreferencesMenu(int client)
{
	Menu menu						= new Menu(MenuHandlerPreferences, MenuAction_Select | MenuAction_End);
	menu.ExitBackButton = true;

	menu.SetTitle("%t", "Hub_Menu_Preferences");

	for (int i = 0; i < sizeof(preferenceData); i++)
	{
		char info[4];
		if (IntToString(i, info, sizeof(info)) > 0)
		{
			char preferenceName[128], display[128];
			Format(preferenceName, sizeof(preferenceName), "%s", preferenceData[i]);

			Cookie cookie			 = GetCookieByName(preferenceName);
			int		 cookieValue = GetCookieValue(client, cookie);

			if (cookieValue == 0)
				Format(display, sizeof(display), "☐ %t", preferenceName, client);
			else
				Format(display, sizeof(display), "☑ %t", preferenceName, client);

			menu.AddItem(info, display, ITEMDRAW_DEFAULT);
		}
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

void ShowGamblingMenu(int client)
{}

void ShowInventoryMenu(int client)
{
	Menu menu						= new Menu(MenuHandlerInventory);
	menu.ExitButton			= true;
	menu.ExitBackButton = true;

	char title[256];
	Format(title, sizeof(title), "%t", "Hub_Menu_Inventory");

	menu.SetTitle(title);

	GetHubCategories();

	for (int i = 0; i < MAX_CATEGORIES; i++)
	{
		char str[8];
		IntToString(hubCategories[i].id, str, sizeof(str));
		if (strcmp(hubCategories[i].name, "") == 0) continue;
		menu.AddItem(str, hubCategories[i].name, ITEMDRAW_DEFAULT);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

/* Menu Handlers */
public int MenuHandlerHub(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[64];
			menu.GetItem(param2, info, sizeof(info));

			if (StrEqual(info, MENU_SHOP))
			{
				ShowShopMenu(param1);
			}

			if (StrEqual(info, MENU_PREFERENCES))
			{
				ShowPreferencesMenu(param1);
			}

			if (StrEqual(info, MENU_INVENTORY))
			{
				ShowInventoryMenu(param1);
			}

			if (StrEqual(info, MENU_GAMBLING))
			{
				ShowGamblingMenu(param1);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
		case MenuAction_DisplayItem:
		{
			char info[64], display[128];
			menu.GetItem(param2, info, sizeof(info), _, display, sizeof(display));

			Format(display, sizeof(display), "%T", display, param1);
			return RedrawMenuItem(display);
		}
	}

	return 0;
}

// Shops related content
public int MenuHandlerShop(Menu menu, MenuAction menuActions, int param1, int param2)
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

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				ShowHubMenu(param1);
		}
	}

	return 1;
}

public void CreateDynamicItemMenu(int client, int categoryId)
{
	Menu menu						= new Menu(ItemMenuHandler);
	menu.ExitButton			= true;
	menu.ExitBackButton = true;

	menu.SetTitle(hubCategories[categoryId].name);

	int clientCredits = GetPlayerCredits(client);

	GetHubItems(categoryId);

	// Create an array for indices
	int itemIndices[MAX_ITEMS];
	for (int i = 0; i < MAX_ITEMS; i++)
	{
		itemIndices[i] = i;	 // Initialize with the index
	}

	// Bubble Sort to sort indices based on price
	for (int i = 0; i < MAX_ITEMS - 1; i++)
	{
		for (int j = 0; j < MAX_ITEMS - i - 1; j++)
		{
			if (hubItems[categoryId][itemIndices[j]].price > hubItems[categoryId][itemIndices[j + 1]].price)
			{
				// Swap the indices
				int temp					 = itemIndices[j];
				itemIndices[j]		 = itemIndices[j + 1];
				itemIndices[j + 1] = temp;
			}
		}
	}

	// Now add items to the menu using the sorted indices
	for (int i = 0; i < MAX_ITEMS; i++)
	{
		int	 sortedIndex = itemIndices[i];
		char str[8];
		int	 id = hubItems[categoryId][sortedIndex].id;
		IntToString(sortedIndex, str, sizeof(str));
		if (strcmp(hubItems[categoryId][sortedIndex].name, "") == 0) continue;

		char betterName[128];
		Format(betterName, sizeof(betterName), "%s - %d", hubItems[categoryId][sortedIndex].name, hubItems[categoryId][sortedIndex].price);

		bool hasEnoughToBuy = clientCredits >= hubItems[categoryId][sortedIndex].price;
		bool alreadyOwns		= hubPlayersItems[client][id].internal_OwnsItem;

		if (alreadyOwns)
		{
			Format(betterName, sizeof(betterName), "%s - %d (Owned)", hubItems[categoryId][sortedIndex].name, hubItems[categoryId][sortedIndex].price);
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

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				ShowShopMenu(param1);
		}
	}

	return 1;
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

	return 1;
}

// Preferences related content
public int MenuHandlerPreferences(Menu menu, MenuAction menuActions, int param1, int param2)
{
	switch (menuActions)
	{
		case MenuAction_Select:
		{
			char strOption[8];
			menu.GetItem(param2, strOption, sizeof(strOption));

			int	 option = StringToInt(strOption);
			char preferenceName[128];
			Format(preferenceName, sizeof(preferenceName), "%s", preferenceData[option]);

			char preferenceFormatted[128];
			Format(preferenceFormatted, sizeof(preferenceFormatted), "%t", preferenceName, param1);

			Cookie cookie = GetCookieByName(preferenceName);
			int		 value	= GetCookieValue(param1, cookie);

			if (value == 1)
			{
				SetCookieValue(param1, cookie, "0");
				CPrintToChat(param1, "%t", "Hub_Preference_Disabled", preferenceFormatted);
			}
			else
			{
				SetCookieValue(param1, cookie, "1");
				CPrintToChat(param1, "%t", "Hub_Preference_Enabled", preferenceFormatted);
			}

			ShowPreferencesMenu(param1);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				ShowHubMenu(param1);
		}
	}

	return 1;
}

// Inventory related content
public int MenuHandlerInventory(Menu menu, MenuAction menuActions, int param1, int param2)
{
	switch (menuActions)
	{
		case MenuAction_Select:
		{
			char strOption[8];
			menu.GetItem(param2, strOption, sizeof(strOption));

			int categoryId = StringToInt(strOption);

			CreateInventoryItemsMenu(param1, categoryId);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				ShowHubMenu(param1);
		}
	}

	return 1;
}

public void CreateInventoryItemsMenu(int client, int categoryId)
{
	// Get the items this user has on this category
	GetHubItems(categoryId);

	Menu menu						= new Menu(MenuHandlerInventoryItem);
	menu.ExitButton			= true;
	menu.ExitBackButton = true;

	menu.SetTitle(hubCategories[categoryId].name);

	for (int i = 0; i < MAX_ITEMS; i++)
	{
		char str[8];
		IntToString(i, str, sizeof(str));
		if (strcmp(hubItems[categoryId][i].name, "") == 0) continue;

		char betterName[128];
		Format(betterName, sizeof(betterName), "%s", hubItems[categoryId][i].name);

		bool ownsItem = hubPlayersItems[client][i].internal_OwnsItem;

		if (!ownsItem)
			continue;

		menu.AddItem(str, betterName, ITEMDRAW_DEFAULT);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandlerInventoryItem(Menu menu, MenuAction menuActions, int param1, int param2)
{
	switch (menuActions)
	{
		case MenuAction_Select:
		{
			char strOption[8];
			menu.GetItem(param2, strOption, sizeof(strOption));

			int itemId = StringToInt(strOption);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				ShowInventoryMenu(param1);
		}
	}

	return 1;
}
