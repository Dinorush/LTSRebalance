/* LTS Rebalance replaces this file for the following reasons:
   1. Change Sword Block functionality
      • Block on ready, not on switch
	  • Block has scaling damage reduction based on remaining charge
   2. Implement new Highlander effect
*/
untyped
global function MpTitanAbilityBasicBlock_Init

global function OnWeaponActivate_titanability_basic_block
global function OnWeaponDeactivate_titanability_basic_block
global function OnWeaponAttemptOffhandSwitch_titanability_basic_block
global function OnWeaponPrimaryAttack_titanability_basic_block
global function OnWeaponChargeBegin_titanability_basic_block

global function OnWeaponActivate_ability_swordblock
global function OnWeaponDeactivate_ability_swordblock
global function OnWeaponAttemptOffhandSwitch_ability_swordblock
global function OnWeaponPrimaryAttack_ability_swordblock
global function OnWeaponChargeBegin_ability_swordblock

#if CLIENT
global enum LTSRebalance_eDirection 
{
    down, 
    up,
    left,
    right
}

global struct LTSRebalance_TopoData {
    vector position = Vector( 0.0, 0.0, 0.0 )
    vector size = Vector( 0.0, 0.0, 0.0 )
    vector angles = Vector( 0.0, 0.0, 0.0 )
    var topo
}

global struct LTSRebalance_BarTopoData {
    vector position = Vector( 0.0, 0.0, 0.0 )
    vector size = Vector( 0.0, 0.0, 0.0 )
    vector angles = Vector( 0.0, 0.0, 0.0 )
    int segments = 1
    array<var> imageRuis
    array<LTSRebalance_TopoData> topoData
    int direction
	float fill
    void functionref( entity ) updateFunc = null
}
struct
{
	float earn_meter_titan_multiplier = 1.0
	table< string, LTSRebalance_BarTopoData > LTSRebalance_block_ui
	var LTSRebalance_block_text
} file
#else
struct
{
	float earn_meter_titan_multiplier = 1.0
} file
#endif

void function MpTitanAbilityBasicBlock_Init()
{
#if SERVER
	AddDamageFinalCallback( "player", BasicBlock_OnDamage )
	AddDamageFinalCallback( "npc_titan", BasicBlock_OnDamage )
#else
	if ( LTSRebalance_EnabledOnInit() )
	{
		LTSRebalance_BarTopoData bg = LTSRebalance_BasicImageBar_CreateRuiTopo( < 0, 0, 0 >, < 0.0, 0.085, 0.0 >, 0.105, 0.015, LTSRebalance_eDirection.right )
		RuiSetFloat3( bg.imageRuis[0], "basicImageColor", < 0, 0, 0 > )
		RuiSetFloat( bg.imageRuis[0], "basicImageAlpha", 0.0 )
		LTSRebalance_BarTopoData charge = LTSRebalance_BasicImageBar_CreateRuiTopo( < 0, 0, 0 >, < 0.0, 0.085, 0.0 >, 0.1, 0.0075, LTSRebalance_eDirection.right )
		RuiSetFloat( charge.imageRuis[0], "basicImageAlpha", 0.0 )
		LTSRebalance_BasicImageBar_SetFillFrac( charge, 0.0 )

		// vector angles = <0, 0.1, 0>
		// vector _angles = Vector( angles.y * COCKPIT_RUI_HEIGHT, -angles.x * COCKPIT_RUI_WIDTH, angles.z )
		// var topo = CreateBar( <0, 0, 0>, _angles, COCKPIT_RUI_WIDTH * 0.1, COCKPIT_RUI_HEIGHT * 0.1 )
		var text = RuiCreate( $"ui/cockpit_console_text_center.rpak", clGlobal.topoCockpitHudPermanent, RUI_DRAW_COCKPIT, -1 )
		RuiSetInt( text, "maxLines", 1 )
		RuiSetInt( text, "lineNum", 1 )
		RuiSetFloat2( text, "msgPos", <0, 0.095, 0> )
		RuiSetFloat3( text, "msgColor", <0.4, 1.0, 0.4> )
		RuiSetString( text, "msgText", "0" )
		RuiSetFloat( text, "msgFontSize", 40.0 )
		RuiSetFloat( text, "msgAlpha", 0.0 )
		RuiSetFloat( text, "thicken", 0.0 )
		file.LTSRebalance_block_text = text
		file.LTSRebalance_block_ui["bg"] <- bg
		file.LTSRebalance_block_ui["charge"] <- charge
	}
#endif
	PrecacheParticleSystem( $"P_impact_xo_sword" )
	file.earn_meter_titan_multiplier = GetCurrentPlaylistVarFloat( "earn_meter_titan_multiplier", 1.0 )
}

