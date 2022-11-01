/* LTS Rebalance replaces this file for the following reasons:
   1. Implement Perfect Kits Temporal Anomaly
   2. Implement Rebalance Phase Reflex
*/
global function OnWeaponPrimaryAttack_titanability_phase_dash
global function MpTitanabilityPhaseDashInit

#if SERVER
global function OnWeaponNPCPrimaryAttack_titanability_phase_dash
global function SetPlayerVelocityFromInput
#endif

const PHASE_DASH_SPEED = 1000
const float LTSREBALANCE_REFLEX_START_DELAY = 4.0
const float LTSREBALANCE_REFLEX_DURATION = 5.0

// Only ran in LTSRebalance
void function MpTitanabilityPhaseDashInit()
{
	#if SERVER
		PrecacheParticleSystem( $"arcball_CH_dlight" )
		PrecacheParticleSystem( $"arcball_CH_elec_rope" )
	#else
		AddServerToClientStringCommandCallback( "ltsrebalance_refresh_reflex_hud", LTSRebalance_RefreshReflexHUD )
	#endif
}

#if CLIENT
void function LTSRebalance_RefreshReflexHUD( array<string> args )
{
	thread LTSRebalance_RefreshReflexHUDThink()
}

void function LTSRebalance_RefreshReflexHUDThink()
{
	wait 0.1
	if ( !IsSpectating() && !IsWatchingReplay() )
		ClWeaponStatus_RefreshWeaponStatus( GetLocalClientPlayer() )
}
#endif

var function OnWeaponPrimaryAttack_titanability_phase_dash( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	//PlayWeaponSound( "fire" )
	entity player = weapon.GetWeaponOwner()

	float shiftTime = 1.0

	if ( IsAlive( player ) )
	{
		if ( PhaseShift( player, 0, shiftTime ) )
		{
			if ( player.IsPlayer() )
			{
				PlayerUsedOffhand( player, weapon )

				#if SERVER
					EmitSoundOnEntityExceptToPlayer( player, player, "Stryder.Dash" )
					entity soul = player.GetTitanSoul()
					if ( LTSRebalance_Enabled() && IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_RONIN_AUTOSHIFT ) )
					{
						table weaponDotS = expect table( weapon.s )
						if ( weapon.HasMod( "LTSRebalance_reflex_helper" ) )
						{
							weapon.RemoveMod( "LTSRebalance_reflex_helper" )
							player.SetOrigin( expect vector( weaponDotS.savedOrigin ) )
							player.SetVelocity( <0, 0, 0> )
							return weapon.GetWeaponPrimaryClipCount()
						}
						else
						{
							weaponDotS.savedOrigin <- player.GetOrigin()
							thread LTSRebalance_CreateReflexGate( player, weapon )
						}
					}
					thread PhaseDash( weapon, player )

					if ( soul == null )
						soul = player

					float fade = 0.5
					StatusEffect_AddTimed( soul, eStatusEffect.move_slow, 0.6, shiftTime + fade, fade )
				#elseif CLIENT
					if ( LTSRebalance_Enabled() && weapon.GetWeaponPrimaryClipCount() < weapon.GetAmmoPerShot() )
						return weapon.GetWeaponPrimaryClipCount()

					float xAxis = InputGetAxis( ANALOG_LEFT_X )
					float yAxis = InputGetAxis( ANALOG_LEFT_Y ) * -1
					vector angles = player.EyeAngles()
					vector directionForward = GetDirectionFromInput( angles, xAxis, yAxis )
					if ( IsFirstTimePredicted() )
					{
						EmitSoundOnEntity( player, "Stryder.Dash" )
					}
				#endif
			}
		}

	}
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

#if SERVER
var function OnWeaponNPCPrimaryAttack_titanability_phase_dash( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return OnWeaponPrimaryAttack_titanability_phase_dash( weapon, attackParams )
}

void function PhaseDash( entity weapon, entity player )
{
	float movestunEffect = 1.0 - StatusEffect_Get( player, eStatusEffect.dodge_speed_slow )
	float moveSpeed
	if ( weapon.HasMod( "fd_phase_distance" ) )
		moveSpeed = PHASE_DASH_SPEED * movestunEffect * 1.5
	else
		moveSpeed = PHASE_DASH_SPEED * movestunEffect

	bool perfectPhase = weapon.HasMod( "PerfectKitsReplace_pas_ronin_phase" )
	SetPlayerVelocityFromInput( player, moveSpeed, <0,0,200>, perfectPhase )
}

void function SetPlayerVelocityFromInput( entity player, float scale, vector baseVel = < 0,0,0 >, bool perfectPhase = false )
{
	vector angles = player.EyeAngles()
	float xAxis = player.GetInputAxisRight()
	float yAxis = player.GetInputAxisForward()
	vector directionForward = GetDirectionFromInput( angles, xAxis, yAxis )

	if ( perfectPhase )
	{
		directionForward.z = max( 0.0, directionForward.z )
		baseVel = < 0, 0, PHASE_DASH_SPEED >
	}

	player.SetVelocity( directionForward * scale + baseVel )
}

entity function LTSRebalance_CreateReflexGate( entity player, entity weapon )
{
	weapon.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "DisembarkingTitan" )

	vector origin = player.GetWorldSpaceCenter()
	array<entity> fxEnts = []
	
	OnThreadEnd(
		function() : ( weapon, player, fxEnts )
		{
			if ( IsValid( weapon ) && weapon.HasMod( "LTSRebalance_reflex_helper" ) )
				weapon.RemoveMod( "LTSRebalance_reflex_helper" )
			
			if ( IsValid( player ) )
				ServerToClientStringCommand( player, "ltsrebalance_refresh_reflex_hud" )

			foreach ( entity fx in fxEnts ) 
				if ( IsValid( fx ) )
					EffectStop( fx )
		}
	)

	// Create initial gate FX, toned down to show it doesn't exist yet
	int fxID = GetParticleSystemIndex( $"arcball_CH_dlight" )
	fxEnts.append( StartParticleEffectInWorld_ReturnEntity( fxID, origin, <0, 0, 0> ) )
	fxID = GetParticleSystemIndex( $"arcball_CH_elec_rope" )
	fxEnts.append( StartParticleEffectInWorld_ReturnEntity( fxID, origin, <0, 0, 0> ) )
	wait LTSREBALANCE_REFLEX_START_DELAY
	EffectStop( fxEnts[0] )
	EffectStop( fxEnts[1] )

	// Enable warping and start full gate FX
	weapon.AddMod( "LTSRebalance_reflex_helper" )
	ServerToClientStringCommand( player, "ltsrebalance_refresh_reflex_hud" )
	fxID = GetParticleSystemIndex( $"P_wpn_arcball_trail" )
	fxEnts[0] = StartParticleEffectInWorld_ReturnEntity( fxID, origin, <0, 0, 0> )

	float endTime = Time() + LTSREBALANCE_REFLEX_DURATION
	while( weapon.HasMod( "LTSRebalance_reflex_helper" ) && Time() < endTime )
		WaitFrame()

	// Effects and attachments are cleaned up on thread end
}
#endif

vector function GetDirectionFromInput( vector playerAngles, float xAxis, float yAxis )
{
	playerAngles.x = 0
	playerAngles.z = 0
	vector forward = AnglesToForward( playerAngles )
	vector right = AnglesToRight( playerAngles )

	vector directionVec = Vector(0,0,0)
	directionVec += right * xAxis
	directionVec += forward * yAxis

	vector directionAngles = VectorToAngles( directionVec )
	vector directionForward = AnglesToForward( directionAngles )

	return directionForward
}