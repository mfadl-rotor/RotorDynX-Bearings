# Changelog

All notable changes to **RotorDynX Bearings** are documented in this file.

RotorDynX has evolved through two main development tracks:

- the unified hydrodynamic journal-bearing solver
- the tilting-pad journal-bearing (TPJB) solver

Version entries below reflect confirmed development milestones. Dates are omitted where they were not formally tagged at the time of development.

---

## [Unreleased]

### In progress
- External benchmark validation of spherical-pivot TPJB dynamic coefficients
- Independent finite-difference verification of TPJB stiffness and damping
- Additional published benchmark cases
- Improved validation reporting and automated comparison tables
- Expanded example library and GitHub documentation

---

# TPJB Development

## [TPJB v1.4] - Spherical-Pivot Production Solver

### Added
- Spherical-pivot TPJB formulation
- Two rotational degrees of freedom per pad:
  - circumferential tilt
  - axial tilt
- Coupled pad dynamic coordinates using `alpha + beta`
- Full static moment equilibrium:
  - circumferential pad moment = 0
  - axial pad moment = 0
- Production single-point solver workflow
- Unified result structure through `RotorDynXResult`
- Dimensionless TPJB result reporting
- Solver timing summary
- Dynamic matrix conditioning checks
- Active-pad reporting for dynamic condensation

### Dynamic solver
- Direct perturbed-Reynolds dynamic coefficient calculation
- Coupled massless-pad stiffness and damping condensation
- Cached Reynolds operator/factorization for dynamic sensitivities
- Frozen steady positive-pressure region during perturbation solution
- Equivalent 2 × 2 journal stiffness matrix
- Equivalent 2 × 2 journal damping matrix

### Static solver
- Nested static TPJB equilibrium:
  - inner pad-moment solution
  - outer journal-force equilibrium
- Warm-started local pad-root solution
- Full-scan fallback when local pad-root search is not sufficient
- Force convergence reporting
- Pad-moment residual reporting
- Active-pad load threshold handling

### Output
- Journal eccentricity and attitude
- Journal center position
- Individual pad tilt
- Individual pad load
- Circumferential and axial pad moments
- Minimum film thickness
- Pivot film thickness
- Maximum pressure
- Maximum pad load
- Friction power
- Effective viscosity
- Full K/C matrices
- Dimensionless K/C coefficients
- Runtime breakdown

### Validation status
- Static equilibrium converged to production tolerances for current cases
- Spherical-pivot dynamic formulation implemented
- External dynamic benchmark validation still in progress

---

## [TPJB v1.2] - Coupled Dynamic TPJB Solver

### Added
- Direct perturbed-Reynolds stiffness and damping calculation for TPJBs
- Coupled massless-pad K/C condensation
- Journal/pad dynamic coupling
- Pad-specific preload handling
- Unified RotorDynX plotting workflow

### Improved
- TPJB static equilibrium robustness
- Loaded-pad root detection
- Idle-pad handling
- Numerical stability of pad equilibrium
- Pressure-field storage and post-processing

### Fixed
- Friction-power integration corrected to use two-dimensional trapezoidal wall-shear integration
- Previous power integration inconsistency removed

---

## [TPJB v1.0 - v1.1] - Production Static TPJB Framework

### Added
- Full pad-by-pad Reynolds solution
- Individual pad load calculation
- Pad pressure-field calculation
- Minimum film-thickness calculation
- Pivot film-thickness calculation
- Maximum-pressure calculation
- Static journal equilibrium
- Individual pad moment equilibrium
- LBP and LOP pad arrangements
- Pivot-offset support
- Pad preload support
- Active and lightly-loaded pad handling

### Improved
- Nested equilibrium strategy
- Force-balance convergence
- Pad-root search behavior
- Pad indexing and geometry generation
- Production output formatting

---

## [TPJB v0.2 and early development]

### Added
- Initial tilting-pad bearing geometry
- Initial pad Reynolds solution
- Pad pivot definition
- Preliminary pad-tilt solution
- Initial TPJB result structures

### Fixed
- Struct initialization issues
- Non-trivial loaded-root selection
- Idle-pad root handling
- Pad-equilibrium initialization

### Extended
- Line-pivot support
- Spherical-pivot development path
- Preparation for coupled dynamic degrees of freedom

---

# Unified Journal-Bearing Solver Development

## [v3.13] - Turbulence and Three-Lobe Update

### Added
- Constantinescu turbulence model
- Reynolds-number-dependent circumferential mobility
- Reynolds-number-dependent axial mobility
- Turbulence correction in Couette shear
- Direct-perturbation updates for turbulence-enabled cases

### Improved
- Consistency between static and dynamic turbulent-film treatment
- Hydrodynamic mobility evaluation
- Shear and power-loss treatment under turbulent conditions