#if CLIENT
var function CreateBar( vector posOffset, vector angles, float hudWidth, float hudHeight )
{
    var topo = RuiTopology_CreateSphere( 
        COCKPIT_RUI_OFFSET + posOffset, // 
        AnglesToRight( angles ), // right
        AnglesToUp( angles ) * -1, // down 
        COCKPIT_RUI_RADIUS, 
        hudWidth, 
        hudHeight, 
        COCKPIT_RUI_SUBDIV // 3.5
    ) 
    return topo
}
#endif

const int TITAN_BLOCK = 1
const int PILOT_BLOCK = 2

bool function OnWeaponChargeBegin_titanability_basic_block( entity weapon )
{
	return OnChargeBegin( weapon, TITAN_BLOCK )
}
void function OnWeaponActivate_titanability_basic_block( entity weapon )
{
	OnActivate( weapon, TITAN_BLOCK )
}
void function OnWeaponDeactivate_titanability_basic_block( entity weapon )
{
	OnDeactivate( weapon, TITAN_BLOCK )
}

bool function OnWeaponAttemptOffhandSwitch_titanability_basic_block( entity weapon )
{
	return OnAttemptOffhandSwitch( weapon, TITAN_BLOCK )
}
var function OnWeaponPrimaryAttack_titanability_basic_block( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return 0
}

bool function OnWeaponChargeBegin_ability_swordblock( entity weapon )
{
	return OnChargeBegin( weapon, PILOT_BLOCK )
}
void function OnWeaponActivate_ability_swordblock( entity weapon )
{
	OnActivate( weapon, PILOT_BLOCK )
}
void function OnWeaponDeactivate_ability_swordblock( entity weapon )
{
	OnDeactivate( weapon, PILOT_BLOCK )
}
bool function OnWeaponAttemptOffhandSwitch_ability_swordblock( entity weapon )
{
	return OnAttemptOffhandSwitch( weapon, PILOT_BLOCK )
}
var function OnWeaponPrimaryAttack_ability_swordblock( entity weapon, WeaponPrimaryAttackParams attackParams )
{
	return 0
}


bool function OnChargeBegin( entity weapon, int blockType )
{
	weapon.EmitWeaponSound_1p3p( "", "ronin_sword_draw_3p" )
	if ( LTSRebalance_Enabled() )
	{
		entity weaponOwner = weapon.GetWeaponOwner()
		if ( weaponOwner.IsPlayer() )
			PlayerUsedOffhand( weaponOwner, weapon )
		StartShield( weapon )
		#if SERVER
		weaponOwner.Signal( "HighlanderEnd" )
		#endif
	}

	return true
}

