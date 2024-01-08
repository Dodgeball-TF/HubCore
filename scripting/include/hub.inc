/**
 * Gets player credits
 * 
 * @param client The client index
 * @return The player credits
 */
native int GetPlayerCredits(int client);

/**
 * Sets player credits
 * 
 * @param client The client index
 * @param credits The new player credits
 * @return 1 on success, 0 on failure
 */
native int SetPlayerCredits(int client, int credits);

/**
 * Adds credits to a player
 *  
 * @param client The client index
 * @param credits The credits to add
 * @return 1 on success, 0 on failure
 */
native int AddPlayerCredits(int client, int credits);

/**
 * Removes credits from a player
 *  
 * @param client The client index
 * @param credits The credits to remove
 * @return 1 on success, 0 on failure
 */
native int RemovePlayerCredits(int client, int credits);

/**
 * Gets the categories of the hub
 * 
 * @return The categories of the hub
 */
native int Hub_GetHubCategory(int index, any[] hubCategories, int size = sizeof(HubCategories));

/**
 * Gets the items of a hub category
 * 
 * @param index The category index
 * @return The items of the hub category
 * @note The category index is the index of the category in the array returned by Hub_GetHubCategory
 */
native int Hub_GetHubItem(int index, int categoryId, any[] hubItems, int size = sizeof(HubItems));

/**
 * Gets the name of a hub category
 * 
 * @param client The client index
 * @return The players items
 */
native any Hub_GetHubPlayerItem(int client, any[] hubplayersItems, int size = sizeof(HubPlayersItems));

/**
 * Checks if the client has the item
 * 
 * @param client The client index
 * @param name The item name
 * @return 1 if the client has the item, 0 if not
 */
native int Hub_HasPlayerItemName(int client, char[] name);