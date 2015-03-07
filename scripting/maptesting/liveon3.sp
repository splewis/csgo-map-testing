/** Begins the LO3 process. **/
public Action BeginLO3(Handle timer) {
    g_GameState = GameState_GoingLive;

    // force kill the warmup if we need to
    if (InWarmupPeriod()) {
        EndWarmup();
    }

    // start lo3
    PugSetupMessageToAll("%t", "RestartCounter", 1);
    ServerCommand("mp_restartgame 1");
    CreateTimer(3.0, Restart2);

    return Plugin_Handled;
}

public Action Restart2(Handle timer) {
    PugSetupMessageToAll("%t", "RestartCounter", 2);
    ServerCommand("mp_restartgame 1");
    CreateTimer(4.0, Restart3);

    return Plugin_Handled;
}

public Action Restart3(Handle timer) {
    PugSetupMessageToAll("%t", "RestartCounter", 3);
    ServerCommand("mp_restartgame 5");
    CreateTimer(5.1, MatchLive);
}

public Action MatchLive(Handle timer) {
    g_GameState = GameState_Live;

    for (int i = 0; i < 5; i++)
        PugSetupMessageToAll("%t", "Live");
}
