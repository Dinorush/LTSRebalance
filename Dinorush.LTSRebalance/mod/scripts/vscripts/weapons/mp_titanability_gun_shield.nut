global function OnWeaponPrimaryAttack_gun_shield
global function MpTitanAbilityGunShield_Init

#if SERVER
global function OnWeaponNpcPrimaryAttack_gun_shield
#else
global function ServerCallback_PilotCreatedGunShield
#endif

const FX_TITAN_GUN_SHIELD_VM = $"P_titan_gun_shield_FP"
const FX_TITAN_GUN_SHIELD_WALL = $"P_titan_gun_shield_3P"
const FX_TITAN_GUN_SHIELD_BREAK = $"P_xo_armor_break_CP"
global const float TITAN_GUN_SHIELD_RADIUS = 105
global const int TITAN_GUN_SHIELD_HEALTH = 2500
global const int PAS_LEGION_SHEILD_HEALTH = 5000

#if CLIENT
struct
{
	int sphereClientFXHandle = -1
} file
#endif
void function MpTitanAbilityGunShield_Init()
{
	PrecacheParticleSystem( FX_TITAN_GUN_SHIELD_WALL )
	PrecacheParticleSystem( FX_TITAN_GUN_SHIELD_VM )
	PrecacheParticleSystem( FX_TITAN_GUN_SHIELD_BREAK )
	RegisterSignal( "GunShieldEnd" )
}

var function OnWeaponPrimaryAttack_gun_shield( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	entity weaponOwner = weapon.GetWeaponOwner()

	Assert( IsValid( weaponOwner ), "weapon owner is not valid at the start of on weapon primary attack" )
	Assert( IsAlive( weaponOwner ), "weapon owner is not alive at the start of on weapon primary attack" )
	array<entity> weapons = GetPrimaryWeapons( weaponOwner )
	Assert( weapons.len() > 0 )
	if ( weapons.len() == 0 )
		return 0

	entity primaryWeapon = weapons[0]
	if ( !IsValid( primaryWeapon ) )
		return 0

	if ( weaponOwner.ContextAction_IsActive() )
		return 0

    if ( LTSRebalance_Enabled() && !CanUseGunShield( weaponOwner ) )
        return 0

	float duration = weapon.GetWeaponSettingFloat( eWeaponVar.fire_duration )
	if ( weaponOwner.IsPlayer() )
		PlayerUsedOffhand( weaponOwner, weapon )

	#if SERVER
	if ( LTSRebalance_Enabled() )
	{
		entity soul = weaponOwner.GetTitanSoul()
		if ( ( IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_LEGION_GUNSHIELD ) ) || weapon.HasMod( "fd_gun_shield" ) )
		{
			LTSRebalance_TrackTempShields( weaponOwner )
			LTSRebalance_AddTempShields( soul, soul.GetShieldHealthMax(), 0, 0, weapon.GetWeaponSettingFloat( eWeaponVar.fire_duration ) )
			AddEntityCallback_OnPostShieldDamage( weaponOwner, LTSRebalance_BulwarkNoShieldCore )
		}
	}
	#endif

	thread GunShieldThink( primaryWeapon, weapon, weaponOwner, duration )
	return weapon.GetWeaponSettingInt( eWeaponVar.ammo_per_shot )
}

