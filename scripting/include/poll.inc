#if defined _poll_included
 #endinput
#endif
#define _poll_included

#define POLL_TITLE_LENGTH 128
#define POLL_OPTION_LENGTH 64
typedef PollHandler = function void (int totalCount);

ArrayList __pollChoices;
char __pollTitle[POLL_TITLE_LENGTH];
int __pollSelection[MAXPLAYERS+1] = -1;
bool __activePoll = false;
PollHandler __pollHandler;

stock void CreatePoll(const char[] pollTitle, ArrayList choices, int duration, PollHandler handler, int spacers=2) {
    if (__activePoll) {
        LogError("CreatePoll(%s) failed - there is already an active poll", pollTitle);
        return;
    }

    strcopy(__pollTitle, sizeof(__pollTitle), pollTitle);
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

            for (int j = 0; j < spacers; j++) {
                menu.AddItem("linespacer", "", ITEMDRAW_SPACER);
            }

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

stock int GetPollNumChoices() {
    return __pollChoices.Length;
}

stock int GetPollChoice(int pollChoice, char[] buffer, int len) {
    __pollChoices.GetString(pollChoice, buffer, len);
    int count = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (__pollSelection[i] == pollChoice)
            count++;
    }
    return count;
}

public void GetPollTitle(char[] buffer, int len) {
    strcopy(buffer, len, __pollTitle);
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
    int totalCount = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && __pollSelection[i] != -1)
            totalCount++;
    }

    Call_StartFunction(INVALID_HANDLE, __pollHandler);
    Call_PushCell(totalCount);
    Call_Finish();
    __activePoll = false;
    delete __pollChoices;
}
