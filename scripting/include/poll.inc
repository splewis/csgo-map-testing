#if defined _poll_included
 #endinput
#endif
#define _poll_included

#define POLL_TITLE_LENGTH 128
#define POLL_OPTION_LENGTH 64

typedef PollHandler = function void (const char[] pollTitle, int totalVotes, int numOptions, ArrayList numVotes, ArrayList optionNames);

ArrayList __pollOptionNames;
ArrayList __pollVoteCounts;

char __pollTitle[POLL_TITLE_LENGTH];
PollHandler __pollHandler;

stock bool CreatePoll(const char[] pollTitle, ArrayList choices, int duration, PollHandler handler, int spacers=2) {
    if (!IsNewVoteAllowed()) {
        LogError("CreatePoll(%s) failed - there is already an active poll", pollTitle);
        return false;
    }

    strcopy(__pollTitle, sizeof(__pollTitle), pollTitle);
    __pollOptionNames = new ArrayList(POLL_OPTION_LENGTH);
    __pollVoteCounts = new ArrayList();
    __pollHandler = handler;

    for (int i = 0; i < choices.Length; i++) {
        char buffer[POLL_OPTION_LENGTH];
        choices.GetString(i, buffer, sizeof(buffer));
        __pollOptionNames.PushString(buffer);
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
        __pollOptionNames.GetString(j, buffer, sizeof(buffer));
        AddMenuInt(menu, j, buffer);
    }

    return VoteMenuToAll(menu, duration);
}

stock bool CanMakePoll() {
    return !IsVoteInProgress();
}

public int __PollMenuHandler(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_End) {
        CloseHandle(menu);
    }
}

public int __VotePollHandler(Menu menu,
                             int totalVotes,
                             int numClients,
                             const clientInfo[][2],
                             int numItems,
                             const itemInfo[][2]) {

    for (int i = 0; i < numClients; i++) {
        int choiceIndex = clientInfo[i][VOTEINFO_CLIENT_ITEM];
        int curVotes = __pollVoteCounts.Get(choiceIndex);
        __pollVoteCounts.Set(choiceIndex, curVotes + 1);
    }

    Call_StartFunction(INVALID_HANDLE, __pollHandler);
    Call_PushString(__pollTitle);
    Call_PushCell(totalVotes);
    Call_PushCell(numItems);
    Call_PushCell(__pollVoteCounts);
    Call_PushCell(__pollOptionNames);
    Call_Finish();

    delete __pollVoteCounts;
    delete __pollOptionNames;
}
