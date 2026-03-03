# DistrictRobo (Rojo)

## Run
1. Start the sync server:

```bash
rojo serve
```

2. Open your Roblox place in Studio.
3. Connect to the running Rojo project.
4. Press Play.

## Optional Drone Model Asset
- Path: `ReplicatedStorage/Assets/Drones/DroneModel`
- Required: `DroneModel` must be a `Model` with `PrimaryPart` set.
- Behavior:
  - If present, drones spawn from this model.
  - If missing, the game uses the existing placeholder sphere drone automatically.
