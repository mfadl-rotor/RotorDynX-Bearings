# RotorDynX Bearings 1.0.0

First public release of RotorDynX Bearings.

## Included
- Unified hydrodynamic journal-bearing solver
- Plain journal bearing
- Elliptical / two-lobe bearing
- Three-lobe bearing
- Three-axial-groove bearing
- Tapered-land bearing
- Pressure-dam bearing
- Worn-bearing model
- Tilting-pad journal bearing (TPJB)
- Spherical-pivot TPJB formulation
- Static equilibrium and pressure-field calculations
- Performance quantities and dimensionless results
- Direct perturbed-Reynolds stiffness and damping calculation
- MATLAB graphical interface

## TPJB validation note
The spherical-pivot TPJB static solver is operational. The spherical-pivot
dynamic coefficient formulation is implemented and remains under external
benchmark validation.

## MATLAB
The solver backend is written as a MATLAB script with local functions.
The graphical application requires a MATLAB release supporting `uifigure`
and related UI components.

## Running the software

### Graphical interface
Run:

```matlab
RotorDynX_Bearings_App
```

### Solver directly
Open `RotorDynX_Bearings.m`, set the bearing type, operating conditions and
analysis options in the user-control section, then run the script.

## Packaging note
This public package was prepared from the current production solver branch.
Development-only paths, superseded filenames and temporary release labels
were removed. Numerical solver equations were not altered during packaging.