void function OnActivate( entity weapon, int blockType )
{
    entity weaponOwner = weapon.GetWeaponOwner()
	if ( !LTSRebalance_Enabled() )
	{
		if ( weaponOwner.IsPlayer() )
			PlayerUsedOffhand( weaponOwner, weapon )
		StartShield( weapon )
	}

	#if CLIENT
		if ( LTSRebalance_Enabled() && !IsWatchingReplay() && IsLocalViewPlayer( weaponOwner ) )
		{
			RuiSetFloat( file.LTSRebalance_block_ui["bg"].imageRuis[0], "basicImageAlpha", 0.35 )
			RuiSetFloat( file.LTSRebalance_block_ui["charge"].imageRuis[0], "basicImageAlpha", 0.7 )
			RuiSetFloat( file.LTSRebalance_block_text, "msgAlpha", 0.7 )
			thread ClLTSRebalance_BlockUIThink( weaponOwner, weapon )
		}
	#endif

    entity offhandWeapon = weaponOwner.GetOffhandWeapon( OFFHAND_MELEE )
    if ( IsValid( offhandWeapon ) && ( offhandWeapon.HasMod( "super_charged" ) || offhandWeapon.HasMod( "LTSRebalance_super_charged" ) ) )
		thread BlockSwordCoreFXThink( weapon, weaponOwner )
}


#if CLIENT
void function ClLTSRebalance_BlockUIThink( entity player, entity weapon )
{
	player.EndSignal( "OnDestroy" )
	weapon.EndSignal( "OnDestroy" )
	weapon.EndSignal( "WeaponDeactivateEvent" )

	OnThreadEnd(
		function() : ()
		{
			RuiSetFloat( file.LTSRebalance_block_ui["charge"].imageRuis[0], "basicImageAlpha", 0.0 )
			RuiSetFloat( file.LTSRebalance_block_ui["bg"].imageRuis[0], "basicImageAlpha", 0.0 )
			RuiSetFloat( file.LTSRebalance_block_text, "msgAlpha", 0.0 )
		}
	)

	while ( true )
	{
		if ( !IsLocalViewPlayer( weapon.GetWeaponOwner() ) )
			return

		float ammoFrac = float( weapon.GetWeaponPrimaryClipCount() ) / float( weapon.GetWeaponPrimaryClipCountMax() )
		RuiSetFloat3( file.LTSRebalance_block_text, "msgColor", GetBlockTextColor( ammoFrac ) )
		RuiSetString( file.LTSRebalance_block_text, "msgText", format( "%.0f%%", ( 1.0 - LTSRebalance_GetCurrentBlock( weapon ) ) * 100.0 ) )
		LTSRebalance_BasicImageBar_SetFillFrac( file.LTSRebalance_block_ui["charge"], ammoFrac )
		WaitFrame()
	}
}

vector function GetBlockTextColor( float chargeFrac )
{
	return GetTriLerpColor( 1 - chargeFrac, <0.3, 1.0, 0.3>, <0.8, 0.6, 0.4>, <1.0, 0.1, 0.1> )
}

// Copied from vortex, since it's not a global func
vector function GetTriLerpColor( float fraction, vector color1, vector color2, vector color3 )
{
	float crossover1 = 0.4  // from zero to this fraction, fade between color1 and color2
	float crossover2 = 0.95 // from crossover1 to this fraction, fade between color2 and color3

	float r, g, b

	// 0 = full charge, 1 = no charge remaining
	if ( fraction < crossover1 )
	{
		r = Graph( fraction, 0, crossover1, color1.x, color2.x )
		g = Graph( fraction, 0, crossover1, color1.y, color2.y )
		b = Graph( fraction, 0, crossover1, color1.z, color2.z )
		return <r, g, b>
	}
	else if ( fraction < crossover2 )
	{
		r = Graph( fraction, crossover1, crossover2, color2.x, color3.x )
		g = Graph( fraction, crossover1, crossover2, color2.y, color3.y )
		b = Graph( fraction, crossover1, crossover2, color2.z, color3.z )
		return <r, g, b>
	}
	else
	{
		// for the last bit of overload timer, keep it max danger color
		r = color3.x
		g = color3.y
		b = color3.z
		return <r, g, b>
	}

	unreachable
}
#endif

void function OnDeactivate( entity weapon, int blockType )
{
	EndShield( weapon )

	#if CLIENT
	weapon.Signal( "WeaponDeactivateEvent" )
	#endif

	asset first_fx
	asset third_fx

	if ( weapon.HasMod( "modelset_prime" ) )
	{
		first_fx = SWORD_GLOW_PRIME_FP
		third_fx = SWORD_GLOW_PRIME
	}
	else
	{
		first_fx = SWORD_GLOW_FP
		third_fx = SWORD_GLOW
	}

	weapon.StopWeaponEffect( first_fx, third_fx )
}

