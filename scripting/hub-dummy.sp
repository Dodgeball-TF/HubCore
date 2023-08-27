#include <sdkhooks>
#include <sdktools>
#include <sourcemod>
#include <hub>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION		 "1.0.0"
#define PLUGIN_DESCRIPTION "Hub-Dummy"

bool canUseCore = false;

public Plugin myinfo =
{
	name				= "hub-dummy",
	author			= "Tolfx",
	description = PLUGIN_DESCRIPTION,
	version			= PLUGIN_VERSION,
	url					= "https://github.com/Dodgeball-TF/HubCore"
};

public void OnPluginStart()
{
	LoadTranslations("hub.phrases.txt");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("hub-dummy");
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