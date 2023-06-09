# LTS Rebalance

**Required by Server and Client**

A comprehensive rebalancing of titans and titan kits focused on improving balance and meta diversity in LTS. The changes are numerous and significantly alter the power of several titans and kits, but the gameplay of each titan should remain fairly close to Vanilla. The mod is usable outside of LTS; the balance merely does not consider other modes.

## Balance Changelog

All balancing/changes can be viewed in [this changelog document](https://docs.google.com/document/d/10mZtK7w7MOTv9kGNQru96G7XpEZqv8_dUw_I29RhDj4/edit?usp=sharing).

### Activation

This mod enables a new setting, "LTS Rebalance", under the "Promode" category in private match settings turned on by default. When turned on, LTS Rebalance changes will apply.

### Weapon Cosmetic Mod Conflictions

These weapons have limitations that prevent them from working with certain mods that attempt to add reticles or effects to a set list of weapons:

- Predator Cannon
  - Weapon is entirely replaced. No mods that reference this weapon specifically or modify its reticle will work.
- 40mm Tracker Cannon
  - Reticles are replaced. Reticle mods that use KeyValue modding will not work.

## FAQs

### My game bugs out/crashed when I played Tone/Monarch on normal servers.

Recent Northstar updates broke something, and joining normal servers with the mod on no longer fully disables it (has the same issue as what KVFix fixes below). Until this is fixed, you need to disable the mod (not KVFix) on the main menu to join normal servers and not get wack behavior.

### What is Dinorush.LTSRebalance_KVFix?

Basic ver: Northstar currently does not reload all the files it should when reloading mods via the mod menu. This mod fixes the problem if LTSRebalance is enabled/disabled, otherwise you may experience weird gameplay behavior or crashes. (Note: may cause a short "freeze" when loaded into MP)

Technical ver: Northstar doesn't reparse weapon keyvalue files when reloading mods. This mod checks whether LTSRebalance is on and whether LTSRebalance keyvalue files are loaded. If it detects that these two checks do not match, it will attempt a `weapon_reparse` when possible. Otherwise, the user can get incorrect keyvalue desyncs during gameplay or even crashes for certain function calls that don't work in vanilla.

### If I want to disable LTSRebalance, should I also disable LTSRebalance_KVFix?

**No.** This mod exists specifically for the case that LTSRebalance is disabled; it should be left on.

### Can I turn off LTSRebalance_KVFix and still use LTSRebalance?

Sure. LTSRebalance_KVFix is not necessary to use LTSRebalance. However, if you ever use the mod menu to enable/disable LTSRebalance, you will need to manually run `weapon_reparse` with `sv_cheats` on in the multiplayer menu/a private match or reboot your game to avoid the aforementioned issues. Unless you know what you're doing, I wouldn't recommend turning KVFix off.
