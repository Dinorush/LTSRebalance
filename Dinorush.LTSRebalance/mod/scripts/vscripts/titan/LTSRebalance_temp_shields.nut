untyped

// Temp Shields are a system introduced by LTS Rebalance.
// There can be multiple temp shields simultaneously. Each splits the damage taken,
// and temp shields are always damaged before permanent shields
// They decay at a set rate after a set delay, customized on creation.
// If permanent shields overwrite temp shields, it will delay the decay by the corresponding
// amount evenly for all temp shields.

global function LTSRebalance_TrackTempShields
global function LTSRebalance_AddTempShields
global function LTSRebalance_HandleTempShieldChange
global function LTSRebalance_GetTempShieldHealth

// Initializes the temporary shield system for the given titan (soul).
// Must be called before any temporary shield systems can be used on the titan!
void function LTSRebalance_TrackTempShields( entity titan )
{
	#if SERVER
	if ( !LTSRebalance_Enabled() )
		return

	// Double init guard
	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) || "tempShields" in soul.s )
		return

	soul.s.tempShields <- []
	soul.s.trackedShieldHealth <- soul.GetShieldHealth()

	// Starts the running thread that handles temporary shield decay + damage taken
	thread LTSRebalance_MonitorTempShieldsThink( soul )
	#endif
}

// Helper function that totals temporary shield health for the given titan soul.
int function LTSRebalance_GetTempShieldHealth( entity soul )
{
	int totalTemp = 0
	if ( LTSRebalance_Enabled() && "tempShields" in soul.s )
		foreach( tempShield in soul.s.tempShields )
			totalTemp += expect int( tempShield.shield )

	return totalTemp
}

// Adds temporary shields to the titan. This also adds the shields themselves (i.e. the shield health need not be set separately)
void function LTSRebalance_AddTempShields( entity soul, int tempShields, int tempOverflow, float decayTime, float delay = 0 )
{
	#if SERVER
	// Any shields that overflow past max shield health is added to the temp shield's overflow
	int extraShields = maxint( 0, soul.GetShieldHealth() + tempShields - soul.GetShieldHealthMax() )
	tempOverflow += extraShields
	tempShields -= tempOverflow

	LTSRebalance_LogStruct ornull ls = LTSRebalance_GetLogStruct( soul.GetTitan() )
	if ( ls != null )
	{
		expect LTSRebalance_LogStruct( ls )
		ls.tempShieldsGained += tempShields
	}

	// Set the shield health and add the newly created temp shield to the list 
	soul.SetShieldHealth( soul.GetShieldHealth() + tempShields )
	soul.s.tempShields.append(
		{ 
			shield = tempShields,
			overflow = tempOverflow,
			total = tempShields + tempOverflow,
			decayTime = decayTime,
			delay = delay
		} 
	)
	#endif
}

// Handles updating temp shields in response to any non-decay, non-temp source (e.g. damage, permanent shields).
// Should be called before shield gets added to (via battery, core, or siphon) or after damage has been taken.
void function LTSRebalance_HandleTempShieldChange( entity soul, int change )
{
	#if SERVER
	if ( change > 0 ) // Hijacking this function to log shield gain stats
	{
		LTSRebalance_LogStruct ornull ls = LTSRebalance_GetLogStruct( soul.GetTitan() )
		if ( ls != null )
		{
			expect LTSRebalance_LogStruct( ls )
			int tempShields = LTSRebalance_GetTempShieldHealth( soul )
			int shieldsGained = minint( change, soul.GetShieldHealthMax() - soul.GetShieldHealth() + tempShields )
			ls.shieldsGained += shieldsGained
			ls.shieldsWasted += change - shieldsGained
		}
	}

	// Check whether temp shields exists
	if ( !LTSRebalance_Enabled() || change == 0 || !( "tempShields" in soul.s ) || soul.s.tempShields.len() == 0 )
		return

	// If the incoming change is damage
	if ( change < 0 )
		LTSRebalance_HandleTempShieldChange_Internal( soul, -change )
	// If the incoming change is permanent shielding
	else
	{
		// Handles case where shield was damaged and then healed before thread updated tracked health
		if ( soul.s.trackedShieldHealth > soul.GetShieldHealth() )
			LTSRebalance_HandleTempShieldChange_Internal( soul, soul.GetShieldHealth() - expect int( soul.s.trackedShieldHealth ) )

		// Only overwrite temp shielding if shields overflow (i.e. shift temp shield amount to temp shield overflow)
		int tempShieldOverwritten = change - ( soul.GetShieldHealthMax() - soul.GetShieldHealth() )
		if ( tempShieldOverwritten < 0)
			return

		LTSRebalance_HandleTempShieldChange_Internal( soul, tempShieldOverwritten, true )
	}
	#endif
}

