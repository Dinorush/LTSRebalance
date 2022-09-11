untyped

global function LTSRebalance_TrackTempShields
global function LTSRebalance_AddTempShields
global function LTSRebalance_HandleTempShieldChange
global function LTSRebalance_GetTempShieldHealth

void function LTSRebalance_TrackTempShields( entity titan )
{
	#if SERVER
	if ( !LTSRebalance_Enabled() )
		return

	entity soul = titan.GetTitanSoul()
	if ( !IsValid( soul ) || "tempShields" in soul.s )
		return

	soul.s.tempShields <- []
	soul.s.trackedShieldHealth <- soul.GetShieldHealth()
	thread LTSRebalance_MonitorTempShieldsThink( soul )
	#endif
}

int function LTSRebalance_GetTempShieldHealth( entity soul )
{
	int totalTemp = 0
	if ( LTSRebalance_Enabled() && "tempShields" in soul.s )
		foreach( tempShield in soul.s.tempShields )
			totalTemp += expect int( tempShield.shield )

	return totalTemp
}

void function LTSRebalance_AddTempShields( entity soul, int tempShields, int tempOverflow, float decayTime, float delay = 0 )
{
	#if SERVER
	int extraShields = maxint( 0, soul.GetShieldHealth() + tempShields - soul.GetShieldHealthMax() )
	tempOverflow += extraShields
	tempShields -= tempOverflow

	LTSRebalance_LogStruct ornull ls = LTSRebalance_GetLogStruct( soul.GetTitan() )
	if ( ls != null )
	{
		expect LTSRebalance_LogStruct( ls )
		ls.tempShieldsGained += tempShields
	}

	soul.SetShieldHealth( soul.GetShieldHealth() + tempShields )
	soul.s.tempShields.append( { shield = tempShields, overflow = tempOverflow, total = tempShields + tempOverflow, decayTime = decayTime, delay = delay } )
	#endif
}

// Should be called before shield gets added to (via battery, core, or siphon) or after damage has been taken
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

	// Have to check whether temp shields exists since it only gets added on the first Siphon use
	if ( !LTSRebalance_Enabled() || change == 0 || !( "tempShields" in soul.s ) || soul.s.tempShields.len() == 0 )
		return

	if ( change < 0 )
		LTSRebalance_HandleTempShieldChange_Internal( soul, -change )
	else
	{
		// Handles case where shield was damaged and then healed before thread updated tracked health
		if ( soul.s.trackedShieldHealth > soul.GetShieldHealth() )
			LTSRebalance_HandleTempShieldChange_Internal( soul, soul.GetShieldHealth() - expect int( soul.s.trackedShieldHealth ) )

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
			// If shield was damaged
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

void function LTSRebalance_DecayTempShields( entity soul, float passedTime )
{
	array tempShields = expect array( soul.s.tempShields )
	for( int i = tempShields.len() - 1; i >= 0; i-- )
	{
		float remainingTime = passedTime
		if ( tempShields[i].delay > passedTime )
		{
			tempShields[i].delay -= passedTime
			continue
		}
		else if ( tempShields[i].delay > 0 )
		{
			remainingTime -= expect float( tempShields[i].delay )
			tempShields[i].delay = 0
		}

		float decayPercent = min( 1.0, tempShields[i].decayTime > 0 ? remainingTime / expect float( tempShields[i].decayTime ) : 1.0 )
		int decay = int( tempShields[i].total * decayPercent + 0.5 )
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

#if SERVER
void function LTSRebalance_HandleTempShieldChange_Internal( entity soul, int change, bool isGain = false )
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
