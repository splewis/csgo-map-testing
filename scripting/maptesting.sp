#include <cstrike>
#include <sourcemod>
#include <sdktools>
#include "include/logdebug.inc"
#include "include/poll.inc"

#pragma semicolon 1
#pragma newdecls required

/***********************
 *                     *
 *   Global variables  *
 *                     *
 ***********************/

/** ConVar handles **/
ConVar g_LiveCfg;
ConVar g_PollDuration;
ConVar g_WarmupCfg;

enum GameState {
    GameState_None = 0,
    GameState_WaitingForPlayers = 1,
    GameState_Warmup = 2,
    GameState_GoingLive = 3,
    GameState_Live = 4,
    GameState_Done = 5,
};
GameState g_GameState = GameState_None;

char g_ChatLogFile[PLATFORM_MAX_PATH];
char g_FeedbackLogFile[PLATFORM_MAX_PATH];
char g_PollLogFile[PLATFORM_MAX_PATH];


#include "maptesting/generic.sp"
#include "maptesting/liveon3.sp"
#include "maptesting/logging.sp"


/***********************
 *                     *
 * Sourcemod forwards  *
 *                     *
 ***********************/

public Plugin myinfo = {
    name = "CS:GO MapTesting",
    author = "splewis",
    description = "Tools for facilitating map testing",
    version = PLUGIN_VERSION,
    url = "https://github.com/splewis/csgo-map-testing"
};

public void OnPluginStart() {
    InitDebugLog(DEBUG_CVAR, "maptesting");

    LoadTranslations("common.phrases");
    LoadTranslations("maptesting.phrases");

    /** ConVars **/
    g_LiveCfg = CreateConVar("sm_maptesting_live_cfg", "live.cfg", "Config to execute when the game goes live");
    g_WarmupCfg = CreateConVar("sm_maptesting_warmup_cfg", "warmup.cfg", "Config to execute for warmup periods");
    g_PollDuration = CreateConVar("sm_maptesting_poll_duration", "20", "How long the map vote should last if using map-votes", _, true, 10.0);
    AutoExecConfig(true, "maptesting");

    RegAdminCmd("sm_poll", Command_CreatePoll, ADMFLAG_CHANGEMAP);

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("cs_win_panel_match", Event_MatchOver);
    HookEvent("round_start", Event_RoundStart);

    g_GameState = GameState_None;
}

public void OnConfigsExecuted() {
    ServerCommand("mp_do_warmup_period 1");
}

public Action Command_CreatePoll(int client, int args) {
    int numArgs = GetCmdArgs();

    if (IsPollActive()) {
        ReplyToCommand(client, "[SM] There is already an active poll");
        return Plugin_Handled;
    }

    if (numArgs < 3) {
        ReplyToCommand(client, "[SM] Usage: sm_poll <title> <options1> <option2> ...");
        return Plugin_Handled;
    }

    char title[POLL_TITLE_LENGTH];
    GetCmdArg(1, title, sizeof(title));

    ArrayList choices = new ArrayList(POLL_OPTION_LENGTH);
    char buffer[POLL_OPTION_LENGTH];
    for (int i = 2; i <= numArgs; i++) {
        GetCmdArg(i, buffer, sizeof(buffer));
        choices.PushString(buffer);
    }

    CreatePoll(title, choices, g_PollDuration.IntValue, PollLogCallback);

    delete choices;
    return Plugin_Handled;
}

public void OnMapStart() {
    char mapName[PLATFORM_MAX_PATH];
    GetCleanMapName(mapName, sizeof(mapName));
    BuildPath(Path_SM, g_ChatLogFile, sizeof(g_ChatLogFile), "logs/%s_chat.txt", mapName);
    BuildPath(Path_SM, g_FeedbackLogFile, sizeof(g_FeedbackLogFile), "logs/%s_feedback.txt", mapName);
    BuildPath(Path_SM, g_PollLogFile, sizeof(g_PollLogFile), "logs/%s_polls.txt", mapName);
}

public void OnClientConnected(int client) {
    if (g_GameState == GameState_None) {
        g_GameState = GameState_WaitingForPlayers;
        ServerCommand("mp_warmuptime %d", 60*7);
        ServerCommand("mp_warmup_start");
        ExecCfg(g_WarmupCfg);
    }

    int connectedCount = GetConnectedClientCount();

    if (g_GameState == GameState_Warmup && connectedCount >= 10) {
        g_GameState = GameState_Warmup;
        ServerCommand("mp_warmuptime %d", 60*5);
    }
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs) {
    char feedbackTriggers[][] = {
        "!fb", "!feedback", "!bug", "!issue", "!gf", "!f"
    };

    char buffer[256];
    for (int i = 0; i < sizeof(feedbackTriggers); i++) {
        if (SplitStringRight(sArgs, feedbackTriggers[i], buffer, sizeof(buffer))) {
            TrimString(buffer);
            Logger_LogFeedback(client, buffer);
            return Plugin_Continue;
        }
    }

    Logger_LogChatMessage(client, sArgs);

    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (!IsPlayer(client))
        return;

    if (InWarmupState()) {
        SetEntProp(client, Prop_Send, "m_iAccount", 16000);
        SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
    }
}


public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast) {
    int roundNumber = CS_GetTeamScore(CS_TEAM_CT) + CS_GetTeamScore(CS_TEAM_T) + 1;
    LogDebug("Event_RoundStart, roundNumber = %d, state = %d", roundNumber, g_GameState);

    if (roundNumber == 1 && InWarmupState() && !InWarmupPeriod()) {
        ServerCommand("exec gamemode_competitive");
        ExecCfg(g_LiveCfg);
        CreateTimer(3.0, BeginLO3);
    } else if (g_GameState == GameState_Done) {
        g_GameState = GameState_Warmup;
        ServerCommand("mp_warmuptime %d", 60*3);
        ServerCommand("mp_warmup_start");
        ExecCfg(g_WarmupCfg);
    } else if (g_GameState == GameState_Live) {
        if (roundNumber == 2) {
            GiveImpressionsPoll();
        }

        if (roundNumber == GetConVarInt(FindConVar("mp_maxrounds")) - 1) {
            GiveLayoutPoll();
        }

    }
}

public Action Event_MatchOver(Handle event, const char[] name, bool dontBroadcast) {
    LogDebug("Event_MatchOver");
    g_GameState = GameState_Done;
}

public void ExecCfg(ConVar cvar) {
    char cfg[PLATFORM_MAX_PATH];
    cvar.GetString(cfg, sizeof(cfg));
    ServerCommand("exec \"%s\"", cfg);
}

public bool InWarmupState() {
    return g_GameState <= GameState_Warmup;
}
