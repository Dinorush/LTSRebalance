#if UI
global function LTSRebalance_KVFixUI_Init

// The function to check if a mod is on only exists in UI, so we use a UI callback + ConVar to get the info to client/server.
void function LTSRebalance_KVFixUI_Init()
{
	bool ornull modOn = NSIsModEnabled( "Dinorush's LTS Rebalance" )
	SetConVarBool( "ltsrebalance_mod_on", modOn ? true : false )
	if ( modOn == null )
		print( "LTS Rebalance KVFix - LTS Rebalance status: null")
	else
		print( "LTS Rebalance KVFix - LTS Rebalance status: " + ( modOn ? true : false) )
}
#elseif CLIENT
// We need to call weapon_reparse on client (otherwise client does not reparse files).
// However, we need to make sure the server is local, so we let the server send a command to the client to trigger it.
// We also need to trigger the server's reparse after the client's finishes, otherwise it won't run.
global function LTSRebalance_KVFix_ClInit
global function LTSRebalance_KVFix_KeyValuesOn

void function LTSRebalance_KVFix_ClInit()
{
	AddServerToClientStringCommandCallback( "ltsrebalance_can_reparse", LTSRebalance_KVFix_SendClientCommand )
}

void function LTSRebalance_KVFix_SendClientCommand( array<string> args )
{
	thread LTSRebalance_KVFix_SendClientCommandInternal()
}

void function LTSRebalance_KVFix_SendClientCommandInternal()
{
	while( !GetLocalClientPlayer() )
		WaitFrame()
	LTSRebalance_KVFix_ClRecompile( GetLocalClientPlayer() )
}

void function LTSRebalance_KVFix_ClRecompile( entity player )
{
	bool isModEnabled = GetConVarBool( "ltsrebalance_mod_on" )
	string[2] testDummy = [ "mp_titanweapon_sniper", "LTSRebalance" ] // Some weapon and a LTSRebalance mod to check if it was compiled
	print( "LTS Rebalance KVFix - LTS Rebalance KeyValues found: " + LTSRebalance_KVFix_KeyValuesOn() )
	print( "LTS Rebalance KVFix - KeyValues match: " + ( LTSRebalance_KVFix_KeyValuesOn() == isModEnabled ) )
	if ( LTSRebalance_KVFix_KeyValuesOn() == isModEnabled )
		return

	print( "LTS Rebalance KVFix - Attempting reparse")
	int netChanModeOriginal = GetConVarInt( "net_chan_limit_mode" )
	int svCheatsOriginal = GetConVarInt( "sv_cheats" )
	player.ClientCommand( "net_chan_limit_mode 0" )	// Don't want to kick the player back to main menu when recompiling
	player.ClientCommand( "sv_cheats 1" )			// Need sv_cheats to execute command
	player.ClientCommand( "weapon_reparse" )
	player.ClientCommand( "sv_cheats " + svCheatsOriginal )
	player.ClientCommand( "net_chan_limit_mode " + netChanModeOriginal )
	player.ClientCommand( "ltsrebalance_trigger_recompile" )
}
#else
// Server runs some simple checks to run KVFix in the multiplayer lobby. This should prevent reparsing in actual matches.
// The client must be triggered by the server in this way so that the client does not attempt reparse on nonlocal servers.
// The client must also tell the server to reparse, since the server's will fail if it attempts to do so during the client's.
global function LTSRebalance_KVFix_Init
global function LTSRebalance_KVFix_KeyValuesOn

void function LTSRebalance_KVFix_Init()
{
	if ( GetMapName() == "mp_lobby" )
	{
		AddClientCommandCallback( "ltsrebalance_trigger_recompile", LTSRebalance_KVFix_Recompile )
		thread LTSRebalance_KVFix_AlertClient()
	}
}

void function LTSRebalance_KVFix_AlertClient()
{
	while( GetPlayerArray().len() == 0 )
		WaitFrame()
	ServerToClientStringCommand( GetPlayerArray()[0], "ltsrebalance_can_reparse" )
}

bool function LTSRebalance_KVFix_Recompile( entity player, array<string> args )
{
	bool isModEnabled = GetConVarBool( "ltsrebalance_mod_on" )
	print( "LTS Rebalance KVFix - LTS Rebalance KeyValues found: " + LTSRebalance_KVFix_KeyValuesOn() )
	print( "LTS Rebalance KVFix - KeyValues match: " + ( LTSRebalance_KVFix_KeyValuesOn() == isModEnabled ) )
	if ( LTSRebalance_KVFix_KeyValuesOn() == isModEnabled )
		return true

	print( "LTS Rebalance KVFix - Attempting reparse")
	int netChanModeOriginal = GetConVarInt( "net_chan_limit_mode" )
	int svCheatsOriginal = GetConVarInt( "sv_cheats" )
	ServerCommand( "net_chan_limit_mode 0" )	// Don't want to kick the player back to main menu when recompiling
	ServerCommand( "sv_cheats 1" )			// Need sv_cheats to execute command
	ServerCommand( "weapon_reparse" )
	ServerCommand( "sv_cheats " + svCheatsOriginal )
	ServerCommand( "net_chan_limit_mode " + netChanModeOriginal )
	return true
}
#endif

#if SERVER || CLIENT
bool function LTSRebalance_KVFix_KeyValuesOn()
{
	string[2] testDummy = [ "mp_titanweapon_sniper", "LTSRebalance" ] // Some weapon and a LTSRebalance mod to check if it was compiled
	return GetWeaponMods_Global( testDummy[0] ).contains( testDummy[1] )
}
#endif