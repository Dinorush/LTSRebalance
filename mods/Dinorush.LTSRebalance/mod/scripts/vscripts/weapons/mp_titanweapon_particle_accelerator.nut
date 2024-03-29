/* LTS Rebalance replaces this file for the following reasons:
   1. Implement baseline changes
   2. Implement Perfect Kits Refraction Lens
   3. Fix splitting without damage reduction
   4. Link new OnWeaponActivate functions to a vanilla function
*/
untyped

global function MpTitanWeaponParticleAccelerator_Init

global function OnWeaponPrimaryAttack_titanweapon_particle_accelerator
global function OnWeaponActivate_titanweapon_particle_accelerator
global function OnWeaponCooldown_titanweapon_particle_accelerator
global function OnWeaponStartZoomIn_titanweapon_particle_accelerator
global function OnWeaponStartZoomOut_titanweapon_particle_accelerator

global function PROTO_GetHeatMeterCharge

#if SERVER
global function OnWeaponNpcPrimaryAttack_titanweapon_particle_accelerator
#endif

const ADS_SHOT_COUNT_NORMAL = 3
const ADS_SHOT_COUNT_UPGRADE = 5
const PERFECTKITS_ADS_SHOT_COUNT_UPGRADE = 7
const TPAC_PROJECTILE_SPEED = 8000
const TPAC_PROJECTILE_SPEED_NPC = 5000
const LSTAR_LOW_AMMO_WARNING_FRAC = 0.25
const LSTAR_COOLDOWN_EFFECT_1P = $"wpn_mflash_snp_hmn_smokepuff_side_FP"
const LSTAR_COOLDOWN_EFFECT_3P = $"wpn_mflash_snp_hmn_smokepuff_side"
const LSTAR_BURNOUT_EFFECT_1P = $"xo_spark_med"
const LSTAR_BURNOUT_EFFECT_3P = $"xo_spark_med"

const TPA_ADS_EFFECT_1P = $"P_TPA_electricity_FP"
const TPA_ADS_EFFECT_3P = $"P_TPA_electricity"

const CRITICAL_ENERGY_RESTORE_AMOUNT = 30
const SPLIT_SHOT_CRITICAL_ENERGY_RESTORE_AMOUNT = 8

const LTSREBALANCE_CRITICAL_ENERGY_RESTORE_AMOUNT = 15
const LTSREBALANCE_SPLIT_SHOT_CRITICAL_ENERGY_RESTORE_AMOUNT = 7
const LTSREBALANCE_PAS_SPLIT_SHOT_CRITICAL_ENERGY_RESTORE_AMOUNT = 0

struct {
	float[PERFECTKITS_ADS_SHOT_COUNT_UPGRADE] boltOffsets = [
		0.0,
		0.022,
		-0.022,
		0.044,
		-0.044,
		0.066,
		-0.066
	]

	float[PERFECTKITS_ADS_SHOT_COUNT_UPGRADE] LTSRebalance_boltOffsets = [
		0.0,
		0.02,
		-0.02,
		0.04,
		-0.04,
		0.06,
		-0.06
	]
} file

function MpTitanWeaponParticleAccelerator_Init()
{
	PrecacheParticleSystem( LSTAR_COOLDOWN_EFFECT_1P )
	PrecacheParticleSystem( LSTAR_COOLDOWN_EFFECT_3P )
	PrecacheParticleSystem( LSTAR_BURNOUT_EFFECT_1P )
	PrecacheParticleSystem( LSTAR_BURNOUT_EFFECT_3P )
	PrecacheParticleSystem( TPA_ADS_EFFECT_1P )
	PrecacheParticleSystem( TPA_ADS_EFFECT_3P )

	#if SERVER
	AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_particle_accelerator, OnHit_TitanWeaponParticleAccelerator )
    #endif
}

void function OnWeaponStartZoomIn_titanweapon_particle_accelerator( entity weapon )
{
	array<string> mods = weapon.GetMods()
	if ( weapon.HasMod( "fd_split_shot_cost") )
	{
		if ( weapon.HasMod( "pas_ion_weapon_ads" ) || weapon.HasMod( "LTSRebalance_pas_ion_weapon_ads" ) )
			mods.append( "fd_upgraded_proto_particle_accelerator_pas" )
		else
			mods.append( "fd_upgraded_proto_particle_accelerator" )
	}
	else
	{
		if ( weapon.HasMod( "pas_ion_weapon_ads" ) || weapon.HasMod( "LTSRebalance_pas_ion_weapon_ads" ) )
			mods.append( "proto_particle_accelerator_pas" )
		else
			mods.append( "proto_particle_accelerator" )
	}

	if ( weapon.HasMod( "PerfectKits_pas_ion_weapon_ads" ) )
		mods.append( "PerfectKits_pas_ion_weapon_ads_helper" )
	#if SERVER
	else if ( PerfectKits_Enabled() )
	{
		entity owner = weapon.GetWeaponOwner()
		if ( owner.IsTitan() && IsValid( owner.GetTitanSoul() ) && SoulHasPassive( owner.GetTitanSoul(), ePassives.PAS_ION_WEAPON ) )
			mods.append( "PerfectKits_pas_ion_weapon_helper" )
	}
	#endif

	weapon.SetMods( mods )
	weapon.s.zoomedIn = true

	#if CLIENT
		entity weaponOwner = weapon.GetWeaponOwner()
		if ( weaponOwner == GetLocalViewPlayer() )
			EmitSoundOnEntity( weaponOwner, "Weapon_Particle_Accelerator_WindUp_1P" )
	#endif
	weapon.PlayWeaponEffectNoCull( TPA_ADS_EFFECT_1P, TPA_ADS_EFFECT_3P, "muzzle_flash" )
	//weapon.PlayWeaponEffectNoCull( $"wpn_arc_cannon_charge_fp", $"wpn_arc_cannon_charge", "muzzle_flash" )
	weapon.EmitWeaponSound( "arc_cannon_charged_loop" )
}