#if SERVER
void function LTSRebalance_MonitorTempShieldsThink( entity soul )
{
	soul.EndSignal( "OnDestroy" )
	float lastTime = Time()
	while(1)
	{
		WaitFrame()
		if( soul.s.tempShields.len() > 0 )
		{
			// If shield was damaged, update temp shields (shield healing is explicitly tracked in script)
			int damage = expect int( soul.s.trackedShieldHealth ) - soul.GetShieldHealth()
			if( damage > 0 )
				LTSRebalance_HandleTempShieldChange( soul, -damage )

			// Decay temp shields over time
			LTSRebalance_DecayTempShields( soul, Time() - lastTime )
		}
		soul.s.trackedShieldHealth = soul.GetShieldHealth()
		lastTime = Time()
	}
}

// Loops over temp shields, decaying them using the given amount of time passed (in seconds).
// Temp shields that decay to 0 are removed.
void function LTSRebalance_DecayTempShields( entity soul, float passedTime )
{
	array tempShields = expect array( soul.s.tempShields )
	for( int i = tempShields.len() - 1; i >= 0; i-- )
	{
		float remainingTime = passedTime
		// Don't decay temp shields during delay
		if ( tempShields[i].delay > passedTime )
		{
			tempShields[i].delay -= passedTime
			continue
		}
		// Account for remaining delay if it exists
		else if ( tempShields[i].delay > 0 )
		{
			remainingTime -= expect float( tempShields[i].delay )
			tempShields[i].delay = 0
		}

		// Decays the proportional amount of shield for the percent of time passed vs overall decay time.
		// If decay time is 0, decays the entire shield.
		float decayPercent = min( 1.0, tempShields[i].decayTime > 0 ? remainingTime / expect float( tempShields[i].decayTime ) : 1.0 )
		int decay = int( tempShields[i].total * decayPercent + 0.5 )

		// Decay from overflow before the actual temp shields
		if ( tempShields[i].overflow > 0 )
		{
			tempShields[i].overflow -= decay
			// Reduce decay but don't halt it if some overflow exists, but not enough to prevent all decay
			if ( tempShields[i].overflow < 0 )
			{
				decay = - expect int( tempShields[i].overflow )
				tempShields[i].overflow = 0
			}
			else
				continue
		}
		
		// Decay the temp shields and reduce the titan's actual shields
		decay = minint( tempShields[i].shield, decay )
		tempShields[i].shield -= decay

		soul.SetShieldHealth( soul.GetShieldHealth() - decay )
		// Clean up dead shields
		if ( tempShields[i].shield <= 0 )
			tempShields.remove(i)
	}
}

// Handles splitting damage/healing to each current temp shield evenly.
void function LTSRebalance_HandleTempShieldChange_Internal( entity soul, int change, bool isGain = false )
{	
	array tempShields = expect array( soul.s.tempShields )
	float damagePer = float( change ) / tempShields.len()
	// We want to spread the damage out to other temp shields if one couldn't block all of its own spread.
	// So, sort the list by shield amount and loop up it so we ensure the smallest shields pass remaining damage up.
	tempShields.sort( function(a, b) { return a.shield > b.shield } )

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
