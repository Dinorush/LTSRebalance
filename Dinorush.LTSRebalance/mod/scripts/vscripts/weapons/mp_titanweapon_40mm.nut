global function MpTitanweapon40mm_Init

global function OnWeaponOwnerChanged_titanweapon_40mm
global function OnWeaponPrimaryAttack_titanweapon_40mm
global function OnWeaponDeactivate_titanweapon_40mm
global function OnWeaponReload_titanweapon_40mm
global function OnProjectileCollision_titanweapon_sticky_40mm
global function OnWeaponChargeLevelIncreased_titanweapon_sticky_40mm
global function OnWeaponStartZoomIn_titanweapon_sticky_40mm
global function OnWeaponReadyToFire_titanweapon_sticky_40mm
#if SERVER
global function ApplyTrackerMark
global function OnWeaponNpcPrimaryAttack_titanweapon_40mm
#endif // #if SERVER
#if CLIENT
	global function OnClientAnimEvent_titanweapon_40mm
#endif

global const PROJECTILE_SPEED_40MM		= 8000.0
const PERFECTKITS_ENHANCED_SPEED_40MM	= 2400.0
global const TITAN_40MM_SHELL_EJECT		= $"models/Weapons/shellejects/shelleject_40mm.mdl"

global const TANK_BUSTER_40MM_SFX_LOOP	= "Weapon_Vortex_Gun.ExplosiveWarningBeep"
global const TITAN_40MM_EXPLOSION_SOUND	= "Weapon.Explosion_Med"
global const MORTAR_SHOT_SFX_LOOP		= "Weapon_Sidwinder_Projectile"

#if SP
global const TRACKER_LIFETIME = 60.0
#elseif MP
global const TRACKER_LIFETIME = 15.0
global const LTSREBALANCE_TRACKER_LIFETIME = 12.0
#endif

void function MpTitanweapon40mm_Init()
{
	PrecacheParticleSystem( $"wpn_mflash_40mm_smoke_side_FP" )
	PrecacheParticleSystem( $"wpn_mflash_40mm_smoke_side" )
	PrecacheParticleSystem( $"P_scope_glint" )

	#if SERVER
		PrecacheModel( TITAN_40MM_SHELL_EJECT )
		AddDamageCallbackSourceID( eDamageSourceId.mp_titanweapon_sticky_40mm, Tracker40mm_DamagedTarget )
		if ( LTSRebalance_EnabledOnInit() )
			AddCallback_OnTitanBecomesPilot( LTSRebalance_BurstLoaderClear )
	#endif

	RegisterSignal("TrackerRocketsFired")
	RegisterSignal("DisembarkingTitan")

}

void function OnWeaponDeactivate_titanweapon_40mm( entity weapon )
{
}

var function OnWeaponPrimaryAttack_titanweapon_40mm( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	return FireWeaponPlayerAndNPC( attackParams, true, weapon )
}

#if SERVER
var function OnWeaponNpcPrimaryAttack_titanweapon_40mm( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	weapon.EmitWeaponNpcSound( LOUD_WEAPON_AI_SOUND_RADIUS_MP, 0.2 )

	return FireWeaponPlayerAndNPC( attackParams, false, weapon )
}
#endif // #if SERVER

