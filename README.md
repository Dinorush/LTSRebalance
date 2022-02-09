# Dinorush.LTSRebalance

**Required by Server and Client**

Does a comprehensive rebalancing of titans and titan kits focused on LTS balance.

### Activation

This mod enables a new setting, "LTS Rebalance", under the "Promode" category in private match settings. When turned on, LTS Rebalance changes will apply.

### ConVars

- `ltsrebalance_force_recompile`: Default value of `1`. Recompiles KeyValue files upon entering the multiplayer lobby if they do not have LTSRebalance changes. Will not work if the mod is disabled. (If you're not sure what this does, just leave it on)

## Balance Changelog

All balancing/changes can be viewed in [this changelog document](https://docs.google.com/document/d/10mZtK7w7MOTv9kGNQru96G7XpEZqv8_dUw_I29RhDj4/edit?usp=sharing).

## Weapon Mod Conflictions

These weapons are entirely replaced, and will not work with mods that attempt to add reticles or effects to a set list of weapons:

- Predator Cannon
  - Needed to fit more attachments for rebalance features
- 40mm Tracker Cannon
  - Needed to prevent crash on vanilla servers, until Northstar forces `weapon_reparse` when mods are disabled on the main menu.