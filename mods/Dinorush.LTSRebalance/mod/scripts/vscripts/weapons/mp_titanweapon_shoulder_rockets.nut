/* LTS Rebalance replaces this file for the following reasons:
   1. Implement baseline changes
   2. Fix dumbfired rockets firing less than they should
   3. Fix not being able to use missiles until 20% charge
*/
global function MpTitanWeaponShoulderRockets_Init
global function OnWeaponOwnerChanged_titanweapon_shoulder_rockets
global function OnWeaponPrimaryAttack_titanweapon_shoulder_rockets
global function OnWeaponAttemptOffhandSwitch_titanweapon_shoulder_rockets
global function OnWeaponChargeBegin_titanweapon_shoulder_rockets
#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_shoulder_rockets
#endif

//----------------------
// Multi-Target Missile System
//----------------------

const SHOULDERROCKETS_NUM_ROCKETS_PER_SHOT				= 1
const float SHOULDERROCKETS_MISSILE_SPEED				= 1000.0
const float LTSREBALANCE_SHOULDERROCKETS_MISSILE_SPEED 	= 2500.0
const SHOULDERROCKETS_APPLY_RANDOM_SPREAD				= true
const SHOULDERROCKETS_LAUNCH_OUT_TIME					= 0.2
const SHOULDERROCKETS_LAUNCH_IN_LERP_TIME				= 0.0
const SHOULDERROCKETS_LAUNCH_IN_TIME					= 0.0
const SHOULDERROCKETS_LAUNCH_STRAIGHT_LERP_TIME			= -0.2

struct
{
	int validShotTimes = 0
	float lastValidUseTime = -999
	int launch_out_angle = 10
	int launch_in_angle = -10
} file

void function MpTitanWeaponShoulderRockets_Init()
{
	#if MP
		file.launch_in_angle = -5
		file.launch_out_angle = 5
	#endif
}

bool function OnWeaponAttemptOffhandSwitch_titanweapon_shoulder_rockets( entity weapon )
{
	if ( !LTSRebalance_Enabled() )
		return weapon.GetWeaponChargeFraction() <= 0.8
	int maxTargetedBurst = weapon.GetWeaponSettingInt( eWeaponVar.smart_ammo_max_targeted_burst )
	float shotFrac = 1.0 / maxTargetedBurst.tofloat()
	return weapon.GetWeaponChargeFraction() <= 1.0 - shotFrac
}

void function OnWeaponOwnerChanged_titanweapon_shoulder_rockets( entity weapon, WeaponOwnerChangedParams changeParams )
{
	Init_titanweapon_shoulder_rockets( weapon )
}

bool function OnWeaponChargeBegin_titanweapon_shoulder_rockets( entity weapon )
{
	// only set this if we are close to fully charged - so the hint doesn't display when we are low on charge
	// !!!! WARNING: change this if we start using startChargeTime for other things !!!!
	if ( weapon.GetWeaponChargeFraction() < 0.5 )
		weapon.w.startChargeTime = Time()
	else
		weapon.w.startChargeTime = 0.0

	return true
}

void function Init_titanweapon_shoulder_rockets( entity weapon )
{
	if ( !weapon.w.initialized )
	{
		float multiSpeed = LTSRebalance_Enabled() ? LTSREBALANCE_SHOULDERROCKETS_MISSILE_SPEED : VANGUARD_SHOULDER_MISSILE_SPEED
		float missileSpeed = IsMultiplayer() ? multiSpeed : SHOULDERROCKETS_MISSILE_SPEED
		SmartAmmo_SetMissileSpeed( weapon, missileSpeed )
		float homingSpeed = IsMultiplayer() ? ( multiSpeed / SHOULDERROCKETS_MISSILE_SPEED * 250 ) : 250.0
		SmartAmmo_SetMissileHomingSpeed( weapon, homingSpeed )
		SmartAmmo_SetUnlockAfterBurst( weapon, true )
		float launchOutTime =  VANGUARD_SHOULDER_MISSILE_SPEED / multiSpeed * SHOULDERROCKETS_LAUNCH_OUT_TIME
		SmartAmmo_SetExpandContract( weapon, SHOULDERROCKETS_NUM_ROCKETS_PER_SHOT, SHOULDERROCKETS_APPLY_RANDOM_SPREAD, file.launch_out_angle, launchOutTime, SHOULDERROCKETS_LAUNCH_IN_LERP_TIME, file.launch_in_angle, SHOULDERROCKETS_LAUNCH_IN_TIME, SHOULDERROCKETS_LAUNCH_STRAIGHT_LERP_TIME )
		weapon.w.initialized = true
	}
}