int function FireWeaponPlayerAndNPC( WeaponPrimaryAttackParams attackParams, bool playerFired, entity weapon )
{
	entity owner = weapon.GetWeaponOwner()
	if ( weapon.HasMod( "PerfectKitsReplace_pas_tone_burst" ) )
	{
		if ( attackParams.burstIndex == 0 )
		{
			int level = weapon.GetWeaponChargeLevel()
			if ( level == 3 )
			{
				weapon.AddMod( "PerfectKits_burst_helper" )
				weapon.SetWeaponBurstFireCount( weapon.GetWeaponPrimaryClipCount() )
			}
			else
			{
				if ( weapon.HasMod( "PerfectKits_burst_helper" ) )
					weapon.RemoveMod( "PerfectKits_burst_helper" )
				weapon.SetWeaponBurstFireCount( 1 )
			}
		}
	}
	else if ( weapon.HasMod( "pas_tone_burst" ) || weapon.HasMod( "LTSRebalance_pas_tone_burst" ) )
	{
		if ( attackParams.burstIndex == 0 )
		{
			int level = weapon.GetWeaponChargeLevel()
			thread LTSRebalance_Drain40mmCharge( weapon )
			weapon.SetWeaponBurstFireCount( maxint( 1, level ) )
		}
	}

	bool shouldCreateProjectile = false
	if ( IsServer() || weapon.ShouldPredictProjectiles() )
		shouldCreateProjectile = true
	#if CLIENT
		if ( !playerFired )
			shouldCreateProjectile = false
	#endif

	if ( shouldCreateProjectile )
	{
		float speed = PROJECTILE_SPEED_40MM
		float gravity = 0.05
		if ( PerfectKits_Enabled() && weapon.HasMod( "pas_tone_weapon" ) )
		{
			speed = PERFECTKITS_ENHANCED_SPEED_40MM
			gravity = 0.005
		}

		bool hasMortarShotMod = weapon.HasMod( "mortar_shots" )
		if( hasMortarShotMod )
			speed *= 0.6

		//TODO:: Calculate better attackParams.dir if auto-titan using mortarShots
		entity bolt = weapon.FireWeaponBolt( attackParams.pos, attackParams.dir, speed, damageTypes.gibBullet | DF_IMPACT | DF_EXPLOSION | DF_RAGDOLL | DF_KNOCK_BACK, DF_EXPLOSION | DF_RAGDOLL | DF_KNOCK_BACK, playerFired , 0 )
		if ( bolt )
		{
			if ( hasMortarShotMod )
			{
				bolt.kv.gravity = 4.0
				bolt.kv.lifetime = 10.0
				#if SERVER
					EmitSoundOnEntity( bolt, MORTAR_SHOT_SFX_LOOP )
				#endif
			}
			else
			{
				bolt.kv.gravity = gravity
			}
		}

        if ( weapon.HasMod( "LTSRebalance_pas_tone_weapon_on" ) )
        {
			weapon.RemoveMod( "LTSRebalance_pas_tone_weapon_on" )
			weapon.EmitWeaponSound_1p3p( "Weapon_40mm_Fire_Amped_1P", "Weapon_40mm_Fire_Amped_3P" )
        }
	}

	weapon.w.lastFireTime = Time()

	if ( weapon.HasMod( "PerfectKitsReplace_pas_tone_burst" ) && weapon.GetBurstFireShotsPending() == 1 )
		return 5

	return 1
}

void function LTSRebalance_Drain40mmCharge( entity weapon )
{
	weapon.SetWeaponChargeFractionForced( 0.0 )
	WaitEndFrame() // Charge doesn't get set to 0 if only firing 1 shot and ADSing for some reason
	if ( IsValid( weapon ) )
		weapon.SetWeaponChargeFractionForced( 0.0 )
}

void function OnWeaponReload_titanweapon_40mm( entity weapon, int milestone )
{
	#if SERVER
    if( weapon.HasMod( "LTSRebalance_pas_tone_weapon_on" ) )
        weapon.RemoveMod( "LTSRebalance_pas_tone_weapon_on" )

	if ( weapon.IsChargeWeapon() )
		weapon.SetWeaponChargeFractionForced( 0 )
	#endif
}

#if CLIENT
void function OnClientAnimEvent_titanweapon_40mm( entity weapon, string name )
{
	GlobalClientEventHandler( weapon, name )

	if ( name == "muzzle_flash" )
	{
		weapon.PlayWeaponEffect( $"wpn_mflash_40mm_smoke_side_FP", $"wpn_mflash_40mm_smoke_side", "muzzle_flash_L" )
		weapon.PlayWeaponEffect( $"wpn_mflash_40mm_smoke_side_FP", $"wpn_mflash_40mm_smoke_side", "muzzle_flash_R" )
	}

	if ( name == "shell_eject" )
		thread OnShellEjectEvent( weapon )
}

