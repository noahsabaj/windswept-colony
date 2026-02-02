# Stationary Radio (Dispatch Console) Design

## Overview

A placeable multi-channel radio console for dispatch operations. Unlike the handheld radio (single frequency, battery powered), the stationary radio supports 4 simultaneous channels, wired power, and acts as a fixed audio pickup/broadcast point in the world.

## Features

### 1. Model

**Model:** `models/props_lab/citizenradio.mdl` (HL2 citizen radio)

This is a built-in HL2 model - no Workshop addon required.

### 2. Multi-Channel Support

4 independent channels, each with:
- **Frequency**: 100.0 - 999.9 (###.# format)
- **TX toggle**: Enable/disable transmitting on this channel
- **RX toggle**: Enable/disable receiving on this channel
- **Volume**: 0-100 (affects how loud you hear incoming on this channel)

**Default state**: All channels set to 100.0, TX off, RX off, Volume 50.

### 3. Wired Power

No battery required. The stationary radio is always powered when placed in the world. The item form (in inventory) is inert - must be placed to function.

### 4. Placement & Pickup

**Placement:**
1. Right-click item in inventory → "Drop" (standard Helix)
2. Pick up with hands to position and orient
3. Once positioned, press E to open config UI

**Pickup:**
- Hold E (standard Helix `itemPickupTime`) to pick back up into inventory
- Channel configurations persist on the item

### 5. User Interface

Single-user access - only one player can have the UI open at a time.

```
┌─────────────────────────────────────────────────────────────────┐
│  DISPATCH CONSOLE                                          [X]  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  CH1  [◄] 100.0 [►]  [TX: ON ]  [RX: ON ]  VOL ════●════════   │
│  CH2  [◄] 150.5 [►]  [TX: OFF]  [RX: ON ]  VOL ═══════●═════   │
│  CH3  [◄] 200.0 [►]  [TX: OFF]  [RX: OFF]  VOL ══════════●══   │
│  CH4  [◄] 100.0 [►]  [TX: OFF]  [RX: OFF]  VOL ●════════════   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Type message here...                                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                            [TRANSMIT] [MIC: OFF]│
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Frequency control**: Left/right arrow buttons increment/decrement by 0.1. Click and hold for rapid change.

**TX/RX toggles**: Click to toggle. Visual feedback: gray = off, colored = on.

**Volume slider**: Horizontal slider 0-100 per channel.

**Text input**: Type message, click TRANSMIT or press Enter to broadcast.

**MIC toggle**: Open mic mode - when ON, voice continuously transmits.

### 6. Voice Transmission

**Open Mic Mode (MIC: ON):**
- Player at console is added to `Schema.radioTransmitters`
- All sound reaching the entity's world position is broadcast
- Broadcasts to ALL frequencies with TX enabled
- Nearby gunshots, people talking, ambient noise - all transmitted

**Push-to-talk:** Not implemented for stationary radio. Use MIC toggle or text.

**Sound Pickup:**
The stationary radio acts as a "virtual ear" at its world position:
- Uses the entity's position for voice range calculations
- If someone speaks within voice range of the entity AND MIC is ON, their voice is transmitted
- This includes the player at the console and anyone nearby

### 7. Voice Reception

**Receiving voice:**
- Player at console hears voice from all RX-enabled channels
- Each channel's volume setting scales that channel's audio
- Multiple channels mix together (GMod handles audio mixing)

**Eavesdrop from stationary radio:**
Players near the stationary radio can hear incoming transmissions:
```
eavesdropRange = 400 * (channelVolume / 100) * transmitterAmplitude
```

### 8. Text Transmission

**Sending:**
- Type message in text field
- Click TRANSMIT or press Enter
- Message broadcasts to ALL frequencies with TX enabled
- Uses existing `radio` chat class

**Receiving:**
- Messages on RX-enabled frequencies appear in player's chat
- Clean format (no channel prefix): `John radios in: "Message here"`
- Players establish their own RP protocols for identification

### 9. Single User Access

Only one player can use the console at a time:
- Press E while another player has UI open → "Console in use" notification
- When player closes UI or walks away, console becomes available
- Walking too far from console (>200 units) auto-closes UI

## Technical Implementation

### Files to Create

1. **`schema/libs/sh_radio.lua`** - Shared radio utilities
   - `ix.radio.ValidateFrequency(freq)` - Returns true if valid ###.# format
   - `ix.radio.FormatFrequency(freq)` - Ensures proper formatting
   - `ix.radio.FREQ_MIN = 100.0`
   - `ix.radio.FREQ_MAX = 999.9`

2. **`schema/items/equipment/sh_stationary_radio.lua`** - The item
   - Standard Helix item (droppable)
   - Stores channel data in item data
   - On drop, spawns `ix_stationary_radio` entity

3. **`entities/entities/ix_stationary_radio/shared.lua`** - Shared entity
   - ENT.Type = "anim"
   - ENT.PrintName = "Stationary Radio"

4. **`entities/entities/ix_stationary_radio/init.lua`** - Server entity
   - SetupDataTables for 4 channels (freq, tx, rx, vol each)
   - Use handling (open UI vs pickup)
   - Track current user
   - Voice transmitter registration

5. **`entities/entities/ix_stationary_radio/cl_init.lua`** - Client entity + UI
   - Render model
   - Derma UI panel (ixStationaryRadio)
   - Net message handling

### Files to Modify

1. **`schema/sh_schema.lua`**
   - Add: `ix.util.Include("libs/sh_radio.lua")`

2. **`schema/sv_hooks.lua`**
   - Update `PlayerCanHearPlayersVoice` to handle stationary radio transmitters
   - Add stationary radio entity as potential "listener" for voice pickup

3. **`schema/sv_netstrings.lua`**
   - Add: ixStationaryRadioOpen, ixStationaryRadioClose
   - Add: ixStationaryRadioConfig, ixStationaryRadioTransmit
   - Add: ixStationaryRadioMic

4. **`schema/languages/sh_english.lua`**
   - Add: stationaryRadioInUse, stationaryRadioTooFar

### Network Strings

| String | Direction | Purpose |
|--------|-----------|---------|
| ixStationaryRadioOpen | S→C | Tell client to open UI for entity |
| ixStationaryRadioClose | C→S | Client closed UI |
| ixStationaryRadioConfig | C→S | Client changed channel config |
| ixStationaryRadioTransmit | C→S | Client sent text message |
| ixStationaryRadioMic | C→S | Client toggled MIC on/off |

### Entity NetworkVars

```lua
function ENT:SetupDataTables()
    -- Current user (0 if none)
    self:NetworkVar("Entity", 0, "User")

    -- 4 channels x 4 properties = 16 vars
    for i = 1, 4 do
        self:NetworkVar("String", i - 1, "Ch" .. i .. "Freq")     -- "100.0"
        self:NetworkVar("Bool", (i - 1) * 2, "Ch" .. i .. "TX")   -- true/false
        self:NetworkVar("Bool", (i - 1) * 2 + 1, "Ch" .. i .. "RX") -- true/false
        self:NetworkVar("Int", i - 1, "Ch" .. i .. "Vol")         -- 0-100
    end
end
```

### Voice Integration

**Transmitter registration:**
When MIC is ON, add entry to `Schema.radioTransmitters`:
```lua
Schema.radioTransmitters[entity] = {
    frequencies = {"100.0", "200.0"},  -- All TX-enabled frequencies
    entity = entity,                    -- The stationary radio entity
    isStationary = true                 -- Flag for special handling
}
```

**PlayerCanHearPlayersVoice modifications:**
```lua
-- Check if speaker is near any stationary radio with MIC on
for ent, data in pairs(Schema.radioTransmitters) do
    if data.isStationary then
        local distSqr = speaker:GetPos():DistToSqr(ent:GetPos())
        local voiceRange = GetAmplitudeRange(Schema.voiceAmplitudes[speaker] or 0)
        if distSqr <= voiceRange * voiceRange then
            -- Speaker is within range of stationary radio
            -- Route their voice to all TX frequencies
        end
    end
end
```

### Item Data Structure

```lua
item:SetData("channels", {
    {freq = "100.0", tx = false, rx = false, vol = 50},
    {freq = "100.0", tx = false, rx = false, vol = 50},
    {freq = "100.0", tx = false, rx = false, vol = 50},
    {freq = "100.0", tx = false, rx = false, vol = 50}
})
```

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Player walks away from console | UI auto-closes at 200 units |
| Player dies at console | UI closes, console becomes available |
| Console picked up while in use | UI closes for user, item goes to picker's inventory |
| All TX channels off + MIC on | MIC has no effect (nothing to transmit to) |
| All RX channels off | No incoming audio |
| Volume 0 on channel | That channel is silent, eavesdrop range = 0 |
| Same frequency on multiple channels | Redundant but allowed |
| Text transmit with no TX enabled | "No transmit channels enabled" notification |

## Relationship to Handheld Radio

Both radios use shared utilities from `libs/sh_radio.lua`:
- Frequency validation
- Radio chat class

**Key differences:**

| Feature | Handheld | Stationary |
|---------|----------|------------|
| Channels | 1 | 4 |
| Power | Battery | Wired |
| Mobility | Inventory item | Placed entity |
| Voice TX | Hold H key | MIC toggle |
| Volume | Single setting | Per-channel |
| TX/RX | Implicit (on = both) | Explicit toggles |