bool function OnAttemptOffhandSwitch( entity weapon, int blockType )
{
	bool allowSwitch = weapon.GetWeaponChargeFraction() < 0.9
	return allowSwitch
}

void function BlockSwordCoreFXThink( entity weapon, entity weaponOwner )
{
	weapon.EndSignal( "WeaponDeactivateEvent" )
	weapon.EndSignal( "OnDestroy" )

	asset first_fx
	asset third_fx

	if ( weapon.HasMod( "modelset_prime" ) )
	{
		first_fx = SWORD_GLOW_PRIME_FP
		third_fx = SWORD_GLOW_PRIME
	}
	else
	{
		first_fx = SWORD_GLOW_FP
		third_fx = SWORD_GLOW
	}

	OnThreadEnd(
	function() : ( weapon, first_fx, third_fx )
		{
			if ( IsValid( weapon ) )
				weapon.StopWeaponEffect( first_fx, third_fx )
		}
	)

	weapon.PlayWeaponEffectNoCull( first_fx, third_fx, "sword_edge" )

#if SERVER
	weaponOwner.WaitSignal( "CoreEnd" )
#endif

#if CLIENT
	entity offhandWeapon = weaponOwner.GetOffhandWeapon( OFFHAND_MELEE )
	while ( IsValid( offhandWeapon ) && offhandWeapon.HasMod("super_charged" ) )
		WaitFrame()
#endif
}


void function StartShield( entity weapon )
{
#if SERVER
	entity weaponOwner = weapon.GetWeaponOwner()
	weaponOwner.e.blockActive = true

	if ( LTSRebalance_Enabled() )
    	weapon.AddMod( "LTSRebalance_stop_regen" )
#endif
}


void function EndShield( entity weapon )
{
#if SERVER
	entity weaponOwner = weapon.GetWeaponOwner()
	weaponOwner.e.blockActive = false

	if ( LTSRebalance_Enabled() )
	{
		weapon.RemoveMod( "LTSRebalance_stop_regen" )
		weapon.RegenerateAmmoReset()
	}
#endif
}

const float TITAN_BLOCK_DAMAGE_REDUCTION = 0.3
const float LTSREBALANCE_TITAN_BLOCK_DAMAGE_REDUCTION = 0.25
const float LTSREBALANCE_TITAN_BLOCK_DAMAGE_EXPONENT = 1.15
const float SWORD_CORE_BLOCK_DAMAGE_REDUCTION = 0.15
const float LTSREBALANCE_SWORD_CORE_BLOCK_DAMAGE_REDUCTION = 0.125
const float LTSREBALANCE_SWORD_CORE_BLOCK_DAMAGE_EXPONENT = 1.27
const float LTSREBALANCE_TITAN_BLOCK_DAMAGE_PER_INCREMENT = 1000.0
const float LTSREBALANCE_SWORD_CORE_BLOCK_AMMO_REDUCTION = 0.67
const float LTSREBALANCE_TITAN_BLOCK_DAMAGE_EXPONENT_MIN = pow( LTSREBALANCE_TITAN_BLOCK_DAMAGE_EXPONENT, 1.0 / LTSREBALANCE_TITAN_BLOCK_DAMAGE_PER_INCREMENT ) - 1.0
const float LTSREBALANCE_SWORD_CORE_BLOCK_DAMAGE_EXPONENT_MIN = pow( LTSREBALANCE_SWORD_CORE_BLOCK_DAMAGE_EXPONENT, 1.0 / LTSREBALANCE_TITAN_BLOCK_DAMAGE_PER_INCREMENT ) - 1.0

