# Changelog

All notable changes to **RotorDynX Bearings** are documented here.

RotorDynX was developed progressively, with each bearing family added and validated as a separate engineering module before being integrated into the unified solver.

---

## [Unreleased]

### In progress
- External benchmark validation of spherical-pivot TPJB dynamic coefficients
- Independent finite-difference verification of TPJB stiffness and damping
- Additional published benchmark cases
- Expanded example library and validation documentation
- Improved automated benchmark reporting

---

# Bearing Development History

## Plain Journal Bearing

The first RotorDynX bearing model was the conventional plain hydrodynamic journal bearing.

### Added
- Finite-difference Reynolds-equation solver
- Journal static equilibrium
- Pressure-field calculation
- Oil-film reaction forces
- Eccentricity ratio
- Attitude angle
- Minimum film thickness
- Maximum pressure
- Flow calculation
- Friction and power-loss calculation
- Dimensionless operating parameters

### Dynamic analysis
- Initial finite-difference stiffness and damping extraction
- Direct and cross-coupled K/C coefficients
- Later upgraded to the direct perturbed-Reynolds formulation

The plain-bearing module became the numerical foundation for the later bearing families.

---

## Elliptical / Two-Lobe Bearing

The next geometry introduced was the preloaded two-lobe or elliptical bearing.

### Added
- Fixed-lobe geometry framework
- Two-pad bearing representation
- Preload definition
- Pad-center geometry
- Separate upper and lower lobe film-thickness calculation
- Generalized fixed-lobe pressure solution

### Development reference
Early development cases used a two-pad configuration with preload-based geometry, including representative cases around:

- preload `m = 0.5`
- pivot/lobe angular fraction `alpha = 0.5`

### Improved
- Unified geometry generation
- Force projection from individual lobes
- Static equilibrium for multi-lobe bearings
- Dynamic coefficient calculation using the common RotorDynX framework

---

## Three-Lobe Journal Bearing

The fixed-lobe engine was then extended to three-pad preloaded bearings.

### Added
- Three-lobe geometry generation
- Three individual hydrodynamic pressure regions
- Preloaded multi-lobe film geometry
- Combined force and moment post-processing
- Static and dynamic analysis through the unified solver

### Classification
Three-pad bearings with:

`m > 0`

are identified as:

**Three-Lobe Journal Bearing**

### Improved
- Pad indexing
- Load-angle handling
- Multi-lobe pressure integration
- K/C coefficient consistency

---

## Three-Axial-Groove Bearing

The same multi-pad framework was extended to zero-preload three-pad bearings representing a three-axial-groove configuration.

### Classification
Three-pad bearings with:

`m = 0`

are identified as:

**Three-Axial-Groove Bearing**

### Added
- Axial-groove bearing geometry
- Three separated hydrodynamic regions
- Groove boundary treatment
- Static equilibrium
- Dynamic coefficient calculation

### Fixed
- Bearing-name classification logic was corrected so that:
  - preloaded 3-pad geometry → Three-Lobe Journal Bearing
  - zero-preload 3-pad geometry → Three-Axial-Groove Bearing

---

## Tapered-Land Bearing

A dedicated tapered-land bearing module was then developed.

### Added
- Circumferential tapered-land geometry
- Trailing-land region
- Optional axial side lands
- Piecewise film-thickness definition
- Dedicated pressure-field solution
- Force, flow and power post-processing
- Dynamic coefficient calculation

### Improved
- Transition between tapered and land regions
- Geometry masks
- Boundary-condition handling
- Integration of the module into the unified RotorDynX interface

---

## Pressure-Dam Bearing

The pressure-dam bearing was developed as an independent geometry rather than treating it as a minor modification of the plain bearing.

### Added
- Independent two-pad pressure-dam reconstruction
- Constant-depth top-pad dam pocket
- Axial side dams
- Optional lower-pad relief track
- CENTER and SIDE lower-relief configurations
- Fixed-pressure relief boundaries
- Dedicated leakage reporting
- Static and dynamic calculations

### Validation development
The module progressed through multiple benchmark cases.

Important development work included:

- correction of the Case 2 K/C benchmark implementation
- published-example verification
- separate leakage-path reporting
- progression through benchmark Cases 3, 4 and 5
- review of relief-boundary treatment

### Status
The pressure-dam static and K/C implementation reached a working benchmark state, while individual benchmark assumptions continued to be reviewed against published definitions.

---

## Worn Bearing

