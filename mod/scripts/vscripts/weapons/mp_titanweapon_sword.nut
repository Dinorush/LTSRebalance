untyped
global function OnWeaponActivate_titanweapon_sword
global function OnWeaponDeactivate_titanweapon_sword
global function MpTitanWeaponSword_Init

global const asset SWORD_GLOW_FP = $"P_xo_sword_core_hld_FP"
global const asset SWORD_GLOW = $"P_xo_sword_core_hld"

global const asset SWORD_GLOW_PRIME_FP = $"P_xo_sword_core_PRM_FP"
global const asset SWORD_GLOW_PRIME = $"P_xo_sword_core_PRM"

const float WAVE_SEPARATION = 100
const float VORTEX_DAMAGE_MOD = .2
const float PAS_RONIN_SWORDCORE_COOLDOWN = 0.09

void function MpTitanWeaponSword_Init()
{
	PrecacheParticleSystem( SWORD_GLOW_FP )
	PrecacheParticleSystem( SWORD_GLOW )

	PrecacheParticleSystem( SWORD_GLOW_PRIME_FP )
	PrecacheParticleSystem( SWORD_GLOW_PRIME )

	#if SERVER
		if ( LTSRebalance_EnabledOnInit() )
       	 	AddDamageCallbackSourceID( eDamageSourceId.melee_titan_sword, Sword_DamagedTarget )
		AddDamageCallbackSourceID( eDamageSourceId.mp_titancore_shift_core, Sword_DamagedTarget )
	#endif
}

void function OnWeaponActivate_titanweapon_sword( entity weapon )
{
	if ( weapon.HasMod( "super_charged" ) || weapon.HasMod( "LTSRebalance_super_charged" ) )
	{
		if ( weapon.HasMod( "modelset_prime" ) )
			weapon.PlayWeaponEffectNoCull( SWORD_GLOW_PRIME_FP, SWORD_GLOW_PRIME, "sword_edge" )
		else
			weapon.PlayWeaponEffectNoCull( SWORD_GLOW_FP, SWORD_GLOW, "sword_edge" )
        
        #if SERVER
		if ( LTSRebalance_Enabled() )
        	thread WaitForMeleeAttack( weapon, weapon.GetWeaponOwner() )
        #endif
	}
}

#if SERVER
void function WaitForMeleeAttack( entity weapon, entity titan )
{
    weapon.EndSignal( "WeaponDeactivateEvent" )
    titan.EndSignal( "CoreEnd" )
    titan.EndSignal( "OnDestroy" )
	titan.EndSignal( "OnDeath" )
	titan.EndSignal( "DisembarkingTitan" )
    titan.EndSignal( "TitanEjectionStarted" )

    float lastMeleeTime = 0
    while(1)
    {
        titan.WaitSignal( "OnMelee" )

        // Still inside the same melee
        if(Time() - lastMeleeTime < 0.2)
        {
            lastMeleeTime = Time()
            continue
        }
        
        lastMeleeTime = Time()
		if ( !titan.IsPhaseShifted() )
        	OnMeleeAttackCreateWave( weapon, titan )
    }
}

void function OnMeleeAttackCreateWave( entity weapon, entity titan )
{
    entity inflictor = CreateDamageInflictorHelper( 3.0 )
    array<float> offsets = [ -1.0, 0.0, 1.0 ]
    WeaponPrimaryAttackParams attackParams
    attackParams.pos = titan.EyePosition()
    attackParams.dir = titan.GetViewVector()

    for( int count = 0; count < offsets.len(); count++ )
    {
        vector right = Normalize( CrossProduct( attackParams.dir, <0,0,1> ) )
        vector offset = offsets[count] * right * WAVE_SEPARATION
        const float FUSE_TIME = 99.0
		entity projectile = weapon.FireWeaponGrenade( attackParams.pos + offset, attackParams.dir, < 0,0,0 >, FUSE_TIME, damageTypes.projectileImpact, damageTypes.explosive, false, true, true )
		if ( IsValid( projectile ) )
		{
            thread BeginSwordCoreWave( projectile, inflictor, attackParams.pos + offset, attackParams.dir, right, offsets[count] )
		}
    }
}

