untyped
global function MpTitanWeaponStunLaser_Init

global function OnWeaponAttemptOffhandSwitch_titanweapon_stun_laser
global function OnWeaponPrimaryAttack_titanweapon_stun_laser
global function OnWeaponActivate_titanweapon_stun_laser

#if SERVER
global function OnWeaponNPCPrimaryAttack_titanweapon_stun_laser
global function AddStunLaserHealCallback
#endif

const FX_EMP_BODY_HUMAN			= $"P_emp_body_human"
const FX_EMP_BODY_TITAN			= $"P_emp_body_titan"
const FX_SHIELD_GAIN_SCREEN		= $"P_xo_shield_up"
const SHIELD_BODY_FX			= $"P_xo_armor_body_CP"

const int STUN_LASER_PERM_SHIELD = 500
const int STUN_LASER_TEMP_SHIELD = 900
const float TEMP_SHIELD_DECAY_TIME = 2.0
const float PAS_VANGUARD_SHIELD_DECAY_TIME = 4.0
const float TEMP_SHIELD_TICK_RATE = 0.1
const int STUN_LASER_TRANSFER_PERM_SHIELD = 750
const int PERFECTKITS_ENERGY_THIEF_BONUS_SELF_SHIELD = 250

struct
{
	void functionref(entity,entity,int) stunHealCallback
} file

void function MpTitanWeaponStunLaser_Init()
{

	PrecacheParticleSystem( FX_SHIELD_GAIN_SCREEN )
	PrecacheParticleSystem( SHIELD_BODY_FX )

	#if SERVER
		AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_stun_laser, StunLaser_DamagedTarget )
	#endif

	#if CLIENT
		AddEventNotificationCallback( eEventNotifications.VANGUARD_ShieldGain, Vanguard_ShieldGain )
	#endif
}

void function OnWeaponActivate_titanweapon_stun_laser( entity weapon )
{
	#if SERVER
	entity owner = weapon.GetWeaponOwner()
	if ( IsValid( owner ) )
		LTSRebalance_TrackTempShields( owner )
	#endif
}

bool function OnWeaponAttemptOffhandSwitch_titanweapon_stun_laser( entity weapon )
{
	if ( !LTSRebalance_Enabled() )
		return true

	return WeaponHasAmmoToUse( weapon )
}

var function OnWeaponPrimaryAttack_titanweapon_stun_laser( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	#if CLIENT
		if ( !weapon.ShouldPredictProjectiles() )
			return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
	#endif

	if ( weapon.HasMod( "PerfectKits_pas_vanguard_shield" ) && attackParams.burstIndex == 0 )
	{
		int count = weapon.GetWeaponChargeLevel() + 1
		weapon.SetWeaponBurstFireCount( count )
		weapon.s.burstFireCount <- count
	}

	weapon.s.entitiesHit <- {}

	entity weaponOwner = weapon.GetWeaponOwner()
	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

	bool hasEnergyTransfer = weapon.HasMod( "energy_transfer" ) || weapon.HasMod( "energy_field_energy_transfer" ) || weapon.HasMod( "LTSRebalance_energy_field_energy_transfer" )
	if ( LTSRebalance_Enabled() && hasEnergyTransfer )
		EnergyTransfer_ShotgunBlast( weapon, attackParams.pos, attackParams.dir, 1, DF_GIB | DF_EXPLOSION )
	else
		ShotgunBlast( weapon, attackParams.pos, attackParams.dir, 1, DF_GIB | DF_EXPLOSION )
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	weapon.SetWeaponChargeFractionForced(1.0)
	int ammoCost = weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )

	if ( weapon.GetWeaponBurstFireCount() > 0 )
		ammoCost /= weapon.GetWeaponBurstFireCount()
	return ammoCost
}
#if SERVER
var function OnWeaponNPCPrimaryAttack_titanweapon_stun_laser( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return OnWeaponPrimaryAttack_titanweapon_stun_laser( weapon, attackParams )
}

