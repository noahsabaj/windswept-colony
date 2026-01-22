# Windswept Colony RP

A serious roleplay experience set on the mining colony of Zephyrus.

## Setting

The year is 2200. The Confederation of Earthly Governments (CEG) licenses uninhabited
planets to mining corporations. Zephyrus is one such planet - hostile, dangerous, but
rich in resources.

The Conglomerate holds the mining license. They appointed a Head Foreman to run operations.
But the CEG mandates democratic governance - requiring elected positions for Governor,
Security Chief, and Union President.

## The Power Structure

### The Confederation (Server Owner)
- Invisible, rarely intervenes
- Licenses the planet
- Protects civilian rights
- Can oust any official
- Appoints the Head Foreman

### Head Foreman (Appointed, No Term Limit)
- Corporate representative
- "Technically" in charge
- Appoints corporate staff
- Will they be obeyed?

### The Triad (Elected, 3-Week Terms)

| Position | Role | Appoints |
|----------|------|----------|
| Governor | Political leader | Deputy, Judge, Quartermaster, etc. |
| Security Chief | Police commander | Officers, Sergeants, Deputies |
| Union President | Workers' voice | Shop Stewards |

### Civilians (Default Faction)
- Everyone starts here
- They vote in elections
- They labor
- They survive

## Conflict Matrix

- **Foreman vs Governor**: Production vs popularity
- **Foreman vs Security**: Corporate policy vs elected loyalty  
- **Foreman vs Union**: Profit vs worker rights
- **Governor vs Security**: Laws vs guns
- **Governor vs Union**: Stability vs worker demands
- **Security vs Union**: Protection vs suppression

## Map

Gm_Windswept by Grey The Raptor
- Underground city
- Surface danger (windstorms every ~12 minutes)
- Prison, caves, sewers, slums
- Disable wind: `ent_fire timer_windevent disable`

## Elections

- 3-week terms
- Unlimited re-election (Confederation reserves right to change)
- All civilians (only union workers can vote for union president) can vote
- Governor, Security Chief, and Union President elected separately

## Installation

1. Ensure Helix framework is installed in `garrysmod/gamemodes/helix`
2. Place this schema folder in `garrysmod/gamemodes/windswept`
3. Set gamemode: `+gamemode windswept +map gm_windswept`
4. Subscribe to Gm_Windswept on Workshop

## Credits

- Schema by kwabaj
- Map by Grey The Raptor
- Framework: Helix (NebulousCloud)
