untyped
global function ClLTSRebalance_Init

void function ClLTSRebalance_Init()
{
	AddCallback_PlayerClassChanged( ClLTSRebalance_ToggleUI )
}

void function ClLTSRebalance_ToggleUI( entity player )
{
	if ( !LTSRebalance_Enabled() || IsSpectating() || player != GetLocalClientPlayer() )
		return

	if ( player.IsTitan() )
	{
		if ( player.HasPassive( ePassives.PAS_ION_LASERCANNON ) )
			thread ClLTSRebalance_LightCannonThink( player )
		if ( player.HasPassive( ePassives.PAS_ANTI_RODEO ) )
			thread ClLTSRebalance_CounterReadyThink( player )
	}
}

void function ClLTSRebalance_CounterReadyThink( entity player )
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

	float percent = player.GetPlayerNetFloat( "LTSRebalance_CounterReadyCharge" )
	float oldPercent = 0
	LTSRebalance_BasicImageBar_SetFillFrac( charge, percent )
	while( true )
	{
		WaitFrame()
		percent = player.GetPlayerNetFloat( "LTSRebalance_CounterReadyCharge" )

		LTSRebalance_BasicImageBar_SetFillFrac( charge, percent )
		if ( percent == 1 && oldPercent != 1 )
			RuiSetFloat3( charge.imageRuis[0], "basicImageColor", < 1, 1, 1 > )
		else if ( oldPercent == 1 && percent != 1 )
			RuiSetFloat3( charge.imageRuis[0], "basicImageColor", < 0.4, 0.4, 0.4 > )
		oldPercent = percent
	}
}

void function ClLTSRebalance_LightCannonThink( entity player )
{
	player.EndSignal( "SettingsChanged" )
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath" )

	LTSRebalance_BarTopoData bg = LTSRebalance_BasicImageBar_CreateRuiTopo( <0, 0, 0>, < -0.417, 0.25, 0.0 >, 0.108, 0.02, LTSRebalance_eDirection.right )
	LTSRebalance_BarTopoData coreCharges = LTSRebalance_BasicImageBar_CreateRuiTopo( <0, 0, 0>, < -0.417, 0.25, 0.0 >, 0.1, 0.01, LTSRebalance_eDirection.right )
	OnThreadEnd(
		function() : ( bg, coreCharges )
		{
			LTSRebalance_BasicImageBar_Destroy( bg )
			LTSRebalance_BasicImageBar_Destroy( coreCharges )
		}
	)
	LTSRebalance_BasicImageBar_UpdateSegmentCount( bg, 1, 0.108 )
	RuiSetFloat3( bg.imageRuis[0], "basicImageColor", < 0, 0, 0 > )
	RuiSetFloat( bg.imageRuis[0], "basicImageAlpha", 0.35 )

	LTSRebalance_BasicImageBar_UpdateSegmentCount( coreCharges, 3, 0.075 )
	LTSRebalance_BasicImageBar_SetFillFrac( coreCharges, 0.0 )
	foreach ( var rui in coreCharges.imageRuis )
		RuiSetFloat( rui, "basicImageAlpha", 0.7 )

	int last = 0
	while( true )
	{
		WaitFrame()

		if ( !ClLTSRebalance_ShouldRenderLightCannonUI( player ) )
		{
			LTSRebalance_BasicImageBar_SetFillFrac( coreCharges, 0.0 )
			RuiSetFloat( bg.imageRuis[0], "basicImageAlpha", 0.0 )
			continue
		}

		RuiSetFloat( bg.imageRuis[0], "basicImageAlpha", 0.5 )
		entity core = player.GetOffhandWeapon( OFFHAND_EQUIPMENT )
		int count = LTSREBALANCE_PAS_ION_LASERCANNON_COUNT
		if ( "laserCoreCount" in core.s )
			count -= expect int( core.s.laserCoreCount + 1 ) / 2

		if ( last == count )
			continue
		LTSRebalance_BasicImageBar_SetFillFrac( coreCharges, float( count ) / float( LTSREBALANCE_PAS_ION_LASERCANNON_COUNT ) )
		last = count
	}
}

bool function ClLTSRebalance_ShouldRenderLightCannonUI( entity player )
{
	entity soul = player.GetTitanSoul()
	if ( !IsValid( soul ) )
		return false

	float coreAvailableFrac = soul.GetTitanSoulNetFloat( "coreAvailableFrac" )
	if ( coreAvailableFrac < 1.0 )
		return soul.GetCoreChargeExpireTime() > Time() + 0.1

	return true
}