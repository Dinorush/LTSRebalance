// Runs in UI to call methods not exposed to Server/Client that they need,
global function LTSRebalance_SetVersionNum

void function LTSRebalance_SetVersionNum()
{
	SetConVarString( "ltsrebalance_version_num", NSGetModVersionByModName( "Dinorush's LTS Rebalance" ) )
}