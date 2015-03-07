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
    ArrayList impressions = new ArrayList(64);
    impressions.PushString("Neutral");
    impressions.PushString("Like");
    impressions.PushString("Dislike");
    CreatePoll("What are your current impressions of the map?", impressions, g_PollDuration.IntValue, ImpressionsCallback);
    delete impressions;
}

public void ImpressionsCallback() {
    int neutralCount = 0;
    int likeCount = 0;
    int dislikeCount = 0;
    int totalCount = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            totalCount++;
            switch (GetPollChoice(i)) {
                case 0: neutralCount++;
                case 1: likeCount++;
                case 2: dislikeCount++;
            }
        }
    }

    LogToFile(g_ImpressionsLogFile, "Initial map impressions:");
    LogToFile(g_ImpressionsLogFile, "Neutral: %d (out of %d)", neutralCount, totalCount);
    LogToFile(g_ImpressionsLogFile, "Like: %d (out of %d)", likeCount, totalCount);
    LogToFile(g_ImpressionsLogFile, "Dislike: %d (out of %d)", dislikeCount, totalCount);
}

public void GiveLayoutPoll() {
    ArrayList impressions = new ArrayList(64);
    impressions.PushString("Neutral");
    impressions.PushString("Like");
    impressions.PushString("Dislike");
    CreatePoll("How do you like the map layout?", impressions, g_PollDuration.IntValue, LayoutCallback);
    delete impressions;
}

public void LayoutCallback() {
    int neutralCount = 0;
    int likeCount = 0;
    int dislikeCount = 0;
    int totalCount = 0;
    for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i)) {
            totalCount++;
            switch (GetPollChoice(i)) {
                case 0: neutralCount++;
                case 1: likeCount++;
                case 2: dislikeCount++;
            }
        }
    }

    LogToFile(g_ImpressionsLogFile, "End of game map layout impressions:");
    LogToFile(g_ImpressionsLogFile, "Neutral: %d (out of %d)", neutralCount, totalCount);
    LogToFile(g_ImpressionsLogFile, "Like: %d (out of %d)", likeCount, totalCount);
    LogToFile(g_ImpressionsLogFile, "Dislike: %d (out of %d)", dislikeCount, totalCount);
}