void function OnWeaponStartZoomOut_titanweapon_particle_accelerator( entity weapon )
{
	array<string> mods = weapon.GetMods()
	mods.fastremovebyvalue( "proto_particle_accelerator" )
	mods.fastremovebyvalue( "proto_particle_accelerator_pas" )
	mods.fastremovebyvalue( "PerfectKits_pas_ion_weapon_ads_helper" )
	mods.fastremovebyvalue( "PerfectKits_pas_ion_weapon_helper" )
	weapon.SetMods( mods )
	weapon.s.zoomedIn = false
	//weapon.StopWeaponEffect( $"wpn_arc_cannon_charge_fp", $"wpn_arc_cannon_charge" )
	weapon.StopWeaponEffect( TPA_ADS_EFFECT_1P, TPA_ADS_EFFECT_3P )
	weapon.StopWeaponSound( "arc_cannon_charged_loop" )
}

void function OnWeaponActivate_titanweapon_particle_accelerator( entity weapon )
{
	if ( LTSRebalance_Enabled() && weapon.GetWeaponClassName() == "mp_titanweapon_stun_laser" )
	{
		OnWeaponActivate_titanweapon_stun_laser( weapon )
		return
	}
	
	if ( !( "initialized" in weapon.s ) )
	{
		weapon.s.zoomedIn <- false
		weapon.s.initialized <- true
	}
}