var function OnWeaponPrimaryAttack_titanweapon_shoulder_rockets( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	bool shouldPredict = weapon.ShouldPredictProjectiles()

#if CLIENT
		if ( !shouldPredict )
			return 1
#endif

	entity owner = weapon.GetWeaponOwner()

#if SERVER
	if ( owner.IsNPC() && owner.GetEnemy() && owner.GetEnemy().IsPlayer() )
		SmartAmmo_SetShouldTrackPosition( weapon, true )
	else
#endif
		SmartAmmo_SetShouldTrackPosition( weapon, false )

	int smartAmmoFired = SmartAmmo_FireWeapon( weapon, attackParams, damageTypes.projectileImpact, damageTypes.explosive )
	int maxTargetedBurst = weapon.GetWeaponSettingInt( eWeaponVar.smart_ammo_max_targeted_burst )
	float shotFrac = 1.0 / maxTargetedBurst.tofloat()

	if ( smartAmmoFired == 0 )
	{
		if ( IsMultiplayer() )
		{
			if ( LTSRebalance_Enabled() )
				weapon.SetWeaponBurstFireCount( maxTargetedBurst - int( ceil( weapon.GetWeaponChargeFraction() * maxTargetedBurst ) ) )
			else
				weapon.SetWeaponBurstFireCount( maxTargetedBurst - int( (weapon.GetWeaponChargeFraction() + shotFrac ) * maxTargetedBurst ) )
			OnWeaponPrimaryAttack_titanweapon_salvo_rockets( weapon, attackParams )
        }
		else
		{
			entity missile = weapon.FireWeaponMissile( attackParams.pos, attackParams.dir, SHOULDERROCKETS_MISSILE_SPEED, damageTypes.projectileImpact, damageTypes.explosive, false, shouldPredict )
			weapon.SetWeaponBurstFireCount( 1 )
		}

		weapon.SetWeaponChargeFractionForced( weapon.GetWeaponChargeFraction() + shotFrac )
	}
	else
	{
		weapon.SetWeaponChargeFractionForced( weapon.GetWeaponChargeFraction() + shotFrac )


		if ( owner.IsPlayer() && attackParams.burstIndex == 0 )
		{
			if ( PlayerMisusedShoulderRockets( weapon ) && !PlayerKnowsHowToUseShoulderRockets( weapon ) )
			{
				#if CLIENT && HAS_TITAN_TELEMETRY
				int validTargets = 0
				array<entity> storedTargets = SmartAmmo_GetWeaponTargets( weapon )
				foreach ( target in storedTargets )
				{
					if ( IsHumanSized( target ) )
						continue

					validTargets++
				}

				if ( validTargets >= 1 )
				{
					CreateButtonPressHint( "#HINT_SHOULDER_ROCKETS_HOLD", OFFHAND_ORDNANCE )
				}
				#endif
			}
			else
			{
				file.lastValidUseTime = Time()
				file.validShotTimes++
				PlayerUsedOffhand( owner, weapon )
			}
		}
	}

	return 1
}

bool function PlayerMisusedShoulderRockets( entity weapon )
{
	return ( Time() - weapon.w.startChargeTime < 1.0 && weapon.GetWeaponBurstFireCount() < 5 )
}

bool function PlayerKnowsHowToUseShoulderRockets( entity weapon )
{
	return (!( file.validShotTimes < 6 || file.lastValidUseTime < Time() - 60.0 ))
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_shoulder_rockets( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return OnWeaponPrimaryAttack_titanweapon_shoulder_rockets( weapon, attackParams )
}
#endif