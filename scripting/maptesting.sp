#include <cstrike>
#include <sourcemod>
#include <sdktools>
#include "include/logdebug.inc"
#include "include/poll.inc"

#pragma semicolon 1

/***********************
 *                     *
 *   Global variables  *
 *                     *
 ***********************/

/** ConVar handles **/
ConVar g_LiveCfg;
ConVar g_PollDuration;
ConVar g_WarmupCfg;
ConVar g_InitialWarmupTime;
ConVar g_FullTeamsWarmupTime;
ConVar g_PostGameWarmupTime;
ConVar g_FullPlayerCount;
ConVar g_HideFedbackInChat;
ConVar g_RestartLength;
ConVar g_AnonymousMode;
ConVar g_MinPlayersForPoll;

enum GameState {
    GameState_None = 0,
    GameState_WaitingForPlayers = 1,
    GameState_Warmup = 2,
    GameState_GoingLive = 3,
    GameState_Live = 4,
    GameState_Done = 5,
};
GameState g_GameState = GameState_None;

int g_RoundNumber = 0;
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

    g_InitialWarmupTime = CreateConVar("sm_maptesting_warmup_time_initial", "420", "Warmup time in seconds for when the first player connects");
    g_FullTeamsWarmupTime = CreateConVar("sm_maptesting_warmup_time_full", "300", "Warmup time in seconds for when sm_maptesting_numplayers_full_warmup_time players have joined");
    g_PostGameWarmupTime = CreateConVar("sm_maptesting_warmup_time_post", "120", "Warmup time in seconds after a game ends");

    g_FullPlayerCount = CreateConVar("sm_maptesting_numplayers_full_warmup_time", "10", "Desired number of players to start the \"primary\" warmup period");
    g_HideFedbackInChat = CreateConVar("sm_maptesting_hide_feedback_in_chat", "1", "Whether to hide feedback-chat from being displayed in regular chat");
    g_RestartLength = CreateConVar("sm_maptesting_restart_duration", "3", "Length of the final game restart in the lo3");
    g_AnonymousMode = CreateConVar("sm_maptesting_anonymous_feedback", "0", "How anonymous feedback (/fb instead of !fb) works: 0=completely disabled, 1=not displayed in chat, 2=not display+steamid/name not logged");
    g_MinPlayersForPoll = CreateConVar("sm_maptesting_poll_min_players", "5", "Minimum number of players to be on the server to auto-give polls");

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

    if (CanMakePoll()) {
        ReplyToCommand(client, "[SM] A poll cannot be created right now - try again in a few seconds.");
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
    g_GameState = GameState_None;
    char mapName[PLATFORM_MAX_PATH];
    GetCleanMapName(mapName, sizeof(mapName));
    BuildPath(Path_SM, g_ChatLogFile, sizeof(g_ChatLogFile), "logs/%s_chat.txt", mapName);
    BuildPath(Path_SM, g_FeedbackLogFile, sizeof(g_FeedbackLogFile), "logs/%s_feedback.txt", mapName);
    BuildPath(Path_SM, g_PollLogFile, sizeof(g_PollLogFile), "logs/%s_polls.txt", mapName);
}

public void OnClientConnected(int client) {
    if (IsFakeClient(client))
        return;

    if (g_GameState == GameState_None) {
        g_GameState = GameState_WaitingForPlayers;
        ServerCommand("mp_warmuptime %d", g_InitialWarmupTime.IntValue);
        ServerCommand("mp_warmup_start");
        ExecCfg(g_WarmupCfg);
    }

    int connectedCount = GetConnectedClientCount();

    if (g_GameState == GameState_Warmup && connectedCount >= g_FullPlayerCount.IntValue) {
        g_GameState = GameState_Warmup;
        ServerCommand("mp_warmuptime %d", g_FullTeamsWarmupTime.IntValue);
    }
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs) {
    char helpTriggers[][] = {
        "!help", "!info",
    };

    for (int i = 0; i < sizeof(helpTriggers); i++) {
        if (StrEqual(sArgs, helpTriggers[i])) {
            GivePlayerInfo(client);
            return Plugin_Continue;
        }
    }

    if (strlen(sArgs) <= 2) {
        // no need to do anything with near-empty messages
        return Plugin_Continue;
    }

    char feedbackTriggers[][] = {
        "fb", "feedback", "bug", "issue", "gf",
    };

    char buffer[256];
    for (int i = 0; i < sizeof(feedbackTriggers); i++) {
        if (SplitStringRight(sArgs, feedbackTriggers[i], buffer, sizeof(buffer)) == 1) {
            bool anonymous = g_AnonymousMode.IntValue != 0 && StrEqual(sArgs[0], "/");
            TrimString(buffer);
            Logger_LogFeedback(client, buffer, anonymous);

            if (anonymous) {
                PluginMessage(client, "Your feedback has been submitted anonymously.");
            } else {
                PluginMessage(client, "Your feedback has been submitted.");
            }

            if (g_HideFedbackInChat.IntValue != 0 || anonymous) {
                return Plugin_Handled;
            } else {
                return Plugin_Continue;
            }
        }
    }

    Logger_LogChatMessage(client, sArgs);

    return Plugin_Continue;
}

public void GivePlayerInfo(int client) {
    PluginMessage(client, "Type !fb or !gf to give feedback to the map developer.");
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
    g_RoundNumber = CS_GetTeamScore(CS_TEAM_CT) + CS_GetTeamScore(CS_TEAM_T) + 1;
    LogDebug("Event_RoundStart, roundNumber = %d, state = %d", g_RoundNumber, g_GameState);

    if (GetConnectedClientCount() == 0) {
        return;
    }

    if (g_RoundNumber == 1 && InWarmupState() && !InWarmupPeriod()) {
        ServerCommand("exec gamemode_competitive");
        ExecCfg(g_LiveCfg);
        CreateTimer(3.0, BeginLO3);
    } else if (g_GameState == GameState_Done) {
        g_GameState = GameState_Warmup;
        ServerCommand("mp_warmuptime %d", g_PostGameWarmupTime.IntValue);
        ServerCommand("mp_warmup_start");
        ExecCfg(g_WarmupCfg);
    } else if (g_GameState == GameState_Live) {
        if (g_RoundNumber == 2) {
            Logger_ImpressionPoll();
        }

        if (g_RoundNumber == GetConVarInt(FindConVar("mp_maxrounds")) - 1) {
            Logger_LayoutPoll();
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