void function StunLaser_DamagedTarget( entity target, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	entity weapon = DamageInfo_GetInflictor( damageInfo )
	
	if ( attacker == target )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
		return
	}

	if ( LTSRebalance_Enabled() && IsValid( weapon ) && "entitiesHit" in weapon.s )
	{
		// Increment up to 2 per target since Siphon has two callbacks
		if ( !( target in weapon.s.entitiesHit ) )
			weapon.s.entitiesHit[target] <- 1
		else if ( weapon.s.entitiesHit[target] < 2 )
			weapon.s.entitiesHit[target] += 1
		else
		{
			DamageInfo_SetDamage( damageInfo, 0 )
			return
		}
	}

	float mod = ( IsValid( weapon ) && "burstFireCount" in weapon.s ) ? ( 1.0 + float( weapon.s.burstFireCount - 1 ) * 0.25 ) / float( weapon.s.burstFireCount ) : 1.0

	if ( attacker.GetTeam() == target.GetTeam() )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
		entity attackerSoul = attacker.GetTitanSoul()
		
		if ( !IsValid( weapon ) )
			return
		bool hasEnergyTransfer = weapon.HasMod( "energy_transfer" ) || weapon.HasMod( "energy_field_energy_transfer" ) || weapon.HasMod( "LTSRebalance_energy_field_energy_transfer" )
		if ( target.IsTitan() && IsValid( attackerSoul ) && hasEnergyTransfer )
		{
			entity soul = target.GetTitanSoul()
			if ( IsValid( soul ) )
			{
				int shieldRestoreAmount = LTSRebalance_Enabled() ? STUN_LASER_TRANSFER_PERM_SHIELD : 750
				if ( SoulHasPassive( LTSRebalance_Enabled() ? attackerSoul : soul, ePassives.PAS_VANGUARD_SHIELD ) )
					shieldRestoreAmount = int( 1.25 * shieldRestoreAmount )
				shieldRestoreAmount = int( shieldRestoreAmount * mod )

				shieldRestoreAmount -= PerfectKits_EnergyThiefConvert( target, shieldRestoreAmount )
				LTSRebalance_HandleTempShieldChange( soul, shieldRestoreAmount )
				float shieldAmount = min( soul.GetShieldHealth() + shieldRestoreAmount, soul.GetShieldHealthMax() )
				shieldRestoreAmount = soul.GetShieldHealthMax() - int( shieldAmount )

				soul.SetShieldHealth( shieldAmount )

				if ( file.stunHealCallback != null && shieldRestoreAmount > 0 )
					file.stunHealCallback( attacker, target, shieldRestoreAmount )
			}
			
			if ( LTSRebalance_Enabled() )
			{
				int shieldRestoreAmount = STUN_LASER_PERM_SHIELD
				if ( SoulHasPassive( attackerSoul, ePassives.PAS_VANGUARD_SHIELD ) )
					shieldRestoreAmount = int( 1.25 * shieldRestoreAmount )
				shieldRestoreAmount = int( shieldRestoreAmount * mod )

				shieldRestoreAmount -= PerfectKits_EnergyThiefConvert( attacker, shieldRestoreAmount )
				
				LTSRebalance_HandleTempShieldChange( attackerSoul, shieldRestoreAmount )
				attackerSoul.SetShieldHealth( min( attackerSoul.GetShieldHealth() + shieldRestoreAmount, attackerSoul.GetShieldHealthMax() ) )

				if ( attacker.IsPlayer() )
					MessageToPlayer( attacker, eEventNotifications.VANGUARD_ShieldGain, attacker )
			}

			if ( target.IsPlayer() )
				MessageToPlayer( target, eEventNotifications.VANGUARD_ShieldGain, target )

			if ( attacker.IsPlayer() )
				EmitSoundOnEntityOnlyToPlayer( target, attacker, "EnergySyphon_ShieldGive" )

			float shieldHealthFrac = GetShieldHealthFrac( target )
			if ( shieldHealthFrac < 1.0 )
			{
				int shieldbodyFX = GetParticleSystemIndex( SHIELD_BODY_FX )
				int attachID
				if ( target.IsTitan() )
					attachID = target.LookupAttachment( "exp_torso_main" )
				else
					attachID = target.LookupAttachment( "ref" )

				entity shieldFXEnt = StartParticleEffectOnEntity_ReturnEntity( target, shieldbodyFX, FX_PATTACH_POINT_FOLLOW, attachID )
				EffectSetControlPointVector( shieldFXEnt, 1, < 115, 247, 255 > )
			}
		}
	}
	else if ( target.IsNPC() || target.IsPlayer() )
	{
		entity soul = attacker.GetTitanSoul()
		if ( IsValid( soul ) )
		{
			int permRestoreAmount = target.GetArmorType() == ARMOR_TYPE_HEAVY ? ( LTSRebalance_Enabled() ? STUN_LASER_PERM_SHIELD : 750 ) : 250
			if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_SHIELD ) )
				permRestoreAmount = int( 1.25 * permRestoreAmount )
			permRestoreAmount = int( permRestoreAmount * mod )
			
			permRestoreAmount -= PerfectKits_EnergyThiefConvert( attacker, permRestoreAmount )

			LTSRebalance_HandleTempShieldChange( soul, permRestoreAmount )
			int newShield = minint( soul.GetShieldHealthMax(), soul.GetShieldHealth() + permRestoreAmount )
			soul.SetShieldHealth( newShield )
			if ( LTSRebalance_Enabled() && target.GetArmorType() == ARMOR_TYPE_HEAVY )
			{
				int tempShieldAmount = int( STUN_LASER_TEMP_SHIELD * mod )
				tempShieldAmount -= PerfectKits_EnergyThiefTake( attacker, tempShieldAmount )
				PerfectKits_EnergyThiefConvert( attacker, PERFECTKITS_ENERGY_THIEF_BONUS_SELF_SHIELD ) // Bonus shield to compensate for not using temp shields

				if ( newShield < soul.GetShieldHealthMax() )
				{
					float decayTime = SoulHasPassive( soul, ePassives.PAS_VANGUARD_SHIELD ) ? PAS_VANGUARD_SHIELD_DECAY_TIME : TEMP_SHIELD_DECAY_TIME
					LTSRebalance_AddTempShields( soul, tempShieldAmount, 0, decayTime )
				}
			}
		}
		if ( attacker.IsPlayer() )
			MessageToPlayer( attacker, eEventNotifications.VANGUARD_ShieldGain, attacker )
	}
}

