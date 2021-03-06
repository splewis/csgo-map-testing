public void Logger_LogChatMessage(int client, const char[] text) {
    LogDebug("LogChatMessage %L: %s", client, text);
    LogToFile(g_ChatLogFile, "%L says: %s", client, text);
}

public void Logger_LogFeedback(int client, const char[] text, bool anonymous) {
    LogDebug("Logger_LogFeedback %L: %s", client, text);

    if (anonymous) {
        if (g_AnonymousMode.IntValue == 1) {
            LogToFile(g_FeedbackLogFile, "%L has feedback: %s", client, text);
        } else if (g_AnonymousMode.IntValue == 2) {
            LogToFile(g_FeedbackLogFile, "Anonymous feedback: %s", text);
        } else {
            LogError("[Logger_LogFeedback] got unexpected g_AnonymousMode = %d", g_AnonymousMode.IntValue);
        }

    } else if (OnActiveTeam(client) && IsPlayerAlive(client)) {
        float origin[3];
        GetClientAbsOrigin(client, origin);
        LogToFile(g_FeedbackLogFile, "%L at position (%f, %f, %f) has feedback: %s",
                  client, origin[0], origin[1], origin[2], text);
    } else {
        LogToFile(g_FeedbackLogFile, "%L has feedback: %s", client, text);
    }
}

public void Logger_ImpressionPoll() {
    if (GetConnectedClientCount() >= g_MinPlayersForPoll.IntValue)
        ServerCommand("sm_poll \"What are your initial impressions of the map?\" \"Neutral\" \"Like\" \"Dislike\"");
}

public void Logger_LayoutPoll() {
    if (GetConnectedClientCount() >= g_MinPlayersForPoll.IntValue)
        ServerCommand("sm_poll \"How do you like the map layout?\" \"Neutral\" \"Like\" \"Dislike\"");
}

public void PollLogCallback(const char[] pollTitle, int totalVotes, int numOptions, ArrayList numVotes, ArrayList optionNames) {
    LogToFile(g_PollLogFile, "Results for question %s (taken at round %d), total votes = %d:", pollTitle, g_RoundNumber, totalVotes);
    PluginMessageToAll("The poll (%s) has ended", pollTitle);
    PluginMessageToAll("Results:");

    for (int i = 0; i < numOptions; i++) {
        char choice[POLL_OPTION_LENGTH];
        optionNames.GetString(i, choice, sizeof(choice));

        int timesSelected = numVotes.Get(i);
        float pct = 100.0 * float(timesSelected) / float(totalVotes);

        LogToFile(g_PollLogFile, "Option %d = %s, selected %d/%d times (%.2f%%)", i+1, choice, timesSelected, totalVotes, pct);
        PluginMessageToAll("  %s selected %d/%d times (%.2f%%)", choice, timesSelected, totalVotes, pct);
    }
}