function OnWeaponPrimaryAttack_titanweapon_particle_accelerator( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity owner = weapon.GetWeaponOwner()
	float zoomFrac = owner.GetZoomFrac()
	if ( zoomFrac < 1 && zoomFrac > 0)
		return 0

	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	return FireWeaponPlayerAndNPC( weapon, attackParams, true )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_particle_accelerator( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	return FireWeaponPlayerAndNPC( weapon, attackParams, false )
}
#endif // #if SERVER


function FireWeaponPlayerAndNPC( entity weapon, WeaponPrimaryAttackParams attackParams, bool playerFired )
{
	bool shouldCreateProjectile = false
	if ( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectile = true

	#if CLIENT
		if ( !playerFired )
			shouldCreateProjectile = false
	#endif

	entity owner = weapon.GetWeaponOwner()
    bool inADS = weapon.IsWeaponInAds()
	if ( LTSRebalance_Enabled() && inADS && !weapon.s.zoomedIn ) // Fix for Laser Shot -> Splitter not applying ADS attachments
		OnWeaponStartZoomIn_titanweapon_particle_accelerator( weapon )

	int ADS_SHOT_COUNT = ( weapon.HasMod( "pas_ion_weapon_ads" ) || weapon.HasMod( "LTSRebalance_pas_ion_weapon_ads" ) ) ? ADS_SHOT_COUNT_UPGRADE : ADS_SHOT_COUNT_NORMAL
	if ( shouldCreateProjectile )
	{
	    int shotCount = inADS ? ADS_SHOT_COUNT : 1
		weapon.ResetWeaponToDefaultEnergyCost()
		int cost = weapon.GetWeaponCurrentEnergyCost()
		int currentEnergy = owner.GetSharedEnergyCount()
		bool outOfEnergy = (currentEnergy < cost) || (currentEnergy == 0)
		if ( !inADS || outOfEnergy )
		{
			weapon.SetWeaponEnergyCost( 0 )
			shotCount = 1

			#if CLIENT
				if ( outOfEnergy )
					FlashEnergyNeeded_Bar( cost )
			#endif
			//Single Shots
			weapon.EmitWeaponSound_1p3p( "Weapon_Particle_Accelerator_Fire_1P", "Weapon_Particle_Accelerator_SecondShot_3P" )
		}
		else
		{
			shotCount = ADS_SHOT_COUNT
			//Split Shots
			weapon.EmitWeaponSound_1p3p( "Weapon_Particle_Accelerator_AltFire_1P", "Weapon_Particle_Accelerator_AltFire_SecondShot_3P" )
		}

		if ( PerfectKits_Enabled() )
		{
			if ( shotCount == 1 && weapon.HasMod( "PerfectKits_pas_ion_weapon_ads" ) )
				shotCount = 3
			else if ( shotCount == ADS_SHOT_COUNT_UPGRADE && PerfectKits_Enabled() )
				shotCount = PERFECTKITS_ADS_SHOT_COUNT_UPGRADE
		}

		vector attackAngles = VectorToAngles( attackParams.dir )
		vector baseRightVec = AnglesToRight( attackAngles )
		float[PERFECTKITS_ADS_SHOT_COUNT_UPGRADE] boltOffsets = LTSRebalance_Enabled() ? file.LTSRebalance_boltOffsets : file.boltOffsets
		for ( int index = 0; index < shotCount; index++ )
		{
			vector attackVec = attackParams.dir + baseRightVec * boltOffsets[index]
			int damageType = damageTypes.largeCaliber | DF_STOPS_TITAN_REGEN

			float speed = TPAC_PROJECTILE_SPEED
			if ( owner.IsNPC() )
				speed = TPAC_PROJECTILE_SPEED_NPC

			entity bolt = weapon.FireWeaponBolt( attackParams.pos, attackVec, speed, damageType, damageType, playerFired, 0 )
			if ( bolt != null )
			{
				//bolt.kv.gravity = -0.1
				bolt.kv.rendercolor = "0 0 0"
				bolt.kv.renderamt = 0
				bolt.kv.fadedist = 1
			}
		}
	}
	return 1
}

void function OnWeaponCooldown_titanweapon_particle_accelerator( entity weapon )
{
	weapon.PlayWeaponEffect( LSTAR_COOLDOWN_EFFECT_1P, LSTAR_COOLDOWN_EFFECT_3P, "SPINNING_KNOB" ) //"DWAY_ROTATE"
	weapon.EmitWeaponSound_1p3p( "LSTAR_VentCooldown", "LSTAR_VentCooldown" )
}

int function PROTO_GetHeatMeterCharge( entity weapon )
{
	if ( !IsValid( weapon ) )
		return 0

	entity owner = weapon.GetWeaponOwner()
	if ( !IsValid( owner ) )
		return 0

	if ( weapon.IsReloading() )
		return 8

	float max = float ( owner.GetWeaponAmmoMaxLoaded( weapon ) )
	float currentAmmo = float ( owner.GetWeaponAmmoLoaded( weapon ) )

	float crosshairSegments = 8.0
	return int ( GraphCapped( currentAmmo, max, 0.0, 0.0, crosshairSegments ) )
}

#if SERVER
void function OnHit_TitanWeaponParticleAccelerator( entity victim, var damageInfo )
{
	entity inflictor = DamageInfo_GetInflictor( damageInfo )
	if ( !IsValid( inflictor ) )
		return
	if ( !inflictor.IsProjectile() )
		return

	entity attacker = DamageInfo_GetAttacker( damageInfo )

	if ( !IsValid( attacker ) || attacker.IsProjectile() ) //Is projectile check is necessary for when the original attacker is no longer valid it becomes the projectile.
		return

	if ( attacker.GetSharedEnergyTotal() <= 0 )
		return

	if ( attacker.GetTeam() == victim.GetTeam() )
		return

	entity soul = attacker.GetTitanSoul()
	if ( !IsValid( soul ) )
		return

	if ( PerfectKits_Enabled() && SoulHasPassive( soul, ePassives.PAS_ION_WEAPON ) )
	{
		array<string> mods = inflictor.ProjectileGetMods()
		if ( mods.contains( "proto_particle_accelerator" ) )
			StatusEffect_AddTimed( victim, eStatusEffect.move_slow, 1.0, 0.25, 0.1 )
	}

	bool hasEntangled = ( LTSRebalance_Enabled() || IsSingleplayer() || SoulHasPassive( soul, ePassives.PAS_ION_WEAPON ) )
	if ( hasEntangled && IsCriticalHit( attacker, victim, DamageInfo_GetHitBox( damageInfo ), DamageInfo_GetDamage( damageInfo ), DamageInfo_GetDamageType( damageInfo ) ) )
	{
			array<string> mods = inflictor.ProjectileGetMods()
			var energyGain = 0

			if ( LTSRebalance_Enabled() && ( mods.contains( "proto_particle_accelerator_pas" ) || mods.contains( "fd_upgraded_proto_particle_accelerator_pas" ) ) )
				energyGain = LTSREBALANCE_PAS_SPLIT_SHOT_CRITICAL_ENERGY_RESTORE_AMOUNT
			else if ( mods.contains( "proto_particle_accelerator" ) || ( LTSRebalance_Enabled() && mods.contains( "fd_upgraded_proto_particle_accelerator" ) ) )
				energyGain = LTSRebalance_Enabled() ? LTSREBALANCE_SPLIT_SHOT_CRITICAL_ENERGY_RESTORE_AMOUNT : SPLIT_SHOT_CRITICAL_ENERGY_RESTORE_AMOUNT
			else
				energyGain = LTSRebalance_Enabled() ? LTSREBALANCE_CRITICAL_ENERGY_RESTORE_AMOUNT : CRITICAL_ENERGY_RESTORE_AMOUNT
			attacker.AddSharedEnergy( energyGain )
	}
}
#endif