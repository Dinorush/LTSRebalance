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
const float LTSREBALANCE_REFLEX_CONTACT_DIST = 200.0
const float LTSREBALANCE_REFLEX_CONTACT_DAMAGE = 100.0

void function MpTitanabilityPhaseDashInit()
{
	#if SERVER
		AddCallback_OnTitanBecomesPilot( LTSRebalance_ClearReflexOnDisembark )
	#else
		AddServerToClientStringCommandCallback( "ltsrebalance_refresh_reflex_hud", LTSRebalance_RefreshReflexHUD )
	#endif
}

#if SERVER
void function LTSRebalance_ClearReflexOnDisembark( entity player, entity oldTitan )
{
	entity phaseDash = oldTitan.GetOffhandWeapon( OFFHAND_TITAN_CENTER )
	if ( IsValid( phaseDash ) && phaseDash.HasMod( "LTSRebalance_reflex_helper" ) )
		phaseDash.RemoveMod( "LTSRebalance_reflex_helper" )
}
#else
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
						if ( weapon.GetWeaponPrimaryClipCount() < weapon.GetAmmoPerShot() && weapon.HasMod( "LTSRebalance_reflex_helper" ) )
						{
							weapon.RemoveMod( "LTSRebalance_reflex_helper" )
							player.SetOrigin( expect vector( weaponDotS.savedOrigin ) )
							ServerToClientStringCommand( player, "ltsrebalance_refresh_reflex_hud" )
							return weapon.GetWeaponPrimaryClipCount()
						}
						else
						{
							weaponDotS.savedOrigin <- player.GetOrigin()
							if ( !weapon.HasMod( "LTSRebalance_reflex_helper" ) )
							{
								weapon.AddMod( "LTSRebalance_reflex_helper" )
								ServerToClientStringCommand( player, "ltsrebalance_refresh_reflex_hud" )
							}
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

	// if ( LTSRebalance_Enabled() )
	// {
	// 	entity soul = player.GetTitanSoul()
	// 	if ( IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_RONIN_AUTOSHIFT ) )
	// 		thread LTSRebalance_ReflexContact( player )
	// }
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

void function LTSRebalance_ReflexContact( entity player )
{
	player.EndSignal( "StopPhaseShift" )
	player.EndSignal( "ForceStopPhaseShift" )
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath" )

	float restoreAmount = expect float( GetSettingsForPlayer_DodgeTable( player )["dodgePowerDrain"] )
	array<entity> hitEnts = []
	while( true )
	{
		array<entity> titans = GetNPCArrayEx( "npc_titan", TEAM_ANY, player.GetTeam(), player.GetWorldSpaceCenter(), LTSREBALANCE_REFLEX_CONTACT_DIST )
		array<entity> players = GetPlayerArrayEx( "any", TEAM_ANY, player.GetTeam(), player.GetWorldSpaceCenter(), LTSREBALANCE_REFLEX_CONTACT_DIST )
		foreach ( enemy in players )
			if ( enemy.IsTitan() )
				titans.append( enemy )

		foreach ( titan in titans )
		{
			if ( hitEnts.contains( titan ) )
				continue

			hitEnts.append( titan )
			titan.SetVelocity( < 0, 0, titan.GetVelocity().z > )
			StatusEffect_AddTimed( titan, eStatusEffect.move_slow, 0.5, 1.0, 0.5 )
			StatusEffect_AddTimed( titan, eStatusEffect.dodge_speed_slow, 0.5, 1.0, 0.5 )
			
			MessageToPlayer( player, eEventNotifications.Rodeo_PilotAppliedBatteryToYou, player, false )
			titan.TakeDamage( LTSREBALANCE_REFLEX_CONTACT_DAMAGE, player, player, { damageSourceId = eDamageSourceId.phase_shift, scriptType = DF_ELECTRICAL } );
			player.Server_SetDodgePower( min( 100.0, player.GetDodgePower() + restoreAmount ) )
		}
		WaitFrame()
	}
	
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