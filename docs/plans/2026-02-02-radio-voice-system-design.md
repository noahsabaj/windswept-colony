# Radio Voice System Design

## Overview

Upgrade the handheld radio to support voice transmission over frequencies, battery power, and volume control. Also remove the default GMod voice HUD for anti-metagaming, and implement voice amplitude-based distance scaling for all voice chat.

## Features

### 1. New Radio Model

**Current:** `models/deadbodies/dead_male_civilian_radio.mdl` (broken/error)

**New:**
- World/inventory model: `models/radio/w_radio.mdl`
- Workshop ID: 635535045 (add to resource.AddWorkshop)

Item remains inventory-only (no SWEP required). Toggle on/off from inventory menu.

### 2. Battery Powered Radio

Radio extends `base_battery_device` with 1 battery slot.

**Drain rates:**

| State | Drain Rate | Time on Full Battery |
|-------|------------|----------------------|
| Idle (radio on, no activity) | 0.033 up/sec | ~50 minutes |
| Active (transmitting or receiving) | 0.056 up/sec | ~30 minutes |

**Behavior:**
- Radio requires loaded battery to function (receive or transmit)
- Battery drains continuously while radio is ON (idle drain)
- Battery drains faster during active transmission or reception
- When battery depletes, radio turns off automatically

**Text radio drain (modality equivalence):**

Text and voice are equivalent - same battery cost for fairness (text is for players without mics).

Speaking time estimated at 15 characters/second:
```lua
speakingTime = string.len(message) / 15
batteryDrain = speakingTime * 0.056
```

Examples:
- "Affirmative" (11 chars) → 0.73 sec → 0.041 up
- "Copy that, moving to position" (29 chars) → 1.9 sec → 0.11 up

Both sender AND receivers drain battery for text messages.

### 3. Voice Radio Transmission

**Keybind:** Hold H to transmit voice over radio frequency

**Requirements to transmit:**
- Radio is in inventory and enabled (toggled on)
- Radio has battery with charge
- Player is NOT: knocked out, gagged, restrained/zip-tied, or dead

**Requirements to receive:**
- Radio is in inventory and enabled (toggled on)
- Radio has battery with charge
- (No restrictions on player state - radio works even if knocked/gagged/restrained/dead)

**Who hears the transmission:**
1. All players with radio ON + same frequency (regardless of physical distance)
2. Eavesdroppers: players physically near any receiver (see eavesdrop mechanics)

### 4. Volume Control

New right-click menu option: "Set Volume" (0-100 slider)

**Volume affects:**
- How loud YOU hear incoming transmissions (0 = silent, 100 = full volume)
- Eavesdrop range around you (see formula below)

**Default volume:** 50

### 5. Eavesdrop Mechanics

When a transmission comes through a receiver's radio, nearby players can hear it.

**Eavesdrop range formula:**
```
eavesdropRange = BASE_RANGE * (receiverVolume / 100) * transmitterAmplitude
```

Where:
- `BASE_RANGE` = 400 units (tunable)
- `receiverVolume` = 0-100 (receiver's volume setting)
- `transmitterAmplitude` = 0-1 (how loud transmitter is speaking into mic)

**Examples:**
- Receiver volume 100, transmitter yelling (1.0): 400 * 1.0 * 1.0 = 400 units
- Receiver volume 50, transmitter normal (0.5): 400 * 0.5 * 0.5 = 100 units
- Receiver volume 10, transmitter whispering (0.2): 400 * 0.1 * 0.2 = 8 units

**Multiple receivers nearby:**
If multiple receivers are near an eavesdropper, use the closest receiver's volume (don't double audio).

### 6. Incapacitated States (Knocked/Gagged/Restrained/Dead)

**Receiving:** Radio continues working in all states. The radio is a device - it doesn't care if the owner is unconscious, gagged, restrained, or dead. As long as it has battery and is toggled on, it receives.

- Knocked out body's radio still receives transmissions
- Dead ragdoll's radio (in inventory) still receives
- Gagged/restrained player's radio still receives
- Nearby players can eavesdrop on all these

