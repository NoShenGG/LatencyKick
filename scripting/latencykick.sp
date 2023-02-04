#include <sourcemod>

ConVar g_cvarMaxPing = null;
ConVar g_cvarCheckFrequency = null;
ConVar g_cvarMaxChecks = null;
int g_Ping[MAXPLAYERS+1];
int g_FailedChecks[MAXPLAYERS+1];

public Plugin myinfo =
{
    name = "LatencyKick",
    author = "NoShen",
    description = "Automatically kicks players after failing a certain amount of latency checks",
    version = "1.0",
    url = "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
    PrintToServer("LatencyKick running!");

    g_cvarMaxPing = CreateConVar("sm_maxping", "150", "Maximum ping value that client can have before being kicked", .hasMin = true, .hasMax = false, .min = 0.0);
    g_cvarCheckFrequency = CreateConVar("sm_pingcheckfrequency", "10", "Time to wait in seconds before checking ping values", .hasMin = true, .min = 0.0);
    g_cvarMaxChecks = CreateConVar("sm_maxchecks", "5", "Maximum amount of failed checks before kicking client", .hasMin = true, .min = 0.0);
    AutoExecConfig(true, "latencykick");
}

public void OnMapStart()
{
    // Start timer to check pings and kick appropiately
    CreateTimer(g_cvarCheckFrequency.FloatValue, CheckPlayers, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);

    // Zero out values for each player with map reset
    for(int i = 1; i < MaxClients; i++)
    {
        g_Ping[i] = 0;
        g_FailedChecks[i] = 0;
    }
}

public void OnClientPutInServer(int client)
{
    // Reset values for joining clients
    g_Ping[client] = 0;
    g_FailedChecks[client] = 0;
}

public Action CheckPlayers(Handle Timer)
{
    for(int i = 1; i < MaxClients; i++)
    {
        if(!IsClientConnected(i) || !IsClientInGame(i) || IsFakeClient(i))
        {
            continue;
        }
        UpdatePing(i);
    }
    KickHighPing();
    return Plugin_Continue;
}

void UpdatePing(int client)
{
    char rate[32];
    GetClientInfo(client, "cl_cmdrate", rate, sizeof(rate));
    float ping = GetClientAvgLatency(client, NetFlow_Outgoing);
    float tickRate = GetTickInterval();
    int cmdRate = (StringToInt(rate) > 20 ? StringToInt(rate) : 20);

    ping -= ((0.5 / cmdRate) + (tickRate * 1.0));
    ping -= (tickRate * 0.5);
    ping *= 1000.0;

    g_Ping[client] = RoundToZero(ping);

    if(g_Ping[client] > g_cvarMaxPing.IntValue)
    {
        g_FailedChecks[client]++;
        PrintToChat(client, "[SM] You have failed %d of %d latency checks. Your ping: %d. Max ping: %d", g_FailedChecks[client], g_cvarMaxChecks.IntValue, g_Ping[client], g_cvarMaxPing.IntValue);
    }
    else if(g_FailedChecks[client] > 0)
    {
        g_FailedChecks[client]--;
    }
}

void KickHighPing()
{
    for(int i = 1; i < MaxClients; i++)
    {
        if(!IsClientConnected(i) || !IsClientInGame(i) || IsFakeClient(i))
        {
            continue;
        }

        if(g_FailedChecks[i] >= g_cvarMaxChecks.IntValue)
        {
            KickClient(i, "Your ping is too high! Your ping: %d. Max ping: %d", g_Ping[i], g_cvarMaxPing.IntValue);
        }
    }
}