# Windswept Colony RP

**Windswept Colony RP** is the flagship roleplay schema (the game) built on the [Windswept framework](https://github.com/noahsabaj/windswept) — a hardcore, diegetic **colony-survival** RP set on the mining colony of **Redrock**.

> *"A serious roleplay experience on the mining colony of Redrock."*

It derives from the framework and boots as its own gamemode:

```lua
DeriveGamemode("windswept")   -- gamemode id: windsweptrp
```

## Setting

Redrock is a mining colony worked under the **Eagle Extraction Conglomerate** and administered by the **Colonial Administration**, under the distant **Confederation of Earthly Governments**. The ore goes up the chain — 70% to the corporation, 30% to the administration — and the colonists live in what's left.

## Design pillars

- **Conservation of matter — nothing appears from nowhere.** Every item is found, crafted, or physically present. Money is physical cash and coins; light is battery charge; writing consumes ink. Resources *move*; they're never duplicated (enforced by the framework's atomic `ws.resource` primitives).
- **Anti-metagaming / fog-of-war — information is physical.** The UI never shows the character something they couldn't know: a neutral, colorblind-friendly interface with faction colors off, and identity established in-character (signatures, documents) rather than printed on the HUD.
- **Built factionless.** It leans on the framework's faction-optional design — everyone is a colonist; standing is earned and roleplayed, not handed out by a faction tag.

## Requirements

- The [Windswept framework](https://github.com/noahsabaj/windswept) — this schema `DeriveGamemode("windswept")`s it, so the framework gamemode must be installed alongside it.
- Steam Workshop content the schema depends on (player models, weapon bases, props, etc.) is declared via `resource.AddWorkshop` in `schema/sv_schema.lua` and the relevant item/plugin files — subscribe to / host these so clients download them.

## Acknowledgements

Built on the [Windswept framework](https://github.com/noahsabaj/windswept); see the framework repo for its lineage (a fork of Helix, itself derived from NutScript).
