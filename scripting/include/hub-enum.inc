enum struct HubCategories
{
	int id;
	char name[32];
}

enum struct HubItems
{
	int id;
	char name[32];
	char description[128];
	char type[32];
	int categoryId;
	int price;
}

enum struct HubPlayersItems
{
	char steamID[32];
	int itemId;
	bool internal_OwnsItem;
}

enum struct HubPlayers
{
	char steamID[32];
	char name[MAX_NAME_LENGTH];
	char ip[32];
	int	 credits;
}

enum StateSetPlayerItem
{
	GENERIC_ERROR,
	ALREADY_HAS_ITEM,
	NOT_ENOUGH_CREDITS,
	PAID_FOR_ITEM,
}