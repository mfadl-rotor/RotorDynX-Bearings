<img width="512" height="512" alt="RotorDynX_logo_icon" src="https://github.com/user-attachments/assets/72dd6a55-9bd7-40c4-80c4-ef56788662d6" />


# RotorDynX Bearings

**RotorDynX Bearings** is a MATLAB-based hydrodynamic bearing analysis tool developed for the static and dynamic analysis of journal bearings and tilting-pad journal bearings (TPJBs).

The software is intended for rotordynamics, bearing-performance studies, research, engineering development, and comparison against analytical, published, and commercial-code benchmarks.

> **Current development focus:** spherical-pivot tilting-pad journal bearings with coupled circumferential and axial pad tilt.

---

## Features

RotorDynX currently includes a unified hydrodynamic bearing-analysis framework with capabilities such as:

- Hydrodynamic Reynolds-equation solution
- Static journal equilibrium
- Bearing load and attitude-angle prediction
- Full pressure-field calculation
- Minimum film-thickness calculation
- Maximum film pressure
- Bearing friction and power-loss calculation
- Dimensionless bearing-performance parameters
- Direct calculation of dynamic stiffness and damping coefficients
- Isothermal bearing analysis
- Multiple bearing geometries through a unified workflow
- Production and validation calculation modes

---

## Tilting-Pad Journal Bearing Solver

The TPJB engine includes:

- Multi-pad bearing geometry
- Load-between-pads (LBP) and load-on-pad configurations
- Pad preload
- Pivot offset
- Individual pad pressure solutions
- Individual pad load calculation
- Pad rotational equilibrium
- Journal static equilibrium
- Active-pad detection
- Spherical-pivot formulation
- Circumferential pad tilt
- Axial pad tilt
- Coupled journal/pad dynamic formulation
- Massless-pad dynamic condensation
- Direct perturbed-Reynolds stiffness and damping calculation

For spherical pivots, each pad may include two rotational degrees of freedom:

$$
\alpha_i = \text{circumferential pad tilt}
$$

$$
\beta_i = \text{axial pad tilt}
$$

The static equilibrium conditions are solved from:

$$
F_x = F_{x,\mathrm{required}}
$$

$$
F_y = F_{y,\mathrm{required}}
$$

together with the individual pad moment conditions:

$$
M_{\alpha,i}=0
$$

$$
M_{\beta,i}=0
$$

for every active pad.

---

## Dynamic Coefficients

RotorDynX calculates the linearized bearing force coefficients using the standard linearized force model:

$$
F_x = -(K_{xx}x + K_{xy}y + C_{xx}\dot{x} + C_{xy}\dot{y})
$$

$$
F_y = -(K_{yx}x + K_{yy}y + C_{yx}\dot{x} + C_{yy}\dot{y})
$$

where:

- $K_{xx},K_{yy}$ are direct stiffness coefficients
- $K_{xy},K_{yx}$ are cross-coupled stiffness coefficients
- $C_{xx},C_{yy}$ are direct damping coefficients
- $C_{xy},C_{yx}$ are cross-coupled damping coefficients

For TPJBs, pad degrees of freedom are condensed from the coupled journal-pad dynamic system to obtain an equivalent $2 \times 2$ bearing stiffness and damping representation suitable for rotordynamic models.

---

## Numerical Method

The solver uses a finite-difference discretization of the Reynolds equation over the bearing film.

The TPJB solution is performed using a nested equilibrium strategy:

1. Assume a journal position.
2. Solve the Reynolds equation for each pad.
3. Adjust pad tilt until pad moment equilibrium is satisfied.
4. Sum pad reactions.
5. Adjust journal position until the applied load is balanced.
6. Calculate final bearing-performance quantities.
7. Linearize the Reynolds equation around the converged operating point.
8. Condense pad dynamic degrees of freedom.
9. Return equivalent journal stiffness and damping matrices.

The production solver also uses warm-started local pad-root searches with full-scan fallback where required.

---

## Example TPJB Case

Example operating condition:

