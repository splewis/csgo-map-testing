#include <cstrike>
#include <sdktools>

#if !defined PLUGIN_VERSION
#define PLUGIN_VERSION "0.1.1-dev"
#endif

#define DEBUG_CVAR "sm_maptesting_debug"
#define MAX_INTEGER_STRING_LENGTH 16
#define MAX_FLOAT_STRING_LENGTH 32

static char _colorNames[][] = {"{NORMAL}", "{DARK_RED}", "{PINK}", "{GREEN}", "{YELLOW}", "{LIGHT_GREEN}", "{LIGHT_RED}", "{GRAY}", "{ORANGE}", "{LIGHT_BLUE}", "{DARK_BLUE}", "{PURPLE}", "{CARRIAGE_RETURN}"};
static char _colorCodes[][] = {"\x01",     "\x02",      "\x03",   "\x04",         "\x05",     "\x06",          "\x07",        "\x08",   "\x09",     "\x0B",         "\x0C",        "\x0E",     "\n"};

stock void AddMenuOption(Menu menu, const char[] info, const char[] display, any:...) {
    char formattedDisplay[128];
    VFormat(formattedDisplay, sizeof(formattedDisplay), display, 4);
    menu.AddItem(info, formattedDisplay);
}

stock void AddMenuInt(Menu menu, int value, const char[] display, any:...) {
    char formattedDisplay[128];
    VFormat(formattedDisplay, sizeof(formattedDisplay), display, 4);
    char buffer[MAX_INTEGER_STRING_LENGTH];
    IntToString(value, buffer, sizeof(buffer));
    menu.AddItem(buffer, formattedDisplay);
}

stock int GetMenuInt(Menu menu, int param2) {
    char buffer[MAX_INTEGER_STRING_LENGTH];
    menu.GetItem(param2, buffer, sizeof(buffer));
    return StringToInt(buffer);
}

stock void AddMenuBool(Menu menu, bool value, const char[] display, any:...) {
    char formattedDisplay[128];
    VFormat(formattedDisplay, sizeof(formattedDisplay), display, 4);
    int convertedInt = value ? 1 : 0;
    AddMenuInt(menu, convertedInt, formattedDisplay);
}

stock bool GetMenuBool(Menu menu, int param2) {
    return GetMenuInt(menu, param2) != 0;
}

stock void SwitchPlayerTeam(int client, int team) {
    if (GetClientTeam(client) == team)
        return;

    if (team > CS_TEAM_SPECTATOR) {
        CS_SwitchTeam(client, team);
        CS_UpdateClientModel(client);
        CS_RespawnPlayer(client);
    } else {
        ChangeClientTeam(client, team);
    }
}

stock bool IsValidClient(int client) {
    if (client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client))
        return true;
    return false;
}

stock bool IsPlayer(int client) {
    return IsValidClient(client) && !IsFakeClient(client);
}

stock int GetConnectedClientCount() {
    int clients = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && !IsFakeClient(i)) {
            clients++;
        }
    }
    return clients;
}

stock void Colorize(char[] msg, int size, bool stripColor=false) {
    for (int i = 0; i < sizeof(_colorNames); i ++) {
        char code[] = "\x01";
        if (!stripColor)
            strcopy(code,  sizeof(code), _colorCodes[i]);

        ReplaceString(msg, size, _colorNames[i], code);
    }
}

stock bool IsTVEnabled() {
    Handle tvEnabledCvar = FindConVar("tv_enable");
    if (tvEnabledCvar == INVALID_HANDLE) {
        LogError("Failed to get tv_enable cvar");
        return false;
    }
    return GetConVarInt(tvEnabledCvar) != 0;
}

stock bool Record(const char[] demoName) {
    char szDemoName[256];
    strcopy(szDemoName, sizeof(szDemoName), demoName);
    ReplaceString(szDemoName, sizeof(szDemoName), "\"", "\\\"");
    ServerCommand("tv_record \"%s\"", szDemoName);

    if (!IsTVEnabled()) {
        LogError("Autorecording will not work with current cvar \"tv_enable\"=0. Set \"tv_enable 1\" in server.cfg (or another config file) to fix this.");
        return false;
    }

    return true;
}

stock bool IsPaused() {
    return GameRules_GetProp("m_bMatchWaitingForResume") != 0;
}

stock bool InWarmupPeriod() {
    return GameRules_GetProp("m_bWarmupPeriod") != 0;
}

stock void EndWarmup() {
    ServerCommand("mp_warmup_end");
}

stock bool OnActiveTeam(int client) {
    if (!IsPlayer(client))
        return false;

    int team = GetClientTeam(client);
    return team == CS_TEAM_CT || team == CS_TEAM_T;
}

stock void PluginMessageToAll(const char[] format, any:...) {
    char display[512];
    VFormat(display, sizeof(display), format, 2);
    Colorize(display, sizeof(display));
    PrintToChatAll("[\x05MapCore\x01] %s", display);
}

stock void PluginMessage(int client, const char[] format, any:...) {
    char display[512];
    VFormat(display, sizeof(display), format, 2);
    Colorize(display, sizeof(display));
    PrintToChat(client, "[\x05MapCore\x01] %s", display);
}

// Thanks to KissLick https://forums.alliedmods.net/member.php?u=210752
stock bool SplitStringRight(const char[] source, const char[] split, char[] part, int partLen) {
    int index = StrContains(source, split);
    if (index == -1)
        return false;

    index += strlen(split);
    strcopy(part, partLen, source[index]);
    return true;
}

/**
 * Fills a buffer with the current map name,
 * with any directory information removed.
 * Example: de_dust2 instead of workshop/125351616/de_dust2
 */
stock void GetCleanMapName(char[] buffer, int size) {
    char mapName[128];
    GetCurrentMap(mapName, sizeof(mapName));
    int last_slash = 0;
    int len = strlen(mapName);
    for (int i = 0;  i < len; i++) {
        if (mapName[i] == '/')
            last_slash = i + 1;
    }
    strcopy(buffer, size, mapName[last_slash]);
}