void function OnShellEjectEvent( entity weapon )
{
	entity weaponEnt = weapon

	string tag = "shell"
	float anglePlusMinus = 7.5
	float launchVecMultiplier = 250.0
	float launchVecRandFrac = 0.3
	vector angularVelocity = Vector( RandomFloatRange( -5.0, -1.0 ), 0, RandomFloatRange( -5.0, 5.0 ) )
	float gibLifetime = 6.0

	bool isFirstPerson = IsLocalViewPlayer( weapon.GetWeaponOwner() )
	if ( isFirstPerson )
	{
		weaponEnt = weapon.GetWeaponOwner().GetViewModelEntity()
		if( !IsValid( weaponEnt ) )
			return

		tag = "shell_fp"
		anglePlusMinus = 3.0
		launchVecMultiplier = 200.0
	}

	int tagIdx = weaponEnt.LookupAttachment( tag )
	if ( tagIdx <= 0 )
		return	// catch case of weapon firing at same time as eject or death and viewmodel is removed

	vector tagOrg = weaponEnt.GetAttachmentOrigin( tagIdx )
	vector tagAng = weaponEnt.GetAttachmentAngles( tagIdx )
	tagAng = AnglesCompose( tagAng, Vector( 0, 0, 90 ) )  // the tags have been rotated to be compatible with FX standards

	vector tagAngRand = Vector( RandomFloatRange( tagAng.x - anglePlusMinus, tagAng.x + anglePlusMinus ), RandomFloatRange( tagAng.y - anglePlusMinus, tagAng.y + anglePlusMinus ), RandomFloatRange( tagAng.z - anglePlusMinus, tagAng.z + anglePlusMinus ) )
	vector launchVec = AnglesToForward( tagAngRand )
	launchVec *= RandomFloatRange( launchVecMultiplier, launchVecMultiplier + ( launchVecMultiplier * launchVecRandFrac ) )

	CreateClientsideGib( TITAN_40MM_SHELL_EJECT, tagOrg, weaponEnt.GetAngles(), launchVec, angularVelocity, gibLifetime, 1000, 200 )
}
#endif // CLIENT

void function OnWeaponOwnerChanged_titanweapon_40mm( entity weapon, WeaponOwnerChangedParams changeParams )
{
	#if CLIENT
		if ( changeParams.newOwner != null && changeParams.newOwner == GetLocalViewPlayer() )
			UpdateViewmodelAmmo( false, weapon )
	#endif
}


void function OnProjectileCollision_titanweapon_sticky_40mm( entity projectile, vector pos, vector normal, entity hitEnt, int hitbox, bool isCrit )
{
	array<string> mods = projectile.ProjectileGetMods()

    if ( mods.contains( "LTSRebalance_pas_tone_weapon_on" ) )
        EmitSoundAtPosition( TEAM_UNASSIGNED, projectile.GetOrigin(), "explo_40mm_splashed_impact_3p")

	#if SERVER

	if ( LTSRebalance_Enabled() ) // Remove crit lock effect of enhanced tracker rounds
		return

	entity owner = projectile.GetOwner()
	if ( !IsAlive( owner ) )
		return

	if ( mods.contains( "pas_tone_weapon" ) && isCrit )
 		ApplyTrackerMark( owner, hitEnt, true )
	#endif
}

#if SERVER
float function GetTrackerLifetime()
{
	return LTSRebalance_Enabled() ? LTSREBALANCE_TRACKER_LIFETIME : TRACKER_LIFETIME
}