A dedicated worn-bearing family was then introduced.

### Initial implementation
The first worn-bearing implementation used a constant-depth worn pocket.

### [v3.22]
- Added published worn-pocket benchmark case
- Independent two-axial-groove worn-bearing family
- Added worn-region geometry handling
- Integrated static and dynamic analysis into the unified solver

### [v3.23]
The worn geometry was revised from the earlier constant-depth approximation to a smooth circular worn arc.

### Added / corrected
- Circular-arc wear profile derived from wear depth and wear arc
- Removal of the previous constant-depth wear step
- Smoother film-thickness transition
- Published Section 3.8 benchmark implementation
- Improved dynamic sensitivity treatment

### Dynamic improvements
- Exact low-Re laminar recovery
- Turbulent-mobility derivative included in the perturbed-Reynolds K/C formulation

---

# Core Solver Development

## [v3.12] - Direct Perturbed-Reynolds Dynamic Coefficients

A major solver change was made when RotorDynX moved from repeated nonlinear finite-difference perturbation toward a direct linearized Reynolds formulation.

### Added
- Direct perturbed-Reynolds K/C solver
- Sparse dynamic pressure-sensitivity equations
- Four journal perturbation sensitivity solutions
- Common Reynolds operator
- Cached matrix/factorization
- Frozen equilibrium viscosity during perturbation
- Frozen cavitation active region during first-order perturbation

### Retained
- Finite-difference K/C calculation as an independent QA method

### Performance
Representative direct dynamic calculations were reduced to approximately:

`0.18 - 0.26 s`

during development cases.

### Improved
- Repeatability of K/C extraction
- Separation between equilibrium and perturbation calculations
- Dynamic solver speed
- Numerical consistency

---

## [v3.13] - Turbulence and Bearing Classification Update

### Added
- Constantinescu turbulence formulation
- Reynolds-number-dependent circumferential mobility
- Reynolds-number-dependent axial mobility
- Turbulence correction in Couette shear
- Turbulence-compatible perturbed-Reynolds treatment

### Fixed
- Three-lobe / three-axial-groove classification

### Reference development case
A representative three-lobe calculation produced approximately:

- eccentricity ratio: 0.253
- attitude angle: 29.2 deg
- maximum pressure: 6.78 MPa
- flow: 7.63 L/min

These values were retained as an internal development reference rather than a universal benchmark.

---

# Tilting-Pad Journal Bearing Development

The TPJB solver was developed as a separate bearing engine because the pad rotational equilibrium and dynamic condensation require a different numerical structure from fixed-geometry bearings.

---

## [TPJB v0.2] - Initial TPJB Framework

### Added
- Multi-pad TPJB geometry
- Pad leading edge, pivot and trailing edge definition
- Pad preload
- Pivot offset
- Individual pad Reynolds solution
- Initial pad tilt calculation
- Initial TPJB result structures

---

## [TPJB v0.3 - v0.6] - Pad Equilibrium Development

### Added
- Individual pad load calculation
- Pad pressure fields
- Pad moment integration
- Journal force summation
- Initial nested journal/pad equilibrium

### Improved
- Loaded-pad root selection
- Pad initialization
- Pad indexing
- Static convergence behavior

### Fixed
- Struct initialization issues
- Selection of non-trivial pad equilibrium roots
- Idle and lightly-loaded pad root behavior

---

## [TPJB v0.7] - Power Integration Correction

### Fixed
- TPJB friction-power calculation

The earlier implementation was replaced by full two-dimensional trapezoidal wall-shear integration over the pad surface.

This removed an inconsistency in the earlier power calculation.

---

## [TPJB v0.8 - v0.9A] - Strict Static Equilibrium

### Improved
- Journal force convergence
- Individual pad moment convergence
- Active-pad logic
- Pad-root search robustness

### [v0.9A]
Introduced a stricter nested equilibrium requirement:

- journal force equilibrium
- individual pad moment equilibrium
- tighter convergence reporting

This became the basis for the production static TPJB solver.

---

## [TPJB v0.11] - Direct Perturbed-Reynolds TPJB Dynamics

### Added
- Direct dynamic pressure sensitivities for TPJBs
- Journal displacement perturbations
- Journal velocity perturbations
- Reuse of the steady Reynolds operator
- Dynamic pad-force and moment sensitivities

This replaced repeated full nonlinear perturbation runs for production dynamic calculations.

---

## [TPJB v0.12] - Coupled Massless-Pad K/C Condensation

