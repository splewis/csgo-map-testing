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
PollHandler __pollHandler;

stock bool CreatePoll(const char[] pollTitle, ArrayList choices, int duration, PollHandler handler, int spacers=2) {
    if (!IsNewVoteAllowed()) {
        LogError("CreatePoll(%s) failed - there is already an active poll", pollTitle);
        return false;
    }

    strcopy(__pollTitle, sizeof(__pollTitle), pollTitle);
    __pollChoices = new ArrayList(POLL_OPTION_LENGTH);

    for (int i = 0; i <= sizeof(__pollSelection); i++) {
        __pollSelection[i] = -1;
    }

    __pollHandler = handler;

    for (int i = 0; i < choices.Length; i++) {
        char buffer[POLL_OPTION_LENGTH];
        choices.GetString(i, buffer, sizeof(buffer));
        __pollChoices.PushString(buffer);
    }

    Menu menu = new Menu(__PollMenuHandler);
    SetVoteResultCallback(menu, __VotePollHandler);
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

    return VoteMenuToAll(menu, duration);
}

stock bool CanMakePoll() {
    return !IsNewVoteAllowed();
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
    if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public int __VotePollHandler(Menu menu,
                         int num_votes,
                         int num_clients,
                         const client_info[][2],
                         int num_items,
                         const item_info[][2]) {
    // reset all other poll results
    for (int i = 0; i < sizeof(__pollSelection); i++)
        __pollSelection[i] = -1;

    for (int i = 0; i < num_clients; i++) {
        int client = client_info[i][VOTEINFO_CLIENT_INDEX];
        int info = client_info[i][VOTEINFO_CLIENT_ITEM];
        __pollSelection[client] = GetMenuInt(menu, info);
    }

    Call_StartFunction(INVALID_HANDLE, __pollHandler);
    Call_PushCell(num_votes);
    Call_Finish();
    delete __pollChoices;
}
