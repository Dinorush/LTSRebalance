untyped
global function MpTitanWeaponStunLaser_Init

global function OnWeaponAttemptOffhandSwitch_titanweapon_stun_laser
global function OnWeaponPrimaryAttack_titanweapon_stun_laser
global function OnWeaponActivate_titanweapon_stun_laser
global function StunLaser_HandleTempShieldChange

#if SERVER
global function OnWeaponNPCPrimaryAttack_titanweapon_stun_laser
global function AddStunLaserHealCallback
#endif

const FX_EMP_BODY_HUMAN			= $"P_emp_body_human"
const FX_EMP_BODY_TITAN			= $"P_emp_body_titan"
const FX_SHIELD_GAIN_SCREEN		= $"P_xo_shield_up"
const SHIELD_BODY_FX			= $"P_xo_armor_body_CP"

const int STUN_LASER_PERM_SHIELD = 500
const int STUN_LASER_TEMP_SHIELD = 850
const float TEMP_SHIELD_DECAY_RATE = STUN_LASER_TEMP_SHIELD / 6.0
const float PAS_VANGUARD_SHIELD_DECAY_MOD = 1.5
const float TEMP_SHIELD_TICK_RATE = 0.1
const int STUN_LASER_TRANSFER_PERM_SHIELD = 750


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
	if ( !LTSRebalance_Enabled() )
		return

	entity soul = weapon.GetWeaponOwner().GetTitanSoul()
	if( IsValid( soul ) && !( "tempShields" in soul.s ) )
	{
		soul.s.tempShields <- []
		soul.s.trackedShieldHealth <- soul.GetShieldHealth()
		thread StunLaser_MonitorTempShieldsThink( soul )
	}
	#endif
}

#if SERVER
void function StunLaser_MonitorTempShieldsThink( entity soul )
{
	soul.EndSignal( "OnDestroy" )
	float lastTime = Time()
	while(1)
	{
		WaitFrame()
		if( soul.s.tempShields.len() > 0 )
		{
			// If shield was damaged
			int damage = expect int( soul.s.trackedShieldHealth ) - soul.GetShieldHealth()
			if( damage > 0 )
				StunLaser_HandleTempShieldChange( soul, -damage )

			// Decay temp shields over time
			float mod = SoulHasPassive( soul, ePassives.PAS_VANGUARD_SHIELD ) ? 1.5 : 1.0
			int decayAmt = int( TEMP_SHIELD_DECAY_RATE * ( Time() - lastTime ) / mod + 0.5 )
			StunLaser_DecayTempShields( soul, decayAmt )
		}
		soul.s.trackedShieldHealth = soul.GetShieldHealth()
		lastTime = Time()
	}
}

void function StunLaser_DecayTempShields( entity soul, int decayAmt )
{
	array tempShields = expect array( soul.s.tempShields )
	for( int i = tempShields.len() - 1; i >= 0; i-- )
	{
		int decay = decayAmt
		if ( tempShields[i].overflow > 0 )
		{
			tempShields[i].overflow -= decay
			if ( tempShields[i].overflow < 0 )
			{
				decay = - expect int( tempShields[i].overflow )
				tempShields[i].overflow = 0
			}
			else
				continue
		}
		decay = minint( tempShields[i].shield, decay )
		tempShields[i].shield -= decay

		soul.SetShieldHealth( soul.GetShieldHealth() - decay )
		if ( tempShields[i].shield <= 0 )
			tempShields.remove(i)
	}
}
#endif

// Should be called before shield gets added to (via battery, core, or siphon) or after damage has been taken
void function StunLaser_HandleTempShieldChange( entity soul, int change )
{
	#if SERVER
	// Have to check whether temp shields exists since it only gets added on the first Siphon use
	if ( !LTSRebalance_Enabled() || change == 0 || !( "tempShields" in soul.s ) || soul.s.tempShields.len() == 0 )
		return

	if ( change < 0 )
		StunLaser_HandleTempShieldChange_Internal( soul, -change )
	else
	{
		// Handles case where shield was damaged and then healed before thread updated tracked health
		if ( soul.s.trackedShieldHealth > soul.GetShieldHealth() )
			StunLaser_HandleTempShieldChange_Internal( soul, soul.GetShieldHealth() - expect int( soul.s.trackedShieldHealth ) )

		int tempShieldOverwritten = change - ( soul.GetShieldHealthMax() - soul.GetShieldHealth() )
		if ( tempShieldOverwritten < 0)
			return

		StunLaser_HandleTempShieldChange_Internal( soul, tempShieldOverwritten, true )
	}
	#endif
}

