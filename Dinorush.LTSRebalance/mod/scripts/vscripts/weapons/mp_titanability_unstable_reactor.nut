untyped
global function MpTitanabilityUnstableReactorInit
global function UnstableReactor_InitForPlayer

const float HEALTH_COST_FRAC = 0.05
const int MIN_HEALTH_COST = 400
global const float UNSTABLE_REACTOR_COOLDOWN = 8.0

struct {
	table<entity, float> dashTimes
} file

void function MpTitanabilityUnstableReactorInit()
{
	RegisterSignal( "UnstableReactorUse" )
	RegisterWeaponDamageSource( "mp_titanability_unstable_reactor", "#DEATH_UNSTABLE_REACTOR" )
}

void function UnstableReactor_InitForPlayer( entity player, entity soul )
{
	AddPlayerMovementEventCallback( player, ePlayerMovementEvents.DODGE, UnstableReactor_UpdateDashTime )
	AddButtonPressedPlayerInputCallback( player, IN_DODGE, UnstableReactor_AttemptBlast )
	AddEntityDestroyedCallback( soul, RemoveUnstableReactorCallback )
	thread LTSRebalance_SyncUnstableReactor( soul )
}

void function LTSRebalance_SyncUnstableReactor( entity soul )
{
	soul.EndSignal( "OnDestroy" )

	float charge = 1.0
	float lastTime = Time()
	while( true )
	{
		WaitFrame()
		entity titan = soul.GetTitan()
		if ( !IsValid( titan ) )
		{
			lastTime = Time()
			continue
		}
		
		charge = min( 1.0, charge + ( Time() - lastTime ) / UNSTABLE_REACTOR_COOLDOWN )
		entity player = titan.IsPlayer() ? titan : GetPetTitanOwner( titan )
		if ( IsValid( player ) )
			player.SetPlayerNetFloat( "LTSRebalance_Kit1Charge", charge )

		if ( charge == 1.0 )
		{
			Remote_CallFunction_NonReplay( player, "ServerCallback_UnstableReactor_Ready" )
			player.WaitSignal( "UnstableReactorUse" )
			charge = 0
			titan = soul.GetTitan()
			player = !IsValid( titan ) || titan.IsPlayer() ? titan : GetPetTitanOwner( titan )
			if ( IsValid( player ) )
				player.SetPlayerNetFloat( "LTSRebalance_Kit1Charge", charge )
		}

		lastTime = Time()
	}
}

void function UnstableReactor_UpdateDashTime( entity player )
{
	file.dashTimes[player] <- Time()
}

void function UnstableReactor_AttemptBlast( entity player )
{
	if ( !player.IsTitan() )
		return

	if ( player.GetPlayerNetFloat( "LTSRebalance_Kit1Charge" ) < 1.0 )
		return
	
	// Need a bit of grace period from dash since this callback runs after dash goes and can trigger on the last dash
	if ( !(player in file.dashTimes) || Time() - file.dashTimes[player] < 0.1 )
		return

	// Player needs to have no dashes left to cause an unstable reactor blast
	float dashCost = expect float( GetSettingsForPlayer_DodgeTable( player )["dodgePowerDrain"] )
	if ( player.GetDodgePower() >= dashCost )
		return

	player.Signal( "UnstableReactorUse" )
	MessageToPlayer( player, eEventNotifications.Rodeo_PilotAppliedBatteryToYou, player, true )
	player.Server_SetDodgePower( min( 100.0, player.GetDodgePower() + dashCost ) )
	UnstableReactor_Blast( player )
}

void function UnstableReactor_Blast( entity titan )
{
	int damageFlags = DF_EXPLOSION | DF_ELECTRICAL
	int selfDamage = maxint( MIN_HEALTH_COST, int( titan.GetMaxHealth() * HEALTH_COST_FRAC ) )
	titan.TakeDamage( selfDamage, titan, titan, { scriptType = damageFlags | DF_DOOMED_HEALTH_LOSS, damageSourceId = eDamageSourceId.mp_titanability_unstable_reactor, origin = titan.GetWorldSpaceCenter() } )

	thread UnstableReactor_MakeFX( titan )
	RadiusDamage(
		titan.GetWorldSpaceCenter(),			// center
		titan,									// attacker
		titan,									// inflictor
		60,										// damage
		300,									// damageHeavyArmor
		150,									// innerRadius
		500,									// outerRadius
		SF_ENVEXPLOSION_NO_DAMAGEOWNER,			// flags
		0,										// distanceFromAttacker
		0,										// explosionForce
		damageFlags,							// scriptDamageFlags
		eDamageSourceId.mp_titanability_unstable_reactor	// scriptDamageSourceIdentifier
	)
}

void function UnstableReactor_MakeFX( entity titan )
{
	EmitSoundOnEntity( titan, "Explo_ProximityEMP_Impact_3P" )

	entity particleSystem = CreateEntity( "info_particle_system" )
	particleSystem.kv.start_active = 1
	particleSystem.SetValueForEffectNameKey( $"P_xo_emp_field" )
	particleSystem.SetOrigin( titan.GetWorldSpaceCenter() )
	DispatchSpawn( particleSystem )

	wait 0.6
	particleSystem.Destroy()
}

function RemoveUnstableReactorCallback( soul )
{
	expect entity( soul )
	entity player = soul.GetBossPlayer()
	if ( !IsValid( player ) )
		return

	RemoveButtonPressedPlayerInputCallback( player, IN_DODGE, UnstableReactor_AttemptBlast )
}