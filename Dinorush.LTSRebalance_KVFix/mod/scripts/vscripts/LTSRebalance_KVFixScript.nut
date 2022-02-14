#if UI
global function LTSRebalance_KVFixUI_Init

void function LTSRebalance_KVFixUI_Init()
{
	SetConVarBool( "ltsrebalance_mod_on", NSIsModEnabled( "Dinorush's LTS Rebalance" ) )
}
#else
global function LTSRebalance_KVFix_Init

void function LTSRebalance_KVFix_Init()
{
	thread LTSRebalance_RecompileKeyValues( GetConVarBool( "ltsrebalance_mod_on" ) )
}

void function LTSRebalance_RecompileKeyValues( bool isModEnabled )
{
	wait 1.0 // Sometimes, reparse can fail if done too early. Might be a better way to handle it, but wait is ez

	string[2] testDummy = [ "mp_titanweapon_sniper", "LTSRebalance" ] // Some weapon and a LTSRebalance mod to check if it was compiled

	int netChanModeOriginal = GetConVarInt( "net_chan_limit_mode" )
	bool svCheatsOriginal = GetConVarBool( "sv_cheats" )
	SetConVarInt( "net_chan_limit_mode", 0 )	// Don't want to kick the player back to main menu when recompiling
	SetConVarBool( "sv_cheats", true )			// Need sv_cheats to execute command
	
	// tries limits this to not run for more than 10s; there are probably bigger issues if that happens
	for ( int tries = 0; ( GetWeaponMods_Global( testDummy[0] ).contains( testDummy[1] ) != isModEnabled ) && tries < 10; tries++ )
	{
		ServerCommand( "weapon_reparse" )
		wait 1.0
	}

	SetConVarBool( "sv_cheats", svCheatsOriginal )
	SetConVarInt( "net_chan_limit_mode", netChanModeOriginal )
}
#endif