void function GunShieldThink( entity weapon, entity shieldWeapon, entity owner, float duration )
{
	weapon.EndSignal( "OnDestroy" )
	owner.EndSignal( "OnDestroy" )
	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "DisembarkingTitan" )
	owner.EndSignal( "TitanEjectionStarted" )
	//owner.EndSignal( "SettingsChanged")

	weapon.e.gunShieldActive = true
	weapon.SetForcedADS()
	if ( owner.IsPlayer() )
		owner.SetMeleeDisabled()

	OnThreadEnd(
	function() : ( weapon, owner )
		{
			if ( !LTSRebalance_Enabled() )
			{
				if ( IsValid( weapon ) )
				{
					weapon.e.gunShieldActive = false
					if ( !weapon.HasMod( "LongRangePowerShot" ) && !weapon.HasMod( "CloseRangePowerShot" ) && !weapon.HasMod( "SiegeMode" ) )
					{
						while( weapon.GetForcedADS() )
							weapon.ClearForcedADS()
					}
					weapon.StopWeaponEffect( FX_TITAN_GUN_SHIELD_VM, FX_TITAN_GUN_SHIELD_WALL )
				}
				if ( IsValid( owner ) )
				{
					if ( owner.IsPlayer() )
						owner.ClearMeleeDisabled()
					owner.Signal( "GunShieldEnd" )
				}
			}
			#if SERVER
			else if ( IsValid( owner ) )
			{
				entity soul = owner.GetTitanSoul()
				if ( IsValid ( soul ) && SoulHasPassive( soul, ePassives.PAS_LEGION_GUNSHIELD ) )
					RemoveEntityCallback_OnPostShieldDamage( owner, LTSRebalance_BulwarkNoShieldCore )
			}
			#endif
		}
	)

    // Check on startup to fix bug where cooldown begins earlier than Gun Shield spawns, giving it a shorter cooldown
	while( !weapon.IsReloading() && !CanUseGunShield( owner, true ) )
	{
		wait 0.1
	}

	#if SERVER
	entity soul = owner.GetTitanSoul()
		if ( PerfectKits_Enabled() && IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_LEGION_GUNSHIELD ) )
			thread Sv_CreateGunShields( owner, weapon, shieldWeapon, duration )
		else
			thread Sv_CreateGunShield( owner, weapon, shieldWeapon, duration )
	#endif

	if ( duration > 0 )
		wait duration
	else
		WaitForever()
}

