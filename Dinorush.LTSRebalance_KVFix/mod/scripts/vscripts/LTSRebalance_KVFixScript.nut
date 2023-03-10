#if CLIENT
// We need to call weapon_reparse on client (otherwise client does not reparse files).
// However, we need to make sure the server is local, so we let the server send a command to the client to trigger it.
global function LTSRebalance_KVFix_ClInit
global function LTSRebalance_KVFix_KeyValuesOn

void function LTSRebalance_KVFix_ClInit()
{
	if ( GetMapName() == "mp_lobby" )
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
	thread LTSRebalance_KVFix_ClRecompile( GetLocalClientPlayer() )
}

void function LTSRebalance_KVFix_ClRecompile( entity player )
{
	#if LTSREBALANCE_ON
	bool isModEnabled = true
	#else
	bool isModEnabled = false
	#endif
	
	string[2] testDummy = [ "mp_titanweapon_sniper", "LTSRebalance" ] // Some weapon and a LTSRebalance mod to check if it was compiled
	bool keyValuesOn = LTSRebalance_KVFix_KeyValuesOn()
	print( "LTS Rebalance KVFix - LTS Rebalance KeyValues found: " + keyValuesOn )
	print( "LTS Rebalance KVFix - KeyValues match: " + ( keyValuesOn == isModEnabled ) )
	if ( keyValuesOn == isModEnabled )
		return

	print( "LTS Rebalance KVFix - Attempting reparse")
	int netChanModeOriginal = GetConVarInt( "net_chan_limit_mode" )
	int svCheatsOriginal = GetConVarInt( "sv_cheats" )
	// These are server-only vars, so we have to use client command instead of SetConVar
	player.ClientCommand( "net_chan_limit_mode 0" )	// Don't want to kick the player back to main menu when recompiling
	player.ClientCommand( "sv_cheats 1" )			// Need sv_cheats to execute command
	player.ClientCommand( "weapon_reparse" )
	wait 0.1
	player.ClientCommand( "sv_cheats " + svCheatsOriginal )
	player.ClientCommand( "net_chan_limit_mode " + netChanModeOriginal )
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
		thread LTSRebalance_KVFix_AlertClient()
}

void function LTSRebalance_KVFix_AlertClient()
{
	while( GetPlayerArray().len() == 0 )
		WaitFrame()
	ServerToClientStringCommand( GetPlayerArray()[0], "ltsrebalance_can_reparse" )
}
#endif

#if SERVER || CLIENT
bool function LTSRebalance_KVFix_KeyValuesOn()
{
	string[2] testDummy = [ "mp_titanweapon_sniper", "LTSRebalance" ] // Some weapon and a LTSRebalance mod to check if it was compiled
	return GetWeaponMods_Global( testDummy[0] ).contains( testDummy[1] )
}
#endif