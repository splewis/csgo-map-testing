#if defined _poll_included
 #endinput
#endif
#define _poll_included

#define POLL_OPTION_LENGTH 64
typedef PollHandler = function void ();

ArrayList __pollChoices;
int __pollSelection[MAXPLAYERS+1] = -1;
bool __activePoll = false;
PollHandler __pollHandler;

stock void CreatePoll(const char[] pollTitle, ArrayList choices, int duration, PollHandler handler) {
    if (__activePoll) {
        LogError("CreatePoll(%s) failed - there is already an active poll", pollTitle);
        return;
    }

    __pollChoices = new ArrayList(POLL_OPTION_LENGTH);
    __activePoll = true;
    for (int i = 0; i <= MAXPLAYERS; i++) {
        __pollSelection[i] = -1;
    }

    __pollHandler = handler;

    for (int i = 0; i < choices.Length; i++) {
        char buffer[POLL_OPTION_LENGTH];
        choices.GetString(i, buffer, sizeof(buffer));
        __pollChoices.PushString(buffer);
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i)) {
            Menu menu = new Menu(__PollMenuHandler);
            SetMenuExitButton(menu, true);
            SetMenuTitle(menu, pollTitle);

            for (int j = 0; j < choices.Length; j++) {
                char buffer[POLL_OPTION_LENGTH];
                __pollChoices.GetString(j, buffer, sizeof(buffer));
                AddMenuInt(menu, j, buffer);
            }

            menu.Display(i, duration);
        }
    }

    CreateTimer(float(duration), __PollTimerHandler);
}

stock bool IsPollActive() {
    return __activePoll;
}

stock int GetPollChoice(int client) {
    return __pollSelection[client];
}

public int __PollMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        int client = param1;
        int choice = GetMenuInt(menu, param2);
        __pollSelection[client] = choice;

    } else if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public Action __PollTimerHandler(Handle timer) {
    Call_StartFunction(INVALID_HANDLE, __pollHandler);
    Call_Finish();
    __activePoll = false;
    delete __pollChoices;
}
