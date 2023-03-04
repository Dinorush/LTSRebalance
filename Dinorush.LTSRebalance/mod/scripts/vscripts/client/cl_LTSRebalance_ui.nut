untyped
global function ClLTSRebalance_Init
global function ServerCallback_UnstableReactor_Ready

struct {
	int uiPassive = -1
} file

const float LTSREBALANCE_PAS_OVERCORE_MAX_BONUS = 0.25 // Make sure this matches the value in _titan_health

void function ClLTSRebalance_Init()
{
	AddCallback_PlayerClassChanged( ClLTSRebalance_ToggleUI )
	AddServerToClientStringCommandCallback( "ltsrebalance_set_ui_passive", SetUIPassive )
}

void function SetUIPassive( array<string> args )
{
	file.uiPassive = args[0].tointeger()
}

void function ClLTSRebalance_ToggleUI( entity player )
{
	if ( !LTSRebalance_Enabled() || IsSpectating() || IsWatchingReplay() || player != GetLocalClientPlayer() )
		return

	if ( player.IsTitan() )
	{
		array<int> passivesToDraw = [ ePassives.PAS_ANTI_RODEO, ePassives.PAS_HYPER_CORE, ePassives.PAS_UNSTABLE_REACTOR ]
		if ( passivesToDraw.contains( file.uiPassive ) )
			thread ClLTSRebalance_Kit1Think( player )
		if ( file.uiPassive == ePassives.PAS_HYPER_CORE )
			thread ClLTSRebalance_OvercoreTextThink( player )
	}
}

void function ClLTSRebalance_Kit1Think( entity player )
{
	player.EndSignal( "SettingsChanged" )
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath" )

	LTSRebalance_BarTopoData bg = LTSRebalance_BasicImageBar_CreateRuiTopo( <0, 0, 0>, < -0.417, 0.47, 0.0 >, 0.108, 0.02, LTSRebalance_eDirection.right )
	LTSRebalance_BarTopoData charge = LTSRebalance_BasicImageBar_CreateRuiTopo( <0, 0, 0>, < -0.417, 0.47, 0.0 >, 0.1, 0.01, LTSRebalance_eDirection.right )

	OnThreadEnd(
		function() : ( bg, charge )
		{
			LTSRebalance_BasicImageBar_Destroy( bg )
			LTSRebalance_BasicImageBar_Destroy( charge )
		}
	)

	LTSRebalance_BasicImageBar_UpdateSegmentCount( bg, 1, 0.108 )
	RuiSetFloat3( bg.imageRuis[0], "basicImageColor", < 0, 0, 0 > )
	RuiSetFloat( bg.imageRuis[0], "basicImageAlpha", 0.35 )

	LTSRebalance_BasicImageBar_UpdateSegmentCount( charge, 1, 0.1 )
	RuiSetFloat3( charge.imageRuis[0], "basicImageColor", < 0.4, 0.4, 0.4 > )
	RuiSetFloat( charge.imageRuis[0], "basicImageAlpha", 0.7 )

	float percent = player.GetPlayerNetFloat( "LTSRebalance_Kit1Charge" )
	if ( percent == 1 )
		RuiSetFloat3( charge.imageRuis[0], "basicImageColor", < 1, 1, 1 > )

	float oldPercent = percent
	LTSRebalance_BasicImageBar_SetFillFrac( charge, percent )
	while( true )
	{
		WaitFrame()
		percent = player.GetPlayerNetFloat( "LTSRebalance_Kit1Charge" )

		LTSRebalance_BasicImageBar_SetFillFrac( charge, percent )
		if ( percent == 1 && oldPercent != 1 )
			RuiSetFloat3( charge.imageRuis[0], "basicImageColor", < 1, 1, 1 > )
		else if ( oldPercent == 1 && percent != 1 )
			RuiSetFloat3( charge.imageRuis[0], "basicImageColor", < 0.4, 0.4, 0.4 > )
		oldPercent = percent
	}
}

void function ClLTSRebalance_OvercoreTextThink( entity player )
{
	player.EndSignal( "SettingsChanged" )
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath" )

	var text = RuiCreate( $"ui/cockpit_console_text_center.rpak", clGlobal.topoCockpitHudPermanent, RUI_DRAW_COCKPIT, -1 )
	RuiSetInt( text, "maxLines", 1 )
	RuiSetInt( text, "lineNum", 1 )
	RuiSetFloat2( text, "msgPos", < -0.417, 0.233, 0 > )
	RuiSetFloat( text, "msgFontSize", 32.0 )
	RuiSetFloat( text, "msgAlpha", 0.7 )
	RuiSetFloat( text, "thicken", 0.0 )

	OnThreadEnd(
		function() : ( text )
		{
			RuiDestroy( text )
		}
	)

	float percent = player.GetPlayerNetFloat( "LTSRebalance_Kit1Charge" )
	float oldPercent = percent
	RuiSetString( text, "msgText", format( "%.2fx", ( 1.0 + percent * LTSREBALANCE_PAS_OVERCORE_MAX_BONUS ) ) )
	RuiSetFloat3( text, "msgColor", <0.7 + percent * 0.3, 0.7 + percent * 0.3, 0.7 - percent * 0.2> )
	while( true )
	{
		WaitFrame()
		percent = player.GetPlayerNetFloat( "LTSRebalance_Kit1Charge" )

		if ( percent != oldPercent )
		{
			RuiSetString( text, "msgText", format( "%.2fx", ( 1.0 + percent * LTSREBALANCE_PAS_OVERCORE_MAX_BONUS ) ) )
			RuiSetFloat3( text, "msgColor", <0.7 + percent * 0.3, 0.7, 0.7 - percent * 0.5> )
			oldPercent = percent
		}
	}
}

void function ServerCallback_UnstableReactor_Ready()
{
	entity player = GetLocalClientPlayer()
	if ( !IsValid( player ) || !player.IsTitan() )
		return
	
	AnnouncementData announcement = CreateAnnouncementMessageQuick( player, "#HUD_UNSTABLE_REACTOR_READY", "#HUD_UNSTABLE_REACTOR_READY_HINT", <1, 0.5, 0>, $"rui/menu/boosts/boost_icon_arc_trap" )
	AnnouncementFromClass( player, announcement )
}