bool function CanUseGunShield( entity owner, bool reqZoom = true )
{
	if ( !owner.IsNPC() )
	{
		if ( owner.GetViewModelEntity().GetModelName() != $"models/weapons/titan_predator/atpov_titan_predator.mdl" )
			return false

		if ( owner.PlayerMelee_IsAttackActive() )
			return false
	}
	else
	{
		return owner.GetActiveWeapon().GetWeaponClassName() == "mp_titanweapon_predator_cannon" || owner.GetActiveWeapon().GetWeaponClassName() == "mp_titanweapon_predator_cannon_ltsrebalance"
	}

	return true
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_gun_shield( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	OnWeaponPrimaryAttack_gun_shield( weapon, attackParams )
}
#endif

#if SERVER
void function Sv_CreateGunShields( entity titan, entity weapon, entity shieldWeapon, float duration )
{
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "DisembarkingTitan" )
	titan.EndSignal( "TitanEjectionStarted" )
	titan.EndSignal( "ContextAction_SetBusy" )

	entity vortexWeapon = weapon
	entity centerHelper = CreateEntity( "info_placement_helper" )
	centerHelper.SetParent( weapon, "gun_shield" )
	DispatchSpawn( centerHelper )

	array<entity> vortexSpheres = [ CreateGunShieldVortexSphere( titan, vortexWeapon, shieldWeapon ) ]
	vortexSpheres.extend(
		[ 	CreateGunShieldVortexSphere( titan, vortexWeapon, shieldWeapon, < 170, 0, 0 >, centerHelper ),
			CreateGunShieldVortexSphere( titan, vortexWeapon, shieldWeapon, < -170, 0, 0 >, centerHelper ),
			CreateGunShieldVortexSphere( titan, vortexWeapon, shieldWeapon, < 85, 170, 0 >, centerHelper ),
			CreateGunShieldVortexSphere( titan, vortexWeapon, shieldWeapon, < -85, 170, 0 >, centerHelper ),
			CreateGunShieldVortexSphere( titan, vortexWeapon, shieldWeapon, < 85, -170, 0 >, centerHelper ),
			CreateGunShieldVortexSphere( titan, vortexWeapon, shieldWeapon, < -85, -170, 0 >, centerHelper )
		]
	)
	int weaponEHandle = vortexWeapon.GetEncodedEHandle()
	int shieldEHandle = vortexSpheres[0].GetEncodedEHandle()
	array<entity> shieldWallFXs
	foreach ( vortexSphere in vortexSpheres )
		shieldWallFXs.append( vortexSphere.e.shieldWallFX )

	if ( titan.IsPlayer() )
	{
		Remote_CallFunction_Replay( titan, "ServerCallback_PilotCreatedGunShield", weaponEHandle, shieldEHandle )
		EmitSoundOnEntityOnlyToPlayer( vortexWeapon, titan, "weapon_predator_mountedshield_start_1p" )
		EmitSoundOnEntityExceptToPlayer( vortexWeapon, titan, "weapon_predator_mountedshield_start_3p" )
	}
	else
	{
		EmitSoundOnEntity( vortexWeapon, "weapon_predator_mountedshield_start_3p" )
	}

	OnThreadEnd(
		function() : ( titan, vortexSpheres, vortexWeapon, shieldWallFXs, centerHelper )
		{
			if ( IsValid( vortexWeapon ) )
			{
                // Remove Shield debuffs when it breaks
				if ( LTSRebalance_Enabled() )
				{
					if ( !vortexWeapon.HasMod( "BasePowerShot" ) && !vortexWeapon.HasMod( "SiegeMode" ) )
					{
						while( vortexWeapon.GetForcedADS() )
							vortexWeapon.ClearForcedADS()
					}

					entity owner = vortexWeapon.GetWeaponOwner()
					if ( IsValid( owner ) )
					{
						if ( owner.IsPlayer() )
							owner.ClearMeleeDisabled()
						owner.Signal( "GunShieldEnd" )
					}

					vortexWeapon.StopWeaponEffect( FX_TITAN_GUN_SHIELD_VM, FX_TITAN_GUN_SHIELD_WALL )
					vortexWeapon.e.gunShieldActive = false
				}

				StopSoundOnEntity( vortexWeapon, "weapon_predator_mountedshield_start_1p" )
				StopSoundOnEntity( vortexWeapon, "weapon_predator_mountedshield_start_3p" )
				if ( IsValid( titan ) && titan.IsPlayer() )
				{
					EmitSoundOnEntityOnlyToPlayer( vortexWeapon, titan, "weapon_predator_mountedshield_stop_1p" )
					EmitSoundOnEntityExceptToPlayer( vortexWeapon, titan, "weapon_predator_mountedshield_stop_3p" )
				}
				else
				{
					EmitSoundOnEntity( vortexWeapon, "weapon_predator_mountedshield_stop_3p" )
				}
				vortexWeapon.SetWeaponUtilityEntity( null )
			}

			foreach ( shieldWallFX in shieldWallFXs )
				if ( IsValid( shieldWallFX ) )
					EffectStop( shieldWallFX )

			bool hadSphere = false
			foreach ( vortexSphere in vortexSpheres )
			{
				if ( IsValid( vortexSphere ) )
				{
					vortexSphere.Destroy()
					hadSphere = true
				}
			}

			if ( IsValid( centerHelper ) )
				centerHelper.Destroy()

			if ( !hadSphere && IsValid( titan ) )
			{
				EmitSoundOnEntity( titan, "titan_energyshield_down" )
				PlayFXOnEntity( FX_TITAN_GUN_SHIELD_BREAK, titan, "PROPGUN" )
			}
		}
	)

	float endTime = Time() + duration
	while ( endTime > Time() )
	{
		bool good = false
		foreach( vortexSphere in vortexSpheres )
		{
			if ( IsValid( vortexSphere ) )
			{
				good = true
				break
			}
		}
		if ( !good )
			return

		WaitFrame()
	}
}