void function BeginSwordCoreWave( entity projectile, entity inflictor, vector pos, vector dir, vector right, float offset )
{
    OnThreadEnd(
    function() : ( projectile )
        {
            if(IsValid(projectile))
            {
                StopSoundOnEntity( projectile, "arcwave_tail_3p" )
                projectile.Destroy()
            }
        }
    )
    projectile.EndSignal( "OnDestroy" )
	projectile.SetAbsOrigin( projectile.GetOrigin() )
	projectile.SetVelocity( Vector( 0, 0, 0 ) )
	projectile.StopPhysics()
	projectile.SetTakeDamageType( DAMAGE_NO )
	projectile.Hide()
	projectile.NotSolid()
    EmitSoundOnEntity( projectile, "arcwave_tail_3p" )

    int maxCount = expect int( projectile.ProjectileGetWeaponInfoFileKeyField( "wave_max_count" ) )
    float step = expect float( projectile.ProjectileGetWeaponInfoFileKeyField( "wave_step_dist" ) )
    entity owner = projectile.GetOwner()
    int pilotDamage = projectile.GetProjectileWeaponSettingInt( eWeaponVar.explosion_damage )
    int titanDamage = projectile.GetProjectileWeaponSettingInt( eWeaponVar.explosion_damage_heavy_armor )
    float explosionradius = projectile.GetProjectileWeaponSettingFloat( eWeaponVar.explosionradius )
    owner.EndSignal("OnDestroy")

	if( !offset )
	{
		const float OFFSET = 11 // shifts some more since the high effect detail dot doesn't line up perfectly
		vector halfOffset = right * ( explosionradius - OFFSET ) * 0.5 
		thread SwordCoreWave_ArcBeam( projectile, pos - halfOffset, right, ( explosionradius + OFFSET ) / 2.0, dir, step )
		thread SwordCoreWave_ArcBeam( projectile, pos + halfOffset, right * -1, ( explosionradius + OFFSET ) / 2.0, dir, step )
	}
	else
		thread SwordCoreWave_ArcBeam( projectile, pos, right * offset, explosionradius, dir, step )
    
    for ( int i = 0; i < maxCount; i++ )
    {
        vector newPos = pos + dir * step

        // Ignores vortex; may re-enable in future
        // VortexBulletHit ornull vortexHit = VortexBulletHitCheck( owner, pos, newPos )
		// if ( vortexHit )
		// {
		// 	expect VortexBulletHit( vortexHit )
		// 	entity vortexWeapon = vortexHit.vortex.GetOwnerWeapon()

		// 	if ( vortexWeapon && vortexWeapon.GetWeaponClassName() == "mp_titanweapon_vortex_shield" )
		// 		VortexDrainedByImpact( vortexWeapon, null, projectile, null ) // drain the vortex shield
		// 	else if ( IsVortexSphere( vortexHit.vortex ) )
		// 		VortexSphereDrainHealthForDamage( vortexHit.vortex, titanDamage * VORTEX_DAMAGE_MOD )

		// 	WaitFrame()
		// 	continue
		// }

        TraceResults forwardTrace = TraceLine( pos, newPos, [ owner ], TRACE_MASK_SHOT, TRACE_COLLISION_GROUP_BLOCK_WEAPONS )
        if( forwardTrace.fraction < 1 && forwardTrace.hitEnt.IsWorld() )
            break

        pos = newPos

        RadiusDamage(
		pos,
		owner, //attacker
		inflictor, //inflictor
		pilotDamage,
		titanDamage,
		explosionradius, // inner radius
		explosionradius, // outer radius
		SF_ENVEXPLOSION_NO_DAMAGEOWNER | SF_ENVEXPLOSION_MASK_BRUSHONLY | SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT,
		0, // distanceFromAttacker
		0, // explosionForce
		DF_ELECTRICAL | DF_STOPS_TITAN_REGEN,
		eDamageSourceId.mp_titancore_shift_core )

        WaitFrame()
    }
    StopSoundOnEntity( projectile, "arcwave_tail_3p" )
}