| Parameter | Value |
|---|---:|
| Journal diameter | 76.200 mm |
| Bearing length | 50.800 mm |
| Assembled radial clearance | 76.500 µm |
| Machined clearance | 123.987 µm |
| Preload | 0.383 |
| Number of pads | 4 |
| Pad arc | 72° |
| Pivot offset | 0.500 |
| Pivot type | Spherical |
| Speed | 3500 rpm |
| Load | 1027.54 N |
| Lubricant viscosity | 0.0187 Pa·s |

Example converged static solution:

```text
Eccentricity ratio       = 0.330054
Journal center Y         = -25.249 um
Minimum film thickness   = 49.973 um
Maximum pressure         = 0.9490 MPa
Maximum pivot load       = 955.299 N
Total friction power     = 0.4933 kW
```

Example equivalent dynamic coefficients:

```text
Kxx = 5.107179e+07 N/m
Kxy = -3.712835e+00 N/m
Kyx = -3.712835e+00 N/m
Kyy = 5.107179e+07 N/m

Cxx = 9.074004e+04 N·s/m
Cxy = 7.638561e-03 N·s/m
Cyx = 7.638562e-03 N·s/m
Cyy = 9.074004e+04 N·s/m
```

These values are provided as an example of the current solver output and should not be interpreted as a universal validation case.

---

## Dimensionless Results

RotorDynX also reports dimensionless bearing parameters, including:

- $L/D$
- Relative clearance $C_b/R$
- Sommerfeld number
- $h_\mathrm{min}/C_b$
- $P_\mathrm{max}/\bar{P}$
- Dimensionless stiffness
- Dimensionless damping

One convention currently used is:

$$
K^*=\frac{K C_b}{W}
$$

and

$$
C^*=\frac{C C_b \omega}{W}
$$

where:

- $C_b$ = assembled radial clearance
- $W$ = bearing load
- $\omega$ = shaft angular speed

---

## Validation Philosophy

RotorDynX is under active development.

Validation is performed using several independent approaches:

- Internal force and moment equilibrium checks
- Mesh-convergence studies
- Dimensional and dimensionless consistency checks
- Finite-difference verification of dynamic coefficients
- Comparison with published bearing solutions
- Comparison with independent engineering software and spreadsheet tools
- Comparison with commercial rotordynamic/bearing-analysis software where suitable benchmark information is available

A difference from another software package does not automatically indicate an error because bearing programs may use different:

- clearance definitions
- preload definitions
- cavitation models
- viscosity models
- turbulence corrections
- pad flexibility assumptions
- pivot models
- coordinate conventions
- dynamic linearization methods
- dimensional normalizations

For this reason, benchmark comparisons should always confirm that the underlying mathematical and physical assumptions are identical.

---

## Current Validation Status

### Static TPJB solver

The static TPJB solver includes:

- journal force equilibrium
- individual pad moment equilibrium
- converged pressure distributions
- pad loads
- minimum film thickness
- maximum pressure
- friction power

The static solver has reached production-level numerical convergence for the current test cases.

### Dynamic TPJB solver

Dynamic stiffness and damping are implemented using direct perturbed Reynolds equations with coupled massless-pad condensation.

The spherical-pivot dynamic formulation is currently considered:

> **Implemented and under external benchmark validation**

Users should therefore independently verify dynamic coefficients before using them for safety-critical or design-certification calculations.

---

## Typical Console Output

```text
============================================================
 ROTORDYNX BEARINGS V1.4 SPHERICAL TPJB
 Unified Hydrodynamic Bearing Solver
============================================================

Selected bearing type : TPJB
Analysis mode         : SINGLEPOINT

STATIC EQUILIBRIUM
Converged              : YES

DYNAMIC STIFFNESS      : AVAILABLE
DYNAMIC DAMPING        : AVAILABLE
THERMAL RESULT         : AVAILABLE
DIMENSIONLESS ANALYSIS : AVAILABLE
```

---

## Requirements

RotorDynX is developed in MATLAB.