void function Sv_CreateGunShield( entity titan, entity weapon, entity shieldWeapon, float duration )
{
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "DisembarkingTitan" )
	titan.EndSignal( "TitanEjectionStarted" )
	titan.EndSignal( "ContextAction_SetBusy" )

	entity vortexWeapon = weapon
	entity vortexSphere = CreateGunShieldVortexSphere( titan, vortexWeapon, shieldWeapon )
	int weaponEHandle = vortexWeapon.GetEncodedEHandle()
	int shieldEHandle = vortexSphere.GetEncodedEHandle()
	entity shieldWallFX = vortexSphere.e.shieldWallFX

	vortexSphere.EndSignal( "OnDestroy" )

	if ( titan.IsPlayer() )
	{
		Remote_CallFunction_Replay( titan, "ServerCallback_PilotCreatedGunShield", weaponEHandle, shieldEHandle )
		EmitSoundOnEntityOnlyToPlayer( vortexWeapon, titan, "weapon_predator_mountedshield_start_1p" )
		EmitSoundOnEntityExceptToPlayer( vortexWeapon, titan, "weapon_predator_mountedshield_start_3p" )
	}
	else
	{
		EmitSoundOnEntity( vortexWeapon, "weapon_predator_mountedshield_start_3p" )
	}

	OnThreadEnd(
		function() : ( titan, vortexSphere, vortexWeapon, shieldWallFX )
		{
			if ( IsValid( vortexWeapon ) )
			{
                // Remove Shield debuffs when it breaks
				if ( LTSRebalance_Enabled() )
				{
					if ( !vortexWeapon.HasMod( "BasePowerShot" ) && !vortexWeapon.HasMod( "SiegeMode" ) )
					{
						while( vortexWeapon.GetForcedADS() )
							vortexWeapon.ClearForcedADS()
					}

					entity owner = vortexWeapon.GetWeaponOwner()
					if ( IsValid( owner ) )
					{
						if ( owner.IsPlayer() )
							owner.ClearMeleeDisabled()
						owner.Signal( "GunShieldEnd" )
					}

					vortexWeapon.StopWeaponEffect( FX_TITAN_GUN_SHIELD_VM, FX_TITAN_GUN_SHIELD_WALL )
					vortexWeapon.e.gunShieldActive = false
				}

				StopSoundOnEntity( vortexWeapon, "weapon_predator_mountedshield_start_1p" )
				StopSoundOnEntity( vortexWeapon, "weapon_predator_mountedshield_start_3p" )
				if ( IsValid( titan ) && titan.IsPlayer() )
				{
					EmitSoundOnEntityOnlyToPlayer( vortexWeapon, titan, "weapon_predator_mountedshield_stop_1p" )
					EmitSoundOnEntityExceptToPlayer( vortexWeapon, titan, "weapon_predator_mountedshield_stop_3p" )
				}
				else
				{
					EmitSoundOnEntity( vortexWeapon, "weapon_predator_mountedshield_stop_3p" )
				}
				vortexWeapon.SetWeaponUtilityEntity( null )
			}

			if ( IsValid( shieldWallFX ) )
				EffectStop( shieldWallFX )

			if ( IsValid( vortexSphere ) )
			{
				vortexSphere.Destroy()
			}
			else if ( IsValid( titan ) )
			{
				EmitSoundOnEntity( titan, "titan_energyshield_down" )
				PlayFXOnEntity( FX_TITAN_GUN_SHIELD_BREAK, titan, "PROPGUN" )
			}
		}
	)

	if ( duration > 0 )
		wait duration
	else
		WaitForever()
}

