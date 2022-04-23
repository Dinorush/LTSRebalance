#if UI
global function LTSRebalance_KVFixUI_Init

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
global function LTSRebalance_KVFix_ClInit

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
	print( "LTS Rebalance KVFix - LTS Rebalance KeyValues found: " + GetWeaponMods_Global( testDummy[0] ).contains( testDummy[1] ) )
	print( "LTS Rebalance KVFix - KeyValues match: " + ( GetWeaponMods_Global( testDummy[0] ).contains( testDummy[1] ) == isModEnabled ) )
	if ( GetWeaponMods_Global( testDummy[0] ).contains( testDummy[1] ) == isModEnabled )
		return

	print( "LTS Rebalance KVFix - Attempting reparse")
	int netChanModeOriginal = GetConVarInt( "net_chan_limit_mode" )
	int svCheatsOriginal = GetConVarInt( "sv_cheats" )
	player.ClientCommand( "net_chan_limit_mode 0" )	// Don't want to kick the player back to main menu when recompiling
	player.ClientCommand( "sv_cheats 1" )			// Need sv_cheats to execute command
	player.ClientCommand( "weapon_reparse" )
	player.ClientCommand( "sv_cheats " + svCheatsOriginal )
	player.ClientCommand( "net_chan_limit_mode " + netChanModeOriginal )
}
#else
global function LTSRebalance_KVFix_Init

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