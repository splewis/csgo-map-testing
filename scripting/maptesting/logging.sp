public void Logger_LogChatMessage(int client, const char[] text) {
    LogDebug("LogChatMessage %L: %s", client, text);
    LogToFile(g_ChatLogFile, "%L says: %s", client, text);
}

public void Logger_LogFeedback(int client, const char[] text) {
    LogDebug("Logger_LogFeedback %L: %s", client, text);

    if (OnActiveTeam(client)) {
        float origin[3];
        GetClientAbsAngles(client, origin);
        LogToFile(g_FeedbackLogFile, "%L at position (%f, %f, %f) has feedback: %s",
                  client, origin[0], origin[1], origin[2], text);
    } else {
        LogToFile(g_FeedbackLogFile, "%L has feedback: %s", client, text);
    }
}

public void GiveImpressionsPoll() {
    ServerCommand("sm_poll \"What are your initial impressions of the map?\" \"Neutral\" \"Like\" \"Dislike\"");
}

public void GiveLayoutPoll() {
    ServerCommand("sm_poll \"How do you like the map layout?\" \"Neutral\" \"Like\" \"Dislike\"");
}

public void PollLogCallback(int totalCount) {
    char title[POLL_TITLE_LENGTH];
    GetPollTitle(title, sizeof(title));
    LogToFile(g_PollLogFile, "Results for question %s:", title);

    for (int i = 0; i < GetPollNumChoices(); i++) {
        char choice[POLL_OPTION_LENGTH];
        int timesSelected = GetPollChoice(i, choice, sizeof(choice));
        LogToFile(g_PollLogFile, "Option %d = %s, selected %d times (out of %d)", i+1, choice, timesSelected, totalCount);
    }
}