void function ApplyTrackerMark( entity owner, entity hitEnt, bool is40mm = false )
{
	if ( !IsAlive( hitEnt ) )
		return

	if ( owner.IsProjectile() )
		return

	entity trackerRockets = owner.GetOffhandWeapon( OFFHAND_ORDNANCE )
	if ( !IsValid( trackerRockets ) )
		return

	int oldCount = trackerRockets.SmartAmmo_GetNumTrackersOnEntity( hitEnt )
	trackerRockets.SmartAmmo_TrackEntity( hitEnt, GetTrackerLifetime() )
	// Perfect Kits Enhanced Tracker Rounds applies full locks on hit. Could do it by calling the function multiple times instead, but
	// doing so would play the audio for each lock stage; this causes only the final lock sound to play.
	if ( is40mm && PerfectKits_Enabled() && owner.GetMainWeapons().len() > 0 && owner.GetMainWeapons()[0].HasMod( "pas_tone_weapon" ) )
	{
		trackerRockets.SmartAmmo_TrackEntity( hitEnt, GetTrackerLifetime() )
		trackerRockets.SmartAmmo_TrackEntity( hitEnt, GetTrackerLifetime() )
	}
	int count = trackerRockets.SmartAmmo_GetNumTrackersOnEntity( hitEnt )

	if ( oldCount == count )
		return

	if ( count == 3 )
	{
//		if ( hitEnt.IsPlayer() )
//			EmitSoundOnEntityOnlyToPlayer( hitEnt, hitEnt, "HUD_40mm_TrackerBeep_Locked" )
        entity sonar = owner.GetOffhandWeapon( OFFHAND_ANTIRODEO )
        if ( LTSRebalance_Enabled() && is40mm && IsValid( sonar ) && sonar.HasMod( "pas_tone_sonar" ) )
        {
            int maxAmmo = sonar.GetWeaponPrimaryClipCountMax()
            int newAmmo = minint( maxAmmo, sonar.GetWeaponPrimaryClipCount() + int( maxAmmo * PAS_TONE_SONAR_COOLDOWN ) )
            sonar.SetWeaponPrimaryClipCountNoRegenReset( newAmmo )
        }

		if ( owner.IsPlayer() )
			EmitSoundOnEntityOnlyToPlayer( owner, owner, "HUD_40mm_TrackerBeep_Locked" )

		int statusEffectID

		if (hitEnt.IsPlayer())
		{
			int statusEffectID = StatusEffect_AddTimed( hitEnt, eStatusEffect.lockon_detected_titan, 1.0, GetTrackerLifetime(), GetTrackerLifetime() )
			if (hitEnt in trackerRockets.w.targetLockEntityStatusEffectID)
				trackerRockets.w.targetLockEntityStatusEffectID[hitEnt] = statusEffectID
			else
				trackerRockets.w.targetLockEntityStatusEffectID[hitEnt] <- statusEffectID

			thread OnOwnerDeathOrDisembark( owner, hitEnt, trackerRockets, statusEffectID )

			entity soul = hitEnt.GetTitanSoul()
			int statusEffectIDSoul = StatusEffect_AddTimed( soul, eStatusEffect.lockon_detected_titan, 1.0, GetTrackerLifetime(), GetTrackerLifetime() )
			if (soul in trackerRockets.w.targetLockEntityStatusEffectID)
				trackerRockets.w.targetLockEntityStatusEffectID[soul] = statusEffectIDSoul
			else
				trackerRockets.w.targetLockEntityStatusEffectID[soul] <- statusEffectIDSoul


			thread OnOwnerDeathOrDisembark(owner, soul, trackerRockets, statusEffectIDSoul )
		}
		else if (hitEnt.IsNPC())
		{
			entity soul = hitEnt.GetTitanSoul()

			if (soul != null)
			{
				int statusEffectID = StatusEffect_AddTimed( soul, eStatusEffect.lockon_detected_titan, 1.0, GetTrackerLifetime(), GetTrackerLifetime() )
				if ( soul in trackerRockets.w.targetLockEntityStatusEffectID )
					trackerRockets.w.targetLockEntityStatusEffectID[soul] = statusEffectID
				else
					trackerRockets.w.targetLockEntityStatusEffectID[soul] <- statusEffectID

				thread OnOwnerDeathOrDisembark( owner, soul, trackerRockets, statusEffectID )
			}
			else
			{
				int statusEffectID = StatusEffect_AddTimed( hitEnt, eStatusEffect.lockon_detected_titan, 1.0, GetTrackerLifetime(), GetTrackerLifetime() )
				if (hitEnt in trackerRockets.w.targetLockEntityStatusEffectID)
					trackerRockets.w.targetLockEntityStatusEffectID[hitEnt] = statusEffectID
				else
					trackerRockets.w.targetLockEntityStatusEffectID[hitEnt] <- statusEffectID

				thread OnOwnerDeathOrDisembark(owner, hitEnt, trackerRockets, statusEffectID )
			}
		}


	}
	else if ( count == 2 )
	{
//		if ( hitEnt.IsPlayer() )
//			EmitSoundOnEntityOnlyToPlayer( hitEnt, hitEnt, "HUD_40mm_TrackerBeep_Hit" )
		if ( owner.IsPlayer() )
			EmitSoundOnEntityOnlyToPlayer( owner, owner, "HUD_40mm_TrackerBeep_Hit" )
	}
	else
	{
//		if ( hitEnt.IsPlayer() )
//			EmitSoundOnEntityOnlyToPlayer( hitEnt, hitEnt, "HUD_40mm_TrackerBeep_Hit" )
		if ( owner.IsPlayer() )
			EmitSoundOnEntityOnlyToPlayer( owner, owner, "HUD_40mm_TrackerBeep_Hit" )
	}
}

void function OnOwnerDeathOrDisembark(entity owner, entity hitEnt, entity trackerRockets, int statusEffectID)
{
	//We check IsAlive before applying this thread, but it still is erroring when an NPC titan is killed before the pulse lands.
	if ( !IsAlive( owner ) )
		return

	owner.EndSignal( "OnDeath" )
	owner.EndSignal( "TrackerRocketsFired" )
	owner.EndSignal( "DisembarkingTitan" )
	if( LTSRebalance_Enabled() )
		trackerRockets.EndSignal( "OnDestroy" )

	OnThreadEnd(
		function () : ( hitEnt, statusEffectID )
		{
			if( IsValid( hitEnt ) && IsAlive( hitEnt ))
				StatusEffect_Stop( hitEnt, statusEffectID )
		}
	)

	float timeWaitedWhileLocked = 0

	if( LTSRebalance_Enabled() )
	{
		while( IsAlive( owner ) && IsAlive( hitEnt ) && SmartAmmo_EntHasEnoughTrackedMarks( trackerRockets, hitEnt ) )
        	wait 0.1
	}
	else
	{
		bool trackedEntIsAlive = IsAlive(hitEnt)
		while(trackedEntIsAlive)
		{
			if(IsAlive(owner))
			{
				wait 0.1
				timeWaitedWhileLocked = timeWaitedWhileLocked + 0.1

				trackedEntIsAlive = IsAlive(hitEnt)

				if (timeWaitedWhileLocked >= GetTrackerLifetime())
					return
			}
			else
			{
				if(hitEnt != null && IsAlive(hitEnt))
					StatusEffect_Stop( hitEnt, statusEffectID )
				return
			}
		}
	}
}