Recommended environment:

- MATLAB
- Standard numerical linear-algebra capability
- Sufficient memory for mesh-refinement and parameter-sweep studies

The exact minimum MATLAB release and required toolboxes should be documented after repository compatibility testing.

---

## Getting Started

1. Clone or download the repository.
2. Open the project directory in MATLAB.
3. Add the RotorDynX folders to the MATLAB path.
4. Open the main RotorDynX input or driver script.
5. Select the bearing type and analysis mode.
6. Define geometry, lubricant properties, speed, and load.
7. Run the solver.
8. Review the generated static, dynamic, thermal, and dimensionless results.

Example workflow:

```matlab
% Add RotorDynX to MATLAB path
addpath(genpath(pwd));

% Configure bearing case
% [Define geometry, lubricant, speed, load, and solver options]

% Run RotorDynX using the repository's main driver
% [Insert main function/script name here]
```

> Replace the final line above with the actual repository entry-point function or script name.

---

## Output

The solver returns a unified result structure containing the calculated bearing quantities.

Current production output includes, where applicable:

- journal equilibrium position
- eccentricity ratio
- attitude angle
- fluid reaction forces
- pad tilt angles
- pad loads
- pad moments
- minimum film thickness
- pivot film thickness
- maximum pressure
- friction power
- effective viscosity
- stiffness matrix
- damping matrix
- solver-conditioning checks
- dimensionless results
- computation timing

---

## Engineering Use

RotorDynX is intended for engineering analysis, research, development, and educational use.

Potential applications include:

- rotordynamic model development
- bearing design studies
- troubleshooting bearing behavior
- comparison of bearing geometries
- sensitivity studies
- stiffness and damping generation for rotor models
- TPJB research
- postgraduate research and thesis work

---

## Limitations

Current limitations may include:

- isothermal assumptions for some production calculations
- simplified lubricant-property treatment
- rigid-pad assumptions unless otherwise implemented
- frozen steady positive-pressure-region treatment during some dynamic calculations
- ongoing external validation of spherical-pivot dynamic coefficients
- no guarantee that results reproduce another bearing code unless identical modeling assumptions are used

The user is responsible for verifying applicability to any particular machine or engineering decision.

---

## Roadmap

Planned or ongoing developments may include:

- expanded TPJB benchmark library
- independent finite-difference K/C verification
- thermo-hydrodynamic analysis
- temperature-dependent lubricant properties
- additional pivot models
- pad flexibility
- misalignment
- shaft and bearing structural coupling
- expanded bearing-geometry library
- automated speed/load sweeps
- graphical result visualization
- automated benchmark reports
- integration with full rotor-bearing dynamic models

---

## Disclaimer

RotorDynX is engineering/research software under active development.

The software and its results should not be used as the sole basis for safety-critical machinery decisions without independent engineering verification.

No warranty is provided regarding the accuracy, completeness, or suitability of the software for a particular application.

---

## Contributing

Contributions, benchmark cases, validation data, bug reports, and suggestions are welcome.

When submitting a benchmark, please include as much of the following information as possible:

- bearing geometry
- clearance definition
- preload definition
- pad arc
- pivot offset
- pivot type
- load direction
- shaft speed
- lubricant viscosity
- temperature assumptions
- cavitation treatment
- expected static results
- expected stiffness/damping coefficients
- coefficient sign and coordinate conventions

This helps ensure that comparisons are made on a consistent basis.

---

## Citation

If RotorDynX is used in academic work, a formal citation format should be added once the repository versioning and release structure are finalized.

Suggested temporary format:

```text
RotorDynX Bearings, MATLAB Hydrodynamic Bearing Analysis Software,
GitHub repository, version 1.4.
```

---

## License

A software license should be selected before public distribution.

Common choices include:

- MIT License
- BSD 3-Clause License
- GNU GPLv3

Choose the license that best matches the intended use and contribution model.

---

## Project Status

**Active development**

Current focus:

**Spherical-pivot TPJB static and dynamic validation**