void function AddStunLaserHealCallback( void functionref(entity,entity,int) func )
{
	file.stunHealCallback = func
}
#endif


#if CLIENT
void function Vanguard_ShieldGain( entity attacker, var eventVal )
{
	if ( attacker.IsPlayer() )
	{
		//FlashCockpitHealthGreen()
		EmitSoundOnEntity( attacker, "EnergySyphon_ShieldRecieved"  )
		entity cockpit = attacker.GetCockpit()
		if ( IsValid( cockpit ) )
			StartParticleEffectOnEntity( cockpit, GetParticleSystemIndex( FX_SHIELD_GAIN_SCREEN	), FX_PATTACH_ABSORIGIN_FOLLOW, -1 )
		Rumble_Play( "rumble_titan_battery_pickup", { position = attacker.GetOrigin() } )
	}

}
#endif

// Energy Transfer has bad dusting on friendlies.
// This is just copied ShotgunBlast except if it missed, we (HACK) switch teams when acquiring targets to get lag compensation on friendlies.
function EnergyTransfer_ShotgunBlast( entity weapon, vector pos, vector dir, int numBlasts, int damageType, float damageScaler = 1.0, float ornull maxAngle = null, float ornull maxDistance = null )
{
	Assert( numBlasts > 0 )
	int numBlastsOriginal = numBlasts
	entity owner = weapon.GetWeaponOwner()
	int team = owner.GetTeam()
	/*
	Debug ConVars:
		visible_ent_cone_debug_duration_client - Set to non-zero to see debug output
		visible_ent_cone_debug_duration_server - Set to non-zero to see debug output
		visible_ent_cone_debug_draw_radius - Size of trace endpoint debug draw
	*/

	if ( maxDistance == null )
		maxDistance	= weapon.GetMaxDamageFarDist()
	expect float( maxDistance )

	if ( maxAngle == null )
		maxAngle = owner.GetAttackSpreadAngle() * 0.5
	expect float( maxAngle )

	array<entity> ignoredEntities 	= [ owner ]
	int traceMask 					= TRACE_MASK_SHOT
	int visConeFlags				= VIS_CONE_ENTS_TEST_HITBOXES | VIS_CONE_ENTS_CHECK_SOLID_BODY_HIT | VIS_CONE_ENTS_APPOX_CLOSEST_HITBOX | VIS_CONE_RETURN_HIT_VORTEX

	entity antilagPlayer
	if ( owner.IsPlayer() )
	{
		if ( owner.IsPhaseShifted() )
			return;

		antilagPlayer = owner
	}

	//JFS - Bug 198500
	Assert( maxAngle > 0.0, "JFS returning out at this instance. We need to investigate when a valid mp_titanweapon_laser_lite weapon returns 0 spread")
	if ( maxAngle == 0.0 )
		return

	array<VisibleEntityInCone> results = FindVisibleEntitiesInCone( pos, dir, maxDistance, (maxAngle * 1.1), ignoredEntities, traceMask, visConeFlags, antilagPlayer, weapon )
	foreach ( result in results )
	{
		float angleToHitbox = 0.0
		if ( !result.solidBodyHit )
			angleToHitbox = DegreesToTarget( pos, dir, result.approxClosestHitboxPos )

		numBlasts -= ShotgunBlastDamageEntity( weapon, pos, dir, result, angleToHitbox, maxAngle, numBlasts, damageType, damageScaler )
		if ( numBlasts <= 0 )
			break
	}

	// Energy Transfer appears to dust, guessing due to antilag not working for teammates. So... this hack.
	#if SERVER
	if ( numBlasts > 0 && owner.IsPlayer() && ( team == TEAM_IMC || team == TEAM_MILITIA ) )
	{
		SetTeam( owner, TEAM_IMC + TEAM_MILITIA - team )
		array<VisibleEntityInCone> results = FindVisibleEntitiesInCone( pos, dir, maxDistance, (maxAngle * 1.1), ignoredEntities, traceMask, visConeFlags, antilagPlayer, weapon )
		SetTeam( owner, team )
		foreach ( result in results )
		{
			if ( result.ent.GetTeam() != team )
				continue

			float angleToHitbox = 0.0
			if ( !result.solidBodyHit )
				angleToHitbox = DegreesToTarget( pos, dir, result.approxClosestHitboxPos )

			numBlasts -= ShotgunBlastDamageEntity( weapon, pos, dir, result, angleToHitbox, maxAngle, numBlasts, damageType, damageScaler )
			if ( numBlasts <= 0 )
				break
		}
	}
	#endif

	//Something in the TakeDamage above is triggering the weapon owner to become invalid.
	owner = weapon.GetWeaponOwner()
	if ( !IsValid( owner ) )
		return

	// maxTracer limit set in /r1dev/src/game/client/c_player.h
	const int MAX_TRACERS = 16
	bool didHitAnything = ((numBlastsOriginal - numBlasts) != 0)
	bool doTraceBrushOnly = (!didHitAnything)
	if ( numBlasts > 0 )
		weapon.FireWeaponBullet_Special( pos, dir, minint( numBlasts, MAX_TRACERS ), damageType, false, false, true, false, false, false, doTraceBrushOnly )
}