void function Tracker40mm_DamagedTarget( entity ent, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( !IsAlive( attacker ) )
		return

	if ( ent == attacker )
		return

 	ApplyTrackerMark( attacker, ent, true )

    entity projectile = DamageInfo_GetInflictor( damageInfo )
	array<string> mods = projectile.ProjectileGetMods()

	if ( DamageInfo_GetDamage( damageInfo ) == 0 )
		return

	if ( PerfectKits_Enabled() && mods.contains( "pas_tone_weapon" ) && ( ent.IsPlayer() || ent.IsNPC() ) && IsAlive( ent ) )
		thread PerfectKits_EnhancedTrackerSonarThink(  ent, projectile.GetOrigin(), attacker )

	if ( !LTSRebalance_Enabled() )
		return

    int flags = DamageInfo_GetCustomDamageType( damageInfo )

    if ( mods.contains( "LTSRebalance_pas_tone_weapon_on" ) )
	{
		if ( flags & DF_IMPACT )
        	ApplyTrackerMark( attacker, ent, true )
	}
	else if ( mods.contains( "pas_tone_weapon" ) && attacker.GetMainWeapons().len() > 0 )
	{
		entity weapon = attacker.GetMainWeapons()[0]
		if ( IsValid( weapon ) && ent.IsTitan() )
			weapon.AddMod( "LTSRebalance_pas_tone_weapon_on" )
	}
}

void function PerfectKits_EnhancedTrackerSonarThink( entity enemy, vector position, entity owner )
{
    enemy.EndSignal( "OnDeath" )
	enemy.EndSignal( "OnDestroy" )

    int team = owner.GetTeam()
	SonarStart( enemy, position, team, owner )
	IncrementSonarPerTeam( team )

	OnThreadEnd(
	function() : ( enemy, team )
		{
			DecrementSonarPerTeam( team )
			if ( IsValid( enemy ) )
				SonarEnd( enemy, team )
		}
	)

    float duration = 1.0
	wait duration
}

void function LTSRebalance_BurstLoaderClear( entity player, entity titan )
{
	if ( titan.GetMainWeapons().len() > 0 )
		titan.GetMainWeapons()[0].SetWeaponChargeFractionForced( 0.0 )
}
#endif

bool function OnWeaponChargeLevelIncreased_titanweapon_sticky_40mm( entity weapon )
{
	#if CLIENT
		if ( InPrediction() && !IsFirstTimePredicted() )
			return true
	#endif

	int level = weapon.GetWeaponChargeLevel()
	int ammo = weapon.GetWeaponPrimaryClipCount()

	if ( ammo >= level )
	{
		if ( level == 2 )
			weapon.EmitWeaponSound( "weapon_40mm_burstloader_leveltick_2" ) //Middle Sound
		else if ( level == 3 )
			weapon.EmitWeaponSound( "weapon_40mm_burstloader_leveltick_3" ) //Final Sound
	}

	return true
}

//First sound
void function OnWeaponStartZoomIn_titanweapon_sticky_40mm( entity weapon )
{
	if ( weapon.IsReadyToFire() )
	{
		if ( weapon.HasMod( "pas_tone_burst") || weapon.HasMod( "LTSRebalance_pas_tone_burst" ) )
			weapon.EmitWeaponSound( "weapon_40mm_burstloader_leveltick_1" )
	}
}

//First Sound
void function OnWeaponReadyToFire_titanweapon_sticky_40mm( entity weapon )
{
	if ( weapon.IsWeaponInAds() && weapon.GetWeaponPrimaryClipCount() > 0 )
    {
		if ( weapon.HasMod( "pas_tone_burst") || weapon.HasMod( "LTSRebalance_pas_tone_burst" ) )
			weapon.EmitWeaponSound( "weapon_40mm_burstloader_leveltick_1" )
    }
}