#if CLIENT
// Assumes LTS Rebalance is on and user is player. For block UI
float function LTSRebalance_GetCurrentBlock( entity weapon )
{
	float initial = LTSREBALANCE_TITAN_BLOCK_DAMAGE_REDUCTION
	float exponent = LTSREBALANCE_TITAN_BLOCK_DAMAGE_EXPONENT
	if ( weapon.HasMod( "LTSRebalance_core_regen" ) )
	{
		initial = LTSREBALANCE_SWORD_CORE_BLOCK_DAMAGE_REDUCTION
		exponent = LTSREBALANCE_SWORD_CORE_BLOCK_DAMAGE_EXPONENT
	}
	float power = float( weapon.GetWeaponPrimaryClipCountMax() - weapon.GetWeaponPrimaryClipCount() ) / ( LTSREBALANCE_TITAN_BLOCK_DAMAGE_PER_INCREMENT / 10.0 )
	return initial * pow( exponent, power )
}
#endif

#if SERVER
void function IncrementChargeBlockAnim( entity blockingEnt, var damageInfo )
{
	entity weapon = blockingEnt.GetActiveWeapon()
	if ( !IsValid( weapon ) )
		return
	if ( !weapon.IsChargeWeapon() )
		return

	int oldIdx = weapon.GetChargeAnimIndex()
	int newIdx = RandomInt( CHARGE_ACTIVITY_ANIM_COUNT )
	if ( oldIdx == newIdx )
		oldIdx = ((oldIdx + 1) % CHARGE_ACTIVITY_ANIM_COUNT)
	weapon.SetChargeAnimIndex( newIdx )
}

