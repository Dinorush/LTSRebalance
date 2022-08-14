global function OnWeaponPrimaryAttack_titanability_phase_dash

#if SERVER
global function OnWeaponNPCPrimaryAttack_titanability_phase_dash
global function SetPlayerVelocityFromInput
#endif

const PHASE_DASH_SPEED = 1000
const float PERFECTKITS_TEMPORAL_RADIUS = 750.0
const float PERFECTKITS_TEMPORAL_DAMAGE = 50.0
const float PERFECTKITS_TEMPORAL_DAMAGE_HEAVYARMOR = 500.0
const float PERFECTKITS_TEMPORAL_PUSH = 500.0
const float PERFECTKITS_TEMPORAL_MIN_SPEED = -500.0
const float PERFECTKITS_TEMPORAL_MAX_DIST = 50.0

var function OnWeaponPrimaryAttack_titanability_phase_dash( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	//PlayWeaponSound( "fire" )
	entity player = weapon.GetWeaponOwner()

	float shiftTime = 1.0
	// float phaseTime = 1.0 // Separate so the slow doesn't last the whole dash for Phase Reflex
	// if ( LTSRebalance_Enabled() && player.IsTitan() )
	// {
	// 	entity soul = player.GetTitanSoul()
	// 	if ( IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_RONIN_AUTOSHIFT ) )
	// 		phaseTime = 2.0
	// }

	if ( IsAlive( player ) )
	{
		if ( PhaseShift( player, 0, shiftTime ) )
		{
			if ( player.IsPlayer() )
			{
				PlayerUsedOffhand( player, weapon )

				#if SERVER
					EmitSoundOnEntityExceptToPlayer( player, player, "Stryder.Dash" )
					thread PhaseDash( weapon, player )
					entity soul = player.GetTitanSoul()
					if ( soul == null )
						soul = player

					float fade = 0.5
					StatusEffect_AddTimed( soul, eStatusEffect.move_slow, 0.6, shiftTime + fade, fade )
				#elseif CLIENT
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
	// if ( perfectPhase )
	// 	thread PerfectKits_DelayedPhaseDrop( player, moveSpeed )
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

void function PerfectKits_DelayedPhaseDrop( entity player, float moveSpeed )
{
	player.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath" )
	player.WaitSignal( "StopPhaseShift" )

	vector vel = player.GetVelocity()
	vel.z = -moveSpeed
	player.SetVelocity( vel )

	entity entBelow = TraceLine( player.GetOrigin(), player.GetOrigin() + < 0,0,-1 >*50, [ player ], TRACE_MASK_TITANSOLID, TRACE_COLLISION_GROUP_NONE ).hitEnt
	while( !player.IsOnGround() && vel.z < PERFECTKITS_TEMPORAL_MIN_SPEED && ( !IsValid( entBelow ) || !entBelow.IsTitan() ) )
	{
		vel = player.GetVelocity()
		WaitFrame()
		entBelow = TraceLine( player.GetOrigin(), player.GetOrigin() + < 0,0,-1 >*50, [ player ], TRACE_MASK_TITANSOLID, TRACE_COLLISION_GROUP_NONE ).hitEnt
	}

	if ( vel.z > PERFECTKITS_TEMPORAL_MIN_SPEED )
		return
	
	PlayFX( FLIGHT_CORE_IMPACT_FX, player.GetOrigin() )
	array<entity> targets = GetNPCArrayEx( "any", TEAM_ANY, player.GetTeam(), player.GetOrigin(), PERFECTKITS_TEMPORAL_RADIUS )
	targets.extend( GetPlayerArrayOfTeam_Alive( GetEnemyTeam( player.GetTeam() ) ) )
	table damageTable = {
		origin = player.GetOrigin(),
		scriptType = DF_RAGDOLL | DF_EXPLOSION,
		damageSourceId = eDamageSourceId.mp_ability_ground_slam
	}

	foreach ( ent in targets )
	{
		if ( !ent.IsOnGround() )
		{
			float downFrac = TraceLine( ent.GetOrigin(), ent.GetOrigin() + <0, 0, -1>*PERFECTKITS_TEMPORAL_MAX_DIST, null, TRACE_MASK_SOLID_BRUSHONLY, TRACE_COLLISION_GROUP_DEBRIS ).fraction
			if ( downFrac == 1.0 )
				continue
		}

		float damage = ent.GetArmorType() == ARMOR_TYPE_HEAVY ? PERFECTKITS_TEMPORAL_DAMAGE_HEAVYARMOR : PERFECTKITS_TEMPORAL_DAMAGE
		ent.TakeDamage( damage, player, player, damageTable )
		if ( ent.IsTitan() || ent.IsPlayer() )
		{
			vector velocity = ent.GetVelocity()
			velocity.z += PERFECTKITS_TEMPORAL_PUSH
			ent.SetVelocity( velocity )
		}
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