### Added
- Coupled journal/pad dynamic formulation
- Massless-pad condensation
- Pad rotational stiffness coupling
- Pad rotational damping coupling
- Equivalent journal 2 × 2 stiffness matrix
- Equivalent journal 2 × 2 damping matrix

This allowed the TPJB to be represented directly in rotor-bearing dynamic models.

---

## [TPJB v1.1] - Production TPJB Solver

### Added
- Production workflow
- Unified static, performance and dynamic result structure
- Production mesh settings
- Improved runtime reporting
- Dimensionless TPJB results
- Improved console output
- Robust active-pad detection

### Improved
- Warm-started pad-root searches
- Full-scan fallback
- Static and dynamic workflow separation
- Dynamic cache construction
- Result consistency checks

---

## [TPJB v1.1A] - Dimensionless Result Correction

### Improved
- Dimensionless coefficient reporting
- Dimensionless stiffness normalization
- Dimensionless damping normalization
- Output consistency

---

## [TPJB v1.2] - Faster TPJB Dynamic Solver

### Improved
- Cached dynamic Reynolds operator/factorization
- Reduced repeated matrix construction
- Faster direct K/C sensitivity calculations
- More efficient production workflow

---

## [TPJB v1.3] - Faster Static Equilibrium

### Improved
- Warm-started static pad roots
- Local pad-root tracking
- Full-scan fallback only when required
- Reduced static-equilibrium runtime
- Better production solver diagnostics

---

## [TPJB v1.4] - Spherical-Pivot TPJB

### Added
- Spherical-pivot formulation
- Two rotational pad degrees of freedom:
  - circumferential tilt
  - axial tilt
- Static circumferential moment condition
- Static axial moment condition
- Coupled `alpha + beta` dynamic pad coordinates
- Spherical-pivot dynamic condensation

### Production static conditions
For every active pad:

`M_circ = 0`

and

`M_axial = 0`

while the journal satisfies the applied bearing-load equilibrium.

### Dynamic solver
- Direct perturbed Reynolds
- Coupled massless-pad K/C condensation
- Cached operator/factorization
- Frozen steady positive-pressure region
- Matrix conditioning checks

### Added output
- Circumferential pad tilt
- Axial pad tilt
- Circumferential pad moment
- Axial pad moment
- Pivot film thickness
- Dynamic matrix conditioning
- Direct/cross coefficient ratios
- Detailed TPJB computation timing

### Current status
- Static spherical-pivot implementation: operational
- Dynamic spherical-pivot implementation: operational
- External K/C benchmark validation: in progress

---

# Current Bearing Families

RotorDynX currently contains the following bearing families:

| Bearing family | Geometry model | Static | Dynamic K/C |
|---|---|---:|---:|
| Plain journal | Fixed geometry | Yes | Yes |
| Elliptical / two-lobe | FixedLobe | Yes | Yes |
| Three-lobe | FixedLobe | Yes | Yes |
| Three-axial-groove | FixedLobe, zero preload | Yes | Yes |
| Tapered-land | Dedicated geometry | Yes | Yes |
| Pressure-dam | Dedicated geometry | Yes | Yes |
| Worn bearing | Dedicated worn geometry | Yes | Yes |
| Tilting-pad journal bearing | Independent TPJB engine | Yes | Yes |
| Spherical-pivot TPJB | TPJB with 2 pad rotational DOF | Yes | Under external validation |

---

# Validation Philosophy

RotorDynX validation is based on several independent checks rather than agreement with a single software package.

The validation process includes:

- force-equilibrium checks
- pad-moment equilibrium checks
- mesh-convergence studies
- dimensional consistency
- dimensionless consistency
- finite-difference verification
- direct perturbed-Reynolds comparison
- published benchmark cases
- comparison with independent engineering tools
- comparison with commercial bearing/rotordynamic software where model assumptions are known

Before comparing two bearing programs, the following definitions must be checked:

- radial or diametral clearance
- assembled or machined clearance
- preload convention
- pad/lobe indexing
- load-angle convention
- pivot convention
- cavitation treatment
- viscosity model
- turbulence model
- pressure boundary conditions
- active-pad treatment
- coordinate convention
- K/C sign convention
- dimensional normalization

---

## Versioning note

RotorDynX was developed rapidly and many intermediate solver revisions were engineering development builds rather than formal public releases.

This changelog therefore records known numerical and bearing-development milestones without assigning dates or release numbers that were not formally used.