float function HandleBlockingAndCalcDamageScaleForHit( entity blockingEnt, var damageInfo )
{
    entity weapon = blockingEnt.GetActiveWeapon()
    if ( !IsValid( weapon ) )
	{
		printt( "swordblock: no valid activeweapon" )
		return 1.0
    }

	if ( blockingEnt.IsTitan() )
	{
		bool shouldPassThroughDamage = (( DamageInfo_GetCustomDamageType( damageInfo ) & (DF_RODEO | DF_MELEE | DF_DOOMED_HEALTH_LOSS) ) > 0)
		if ( shouldPassThroughDamage )
			return 1.0

        float initial = LTSREBALANCE_TITAN_BLOCK_DAMAGE_REDUCTION
        float exponent = LTSREBALANCE_TITAN_BLOCK_DAMAGE_EXPONENT
		float exponentMin = LTSREBALANCE_TITAN_BLOCK_DAMAGE_EXPONENT_MIN
		float damageIncrement = LTSREBALANCE_TITAN_BLOCK_DAMAGE_PER_INCREMENT
		float ammoMod = 1.0
		if ( blockingEnt.IsPlayer() && PlayerHasPassive( blockingEnt, ePassives.PAS_SHIFT_CORE ) )
        {
			if ( !LTSRebalance_Enabled() )
				return SWORD_CORE_BLOCK_DAMAGE_REDUCTION
            initial = LTSREBALANCE_SWORD_CORE_BLOCK_DAMAGE_REDUCTION
            exponent = LTSREBALANCE_SWORD_CORE_BLOCK_DAMAGE_EXPONENT
			exponentMin = LTSREBALANCE_SWORD_CORE_BLOCK_DAMAGE_EXPONENT_MIN
			ammoMod = LTSREBALANCE_SWORD_CORE_BLOCK_AMMO_REDUCTION
        }

		if ( !LTSRebalance_Enabled() )
			return TITAN_BLOCK_DAMAGE_REDUCTION

		float damage = DamageInfo_GetDamage( damageInfo )
		bool critHit = false
		if ( CritWeaponInDamageInfo( damageInfo ) )
			critHit = IsCriticalHit( DamageInfo_GetAttacker( damageInfo ), blockingEnt, DamageInfo_GetHitBox( damageInfo ), DamageInfo_GetDamage( damageInfo ), DamageInfo_GetDamageType( damageInfo ) )

		entity attacker = DamageInfo_GetAttacker( damageInfo )
		if ( HeavyArmorCriticalHitRequired( damageInfo ) && CritWeaponInDamageInfo( damageInfo ) && !critHit && IsValid( attacker ) && !attacker.IsTitan())
		{
			float shieldHealth = float( blockingEnt.GetTitanSoul().GetShieldHealth() )
			if ( shieldHealth - damage <= 0 )
			{
				if ( shieldHealth > 0 )
					damage = shieldHealth
				else
					damage = 0
			}
		}

		if ( damage == 0 )
			return 1.0

		float oldPower = float( weapon.GetWeaponPrimaryClipCountMax() - weapon.GetWeaponPrimaryClipCount() ) / ( damageIncrement / 10.0 )
        int damageTaken = int( damage * ammoMod + 0.5 ) / 10  // Work with damage / 10 since ammo must be < 1000 for display
		int remainingDamage = maxint( 0, damageTaken - weapon.GetWeaponPrimaryClipCount() )
        int newAmmo = int( max ( 0, weapon.GetWeaponPrimaryClipCount() - damageTaken ) )
        weapon.SetWeaponPrimaryClipCount( newAmmo )
        float newPower = float( weapon.GetWeaponPrimaryClipCountMax() - newAmmo ) / ( damageIncrement / 10.0 )

		if ( newPower != oldPower ) // Geometric sum formula
		{
			float increase = ( ( pow( exponent, newPower ) - pow( exponent, oldPower ) ) /
							( exponentMin * ( newPower - oldPower ) * LTSREBALANCE_TITAN_BLOCK_DAMAGE_PER_INCREMENT ) )

			if ( remainingDamage > 0 ) // Handle overspill damage
			{
				damageTaken -= remainingDamage
				float fracDR = initial * increase
				float maxDR = initial * newPower
				return ( damageTaken * fracDR + remainingDamage * maxDR ) / ( damageTaken + remainingDamage )
			}
			else
				return initial * increase
		}
		else // Only occurs if damage < 10 or Sword Block has no ammo left
			return initial * pow( exponent, oldPower )

		
	}

	int damageType = DamageInfo_GetCustomDamageType( damageInfo )
	if ( damageType & DF_RADIUS_DAMAGE )
	{
		printt( "swordblock: not blocking radius damage" )
		return 1.0
	}

	int originalDamage = int( DamageInfo_GetDamage( damageInfo ) + 0.5 )
	int originalAmmo = weapon.GetWeaponPrimaryAmmoCount()

	int ammoCost = 0
	entity attacker = DamageInfo_GetAttacker( damageInfo )
	if ( IsValid( attacker ) && attacker.IsTitan() && (damageType & DF_MELEE) )
		ammoCost = 40	// auto-titan ground-pounds do 2x damage events right now
	else if ( damageType & DF_MELEE )
		ammoCost = 25
	else if ( originalDamage <= 10 )
		ammoCost = 1
	else if ( originalDamage <= 30 )
		ammoCost = 3
	else if ( originalDamage <= 50 )
		ammoCost = 5
	else if ( originalDamage <= 70 )
		ammoCost = 10
	else if ( originalDamage <= 100 )
		ammoCost = 15
	else if ( originalDamage <= 200 )
		ammoCost = 30
	else if ( originalDamage <= 500 )
		ammoCost = 50
	else
		ammoCost = 100


	int newAmmoTotalRaw = (originalAmmo - ammoCost)
	int newAmmoTotal
	float resultDamageScale
	if ( newAmmoTotalRaw >= 0 )
	{
		newAmmoTotal = newAmmoTotalRaw
		resultDamageScale = 0.0
	}
	else
	{
		newAmmoTotal = 0
		resultDamageScale = (float( -newAmmoTotalRaw ) / float( ammoCost ))
	}

	printt( "swordblock: finalDamageScale(" + resultDamageScale + "), ammoTotal(" + newAmmoTotal + ") - originalDamage(" + originalDamage + "), has cost(" + ammoCost + "), of remaining(" + originalAmmo + "), attacker '" + attacker + "', " + GetDescStringForDamageFlags( damageType ) )

	weapon.SetWeaponPrimaryAmmoCount( newAmmoTotal )
	weapon.RegenerateAmmoReset()
	return resultDamageScale
}