**Transmitting:** Blocked in all incapacitated states. You cannot speak into a radio if you're knocked out, dead, gagged, or restrained.

### 7. Voice Amplitude Distance Scaling (Global)

Applies to ALL voice chat (proximity and radio eavesdrop).

**Proximity voice range formula:**
```
voiceRange = BASE_VOICE_RANGE * amplitudeMultiplier(voiceVolume)
```

Where `amplitudeMultiplier` maps voice volume to range:
- Whisper (0.0-0.2): 100-150 units
- Normal (0.2-0.5): 150-400 units
- Loud (0.5-0.8): 400-600 units
- Yelling (0.8-1.0): 600-800 units

Uses `Player:VoiceVolume()` to get current amplitude (0-1).

### 8. Remove Voice Chat HUD

Remove the default GMod voice indicator (player name + icon in bottom right when speaking).

**Why:** Anti-metagaming. Players don't magically know who is speaking. They hear a voice and must identify the speaker through roleplay (recognize the voice, see who's talking, etc.).

**Implementation:** Hook `HUDShouldDraw` and block `"CHudVoiceStatus"` or similar voice HUD element.

## Technical Implementation

### Files to Modify

1. **`schema/items/equipment/sh_handheld_radio.lua`**
   - Change base to `base_battery_device`
   - Add volume data field
   - Add "Set Volume" menu function
   - Update model path
   - Add transmission drain logic hooks

2. **`schema/sv_schema.lua`**
   - Add Workshop resource: `resource.AddWorkshop("635535045")`

3. **`schema/cl_hooks.lua`** (or new file)
   - Hide voice HUD element

4. **`schema/sv_hooks.lua`** (or new file)
   - Override `PlayerCanHearPlayersVoice` for radio transmission
   - Implement amplitude-based distance scaling

5. **`schema/sh_schema.lua`**
   - Register radio chat class modifications if needed

### New Network Strings

- `ixRadioVoiceStart` - Client tells server they started transmitting
- `ixRadioVoiceStop` - Client tells server they stopped transmitting
- `ixRadioSetVolume` - Client sets radio volume

### Key Hooks

**`GM:PlayerCanHearPlayersVoice(listener, speaker)`**
- If speaker is transmitting on radio AND listener has radio on same frequency: return true
- Apply amplitude-based distance for proximity voice
- Apply eavesdrop logic for nearby listeners

**`Think` hook (client)**
- Detect H key held + radio enabled + has battery
- Send start/stop transmission messages to server

**`HUDShouldDraw`**
- Return false for voice HUD elements

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Radio dropped while transmitting | Stop transmission, disable radio |
| Radio disabled while transmitting | Stop transmission |
| Battery depletes | Radio turns off, stops all tx/rx |
| Battery depletes mid-transmission | Stop transmission immediately |
| Knocked out while transmitting | Stop transmission, radio keeps receiving |
| Knocked out player's radio | Still receives (eavesdroppers can hear) |
| Gagged player tries to transmit | Blocked, but still receives |
| Restrained player tries to transmit | Blocked, but still receives |
| Dead player's radio | Still receives (on ragdoll inventory) |
| Volume 0 | No audio heard, eavesdrop range = 0 |
| No receivers on frequency | Transmit into void (realistic) |
| sv_voiceenable 0 | Voice radio disabled, text radio works |
| Multiple receivers near eavesdropper | Use closest receiver's volume |

## Text Radio (Unchanged)

The existing `/r` and `/radio` commands remain unchanged. Text radio and voice radio coexist:
- `/r Hello` sends text to frequency
- Hold H sends voice to frequency

Both have the same eavesdrop mechanic (nearby players hear/see it).

## Future Considerations (Not In Scope)

- Radio static/processing effects on voice
- Different radio models (long-range, short-range)
- Radio channels beyond frequency (encrypted channels, etc.)
- Visual indicator on player model when transmitting (antenna light, etc.)