#if SERVER
void function StunLaser_HandleTempShieldChange_Internal( entity soul, int change, bool isGain = false )
{	
	array tempShields = expect array( soul.s.tempShields )
	float damagePer = float( change ) / tempShields.len()
	// We want to spread the damage out to other temp shields if one couldn't block all of its spread.
	// So, loop up instead of down since temp shield health will always be in ascending order.
	for( int i = 0; i < tempShields.len(); i++ )
	{
		tempShields[i].shield -= int( damagePer + 0.5 )
		if ( isGain )
			tempShields[i].overflow += int( damagePer + 0.5 )

		if ( tempShields[i].shield <= 0 )
		{
			// Redistribute remaining damage to other shields
			if( tempShields.len() > 1 )
				damagePer -= ( float( tempShields[i].shield ) / ( tempShields.len() - 1 ) )
			tempShields.remove(i)
			i--
		}
	}
	soul.s.trackedShieldHealth = soul.GetShieldHealth()
}
#endif

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

	weapon.s.entitiesHit <- []

	entity weaponOwner = weapon.GetWeaponOwner()
	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

	ShotgunBlast( weapon, attackParams.pos, attackParams.dir, 1, DF_GIB | DF_EXPLOSION )
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	weapon.SetWeaponChargeFractionForced(1.0)
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}
#if SERVER
var function OnWeaponNPCPrimaryAttack_titanweapon_stun_laser( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return OnWeaponPrimaryAttack_titanweapon_stun_laser( weapon, attackParams )
}

void function StunLaser_DamagedTarget( entity target, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	entity weapon = attacker.GetOffhandWeapon( OFFHAND_LEFT )
	
	if ( attacker == target )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
		return
	}

	if ( LTSRebalance_Enabled() )
	{
		if ( !(target in weapon.s.entitiesHit) )
			weapon.s.entitiesHit.append( target )
		else
		{
			DamageInfo_SetDamage( damageInfo, 0 )
			return
		}
	}

	if ( attacker.GetTeam() == target.GetTeam() )
	{
		DamageInfo_SetDamage( damageInfo, 0 )
		entity attackerSoul = attacker.GetTitanSoul()
		
		if ( !IsValid( weapon ) )
			return
		bool hasEnergyTransfer = weapon.HasMod( "energy_transfer" ) || weapon.HasMod( "energy_field_energy_transfer" )|| weapon.HasMod( "LTSRebalance_energy_field_energy_transfer")
		if ( target.IsTitan() && IsValid( attackerSoul ) && hasEnergyTransfer )
		{
			entity soul = target.GetTitanSoul()
			if ( IsValid( soul ) )
			{
				int shieldRestoreAmount = LTSRebalance_Enabled() ? STUN_LASER_TRANSFER_PERM_SHIELD : 750
				if ( SoulHasPassive( LTSRebalance_Enabled() ? attackerSoul : soul, ePassives.PAS_VANGUARD_SHIELD ) )
					shieldRestoreAmount = int( 1.25 * shieldRestoreAmount )

				StunLaser_HandleTempShieldChange( soul, shieldRestoreAmount )
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
				StunLaser_HandleTempShieldChange( attackerSoul, shieldRestoreAmount )
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
			int permRestoreAmount = ( target.GetArmorType() == ARMOR_TYPE_HEAVY ? ( LTSRebalance_Enabled() ? STUN_LASER_PERM_SHIELD : 750 ) : 250 )
			if ( SoulHasPassive( soul, ePassives.PAS_VANGUARD_SHIELD ) )
				permRestoreAmount = int( 1.25 * permRestoreAmount )

			StunLaser_HandleTempShieldChange( soul, permRestoreAmount )
			int newShield = minint( soul.GetShieldHealthMax(), soul.GetShieldHealth() + permRestoreAmount )
			soul.SetShieldHealth( newShield )
			if ( LTSRebalance_Enabled() && target.GetArmorType() == ARMOR_TYPE_HEAVY && newShield < soul.GetShieldHealthMax() )
			{
				int tempShieldAmount = minint( soul.GetShieldHealthMax() - soul.GetShieldHealth(), STUN_LASER_TEMP_SHIELD )
				soul.SetShieldHealth( soul.GetShieldHealth() + tempShieldAmount )
				soul.s.tempShields.append( { shield = tempShieldAmount, overflow = STUN_LASER_TEMP_SHIELD - tempShieldAmount } )
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