void function SwordCoreWave_ArcBeam( entity projectile, vector pos, vector right, float halfdist, vector dir, float step )
{
	projectile.EndSignal( "OnDestroy" )
	
    asset beamEffectName = $"P_wpn_charge_tool_beam"
    vector endPos = pos + right * halfdist
    vector startPos = pos - right * halfdist
	// Control point sets the end position of the effect
	entity cpEnd = CreateEntity( "info_placement_helper" )
	SetTargetName( cpEnd, UniqueString( "sword_core_wave_cpEnd" ) )
	cpEnd.SetOrigin( endPos )
	cpEnd.SetParent( projectile )
	DispatchSpawn( cpEnd )

    entity serverEffect = CreateEntity( "info_particle_system" )
	serverEffect.kv.cpoint1 = cpEnd.GetTargetName()
	serverEffect.SetValueForEffectNameKey( beamEffectName )
	serverEffect.kv.start_active = 1
	serverEffect.SetOrigin( startPos )
	serverEffect.SetAngles( VectorToAngles( cpEnd.GetOrigin() - serverEffect.GetOrigin() ) )
	serverEffect.SetParent( projectile )
	DispatchSpawn( serverEffect )

	OnThreadEnd(
		function() : ( cpEnd, serverEffect )
		{
			cpEnd.Destroy()
			serverEffect.Destroy()
		}
	)

	while( IsValid( projectile ) )
	{
		cpEnd.SetAbsOrigin( cpEnd.GetOrigin() + dir * step )
		serverEffect.SetAbsOrigin( serverEffect.GetOrigin() + dir * step )
		WaitFrame()
	}
}

#endif

/*void function DelayedSwordCoreFX( entity weapon )
{
	weapon.EndSignal( "WeaponDeactivateEvent" )
	weapon.EndSignal( "OnDestroy" )

	WaitFrame()

	weapon.PlayWeaponEffectNoCull( SWORD_GLOW_FP, SWORD_GLOW, "sword_edge" )
}*/

void function OnWeaponDeactivate_titanweapon_sword( entity weapon )
{
	if ( weapon.HasMod( "modelset_prime" ) )
		weapon.StopWeaponEffect( SWORD_GLOW_PRIME_FP, SWORD_GLOW_PRIME )
	else
		weapon.StopWeaponEffect( SWORD_GLOW_FP, SWORD_GLOW )

	if ( LTSRebalance_Enabled() )
    	weapon.Signal( "WeaponDeactivateEvent" )
}

#if SERVER
void function Sword_DamagedTarget( entity target, var damageInfo )
{
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	entity soul = attacker.GetTitanSoul()

    if ( LTSRebalance_Enabled() && IsValid( soul ) && SoulHasPassive( soul, ePassives.PAS_RONIN_SWORDCORE ) )
    {
        entity offhand
        foreach ( index in [ OFFHAND_LEFT, OFFHAND_ANTIRODEO, OFFHAND_RIGHT ] )
        {
            offhand = attacker.GetOffhandWeapon( index )
            if ( !offhand )
                continue
            
            int maxAmmo = offhand.GetWeaponPrimaryClipCountMax()
            int newAmmo = minint( maxAmmo, offhand.GetWeaponPrimaryClipCount() + int( maxAmmo * PAS_RONIN_SWORDCORE_COOLDOWN ) )
            offhand.SetWeaponPrimaryClipCountNoRegenReset( newAmmo )
        } 
    }

    if( DamageInfo_GetDamageSourceIdentifier( damageInfo ) != eDamageSourceId.mp_titancore_shift_core )
        return

    // Don't want sword core beams to give shields in Aegis
    if( DamageInfo_GetInflictor( damageInfo ).IsProjectile() )
        return

	entity coreWeapon = attacker.GetOffhandWeapon( OFFHAND_EQUIPMENT )
	if ( !IsValid( coreWeapon ) )
		return

	if ( ( coreWeapon.HasMod( "fd_duration" ) || coreWeapon.HasMod( "LTSRebalance_fd_duration" ) ) && IsValid( soul ) )
	{
		int shieldRestoreAmount = target.GetArmorType() == ARMOR_TYPE_HEAVY ? 500 : 250
		soul.SetShieldHealth( min( soul.GetShieldHealth() + shieldRestoreAmount, soul.GetShieldHealthMax() ) )
	}
}
#endif