entity function CreateGunShieldVortexSphere( entity player, entity vortexWeapon, entity shieldWeapon, vector offset = < 0, 0, 0 > , entity centerHelper = null )
{
	int attachmentID = vortexWeapon.LookupAttachment( "gun_shield" )
	float sphereRadius = TITAN_GUN_SHIELD_RADIUS
	entity vortexSphere = CreateEntity( "vortex_sphere" )
	Assert( vortexSphere )

	SetTargetName( vortexSphere, GUN_SHIELD_WALL )

//	if ( 0 )
//	{
		vortexSphere.kv.spawnflags = SF_ABSORB_BULLETS
		vortexSphere.kv.height = TITAN_GUN_SHIELD_RADIUS * 2
		vortexSphere.kv.radius = TITAN_GUN_SHIELD_RADIUS
//	}
//	else
//	{
//		vortexSphere.kv.spawnflags = SF_ABSORB_CYLINDER | SF_ABSORB_BULLETS
//		vortexSphere.kv.height = TITAN_GUN_SHIELD_RADIUS * 2
//		vortexSphere.kv.radius = TITAN_GUN_SHIELD_RADIUS
//	}

	vortexSphere.e.proto_weakToPilotWeapons = false
	vortexSphere.kv.enabled = 0
	vortexSphere.kv.bullet_fov = PLAYER_SHIELD_WALL_FOV
	vortexSphere.kv.physics_pull_strength = 25
	vortexSphere.kv.physics_side_dampening = 6
	vortexSphere.kv.physics_fov = 360
	vortexSphere.kv.physics_max_mass = 2
	vortexSphere.kv.physics_max_size = 6
	float health
	entity soul = player.GetTitanSoul()
	bool hasShieldUpgrade = ( IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_LEGION_GUNSHIELD ) ) || shieldWeapon.HasMod( "fd_gun_shield" )
	if ( hasShieldUpgrade && !LTSRebalance_Enabled() )
		health = PAS_LEGION_SHEILD_HEALTH
	else
		health = TITAN_GUN_SHIELD_HEALTH
	vortexSphere.SetHealth( health )
	vortexSphere.SetMaxHealth( health )

	vortexSphere.SetTakeDamageType( DAMAGE_YES )

	if ( shieldWeapon.HasMod( "npc_infinite_shield" ) )
	{
		vortexSphere.SetInvulnerable()
		SetVortexSphereBulletHitRules( vortexSphere, GunShield_InvulBulletHitRules )
		SetVortexSphereProjectileHitRules( vortexSphere, GunShield_InvulProjectileHitRules )
	}

	DispatchSpawn( vortexSphere )

	vortexSphere.SetOwner( player )
	vortexSphere.SetOwnerWeapon( vortexWeapon )
	if ( centerHelper != null )
		vortexSphere.SetParent( centerHelper )
	else
	{
		vortexSphere.SetParent( vortexWeapon, "gun_shield" )
		vortexWeapon.SetWeaponUtilityEntity( vortexSphere )
	}

	EntFireByHandle( vortexSphere, "Enable", "", 0, null, null )

	// Shield wall fx control point
	entity cpoint = CreateEntity( "info_placement_helper" )
	SetTargetName( cpoint, UniqueString( "shield_wall_controlpoint" ) )
	DispatchSpawn( cpoint )

	vortexSphere.e.shieldWallFX = CreateEntity( "info_particle_system" )
	entity shieldWallFX = vortexSphere.e.shieldWallFX
	shieldWallFX.SetValueForEffectNameKey( FX_TITAN_GUN_SHIELD_WALL )
	shieldWallFX.kv.start_active = 1
	SetVortexSphereShieldWallCPoint( vortexSphere, cpoint )
	shieldWallFX.SetOwner( player )
	shieldWallFX.SetParent( player )
	shieldWallFX.kv.VisibilityFlags = (ENTITY_VISIBLE_TO_FRIENDLY | ENTITY_VISIBLE_TO_ENEMY) // not owner only
	shieldWallFX.kv.cpoint1 = cpoint.GetTargetName()
	shieldWallFX.SetStopType( "destroyImmediately" )
	shieldWallFX.DisableHibernation()
	shieldWallFX.SetOrigin( offset )

	if ( centerHelper != null )
		vortexSphere.SetAngles( <180, 0, 0> )
	else
	{
		vortexSphere.SetGunVortexAngles( < 0, 0, 180 > )
		vortexSphere.SetGunVortexAttachment( "gun_shield" )
	}
	vortexSphere.SetVortexEffect( shieldWallFX )
	vortexSphere.SetOrigin( offset )

	DispatchSpawn( shieldWallFX )

	if ( shieldWeapon.HasMod( "npc_infinite_shield" ) )
	{
		shieldWallFX.e.cpoint.SetOrigin( < 246.0, 134.0, 40.0 > ) // AMPED COLOR
	}
	else
	{
		thread UpdateGunShieldColor( vortexSphere )
	}

	return vortexSphere
}

