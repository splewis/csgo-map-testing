public void Logger_LogChatMessage(int client, const char[] text) {
    LogDebug("LogChatMessage %L: %s", client, text);
    LogToFile(g_ChatLogFile, "%L says: %s", client, text);
}

public void Logger_LogFeedback(int client, const char[] text, bool anonymous) {
    LogDebug("Logger_LogFeedback %L: %s", client, text);

    if (anonymous) {
        LogToFile(g_FeedbackLogFile, "Anonymous feedback: %s", text);
    } else if (OnActiveTeam(client) && IsPlayerAlive(client)) {
        float origin[3];
        GetClientAbsAngles(client, origin);
        LogToFile(g_FeedbackLogFile, "%L at position (%f, %f, %f) has feedback: %s",
                  client, origin[0], origin[1], origin[2], text);
    } else {
        LogToFile(g_FeedbackLogFile, "%L has feedback: %s", client, text);
    }
}

public void Logger_ImpressionPoll() {
    ServerCommand("sm_poll \"What are your initial impressions of the map?\" \"Neutral\" \"Like\" \"Dislike\"");
}

public void Logger_LayoutPoll() {
    ServerCommand("sm_poll \"How do you like the map layout?\" \"Neutral\" \"Like\" \"Dislike\"");
}

public void PollLogCallback(int totalCount) {
    char title[POLL_TITLE_LENGTH];
    GetPollTitle(title, sizeof(title));
    LogToFile(g_PollLogFile, "Results for question %s (taken at round %d), total votes = %d:", title, g_RoundNumber, totalCount);
    PluginMessageToAll("The poll (%s) has ended", title);
    PluginMessageToAll("Results:");

    for (int i = 0; i < GetPollNumChoices(); i++) {
        char choice[POLL_OPTION_LENGTH];
        int timesSelected = GetPollChoice(i, choice, sizeof(choice));
        float pct = 100.0*float(timesSelected)/float(totalCount);
        LogToFile(g_PollLogFile, "Option %d = %s, selected %d/%d times (%.2f%%)", i+1, choice, timesSelected, totalCount, pct);
        PluginMessageToAll("  %s selected %d/%d times (%.2f%%)", choice, timesSelected, totalCount, pct);
    }
}