### Fixed
- Corrected Three-Lobe bearing naming in the unified solver

### Benchmark result
A reference case produced approximately:

- eccentricity ratio: 0.253
- attitude angle: 29.2 deg
- maximum pressure: 6.78 MPa
- flow: 7.63 L/min

These values were used as an internal comparison point during development.

---

## [v3.12] - Direct Perturbed-Reynolds K/C

### Added
- Direct perturbed-Reynolds method as the default first-order dynamic-coefficient solver
- Sparse linear system for dynamic pressure sensitivities
- Four pressure-sensitivity solutions from a common Reynolds operator
- Cached matrix/factorization workflow
- Frozen equilibrium viscosity during perturbation
- Frozen cavitation active set during perturbation

### Retained
- Finite-difference K/C calculation for QA and independent checking

### Performance
- Direct K/C solution reduced dynamic coefficient computation to approximately 0.18-0.26 s for representative cases during development

### Improved
- Separation between equilibrium solution and dynamic linearization
- Repeatability of dynamic coefficient extraction
- Numerical efficiency compared with repeated nonlinear perturbation solves

---

# Earlier Unified-Solver Milestones

Before the v3.12/v3.13 milestones, RotorDynX was progressively expanded into a unified hydrodynamic-bearing framework.

### Bearing geometry support developed
- Plain journal bearing
- Elliptical / two-lobe bearing
- Three-lobe bearing
- Three-axial-groove bearing
- Tapered-land bearing
- Pressure-dam bearing
- Worn-bearing geometry
- Tilting-pad journal bearing

### Core solver capabilities developed
- Finite-difference Reynolds equation solution
- Sparse matrix assembly
- Journal static equilibrium
- Load and attitude-angle calculation
- Pressure-field solution
- Minimum film thickness
- Maximum pressure
- Oil-film reaction forces
- Friction and power loss
- Flow calculation
- Dimensionless bearing parameters
- Speed and operating-condition studies
- Dynamic stiffness and damping extraction
- Isothermal analysis
- Thermal-result framework
- Cavitation-region handling
- Unified reporting and plotting

---

# Numerical and Solver Improvements

Across the project, the following solver improvements were introduced progressively:

### Reynolds solver
- Sparse matrix formulation
- Reuse of matrix structure where possible
- Improved boundary-condition handling
- Positive-pressure-region treatment
- Separation of geometry, operating point, and numerical settings

### Static equilibrium
- Improved journal-position iteration
- Better residual normalization
- More robust convergence reporting
- Nested TPJB journal/pad equilibrium

### Dynamic coefficients
- Finite-difference coefficient extraction used during early validation
- Direct perturbed-Reynolds formulation introduced
- Common operator/factorization reuse
- Pad-DOF condensation for TPJBs
- Cross-coupled and direct coefficient reporting
- Conditioning checks for condensed pad matrices

### Post-processing
- Consistent SI-unit reporting
- Dimensionless stiffness and damping
- Performance summaries
- Computation-time breakdown
- Unified result structure
- Cleaner production-console output

---

# Validation Philosophy

RotorDynX validation does not rely on a single external program.

The current validation approach includes:

- force-equilibrium checks
- pad-moment equilibrium checks
- mesh-convergence studies
- dimensional consistency
- dimensionless consistency
- finite-difference verification of direct K/C calculations
- published benchmark cases
- comparison with independent engineering tools
- comparison with commercial rotordynamic software where assumptions are known

Differences between two bearing programs are investigated before being treated as errors because results may depend on:

- clearance convention
- preload convention
- pivot definition
- load-angle convention
- cavitation treatment
- viscosity model
- turbulence treatment
- active-pad treatment
- coordinate system
- perturbation convention
- coefficient sign convention
- dimensional normalization

---

# Current Project Status

| Module | Status |
|---|---|
| Unified journal-bearing solver | Operational |
| Static equilibrium | Operational |
| Pressure-field solution | Operational |
| Performance calculations | Operational |
| Direct perturbed-Reynolds K/C | Operational |
| Constantinescu turbulence | Implemented |
| TPJB static solver | Operational |
| TPJB pad-moment equilibrium | Operational |
| TPJB massless-pad K/C condensation | Implemented |
| Spherical-pivot TPJB static model | Operational |
| Spherical-pivot TPJB dynamic model | Implemented |
| External spherical-pivot K/C validation | In progress |
| Independent TPJB finite-difference K/C verification | In progress |

---

## Versioning note

RotorDynX was developed rapidly during the research and validation stage, and not every intermediate code revision was released as a formal Git tag. This changelog therefore records confirmed engineering milestones rather than inventing release dates for historical revisions.