void function UpdateGunShieldColor( entity vortexSphere )
{
	while ( IsValid( vortexSphere ) )
	{
		UpdateShieldWallColorForFrac( vortexSphere.e.shieldWallFX, GetHealthFrac( vortexSphere ) )
		WaitFrame()
	}
}

var function GunShield_InvulBulletHitRules( entity vortexSphere, var damageInfo )
{
	DamageInfo_SetDamage( damageInfo, 0 )
}

bool function GunShield_InvulProjectileHitRules( entity vortexSphere, entity attacker, bool takesDamageByDefault )
{
	return false
}

void function LTSRebalance_BulwarkNoShieldCore( entity ent, var damageInfo, float shieldDamage )
{
	// Shield Damage is already dealt before this is called, so this just reduces core gained from the damage dealt
	DamageInfo_SetDamage( damageInfo, DamageInfo_GetDamage( damageInfo ) - shieldDamage )
}
#endif

#if CLIENT
void function ServerCallback_PilotCreatedGunShield( int vortexWeaponEHandle, int vortexSphereEHandle )
{
	entity vortexWeapon = GetEntityFromEncodedEHandle( vortexWeaponEHandle )
	entity vortexSphere = GetEntityFromEncodedEHandle( vortexSphereEHandle )

	if ( !IsValid( vortexWeapon ) )
		return

	if ( !IsValid( vortexSphere ) )
		return

	entity player = vortexWeapon.GetWeaponOwner()

	if ( !IsAlive( player ) )
		return

	thread CL_GunShield_Internal( player, vortexWeapon, vortexSphere )
}

void function CL_GunShield_Internal( entity player, entity vortexWeapon, entity vortexSphere )
{
	vortexSphere.EndSignal( "OnDestroy" )
	player.EndSignal( "OnDeath" )
	player.EndSignal( "GunShieldEnd" )

	asset shieldFX = FX_TITAN_GUN_SHIELD_VM
	file.sphereClientFXHandle = vortexWeapon.PlayWeaponEffectReturnViewEffectHandle( shieldFX, $"", "gun_shield_fp" )

	OnThreadEnd(
		function() : ()
		{
			if ( file.sphereClientFXHandle != -1 )
				EffectStop( file.sphereClientFXHandle, true, false )

			file.sphereClientFXHandle = -1
		}
	)

	float oldHealth = float( vortexSphere.GetHealth() )
    bool wasHolstered = false
	while( true )
	{
        // Bulwark's melee can kill the FP effect, so we need to re-create it
        if( wasHolstered && player.GetActiveWeapon() == vortexWeapon )
            file.sphereClientFXHandle = vortexWeapon.PlayWeaponEffectReturnViewEffectHandle( shieldFX, $"", "gun_shield_fp" )
		float newHealth = float( vortexSphere.GetHealth() )
		UpdateShieldColor( player, oldHealth, newHealth, oldHealth == newHealth )
		oldHealth = newHealth
        wasHolstered = player.GetActiveWeapon() != vortexWeapon
		wait 0.1
	}
	WaitForever()
}

void function UpdateShieldColor( entity player, float oldValue, float newValue, bool actuallyChanged )
{
	if ( !actuallyChanged )
		return

	if ( player != GetLocalViewPlayer() )
		return

	if ( !IsValid( player ) )
		return

	float shieldFrac = newValue / TITAN_GUN_SHIELD_HEALTH
	vector colorVec = GetShieldTriLerpColor( 1 - shieldFrac )

	if ( EffectDoesExist( file.sphereClientFXHandle ) )
		EffectSetControlPointVector( file.sphereClientFXHandle, 1, colorVec )
}
#endif