const float TITAN_BLOCK_ANGLE = 150
const float PILOT_BLOCK_ANGLE = 150
float function GetAngleForBlock( entity blockingEnt )
{
	if ( blockingEnt.IsTitan() )
		return TITAN_BLOCK_ANGLE
	return PILOT_BLOCK_ANGLE
}

void function TriggerBlockVisualEffect( entity blockingEnt, int originalDamage, float damageScale )
{
	if ( damageScale > 0.99 )
		return
	if ( blockingEnt.IsTitan() )
		return

	float blockedDamage = originalDamage * (1.0 - damageScale)
	float blockedScale = blockedDamage / 100.0
	float effectScale = (0.5 * blockedScale)
	if ( blockedScale > 0.01 )
		StatusEffect_AddTimed( blockingEnt, eStatusEffect.emp, effectScale, 0.5, 0.4 )
}

void function BasicBlock_OnDamage( entity blockingEnt, var damageInfo )
{
	if ( !blockingEnt.e.blockActive )
		return

	float damageScale = HandleBlockingAndCalcDamageScaleForHit( blockingEnt, damageInfo )
	if ( damageScale == 1.0 )
		return

	entity weapon = blockingEnt.GetOffhandWeapon( OFFHAND_LEFT )
	if ( blockingEnt.IsPlayer() && weapon.HasMod( "fd_sword_block" ) )
	{
		float meterReward = DamageInfo_GetDamage( damageInfo ) * (1.0 - damageScale) * CORE_BUILD_PERCENT_FROM_TITAN_DAMAGE_INFLICTED * 0.015 * file.earn_meter_titan_multiplier
		PlayerEarnMeter_AddEarnedAndOwned( blockingEnt, 0.0, meterReward )
	}

	entity attacker = DamageInfo_GetAttacker( damageInfo )

	int attachId = blockingEnt.LookupAttachment( "PROPGUN" )
	vector origin = GetDamageOrigin( damageInfo, blockingEnt )
	vector eyePos = blockingEnt.GetAttachmentOrigin( attachId )
	vector vec1 = Normalize( origin - eyePos )
	if ( !LTSRebalance_Enabled() )
	{
		vector blockAngles = blockingEnt.GetAttachmentAngles( attachId )
		vector fwd = AnglesToForward( blockAngles )
		
		float dot = DotProduct( vec1, fwd )
		float angleRange = GetAngleForBlock( blockingEnt )
		float minDot = AngleToDot( angleRange )
		if ( dot < minDot )
			return
	}

	IncrementChargeBlockAnim( blockingEnt, damageInfo )
	EmitSoundOnEntity( blockingEnt, "ronin_sword_bullet_impacts" )
	if ( blockingEnt.IsPlayer() )
	{
		int originalDamage = int( DamageInfo_GetDamage( damageInfo ) + 0.5 )
		TriggerBlockVisualEffect( blockingEnt, originalDamage, damageScale )
		blockingEnt.RumbleEffect( 1, 0, 0 )
	}

	StartParticleEffectInWorldWithControlPoint( GetParticleSystemIndex( $"P_impact_xo_sword" ), DamageInfo_GetDamagePosition( damageInfo ) + vec1*200, VectorToAngles( vec1 ) + <90,0,0>, <255,255,255> )

	LTSRebalance_LogDamageBlockedRaw( blockingEnt, DamageInfo_GetAttacker( damageInfo ), DamageInfo_GetDamage( damageInfo ) * ( 1 - damageScale ), true )

	DamageInfo_ScaleDamage( damageInfo, damageScale )

	// ideally this would be DF_INEFFECTIVE, but we are out of damage flags
	DamageInfo_AddCustomDamageType( damageInfo, DF_NO_INDICATOR )
	DamageInfo_RemoveCustomDamageType( damageInfo, DF_DOOM_FATALITY )
}
#endif