const SHOTGUN_ANGLE_MIN_FRACTION = 0.1;
const SHOTGUN_ANGLE_MAX_FRACTION = 1.0;
const SHOTGUN_DAMAGE_SCALE_AT_MIN_ANGLE = 0.8;
const SHOTGUN_DAMAGE_SCALE_AT_MAX_ANGLE = 0.1;

int function ShotgunBlastDamageEntity( entity weapon, vector barrelPos, vector barrelVec, VisibleEntityInCone result, float angle, float maxAngle, int numPellets, int damageType, float damageScaler )
{
	entity target = result.ent

	//The damage scaler is currently only > 1 for the Titan Shotgun alt fire.
	if ( !target.IsTitan() && damageScaler > 1 )
		damageScaler = max( damageScaler * 0.4, 1.5 )

	entity owner = weapon.GetWeaponOwner()
	// Ent in cone not valid
	if ( !IsValid( target ) || !IsValid( owner ) )
		return 0

	// Fire fake bullet towards entity for visual purposes only
	vector hitLocation = result.visiblePosition
	vector vecToEnt = ( hitLocation - barrelPos )
	vecToEnt.Norm()
	if ( Length( vecToEnt ) == 0 )
		vecToEnt = barrelVec

	// This fires a fake bullet that doesn't do any damage. Currently it triggeres a damage callback with 0 damage which is bad.
	weapon.FireWeaponBullet_Special( barrelPos, vecToEnt, 1, damageType, true, true, true, false, false, false, false ) // fires perfect bullet with no antilag and no spread

#if SERVER
	// Determine how much damage to do based on distance
	float distanceToTarget = Distance( barrelPos, hitLocation )

	if ( !result.solidBodyHit ) // non solid hits take 1 blast more
		distanceToTarget += 130

	int extraMods = result.extraMods
	float damageAmount = CalcWeaponDamage( owner, target, weapon, distanceToTarget, extraMods )

	// vortex needs to scale damage based on number of rounds absorbed
	string className = weapon.GetWeaponClassName()
	if ( (className == "mp_titanweapon_vortex_shield") || (className == "mp_titanweapon_vortex_shield_ion") || (className == "mp_titanweapon_heat_shield") )
	{
		damageAmount *= numPellets
		//printt( "scaling vortex hitscan output damage by", numPellets, "pellets for", weaponNearDamageTitan, "damage vs titans" )
	}

	float coneScaler = 1.0
	//if ( angle > 0 )
	//	coneScaler = GraphCapped( angle, (maxAngle * SHOTGUN_ANGLE_MIN_FRACTION), (maxAngle * SHOTGUN_ANGLE_MAX_FRACTION), SHOTGUN_DAMAGE_SCALE_AT_MIN_ANGLE, SHOTGUN_DAMAGE_SCALE_AT_MAX_ANGLE )

	// Calculate the final damage abount to inflict on the target. Also scale it by damageScaler which may have been passed in by script ( used by alt fire mode on titan shotgun to fire multiple shells )
	float finalDamageAmount = damageAmount * coneScaler * damageScaler
	//printt( "angle:", angle, "- coneScaler:", coneScaler, "- damageAmount:", damageAmount, "- damageScaler:", damageScaler, "  = finalDamageAmount:", finalDamageAmount )

	// Calculate impulse force to apply based on damage
	int maxImpulseForce = expect int( weapon.GetWeaponInfoFileKeyField( "impulse_force" ) )
	float impulseForce = float( maxImpulseForce ) * coneScaler * damageScaler
	vector impulseVec = barrelVec * impulseForce

	int damageSourceID = weapon.GetDamageSourceID()

	//
	float critScale = weapon.GetWeaponSettingFloat( eWeaponVar.critical_hit_damage_scale )
	target.TakeDamage( finalDamageAmount, owner, weapon, { origin = hitLocation, force = impulseVec, scriptType = damageType, damageSourceId = damageSourceID, weapon = weapon, hitbox = result.visibleHitbox, criticalHitScale = critScale } )

	//printt( "-----------" )
	//printt( "    distanceToTarget:", distanceToTarget )
	//printt( "    damageAmount:", damageAmount )
	//printt( "    coneScaler:", coneScaler )
	//printt( "    impulseForce:", impulseForce )
	//printt( "    impulseVec:", impulseVec.x + ", " + impulseVec.y + ", " + impulseVec.z )
	//printt( "        finalDamageAmount:", finalDamageAmount )
	//PrintTable( result )
#endif // #if SERVER

	return 1
}