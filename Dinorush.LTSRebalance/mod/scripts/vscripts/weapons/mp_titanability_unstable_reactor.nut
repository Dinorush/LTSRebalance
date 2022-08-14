global function OnWeaponPrimaryAttack_titanability_unstablereactor
#if SERVER
	global function OnWeaponNpcPrimaryAttack_titanability_unstablereactor
#endif

const float HEALTH_COST_FRAC = 0.08
const int MIN_HEALTH_COST = 600

var function OnWeaponPrimaryAttack_titanability_unstablereactor( entity weapon, WeaponPrimaryAttackParams attackPParams )
{
	entity owner = weapon.GetWeaponOwner()
	if ( IsAlive( owner ) )
	{
#if SERVER
		UnstableReactor_Blast( owner, weapon )
		if ( owner.IsPlayer() )
		{
			MessageToPlayer( owner, eEventNotifications.Rodeo_PilotAppliedBatteryToYou, owner, true )
			float amount = expect float( GetSettingsForPlayer_DodgeTable( owner )["dodgePowerDrain"] )
			owner.Server_SetDodgePower( min( 100.0, owner.GetDodgePower() + amount ) )
		}
#else
		Rumble_Play( "rumble_titan_electric_smoke", {} )
#endif
		if ( owner.IsPlayer() )
			PlayerUsedOffhand( owner, weapon )

		return 1
	}
	return 0
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_titanability_unstablereactor( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )
	entity npc = weapon.GetWeaponOwner()
	if ( IsAlive( npc ) )
		UnstableReactor_Blast( npc, weapon )
}

void function UnstableReactor_Blast( entity titan, entity weapon )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	int damageFlags = DF_EXPLOSION | DF_ELECTRICAL
	int selfDamage = maxint( MIN_HEALTH_COST, int( titan.GetMaxHealth() * HEALTH_COST_FRAC ) )
	titan.TakeDamage( selfDamage, titan, titan, { scriptType = damageFlags | DF_DOOMED_HEALTH_LOSS, damageSourceId = eDamageSourceId.mp_weapon_arc_blast, origin = titan.GetWorldSpaceCenter() } )

	int titanDamage = weapon.GetWeaponSettingInt( eWeaponVar.explosion_damage_heavy_armor )
	int pilotDamage = weapon.GetWeaponSettingInt( eWeaponVar.explosion_damage )
	float innerRadius = weapon.GetWeaponSettingFloat( eWeaponVar.explosion_inner_radius )
	float outerRadius = weapon.GetWeaponSettingFloat( eWeaponVar.explosionradius )

	thread UnstableReactor_MakeFX( titan )
	RadiusDamage(
		titan.GetWorldSpaceCenter(),			// center
		titan,									// attacker
		weapon,									// inflictor
		pilotDamage,							// damage
		titanDamage,							// damageHeavyArmor
		innerRadius,							// innerRadius
		outerRadius,							// outerRadius
		SF_ENVEXPLOSION_NO_DAMAGEOWNER,			// flags
		0,										// distanceFromAttacker
		0,										// explosionForce
		damageFlags,							// scriptDamageFlags
		eDamageSourceId.mp_weapon_arc_blast		// scriptDamageSourceIdentifier
	)
}

void function UnstableReactor_MakeFX( entity titan )
{
	entity particleSystem = CreateEntity( "info_particle_system" )
	particleSystem.kv.start_active = 1
	particleSystem.SetValueForEffectNameKey( $"P_xo_emp_field" )
	particleSystem.SetOrigin( titan.GetWorldSpaceCenter() )
	DispatchSpawn( particleSystem )

	wait 0.6
	particleSystem.Destroy()
}
#endif