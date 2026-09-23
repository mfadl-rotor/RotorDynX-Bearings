%% RotorDynX Bearings
% Unified Hydrodynamic Bearing Solver
%
% Supported bearing families:
%   - Plain journal bearing
%   - Fixed-lobe bearing
%   - Tapered-land bearing
%   - Pressure-dam bearing
%   - Worn bearing
%   - Tilting-pad journal bearing (TPJB)
%
% Analysis capabilities:
%   - Static equilibrium
%   - Pressure and film-thickness fields
%   - Performance and thermal calculations
%   - Dynamic stiffness and damping coefficients
%   - Dimensionless analysis
%   - Single-point and speed-sweep studies
%
% Coordinate convention:
%   theta = 0 at +X and increases counter-clockwise.
%   Positive shaft speed is counter-clockwise.
%   The default external load acts in -Y.
%
% MATLAB R2016b or later is required because this script uses local functions.
%
% Public release: 1.0.0

clear; clc; close all;

fprintf('\n============================================================\n');
fprintf(' ROTORDYNX BEARINGS 1.0.0\n');
fprintf(' Unified Hydrodynamic Bearing Solver\n');
fprintf('============================================================\n\n');

%% ============================================================
% USER CONTROL
% =============================================================

bearingType = "Plain";
% Options:
%   "Plain"
%   "FixedLobe"
%   "TaperLand"
%   "PressureDam"
%   "WornBearing"
%   "TPJB"

analysisMode = "SinglePoint";
%   "SinglePoint"
%   "SpeedSweep"

fprintf('Selected bearing type : %s\n',upper(bearingType));
fprintf('Analysis mode         : %s\n\n',upper(analysisMode));

validTypes = ["Plain","FixedLobe","TaperLand","PressureDam","WornBearing","TPJB"];
if ~any(strcmpi(bearingType,validTypes))
    error('Unknown bearingType "%s".',bearingType);
end

if ~any(strcmpi(analysisMode,["SinglePoint","SpeedSweep"]))
    error('analysisMode must be "SinglePoint" or "SpeedSweep".');
end

%% ============================================================
% ENGINE DISPATCH
% =============================================================

if strcmpi(bearingType,"TPJB")
    RotorDynXResult = runRotorDynXTPJB(analysisMode);
else
    RotorDynXResult = runRotorDynXFixedGeometry(bearingType,analysisMode);
end


%% ============================================================
% DIMENSIONLESS ANALYSIS
% =============================================================
% Explicit RotorDynX reference convention:
%
%   Pbar       = W/(L*D)
%   psi        = Cb/R = 2*Cb/D
%   S          = (mu_ref*N/Pbar)*(R/Cb)^2,  N in rev/s
%   h*         = h/Cb
%   p*         = p/Pbar
%   K*         = K*Cb/W
%   C*         = C*Cb*omega/W
%   Power*     = Power/(W*R*omega)
%
% These definitions are shown explicitly because dimensionless bearing
% coefficients can use different conventions in different references.

RotorDynXResult.dimensionless = computeRotorDynXDimensionless(RotorDynXResult);

fprintf('\nDIMENSIONLESS ANALYSIS\n');
fprintf('------------------------------------------------------------\n');
fprintf('Convention               = RotorDynX Reference Convention\n');
fprintf('L/D                      = %.6f\n',RotorDynXResult.dimensionless.LoverD);
fprintf('Relative clearance Cb/R  = %.6e\n',RotorDynXResult.dimensionless.relativeClearance);
fprintf('Sommerfeld number S      = %.6f\n',RotorDynXResult.dimensionless.Sommerfeld);
fprintf('hmin/Cb                  = %.6f\n',RotorDynXResult.dimensionless.hminStar);
fprintf('Pmax/Pbar                = %.6f\n',RotorDynXResult.dimensionless.PmaxStar);

if isfield(RotorDynXResult.dimensionless,'Kstar')
    fprintf('Kxx* = Kxx*Cb/W          = %.6f\n',RotorDynXResult.dimensionless.Kstar(1,1));
    fprintf('Kyy* = Kyy*Cb/W          = %.6f\n',RotorDynXResult.dimensionless.Kstar(2,2));
end
if isfield(RotorDynXResult.dimensionless,'Cstar')
    fprintf('Cxx* = Cxx*Cb*w/W        = %.6f\n',RotorDynXResult.dimensionless.Cstar(1,1));
    fprintf('Cyy* = Cyy*Cb*w/W        = %.6f\n',RotorDynXResult.dimensionless.Cstar(2,2));
end
fprintf('------------------------------------------------------------\n');

%% ============================================================
% COMPLETION REPORT
% =============================================================

fprintf('\n============================================================\n');
fprintf(' ROTORDYNX BEARINGS 1.0.0 - COMPLETE\n');
fprintf('============================================================\n');
fprintf('Engine               : %s\n',RotorDynXResult.engine);
fprintf('Bearing type         : %s\n',RotorDynXResult.bearingType);
fprintf('Analysis mode        : %s\n',RotorDynXResult.analysisMode);

if isfield(RotorDynXResult,'K')
    fprintf('Dynamic stiffness K  : AVAILABLE\n');
end
if isfield(RotorDynXResult,'C')
    fprintf('Dynamic damping C    : AVAILABLE\n');
end
if isfield(RotorDynXResult,'thermal')
    fprintf('Thermal result       : AVAILABLE\n');
end
if isfield(RotorDynXResult,'speedSweep')
    fprintf('Speed-sweep map      : AVAILABLE\n');
end
if isfield(RotorDynXResult,'dimensionless')
    fprintf('Dimensionless analysis: AVAILABLE\n');
end

fprintf('\nUnified result variable in workspace: RotorDynXResult\n');
fprintf('============================================================\n\n');


function dim = computeRotorDynXDimensionless(R)
% computeRotorDynXDimensionless
% Common dimensionless post-processor for all RotorDynX bearing families.

    if ~isfield(R,'bearingDefinition')
        error('Dimensionless analysis requires bearingDefinition.');
    end
    if ~isfield(R,'operatingPoint')
        error('Dimensionless analysis requires operatingPoint.');
    end

    b = R.bearingDefinition;
    op = R.operatingPoint;

    % ---------------- Geometry references --------------------
    if isfield(b,'D')
        D = b.D;
    elseif isfield(b,'Rj')
        D = 2*b.Rj;
    else
        error('Bearing diameter is unavailable.');
    end

    if isfield(b,'Rj')
        Rj = b.Rj;
    else
        Rj = D/2;
    end

    if isfield(b,'L')
        L = b.L;
    else
        error('Bearing length is unavailable.');
    end

    if isfield(b,'Cb')
        Cb = b.Cb;
    else
        error('Bearing radial clearance Cb is unavailable.');
    end

    if isfield(b,'W')
        W = b.W;
    elseif isfield(op,'W')
        W = op.W;
    elseif isfield(op,'Fy') && isfinite(op.Fy)
        W = abs(op.Fy);
    else
        % fixed geometry engine stores W in the module local scope only,
        % therefore the handoff adds reference.W below.
        if isfield(R,'reference') && isfield(R.reference,'W')
            W = R.reference.W;
        else
            error('Bearing load is unavailable.');
        end
    end

    if isfield(b,'omega')
        omega = abs(b.omega);
    elseif isfield(R,'reference') && isfield(R.reference,'omega')
        omega = abs(R.reference.omega);
    else
        error('Angular speed is unavailable.');
    end

    if isfield(R,'reference') && isfield(R.reference,'muRef')
        muRef = R.reference.muRef;
    elseif isfield(b,'mu')
        muRef = b.mu;
    elseif isfield(R,'thermal') && isfield(R.thermal,'muEff')
        muRef = R.thermal.muEff;
    else
        error('Reference viscosity is unavailable.');
    end

    Nrev = omega/(2*pi);
    Pbar = W/(L*D);

    dim.convention = 'RotorDynX Reference Convention';
    dim.definition = struct( ...
        'Sommerfeld','S=(mu_ref*N/Pbar)*(R/Cb)^2; N in rev/s', ...
        'hminStar','hmin/Cb', ...
        'PmaxStar','Pmax/Pbar', ...
        'Kstar','K*Cb/W', ...
        'Cstar','C*Cb*omega/W', ...
        'PowerStar','Power/(W*R*omega)');

    dim.LoverD = L/D;
    dim.relativeClearance = Cb/Rj;
    dim.clearanceRatio2CbD = 2*Cb/D;
    dim.projectedUnitLoad = Pbar;
    dim.muRef = muRef;
    dim.Sommerfeld = (muRef*Nrev/Pbar)*(Rj/Cb)^2;

    if isfield(op,'epsilon')
        dim.epsilon = op.epsilon;
    elseif isfield(op,'q')
        dim.epsilon = hypot(op.q(1),op.q(2));
    else
        dim.epsilon = NaN;
    end

    if isfield(op,'hmin')
        dim.hminStar = op.hmin/Cb;
    else
        dim.hminStar = NaN;
    end

    if isfield(op,'Pmax')
        dim.PmaxStar = op.Pmax/Pbar;
    else
        dim.PmaxStar = NaN;
    end

    if isfield(R,'K') && isnumeric(R.K)
        dim.Kstar = R.K*Cb/W;
    end
    if isfield(R,'C') && isnumeric(R.C)
        dim.Cstar = R.C*Cb*omega/W;
    end

    % Power: TPJB carries it in result.power. Fixed engine handoff adds it.
    if isfield(op,'power')
        power = op.power;
    elseif isfield(R,'reference') && isfield(R.reference,'PowerLoss')
        power = R.reference.PowerLoss;
    else
        power = NaN;
    end
    dim.PowerStar = power/(W*Rj*omega);

    % ---------------- Speed sweep ------------------------------
    if isfield(R,'speedSweep') && isstruct(R.speedSweep) && ~isempty(fieldnames(R.speedSweep))
        sw = R.speedSweep;
        ds = struct();

        if isfield(sw,'rpm')
            rpm = sw.rpm(:);
        elseif isfield(sw,'speedRPM')
            rpm = sw.speedRPM(:);
        else
            rpm = [];
        end

        if ~isempty(rpm)
            omegaVec = 2*pi*rpm/60;
            NrevVec = rpm/60;

            % Effective viscosity through the sweep.
            if isfield(sw,'mu_Pas')
                muVec = sw.mu_Pas(:);
            elseif isfield(sw,'Sommerfeld')
                % Preserve the solver's own fixed-engine Sommerfeld values.
                muVec = nan(size(rpm));
            else
                muVec = muRef*ones(size(rpm));
            end

            ds.rpm = rpm;

            if isfield(sw,'Sommerfeld')
                ds.Sommerfeld = sw.Sommerfeld(:);
            else
                ds.Sommerfeld = (muVec.*NrevVec/Pbar)*(Rj/Cb)^2;
            end

            if isfield(sw,'epsilon'), ds.epsilon = sw.epsilon(:); end

            if isfield(sw,'hmin')
                ds.hminStar = sw.hmin(:)/Cb;
            elseif isfield(sw,'hmin_um')
                ds.hminStar = sw.hmin_um(:)*1e-6/Cb;
            end

            if isfield(sw,'Pmax')
                ds.PmaxStar = sw.Pmax(:)/Pbar;
            elseif isfield(sw,'Pmax_MPa')
                ds.PmaxStar = sw.Pmax_MPa(:)*1e6/Pbar;
            end

            if isfield(sw,'Power')
                ds.PowerStar = sw.Power(:)./(W*Rj*omegaVec);
            elseif isfield(sw,'power_kW')
                ds.PowerStar = sw.power_kW(:)*1e3./(W*Rj*omegaVec);
            end

            if isfield(sw,'Kxx')
                ds.KxxStar = sw.Kxx(:)*Cb/W;
                ds.KxyStar = sw.Kxy(:)*Cb/W;
                ds.KyxStar = sw.Kyx(:)*Cb/W;
                ds.KyyStar = sw.Kyy(:)*Cb/W;
            end
            if isfield(sw,'Cxx')
                ds.CxxStar = sw.Cxx(:).*Cb.*omegaVec/W;
                ds.CxyStar = sw.Cxy(:).*Cb.*omegaVec/W;
                ds.CyxStar = sw.Cyx(:).*Cb.*omegaVec/W;
                ds.CyyStar = sw.Cyy(:).*Cb.*omegaVec/W;
            end

            dim.speedSweep = ds;
        end
    end
end


function moduleOut = runRotorDynXFixedGeometry(selectedBearingType,masterAnalysisMode)
    % Fixed-geometry hydrodynamic bearing engine.
    %
    % Supported families:
    %   Plain, FixedLobe, TaperLand, PressureDam and WornBearing.
    %
    % The engine solves the finite-length Reynolds equation, journal static
    % equilibrium, leakage, friction/power, optional film-THD behavior and
    % linearized stiffness/damping coefficients.
    %
    % Dynamic coefficients can be calculated using the direct perturbed
    % Reynolds formulation or the retained finite-difference QA method.
    %
    % Flow-regime options include laminar, Constantinescu and automatic
    % laminar-to-turbulent transition treatment.

totalRunTimer = tic;

%% ============================================================
% 1) USER INPUTS
% =============================================================

% ---------------- Bearing geometry ---------------------------
% Available now:
%   "Plain"       -> plain cylindrical journal bearing
%   "FixedLobe"   -> circular-arc fixed-lobe bearing family
%   "TaperLand"   -> tapered-land bearing family
%   "PressureDam" -> plain bore + localized pressure-dam/recess geometry
%   "WornBearing" -> plain bore + localized wear-clearance profile
%
% FixedLobe can represent elliptical/lemon bore, 3-lobe, 4-lobe, etc.
% TaperLand supports:
%   - offset-circular-arc circumferential taper
%   - optional flat trailing land inside each lobe
%   - optional axial SIDE LANDS using axialTaperFraction
%
% axialTaperFraction = 1.00 -> no axial side lands
% axialTaperFraction = 0.75 -> central 75% tapered region,
%                             12.5% flat side land on each axial side
%
% PressureDam V3.21 is structured directly around the published two-pad
% pocket/relief-track benchmark family. V3.22 also introduces the published
% Section 3.8 worn-pocket benchmark; both families remain subject to benchmark
% review before final production qualification.
% Use them for development / sensitivity studies until validation is completed.
%
% For identical pads/lobes, enter ONLY Pad #1. Remaining pads are generated
% automatically by 360/numberOfPads spacing.

bearingType = string(selectedBearingType);   % supplied by RotorDynX master

% ---------------- Solver execution mode ----------------------
% "Production" = fast day-to-day use:
%   - one validated working mesh
%   - no perturbation-size sweep
%   - no K/C fine-mesh verification
%   - warm-started K/C pressure solves
%
% "Validation" = development / QA:
%   - automatic mesh independence
%   - perturbation convergence sweeps
%   - K/C fine-mesh verification
%
solverMode = "Production";       % "Production" or "Validation"

% ---------------- Analysis mode ------------------------------
% "SinglePoint" -> solve one shaft speed and produce the complete report.
% "SpeedSweep"  -> also solve a user-defined speed range and produce:
%                  equilibrium locus, center-clearance zoom, hmin,
%                  eccentricity, pressure, flow, power and optional K/C.
analysisMode = string(masterAnalysisMode);  % supplied by RotorDynX master

singlePointRPM = 3600;

speedStartRPM = 4000;
speedEndRPM   = 48000;
speedStepRPM  = 4000;

% K/C at every speed is more expensive. Keep true for a full rotordynamic map.
speedSweepComputeKC = true;

% Constant bearing load during the sweep.
speedSweepLoadModel = "Constant";

% ---------------- Speed-sweep validity flags -----------------
% These are engineering / numerical warning thresholds, not hard physical
% failure criteria.  They identify points where the hydrodynamic solution
% is close to contact and K/C linearization can become highly sensitive.
nearContactHminWarn = 5e-6;     % [m] warn if hmin < 5 um
nearContactEccWarn  = 0.90;     % [-] warn if e/Cb > 0.90

% Optional stronger "severe" flag for very near-contact points.
nearContactHminSevere = 2e-6;   % [m]
nearContactEccSevere  = 0.97;   % [-]

% Production-mode validated defaults
productionPlainNtheta = 241;
productionFixedLobeNtheta = 360;

productionDxFraction = 1.0e-2;   % validated displacement perturbation / Cb
productionDv = 3.0e-4;           % used only by FiniteDifference K/C

% Dynamic coefficient extraction
% "DirectPerturbed"  -> first-order perturbed Reynolds equations (recommended)
% "FiniteDifference" -> legacy centered nonlinear pressure perturbations
dynamicCoeffMethod = "DirectPerturbed";

% Flow-regime model
% "Laminar"         -> force classical laminar Reynolds equation
% "Constantinescu"  -> force Constantinescu turbulent correction everywhere
% "Auto"            -> laminar at low Re, smooth transition, full turbulent at high Re
%
% AUTO is recommended for normal use.
% Forced Constantinescu is retained for reference cases / published benchmarks
% that explicitly use the turbulent correlation.
turbulenceModel = "Auto";

% Density used in local Reynolds-number calculation [kg/m^3].
% Keep this user-editable because turbulent corrections depend on rho.
turbulenceDensity = 850.0;

% AUTO flow-regime limits based on the maximum local film Reynolds number.
% Below ReLaminarMax -> exactly laminar (kappaTheta=kappaAxial=Cf=1).
% Above ReTurbulentMin -> full Constantinescu correction.
% Between them -> smooth cubic blend.
%
% These are solver regime-selection settings, not universal transition constants.
autoReLaminarMax  = 200.0;
autoReTurbulentMin = 1000.0;

% Production static-equilibrium tolerances
% Keep equilibrium solve at normal engineering accuracy; coefficient-grade
% pressure tolerance is reserved for the final pressure field and K/C solves.
productionPressureTol = 1.0e-6;
productionEquilibriumTol = 1.0e-4;

% Reynolds pressure solver
% "SparseActiveSet" = fast production solver using MATLAB sparse A\b
% "SOR"             = legacy projected-SOR solver for comparison / fallback
pressureSolver = "SparseActiveSet";

% Sparse cavitation active-set controls
sparseMaxActiveSetIter = 40;
sparseCavitationTol = 1.0e-10;

% ------------------------------------------------------------
% DEFAULT CASE BELOW = BOOK SECTION 3.8 WORN-POCKET BENCHMARK
%
% Worn Bearing:
%   L = 3 in, D = 5 in, Cb = 0.005 in
%   N = 3600 rpm, W = 1000 lbf
%   viscosity = 1.5e-6 reyn
%
% Base geometry:
%   two axial grooves / two 160-deg cylindrical pads
%   top pad    = 10 -> 170 deg
%   bottom pad = 190 -> 350 deg
%
% Worn pocket:
%   loaded pad          = bottom pad
%   depth               = 0.00125 in = 25% of Cb
%   circumferential arc = 100 deg = 62.5% of 160-deg pad arc
%   pocket centered at  = 270 deg (load direction)
%
% Published worn-bearing benchmark:
%   Sb      = 0.3375
%   E/Cb    = 0.6673
%   Att     = 20.28 deg
%   hmin    = 2.098 mil
%   Pmax    = 170.545 psi
%   Power   = 2.18133 hp
%   Qside   = 1.314 gpm
%   Mcr     = 8590.1 lbm
%
%   K [lbf/in] =
%       [ 3.489E+05   6.897E+04
%        -9.272E+05   7.470E+05 ]
%
%   C [lbf-s/in] =
%       [ 1.098E+03  -5.639E+02
%        -5.639E+02   4.310E+03 ]
% ------------------------------------------------------------

D = 5.0*0.0254;               % journal diameter [m]
R = D/2;
L = 3.0*0.0254;               % bearing axial length [m]

bearing.type = char(bearingType);
bearing.Cb = 0.005*0.0254;     % base radial clearance [m]
bearing.Rj = R;                 % journal radius needed for exact offset-arc geometry
bearing.L = L;                  % axial length used by pressure-dam geometry validation

if strcmpi(bearing.type,'Plain')

    bearing.displayName = 'Plain Cylindrical Journal Bearing';

elseif strcmpi(bearing.type,'FixedLobe')

    % -------- General circular-arc fixed-lobe input ----------
    bearing.displayName = 'Fixed-Lobe Journal Bearing';

    bearing.numberOfPads = 2;
    bearing.identicalPads = true;

    bearing.pad(1).theta1Deg = 10;     % leading edge [deg]
    bearing.pad(1).theta2Deg = 170;    % trailing edge [deg]
    bearing.pad(1).preload   = 0.50;   % m = 1 - Cb/Cp
    bearing.pad(1).offset    = 0.50;   % alpha / tilt-offset factor

elseif strcmpi(bearing.type,'TaperLand')

    % -------- Tapered-land input ------------------------------
    %
    % Book benchmark family uses 3 lobes, each 100 deg long,
    % separated by 20 deg oil grooves.
    bearing.displayName = 'Tapered-Land Journal Bearing';

    bearing.numberOfPads = 3;
    bearing.identicalPads = true;

    % Enter lobe #1 only when identicalPads = true.
    bearing.pad(1).theta1Deg = 100;    % lobe leading edge [deg]
    bearing.pad(1).theta2Deg = 200;    % lobe trailing edge [deg]

    % Taper undercut:
    % leading-edge clearance = Cb + undercut
    % clearance at the end of the taper arc = Cb
    bearing.pad(1).undercut = 0.0024*0.0254;  % [m] = 1.5*Cb

    % Book Bearing #6 / Taper-3: 75 deg taper + 25 deg flat trailing land.
    bearing.pad(1).taperArcDeg = 75;

    % Offset-arc center convention from the book.
    % Typical tapered-land geometry places the arc center on the
    % centerline of the LEADING OIL GROOVE.  "LeadingEdge" and
    % "Manual" are also supported for other drawings.
    bearing.pad(1).arcCenterMode = 'LeadingGrooveCenter';
    bearing.pad(1).arcCenterAngleDeg = NaN;   % used only for Manual

    % Fraction of total axial bearing length occupied by the central
    % tapered region.  Remaining width is split equally into side lands.
    % Book Bearing #6: z_taper/L = 1.0125/1.35 = 0.75.
    bearing.pad(1).axialTaperFraction = 0.75;

elseif strcmpi(bearing.type,'PressureDam')

    % -------- Independent pressure-dam bearing family ---------
    %
    % Geometry convention:
    %   - two cylindrical pads separated by two axial oil grooves
    %   - constant-depth pocket in the TOP / unloaded pad
    %   - optional circumferential relief track in the BOTTOM / loaded pad
    %
    % The pocket and the relief track do NOT coexist on the same pad.
    % Relief-track pressure is fixed at ambient/supply gauge pressure (0).
    %
    bearing.displayName = 'Pressure-Dam Journal Bearing';

    bearing.numberOfPads = 2;
    bearing.identicalPads = false;

    % Base two-axial-groove geometry
    bearing.pad(1).theta1Deg = 10;      % top pad leading edge
    bearing.pad(1).theta2Deg = 170;     % top pad trailing edge

    bearing.pad(2).theta1Deg = 190;     % bottom pad leading edge
    bearing.pad(2).theta2Deg = 350;     % bottom pad trailing edge

    % TOP PAD pressure pocket
    % Pocket begins at the top-pad leading edge and ends after pocketArcDeg.
    % The abrupt clearance reduction at the pocket trailing edge forms the dam.
    bearing.pocketPad = 1;
    bearing.pocketArcDeg = 125;
    bearing.pocketDepth = 0.015*0.0254;     % [m]
    bearing.pocketAxialLength = 3.0*0.0254; % [m]

    % BOTTOM PAD relief-track configuration
    %   "None"   : no relief track (book case 2)
    %   "Center" : centered track; reliefAxialLength is track width
    %   "Side"   : total reliefAxialLength split equally between both sides
    bearing.reliefPad = 2;
    bearing.reliefMode = "Side";             % "None", "Center", "Side"
    bearing.reliefAxialLength = 2.0*0.0254;  % [m] TOTAL side relief = 1.0 in each side

    % Relief groove is assumed very deep, therefore its pressure is equalized
    % to the supply/ambient gauge pressure.  Depth is used for geometry/contact
    % visualization only; pressure there is prescribed to zero.
    bearing.reliefDepth = 20*bearing.Cb;

elseif strcmpi(bearing.type,'WornBearing')

    % -------- Independent worn-pocket bearing family ----------
    %
    % The book Section 3.8 defines wear by:
    %   depth ratio = wearDepth / Cb
    %   arc ratio   = wearArcDeg / loaded-pad arc
    %
    % The worn surface is modeled as a SMOOTH CIRCULAR ARC.
    % The arc is uniquely defined by the original bore at the two wear
    % boundaries and the maximum wear depth at the wear-zone center.
    bearing.displayName = 'Worn-Pocket Journal Bearing';

    bearing.numberOfPads = 2;
    bearing.identicalPads = false;

    % Base two-axial-groove geometry: 160-deg pads, 20-deg grooves.
    bearing.pad(1).theta1Deg = 10;
    bearing.pad(1).theta2Deg = 170;

    bearing.pad(2).theta1Deg = 190;
    bearing.pad(2).theta2Deg = 350;

    % Worn pocket is in the loaded / bottom pad.
    bearing.wearPad = 2;
    bearing.wearDepth = 0.00125*0.0254;   % [m] = 25% of Cb
    bearing.wearArcDeg = 100;             % [deg] = 62.5% of 160-deg pad
    bearing.wearCenterDeg = 270;          % [deg] load direction

    % 1.0 = wear extends over full bearing axial length.
    bearing.wearAxialFraction = 1.0;

    bearing.wearProfile = 'CircularArc';

else

    error(['Unknown bearingType. Use "Plain", "FixedLobe", "TaperLand", ', ...
           '"PressureDam", or "WornBearing".']);
end

% ---------------- Thermal mode -------------------------------
% Book Bearing #6 benchmark is isothermal.
% Keep false for the side-land benchmark; THD + side lands is intentionally
% blocked until the thermal energy grid is upgraded to full h(theta,z).
fullTHD = false;               % false = isothermal / true = coupled film THD

bearing = prepareBearingDefinition(bearing);

if ~strcmpi(analysisMode,'SinglePoint') && ~strcmpi(analysisMode,'SpeedSweep')
    error('analysisMode must be "SinglePoint" or "SpeedSweep".');
end

if strcmpi(analysisMode,'SpeedSweep')
    if speedStepRPM <= 0
        error('speedStepRPM must be positive.');
    end
    if speedEndRPM < speedStartRPM
        error('speedEndRPM must be >= speedStartRPM.');
    end
    if ~strcmpi(speedSweepLoadModel,'Constant')
        error('V3.20 currently supports speedSweepLoadModel = "Constant" only.');
    end
end


% V3.17: hydrodynamic, flow, friction, direct K/C and stability support
% full tapered-land h(theta,z) with axial side lands.
% The legacy THD energy grid is still based on h(theta) only, so do not
% silently run THD on a side-land geometry until that energy solver is
% upgraded to full h(theta,z).
if fullTHD
    if strcmpi(bearing.type,'TaperLand') && ...
            bearing.pad(1).axialTaperFraction < 1
        error(['THD with tapered-land axial side lands is not enabled yet. ', ...
               'Use fullTHD=false for this 2-D geometry.']);
    elseif strcmpi(bearing.type,'PressureDam')
        error(['THD for the discontinuous pressure-dam / relief-track family ', ...
               'is not enabled yet. Use fullTHD=false for V3.21 validation.']);
    elseif strcmpi(bearing.type,'WornBearing')
        error(['THD for the circular worn-pocket family is not enabled yet. ', ...
               'Use fullTHD=false for V3.22 benchmark validation.']);
    end
end

% Robust display-name alias used by plotting/reporting code.
% Keep one canonical field and one compatibility alias.
if ~isfield(bearing,'displayName') || isempty(bearing.displayName)
    if isContinuousBoreBearing(bearing)
        bearing.displayName = 'Plain Cylindrical Journal Bearing';
    else
        bearing.displayName = 'Journal Bearing';
    end
end
bearing.displayName = bearing.displayName;

% Numerical pressure solver settings are carried with the bearing struct so
% all equilibrium and K/C calls use the same Reynolds core.
bearing.pressureSolver = char(pressureSolver);
bearing.sparseMaxActiveSetIter = sparseMaxActiveSetIter;
bearing.sparseCavitationTol = sparseCavitationTol;

bearing.turbulenceModel = char(turbulenceModel);
bearing.turbulenceDensity = turbulenceDensity;
bearing.autoReLaminarMax = autoReLaminarMax;
bearing.autoReTurbulentMin = autoReTurbulentMin;

% Common reference clearance used for eccentricity ratio and perturbations
Cclr = bearing.Cb;

% ---------------- Operating point ----------------------------
N = singlePointRPM;             % detailed single-point shaft speed [rpm]
omega = 2*pi*N/60;             % shaft speed [rad/s]
W = 1000*4.4482216152605;      % applied load [N] = 1000 lbf

% ---------------- Isothermal viscosity -----------------------
muIso = 1.5e-6*6894.757293168;  % Pa.s, worn-bearing book benchmark

% ---------------- Oil data for THD ---------------------------
TinC = 45;                     % supplied oil temperature [degC]

% ASTM D341/Walther viscosity data
nu40_cSt  = 46.0;              % cSt @ 40 C
nu100_cSt = 7.0;               % cSt @ 100 C

rho40 = 860;                   % density @ 40 C [kg/m^3]
alphaRho = 7.0e-4;             % density slope [1/K]
cpOil = 2000;                  % specific heat [J/(kg.K)]
kOil = 0.13;                   % thermal conductivity [W/(m.K)]

% Thermal boundaries
TbushBulkC    = 50;            % bush bulk temperature [degC]
TjournalBulkC = 55;            % journal bulk temperature [degC]
hBush = 2500;                  % film-to-bush HTC [W/(m^2.K)]
hJournal = 3500;               % film-to-journal HTC [W/(m^2.K)]

% Thermal inlet line
supplyGrooveAngleDeg = 0;

% ---------------- THD iteration controls ---------------------
thermalTolT = 2e-3;
thermalTolMu = 2e-3;
maxThermalIter = 40;
thermalRelax = 0.35;

NyThermal = 7;
thermalMaxNtheta = 121;
thermalMaxNz = 31;

energyTol = 2e-6;
energyMaxIter = 2500;
energyRelax = 0.75;

%% ============================================================
% 2) GENERAL NUMERICAL SETTINGS
% =============================================================

if ~isContinuousBoreBearing(bearing)
    % 2 deg -> 1 deg -> 0.5 deg resolution. This makes typical pad/lobe
    % leading/trailing-edge angles land exactly on the circumferential grid.
    meshLevels = [180 360 720];
else
    meshLevels = [121 241 481 961];
end
meshTolerance = 0.005;         % 0.5%
maxNz = 301;

pressureTol = 1e-6;
maxPressureIter = 5000;
omegaSOR = 1.40;

equilibriumTol = 1e-4;
maxEquilibriumIter = 30;
dqNewtonPerturb = 1e-4;
maxQstep = 0.15;
maxEpsilon = 0.95;

qInitial = [0; -0.50];

%% ============================================================
% 3) HIGH-ACCURACY SETTINGS FOR K/C
% =============================================================

coefficientPressureTol = 1e-9;
coefficientMaxPressureIter = 15000;
coefficientEquilibriumTol = 1e-7;

dxFractions = [2e-2 1e-2 5e-3 3e-3 2e-3 1e-3 5e-4];
dvValues    = [1e-2 3e-3 1e-3 3e-4 1e-4];
perturbTolerance = 0.005;

coefficientMeshTolerance = 0.01;


% ---------------- Execution flags ----------------------------
isProductionMode = strcmpi(solverMode,'Production');
isValidationMode = strcmpi(solverMode,'Validation');

if ~(isProductionMode || isValidationMode)
    error('solverMode must be "Production" or "Validation".');
end

isDirectPerturbedKC = strcmpi(dynamicCoeffMethod,'DirectPerturbed');
isFiniteDifferenceKC = strcmpi(dynamicCoeffMethod,'FiniteDifference');

if ~(isDirectPerturbedKC || isFiniteDifferenceKC)
    error(['dynamicCoeffMethod must be "DirectPerturbed" or ', ...
           '"FiniteDifference".']);
end

doMeshIndependence = isValidationMode;

% Perturbation-size convergence only exists for the legacy finite-difference
% method.  Direct perturbed Reynolds has no artificial dx or dv parameter.
doPerturbationStudy = isValidationMode && isFiniteDifferenceKC;

doKCMeshVerification = isValidationMode;

%% ============================================================
% 4) PREPARE OIL / THD STRUCTURES
% =============================================================

oil.TinC = TinC;
oil.nu40_cSt = nu40_cSt;
oil.nu100_cSt = nu100_cSt;
oil.rho40 = rho40;
oil.alphaRho = alphaRho;
oil.cp = cpOil;
oil.k = kOil;
oil.TbushBulkC = TbushBulkC;
oil.TjournalBulkC = TjournalBulkC;
oil.hBush = hBush;
oil.hJournal = hJournal;
oil.supplyGrooveAngleDeg = supplyGrooveAngleDeg;

thd.fullTHD = fullTHD;
thd.maxIter = maxThermalIter;
thd.relax = thermalRelax;
thd.tolT = thermalTolT;
thd.tolMu = thermalTolMu;
thd.Ny = NyThermal;
thd.maxNtheta = thermalMaxNtheta;
thd.maxNz = thermalMaxNz;
thd.energyTol = energyTol;
thd.energyMaxIter = energyMaxIter;
thd.energyRelax = energyRelax;

fprintf('\n====================================================\n');
if fullTHD
    fprintf(' THERMAL MODE: COUPLED FILM THD\n');
else
    fprintf(' THERMAL MODE: ISOTHERMAL\n');
end
fprintf('====================================================\n');

fprintf('\nBEARING GEOMETRY\n');
fprintf('----------------------------------------------------\n');
fprintf('Type                     = %s\n',bearing.displayName);
fprintf('Base radial clearance Cb = %.3f um\n',bearing.Cb*1e6);

if strcmpi(bearing.type,'FixedLobe')

    fprintf('Number of pads           = %d\n',bearing.numberOfPads);
    fprintf('Identical pads           = %s\n',ternary(bearing.identicalPads,'YES','NO'));

    for pp = 1:bearing.numberOfPads
        fprintf(['Pad %d: theta1=%7.2f deg  theta2=%7.2f deg  ', ...
                 'm=%.3f  alpha=%.3f  Cp=%.3f um\n'], ...
                 pp, ...
                 bearing.pad(pp).theta1Deg, ...
                 bearing.pad(pp).theta2Deg, ...
                 bearing.pad(pp).preload, ...
                 bearing.pad(pp).offset, ...
                 bearing.pad(pp).Cp*1e6);
    end

elseif strcmpi(bearing.type,'TaperLand')

    fprintf('Number of lobes          = %d\n',bearing.numberOfPads);
    fprintf('Identical lobes          = %s\n',ternary(bearing.identicalPads,'YES','NO'));

    for pp = 1:bearing.numberOfPads
        fprintf(['Lobe %d: theta1=%7.2f deg  theta2=%7.2f deg  ', ...
                 'Arc=%.2f deg  TaperArc=%.2f deg  undercut=%.3f um\n'], ...
                 pp, ...
                 bearing.pad(pp).theta1Deg, ...
                 bearing.pad(pp).theta2Deg, ...
                 bearing.pad(pp).arcDeg, ...
                 bearing.pad(pp).taperArcDeg, ...
                 bearing.pad(pp).undercut*1e6);

        fprintf(['        Arc center thetaA=%7.2f deg  ra=%.3f um  ', ...
                 'Ra=%.6f mm\n'], ...
                 bearing.pad(pp).thetaADeg, ...
                 bearing.pad(pp).ra*1e6, ...
                 bearing.pad(pp).Ra*1e3);
    end

    fprintf('Axial taper fraction     = %.3f\n', ...
        bearing.pad(1).axialTaperFraction);

    if bearing.pad(1).axialTaperFraction < 1
        taperedWidth = L*bearing.pad(1).axialTaperFraction;
        sideWidth = 0.5*(L-taperedWidth);

        fprintf('Central tapered width    = %.4f mm\n',taperedWidth*1e3);
        fprintf('Side land width / side   = %.4f mm\n',sideWidth*1e3);
    else
        fprintf('Axial side lands         = NONE\n');
    end

elseif strcmpi(bearing.type,'PressureDam')

    fprintf('Base geometry            = Two axial grooves / two cylindrical pads\n');
    fprintf('Top pad                  = %.2f to %.2f deg\n', ...
        bearing.pad(1).theta1Deg,bearing.pad(1).theta2Deg);
    fprintf('Bottom pad               = %.2f to %.2f deg\n', ...
        bearing.pad(2).theta1Deg,bearing.pad(2).theta2Deg);
    fprintf('Pocket pad               = %d (TOP / unloaded pad)\n',bearing.pocketPad);
    fprintf('Pocket arc               = %.2f deg\n',bearing.pocketArcDeg);
    fprintf('Pocket step angle        = %.2f deg\n',bearing.pocketStepDeg);
    fprintf('Pocket depth             = %.3f mm\n',bearing.pocketDepth*1e3);
    fprintf('Pocket axial length      = %.3f mm\n',bearing.pocketAxialLength*1e3);

    sideDamWidth = 0.5*(L-bearing.pocketAxialLength);
    fprintf('Pocket side dam / side   = %.3f mm\n',max(sideDamWidth,0)*1e3);

    fprintf('Relief mode              = %s\n',char(bearing.reliefMode));

    if ~strcmpi(bearing.reliefMode,'None')
        fprintf('Relief pad               = %d (BOTTOM / loaded pad)\n',bearing.reliefPad);
        fprintf('Relief total axial width = %.3f mm\n',bearing.reliefAxialLength*1e3);

        if strcmpi(bearing.reliefMode,'Side')
            fprintf('Relief width / side      = %.3f mm\n', ...
                0.5*bearing.reliefAxialLength*1e3);
        end
    end

    if strcmpi(bearing.reliefMode,'Center') && ...
            abs(bearing.reliefAxialLength-1.0*0.0254) < 1e-9
        fprintf('Benchmark case           = Book Case 3: centered 1-in relief track\n');
    elseif strcmpi(bearing.reliefMode,'Side') && ...
            abs(bearing.reliefAxialLength-1.0*0.0254) < 1e-9
        fprintf('Benchmark case           = Book Case 4: 0.5-in relief each side\n');
    elseif strcmpi(bearing.reliefMode,'Side') && ...
            abs(bearing.reliefAxialLength-2.0*0.0254) < 1e-9
        fprintf('Benchmark case           = Book Case 5: 1.0-in relief each side\n');
    end

elseif strcmpi(bearing.type,'WornBearing')

    fprintf('Base geometry            = Two axial grooves / two cylindrical pads\n');
    fprintf('Top pad                  = %.2f to %.2f deg\n', ...
        bearing.pad(1).theta1Deg,bearing.pad(1).theta2Deg);
    fprintf('Bottom pad               = %.2f to %.2f deg\n', ...
        bearing.pad(2).theta1Deg,bearing.pad(2).theta2Deg);

    fprintf('Worn pad                 = %d (BOTTOM / loaded pad)\n',bearing.wearPad);
    fprintf('Wear center angle        = %.2f deg\n',bearing.wearCenterDeg);
    fprintf('Wear circumferential arc = %.2f deg\n',bearing.wearArcDeg);
    fprintf('Maximum wear depth       = %.3f um\n',bearing.wearDepth*1e6);
    fprintf('Wear depth / Cb          = %.4f\n',bearing.wearDepth/bearing.Cb);
    fprintf('Wear arc / pad arc       = %.4f\n', ...
        bearing.wearArcDeg/bearing.pad(bearing.wearPad).arcDeg);
    fprintf('Wear profile             = %s\n',bearing.wearProfile);
    fprintf('Wear circle offset       = %.3f mm\n',bearing.wearCircleOffset*1e3);
    fprintf('Wear circle radius       = %.3f mm\n',bearing.wearCircleRadius*1e3);
    fprintf('Wear axial fraction      = %.3f\n',bearing.wearAxialFraction);
    fprintf('Benchmark case           = Book Section 3.8, 25%% depth / 62.5%% arc\n');
end

%% ============================================================
% 5) WORKING MESH SELECTION
% =============================================================

% Production mode will obtain the final high-accuracy solution directly
% on the validated working mesh. Validation mode still performs a final
% coefficient-grade solve after the mesh study.
finalSolutionReady = false;

if doMeshIndependence

    fprintf('\n====================================================\n');
    fprintf(' AUTOMATIC MESH INDEPENDENCE STUDY\n');
    fprintf('====================================================\n');

    previous = [];
    meshVerified = false;
    qWarm = qInitial;
    thermalWarm = [];
    overallMeshError = NaN;

    for meshIndex = 1:length(meshLevels)

        Ntheta = meshLevels(meshIndex);
        dtheta = 2*pi/Ntheta;
        dxArc = R*dtheta;

        targetNz = ceil(L/dxArc)+1;
        if mod(targetNz,2)==0, targetNz = targetNz+1; end

        Nz = min(targetNz,maxNz);
        Nz = max(Nz,5);
        if mod(Nz,2)==0, Nz = Nz+1; end

        dz = L/(Nz-1);

        fprintf('\n----------------------------------------------------\n');
        fprintf('Mesh level %d\n',meshIndex);
        fprintf('Ntheta = %d\n',Ntheta);
        fprintf('Nz     = %d\n',Nz);
        fprintf('dx     = %.4e m\n',dxArc);
        fprintf('dz     = %.4e m\n',dz);
        fprintf('dx/dz  = %.3f\n',dxArc/dz);
        fprintf('----------------------------------------------------\n');

        [eqM,thermalM] = solveCoupledBearing( ...
            R,L,bearing,omega,W,Ntheta,Nz,qWarm, ...
            pressureTol,maxPressureIter,omegaSOR, ...
            equilibriumTol,maxEquilibriumIter,dqNewtonPerturb,maxQstep,maxEpsilon, ...
            fullTHD,muIso,oil,thd,thermalWarm,true);

        qWarm = eqM.q;
        thermalWarm = thermalM;

        current.epsilon = eqM.epsilon;
        current.hmin = eqM.hmin;
        current.Pmax = eqM.Pmax;
        current.phiDeg = eqM.phiDeg;
        current.Ntheta = Ntheta;
        current.Nz = Nz;
        current.eq = eqM;
        current.thermal = thermalM;
        current.aspect = dxArc/dz;

        fprintf('\nMesh results:\n');
        fprintf('epsilon = %.6f\n',current.epsilon);
        fprintf('hmin    = %.4f um\n',current.hmin*1e6);
        fprintf('Pmax    = %.4f MPa\n',current.Pmax/1e6);
        fprintf('phi     = %.3f deg\n',current.phiDeg);

        if fullTHD
            fprintf('Tmean   = %.3f C\n',thermalM.TmeanC);
            fprintf('Tmax    = %.3f C\n',thermalM.TmaxC);
            fprintf('mu mean = %.6e Pa.s\n',mean(thermalM.muHydro(:)));
        end

        if ~isempty(previous)

            errEps  = abs(current.epsilon-previous.epsilon)/max(abs(current.epsilon),eps);
            errHmin = abs(current.hmin-previous.hmin)/max(abs(current.hmin),eps);
            errPmax = abs(current.Pmax-previous.Pmax)/max(abs(current.Pmax),eps);
            errPhi  = abs(angleDiffDeg(current.phiDeg,previous.phiDeg));

            overallMeshError = max([errEps errHmin errPmax]);

            fprintf('\nMesh change:\n');
            fprintf('epsilon error = %.4f %%\n',100*errEps);
            fprintf('hmin error    = %.4f %%\n',100*errHmin);
            fprintf('Pmax error    = %.4f %%\n',100*errPmax);
            fprintf('phi change    = %.4f deg\n',errPhi);
            fprintf('Overall error = %.4f %%\n',100*overallMeshError);

            if overallMeshError <= meshTolerance
                meshVerified = true;
                break;
            end
        end

        previous = current;
    end

    selected = current;
    Ntheta = selected.Ntheta;
    Nz = selected.Nz;

    fprintf('\n====================================================\n');
    fprintf(' MESH INDEPENDENCE %s\n',ternary(meshVerified,'ACHIEVED','NOT ACHIEVED'));
    fprintf('====================================================\n');
    fprintf('Selected Ntheta = %d\n',Ntheta);
    fprintf('Selected Nz     = %d\n',Nz);
    fprintf('Cell aspect     = %.3f\n',selected.aspect);
    if isfinite(overallMeshError)
        fprintf('Mesh error      = %.4f %%\n',100*overallMeshError);
    end
    fprintf('====================================================\n');

else

    % ---------------------------------------------------------
    % PRODUCTION MODE: use a validated working mesh directly
    % ---------------------------------------------------------
    if isContinuousBoreBearing(bearing)
        Ntheta = productionPlainNtheta;
    else
        Ntheta = productionFixedLobeNtheta;
    end

    dtheta = 2*pi/Ntheta;
    dxArc = R*dtheta;

    Nz = ceil(L/dxArc)+1;
    if mod(Nz,2)==0, Nz = Nz+1; end
    Nz = min(Nz,maxNz);
    if mod(Nz,2)==0, Nz = Nz+1; end

    dz = L/(Nz-1);

    fprintf('\n====================================================\n');
    fprintf(' PRODUCTION WORKING MESH\n');
    fprintf('====================================================\n');
    fprintf('Ntheta = %d\n',Ntheta);
    fprintf('Nz     = %d\n',Nz);
    fprintf('dx/dz  = %.3f\n',dxArc/dz);
    fprintf('Mesh validation = PRE-VALIDATED / QA MODE SKIPPED\n');
    fprintf('====================================================\n');

    fprintf('Production equilibrium = FAST POSITION SOLVE + ONE HIGH-ACCURACY PRESSURE REFRESH\n');

    % ---------------------------------------------------------
    % SINGLE production equilibrium solve
    % ---------------------------------------------------------
    % Solve journal position with normal engineering tolerances.
    % Do NOT use the very tight coefficient pressure tolerance here:
    % equilibrium requires many Reynolds solves, so using 1e-9 at every
    % Newton iteration wastes time with negligible change in q.
    [eq,thermalState] = solveCoupledBearing( ...
        R,L,bearing,omega,W,Ntheta,Nz,qInitial, ...
        productionPressureTol,maxPressureIter,omegaSOR, ...
        productionEquilibriumTol,maxEquilibriumIter,dqNewtonPerturb,maxQstep,maxEpsilon, ...
        fullTHD,muIso,oil,thd,[],true);

    % ---------------------------------------------------------
    % ONE coefficient-grade pressure refresh at converged q
    % ---------------------------------------------------------
    % This gives K/C a high-accuracy base pressure without repeating the
    % entire mechanical equilibrium search.
    [Pfinal,FxFinal,FyFinal] = solvePressureVariableMu( ...
        eq.q,[0;0],R,L,bearing,omega,Ntheta,Nz,thermalState.muHydro, ...
        coefficientPressureTol,coefficientMaxPressureIter,omegaSOR,eq.P);

    eq.P = Pfinal;
    eq.Fx = FxFinal;
    eq.Fy = FyFinal;
    eq.Pmax = max(Pfinal(:));

    selected.eq = eq;
    selected.thermal = thermalState;
    selected.Ntheta = Ntheta;
    selected.Nz = Nz;
    selected.aspect = dxArc/dz;

    meshIndex = 1;
    meshVerified = true;
    overallMeshError = NaN;
    finalSolutionReady = true;
end

%% ============================================================
% 6) FINAL HIGH-ACCURACY EQUILIBRIUM
% =============================================================

if ~finalSolutionReady

    % Validation mode only:
    % the mesh study used standard tolerances, therefore make one final
    % coefficient-grade solve on the selected mesh.
    [eq,thermalState] = solveCoupledBearing( ...
        R,L,bearing,omega,W,Ntheta,Nz,selected.eq.q, ...
        coefficientPressureTol,coefficientMaxPressureIter,omegaSOR, ...
        coefficientEquilibriumTol,maxEquilibriumIter,dqNewtonPerturb,maxQstep,maxEpsilon, ...
        fullTHD,muIso,oil,thd,selected.thermal,false);

else

    fprintf('\n====================================================\n');
    fprintf(' FINAL EQUILIBRIUM REUSE\n');
    fprintf('====================================================\n');
    fprintf('Production journal position already solved; base pressure refreshed at coefficient accuracy.\n');
    fprintf('Duplicate high-accuracy equilibrium search = SKIPPED\n');
    fprintf('====================================================\n');

end

theta = eq.theta;
z = eq.z;
P = eq.P;
h = eq.h;
hHydro2D = eq.h2D;
q = eq.q;
muHydro = thermalState.muHydro;

%% ============================================================
% 7) FLOW / FRICTION / ENERGY BALANCE
% =============================================================

[Qleft,Qright,Qtotal,qzLeft,qzRight] = ...
    sideLeakageVariableMu(P,hHydro2D,muHydro,R,theta,z,eq.activeMask,omega,bearing);

[FrictionTorque,PowerLoss,EquivalentFrictionForce,FrictionCoefficient] = ...
    frictionLossVariableMu(P,hHydro2D,muHydro,R,L,omega,W,theta,z,eq.activeMask,bearing);

unitLoad = W/(L*D);

if fullTHD
    muSommerfeld = mean(muHydro(:));
else
    muSommerfeld = muIso;
end

Sommerfeld = (muSommerfeld*(abs(N)/60)/unitLoad)*(R/Cclr)^2;

% THD energy-balance diagnostic
if fullTHD
    energy = thermalEnergyBalance( ...
        thermalState,eq,muHydro,qzLeft,qzRight, ...
        R,L,omega,PowerLoss,oil);
else
    energy.available = false;
    energy.ToutMixC = NaN;
    energy.Qoil = NaN;
    energy.Qbush = NaN;
    energy.Qjournal = NaN;
    energy.Qwalls = NaN;
    energy.Qaccounted = NaN;
    energy.residualW = NaN;
    energy.residualPct = NaN;
end

%% ============================================================
% 8) DYNAMIC COEFFICIENTS
% =============================================================

muKC = muHydro;
PbaseKC = P;

KpertError = nan(size(dxFractions));
CpertError = nan(size(dvValues));

% These are meaningful only for the legacy finite-difference method.
dxPerturbSelected = NaN;
dvPerturbSelected = NaN;

if isDirectPerturbedKC

    fprintf('\n====================================================\n');
    fprintf(' DIRECT PERTURBED-REYNOLDS K/C EXTRACTION\n');
    fprintf('====================================================\n');
    fprintf('Method                   = First-order pressure perturbation\n');
    fprintf('Artificial dx/dv         = NOT REQUIRED\n');
    fprintf('Viscosity field          = FROZEN AT EQUILIBRIUM\n');
    fprintf('Cavitation boundary      = FROZEN AT EQUILIBRIUM\n');

    directKCTimer = tic;

    [K,Cmat,directKC] = calculateBearingKCDirectPerturbed( ...
        q,R,L,bearing,omega,Ntheta,Nz,muKC,PbaseKC);

    directKCRuntime = toc(directKCTimer);

    fprintf('Base positive-P nodes    = %d\n',directKC.nPressureActive);
    fprintf('Sparse matrix size       = %d x %d\n', ...
        directKC.nPressureActive,directKC.nPressureActive);
    fprintf('Direct K/C solve time    = %.3f s\n',directKCRuntime);
    fprintf('====================================================\n');

else

    if doPerturbationStudy

        fprintf('\n====================================================\n');
        fprintf(' K/C PERTURBATION CONVERGENCE STUDY\n');
        fprintf('====================================================\n');

        Klist = zeros(2,2,length(dxFractions));
        Clist = zeros(2,2,length(dvValues));

        fprintf('\nSTIFFNESS PERTURBATION CONVERGENCE\n');
        fprintf('----------------------------------------------------\n');

        for k = 1:length(dxFractions)

            dxPerturb = dxFractions(k)*Cclr;

            Klist(:,:,k) = calculateBearingKOnly( ...
                q,dxPerturb, ...
                R,L,bearing,omega,Ntheta,Nz,muKC,PbaseKC, ...
                coefficientPressureTol,coefficientMaxPressureIter,omegaSOR);

            if k >= 2
                KpertError(k-1) = ...
                    norm(Klist(:,:,k)-Klist(:,:,k-1),'fro') / ...
                    max(norm(Klist(:,:,k),'fro'),eps);

                fprintf('dx/C %.1e -> %.1e : K change = %.4f %%\n', ...
                    dxFractions(k-1),dxFractions(k),100*KpertError(k-1));
            end
        end

        fprintf('\nDAMPING PERTURBATION CONVERGENCE\n');
        fprintf('----------------------------------------------------\n');

        for k = 1:length(dvValues)

            Clist(:,:,k) = calculateBearingCOnly( ...
                q,dvValues(k), ...
                R,L,bearing,omega,Ntheta,Nz,muKC,PbaseKC, ...
                coefficientPressureTol,coefficientMaxPressureIter,omegaSOR);

            if k >= 2
                CpertError(k-1) = ...
                    norm(Clist(:,:,k)-Clist(:,:,k-1),'fro') / ...
                    max(norm(Clist(:,:,k),'fro'),eps);

                fprintf('dv %.1e -> %.1e m/s : C change = %.4f %%\n', ...
                    dvValues(k-1),dvValues(k),100*CpertError(k-1));
            end
        end

        idxK = find(KpertError(1:end-1)<=perturbTolerance,1,'first');
        if isempty(idxK), idxK = length(dxFractions)-1; end

        idxC = find(CpertError(1:end-1)<=perturbTolerance,1,'first');
        if isempty(idxC), idxC = length(dvValues)-1; end

        selectedKindex = idxK+1;
        selectedCindex = idxC+1;

        dxPerturbSelected = dxFractions(selectedKindex)*Cclr;
        dvPerturbSelected = dvValues(selectedCindex);

    else

        fprintf('\n====================================================\n');
        fprintf(' FAST PRODUCTION FINITE-DIFFERENCE K/C EXTRACTION\n');
        fprintf('====================================================\n');

        dxPerturbSelected = productionDxFraction*Cclr;
        dvPerturbSelected = productionDv;

        fprintf('Using validated dx/C = %.3e\n',productionDxFraction);
        fprintf('Using validated dv   = %.3e m/s\n',productionDv);
        fprintf('Perturbation sweep   = SKIPPED\n');
    end

    % Legacy centered finite-difference extraction.
    [K,Cmat] = calculateBearingKC( ...
        q,dxPerturbSelected,dvPerturbSelected, ...
        R,L,bearing,omega,Ntheta,Nz,muKC,PbaseKC, ...
        coefficientPressureTol,coefficientMaxPressureIter,omegaSOR);

    fprintf('\n====================================================\n');
    fprintf(' SELECTED LINEARIZATION PERTURBATIONS\n');
    fprintf('====================================================\n');
    fprintf('Selected dx/C = %.3e\n',dxPerturbSelected/Cclr);
    fprintf('Selected dx   = %.4e m\n',dxPerturbSelected);
    fprintf('Selected dv   = %.4e m/s\n',dvPerturbSelected);
    fprintf('====================================================\n');
end

%% ============================================================
% 9) K/C MESH VERIFICATION
% =============================================================

KmeshError = NaN;
CmeshError = NaN;
KCmeshVerified = false;
KCmeshStatusText = 'SKIPPED';

if doKCMeshVerification

    fprintf('\n====================================================\n');
    fprintf(' ROTORDYNAMIC COEFFICIENT MESH VERIFICATION\n');
    fprintf('====================================================\n');

    if meshIndex < length(meshLevels)

        NthetaFine = meshLevels(meshIndex+1);

        dthetaFine = 2*pi/NthetaFine;
        dxFine = R*dthetaFine;

        NzFine = ceil(L/dxFine)+1;
        if mod(NzFine,2)==0, NzFine = NzFine+1; end
        NzFine = min(NzFine,maxNz);
        if mod(NzFine,2)==0, NzFine = NzFine+1; end

        dzFine = L/(NzFine-1);

        fprintf('Selected mesh : %d x %d\n',Ntheta,Nz);
        fprintf('Fine mesh     : %d x %d\n',NthetaFine,NzFine);
        fprintf('Fine dx/dz    : %.3f\n',dxFine/dzFine);

        [eqFine,thermalFine] = solveCoupledBearing( ...
            R,L,bearing,omega,W,NthetaFine,NzFine,q, ...
            coefficientPressureTol,coefficientMaxPressureIter,omegaSOR, ...
            coefficientEquilibriumTol,maxEquilibriumIter,dqNewtonPerturb,maxQstep,maxEpsilon, ...
            fullTHD,muIso,oil,thd,thermalState,false);

        if isDirectPerturbedKC

            [Kfine,Cfine] = calculateBearingKCDirectPerturbed( ...
                eqFine.q,R,L,bearing,omega,NthetaFine,NzFine, ...
                thermalFine.muHydro,eqFine.P);

        else

            [Kfine,Cfine] = calculateBearingKC( ...
                eqFine.q,dxPerturbSelected,dvPerturbSelected, ...
                R,L,bearing,omega,NthetaFine,NzFine,thermalFine.muHydro,eqFine.P, ...
                coefficientPressureTol,coefficientMaxPressureIter,omegaSOR);
        end

        KmeshError = norm(Kfine-K,'fro')/max(norm(Kfine,'fro'),eps);
        CmeshError = norm(Cfine-Cmat,'fro')/max(norm(Cfine,'fro'),eps);

        overallKCmeshError = max(KmeshError,CmeshError);
        KCmeshVerified = overallKCmeshError <= coefficientMeshTolerance;

        fprintf('\nK matrix mesh change = %.4f %%\n',100*KmeshError);
        fprintf('C matrix mesh change = %.4f %%\n',100*CmeshError);
        fprintf('Overall K/C change   = %.4f %%\n',100*overallKCmeshError);

        if KCmeshVerified
            KCmeshStatusText = 'VERIFIED';
        else
            KCmeshStatusText = 'NOT VERIFIED';
        end

    else
        KCmeshStatusText = 'NO FINER MESH';
    end

else

    fprintf('\n====================================================\n');
    fprintf(' K/C MESH VERIFICATION SKIPPED (PRODUCTION MODE)\n');
    fprintf('====================================================\n');
end

%% ============================================================
% 10) BEARING-ONLY STABILITY / ROOT LOCUS
% =============================================================

fprintf('\n====================================================\n');
fprintf(' STABILITY / ROOT LOCUS STUDY\n');
fprintf('====================================================\n');

massSweep = logspace(-1,5,300);

eigTracked = zeros(4,length(massSweep));
maxRealEig = zeros(size(massSweep));

previousEig = [];

for im = 1:length(massSweep)

    m = massSweep(im);
    M2 = m*eye(2);

    Astate = [zeros(2) eye(2); -M2\K -M2\Cmat];
    eigValues = eig(Astate);

    if im == 1
        [~,ord] = sort(imag(eigValues));
        eigValues = eigValues(ord);
    else
        permList = perms(1:4);
        bestCost = inf;
        bestEig = eigValues;

        for pp = 1:size(permList,1)
            trial = eigValues(permList(pp,:));
            trial = trial(:);
            cost = sum(abs(trial-previousEig));

            if cost < bestCost
                bestCost = cost;
                bestEig = trial;
            end
        end

        eigValues = bestEig;
    end

    eigTracked(:,im) = eigValues;
    previousEig = eigValues;

    maxRealEig(im) = max(real(eigValues));
end

crossIdx = find(maxRealEig(1:end-1).*maxRealEig(2:end)<=0,1,'first');

criticalMass = NaN;
instabilityHz = NaN;
instabilityRad = NaN;
whirlRatio = NaN;

if ~isempty(crossIdx)

    mLo = massSweep(crossIdx);
    mHi = massSweep(crossIdx+1);

    for ib = 1:60

        mMid = sqrt(mLo*mHi);

        fLo = stabilityMargin(mLo,K,Cmat);
        fMid = stabilityMargin(mMid,K,Cmat);

        if fLo*fMid <= 0
            mHi = mMid;
        else
            mLo = mMid;
        end
    end

    criticalMass = sqrt(mLo*mHi);

    Mcrit = criticalMass*eye(2);

    Acrit = [zeros(2) eye(2); -Mcrit\K -Mcrit\Cmat];
    eigCrit = eig(Acrit);

    [~,icrit] = min(abs(real(eigCrit)));
    lambdaCrit = eigCrit(icrit);

    instabilityRad = abs(imag(lambdaCrit));
    instabilityHz = instabilityRad/(2*pi);
    whirlRatio = instabilityRad/max(abs(omega),eps);

    fprintf('\nCritical journal mass = %.4f kg\n',criticalMass);
    fprintf('Instability frequency = %.4f Hz\n',instabilityHz);
    fprintf('Instability frequency = %.4f rad/s\n',instabilityRad);
    fprintf('Whirl frequency ratio = %.4f X\n',whirlRatio);

else
    fprintf('No stability crossing found in selected mass range.\n');
end

%% ============================================================
% 11) FINAL PRINTED RESULTS
% =============================================================

fprintf('\n====================================================\n');
fprintf(' FINAL BEARING PERFORMANCE\n');
fprintf('====================================================\n');
fprintf('Bearing type             = %s\n',bearing.displayName);
fprintf('Solver mode              = %s\n',solverMode);
fprintf('Pressure solver          = %s\n',bearing.pressureSolver);
fprintf('Equilibrium strategy      = %s\n', ...
    ternary(isProductionMode,'Fast q solve + tight P refresh','Validation + final solve'));

fprintf('Speed                    = %.1f rpm\n',N);
fprintf('Load                     = %.2f N\n',W);
fprintf('Eccentricity ratio       = %.5f\n',eq.epsilon);
fprintf('Eccentricity             = %.3f um\n',eq.epsilon*bearing.Cb*1e6);
fprintf('Journal center X         = %.3f um\n',q(1)*bearing.Cb*1e6);
fprintf('Journal center Y         = %.3f um\n',q(2)*bearing.Cb*1e6);
fprintf('Journal center angle     = %.2f deg\n',eq.phiDeg);
fprintf('Minimum film thickness   = %.3f um\n',eq.hmin*1e6);
fprintf('Maximum film thickness   = %.3f um\n',eq.hmax*1e6);
fprintf('Maximum pressure         = %.3f MPa\n',eq.Pmax/1e6);
fprintf('Fluid force Fx           = %.3f N\n',eq.Fx);
fprintf('Fluid force Fy           = %.3f N\n',eq.Fy);

fprintf('\n---------------- THERMAL ---------------------------\n');

if fullTHD

    fprintf('Mode                     = COUPLED FILM-THD\n');
    fprintf('Supply temperature       = %.3f C\n',TinC);
    fprintf('Mean film temperature    = %.3f C\n',thermalState.TmeanC);
    fprintf('Maximum film temperature = %.3f C\n',thermalState.TmaxC);
    fprintf('Minimum film temperature = %.3f C\n',thermalState.TminC);

    fprintf('Mean effective viscosity = %.6e Pa.s\n',mean(muHydro(:)));
    fprintf('Minimum viscosity        = %.6e Pa.s\n',min(muHydro(:)));
    fprintf('Maximum viscosity        = %.6e Pa.s\n',max(muHydro(:)));
    fprintf('Thermal iterations       = %d\n',thermalState.iterations);

    fprintf('\n------------- THERMAL ENERGY CHECK -----------------\n');
    fprintf('Mixed outlet temperature = %.3f C\n',energy.ToutMixC);
    fprintf('Oil enthalpy rise        = %.5f kW\n',energy.Qoil/1000);
    fprintf('Heat to bush             = %.5f kW\n',energy.Qbush/1000);
    fprintf('Heat to journal          = %.5f kW\n',energy.Qjournal/1000);
    fprintf('Net wall heat removal    = %.5f kW\n',energy.Qwalls/1000);
    fprintf('Mechanical power input   = %.5f kW\n',PowerLoss/1000);
    fprintf('Accounted thermal power  = %.5f kW\n',energy.Qaccounted/1000);
    fprintf('Energy residual          = %.5f kW\n',energy.residualW/1000);
    fprintf('Energy residual          = %.3f %%\n',energy.residualPct);

    if abs(energy.residualPct) > 10
        fprintf('ENERGY CHECK STATUS      = REVIEW REQUIRED\n');
    else
        fprintf('ENERGY CHECK STATUS      = ACCEPTABLE FIRST-PASS\n');
    end

else
    fprintf('Mode                     = ISOTHERMAL\n');
    fprintf('Constant viscosity       = %.6e Pa.s\n',muIso);
end

[~,~,kappaThetaFinal,kappaAxialFinal,CfFinal,ReFinal,flowBlendFinal] = ...
    reynoldsTransportFields(h,muHydro,R,omega,bearing);

activeHydro3 = repmat(eq.activeMask,1,size(muHydro,2));
ReActive = ReFinal(activeHydro3);
kThetaActive = kappaThetaFinal(activeHydro3);
kAxialActive = kappaAxialFinal(activeHydro3);
CfActive = CfFinal(activeHydro3);

fprintf('\n---------------- FLOW REGIME -----------------------\n');
fprintf('Turbulence model         = %s\n',bearing.turbulenceModel);
fprintf('Turbulence density       = %.2f kg/m^3\n',bearing.turbulenceDensity);
fprintf('Local Reynolds number    = %.1f to %.1f\n',min(ReActive),max(ReActive));

if strcmpi(bearing.turbulenceModel,'Auto')
    fprintf('AUTO laminar limit       = %.1f\n',bearing.autoReLaminarMax);
    fprintf('AUTO turbulent limit     = %.1f\n',bearing.autoReTurbulentMin);
    fprintf('AUTO turbulence blend    = %.4f\n',flowBlendFinal);

    if flowBlendFinal <= 1e-12
        fprintf('Effective flow regime    = LAMINAR\n');
    elseif flowBlendFinal >= 1-1e-12
        fprintf('Effective flow regime    = FULL CONSTANTINESCU\n');
    else
        fprintf('Effective flow regime    = TRANSITION\n');
    end
elseif strcmpi(bearing.turbulenceModel,'Laminar')
    fprintf('Effective flow regime    = LAMINAR (FORCED)\n');
else
    fprintf('Effective flow regime    = CONSTANTINESCU (FORCED)\n');
end

fprintf('Kappa circumferential    = %.4f to %.4f\n',min(kThetaActive),max(kThetaActive));
fprintf('Kappa axial              = %.4f to %.4f\n',min(kAxialActive),max(kAxialActive));
fprintf('Couette shear factor Cf  = %.4f to %.4f\n',min(CfActive),max(CfActive));

fprintf('\n---------------- FLOW ------------------------------\n');
fprintf('Left side leakage        = %.4f L/min\n',Qleft*60000);
fprintf('Right side leakage       = %.4f L/min\n',Qright*60000);
fprintf('Total side leakage       = %.4f L/min\n',Qtotal*60000);

fprintf('\n--------------- FRICTION ---------------------------\n');
fprintf('Friction torque          = %.5f N.m\n',FrictionTorque);
fprintf('Power loss               = %.5f kW\n',PowerLoss/1000);
fprintf('Equivalent friction force= %.3f N\n',EquivalentFrictionForce);
fprintf('Friction coefficient     = %.6f\n',FrictionCoefficient);

fprintf('\n--------------- DIMENSIONLESS ----------------------\n');
fprintf('Unit bearing load        = %.5f MPa\n',unitLoad/1e6);
fprintf('Sommerfeld number        = %.6f\n',Sommerfeld);

fprintf('\n--------------- STIFFNESS [N/m] --------------------\n');
fprintf('Kxx = %14.5e\n',K(1,1));
fprintf('Kxy = %14.5e\n',K(1,2));
fprintf('Kyx = %14.5e\n',K(2,1));
fprintf('Kyy = %14.5e\n',K(2,2));

fprintf('\n--------------- DAMPING [N.s/m] --------------------\n');
fprintf('Cxx = %14.5e\n',Cmat(1,1));
fprintf('Cxy = %14.5e\n',Cmat(1,2));
fprintf('Cyx = %14.5e\n',Cmat(2,1));
fprintf('Cyy = %14.5e\n',Cmat(2,2));

fprintf('\n--------------- LINEARIZATION ----------------------\n');
fprintf('K/C method               = %s\n',char(dynamicCoeffMethod));

if isDirectPerturbedKC
    fprintf('Displacement step dx     = NOT USED\n');
    fprintf('Velocity step dv         = NOT USED\n');
    fprintf('Cavitation treatment     = FROZEN EQUILIBRIUM ACTIVE SET\n');
else
    fprintf('Selected dx/C            = %.3e\n',dxPerturbSelected/Cclr);
    fprintf('Selected dx              = %.4e m\n',dxPerturbSelected);
    fprintf('Selected dv              = %.4e m/s\n',dvPerturbSelected);
end

if fullTHD
    fprintf('Thermal field for K/C    = FROZEN AT EQUILIBRIUM\n');
end

fprintf('\n--------------- K/C MESH VERIFICATION --------------\n');

if isfinite(KmeshError)
    fprintf('K mesh change            = %.4f %%\n',100*KmeshError);
    fprintf('C mesh change            = %.4f %%\n',100*CmeshError);
end

fprintf('K/C mesh status          = %s\n',KCmeshStatusText);

fprintf('\n--------------- STABILITY --------------------------\n');

if isfinite(criticalMass)
    fprintf('Critical journal mass    = %.4f kg\n',criticalMass);
    fprintf('Instability frequency    = %.4f Hz\n',instabilityHz);
    fprintf('Whirl frequency          = %.4f rad/s\n',instabilityRad);
    fprintf('Whirl frequency ratio    = %.4f X\n',whirlRatio);
end

fprintf('====================================================\n');
fprintf('Total solver runtime      = %.2f s\n',toc(totalRunTimer));

%% ============================================================
% 12) ENGINEERING PLOTS
% =============================================================

thetaDeg = theta*180/pi;

% ------------------------------------------------------------
% Plot 1: 2-D pressure contour
% ------------------------------------------------------------
figure('Name','01 - Pressure Contour','Color','w');
contourf(thetaDeg,z,P'/1e6,30,'LineColor','none');
xlabel('\theta [deg]');
ylabel('Axial position z [m]');
title('Journal Bearing Pressure Distribution [MPa]');
colorbar;
grid on;

% ------------------------------------------------------------
% Plot 2: 3-D pressure surface -- explicit pad/groove separation
% ------------------------------------------------------------
figure('Name','02 - 3D Pressure','Color','w');
hold on;

if isContinuousBoreBearing(bearing)

    surf(thetaDeg,z,(P/1e6)', ...
        'EdgeColor','none');

else

    for ip = 1:bearing.numberOfPads

        padMask = eq.activeMask & (eq.padIndex == ip);

        transitions = diff([false; padMask; false]);
        iStart = find(transitions==1);
        iEnd   = find(transitions==-1)-1;

        for iseg = 1:numel(iStart)

            idx = iStart(iseg):iEnd(iseg);

            if numel(idx)<2
                continue;
            end

            surf(thetaDeg(idx),z,(P(idx,:)/1e6)', ...
                'EdgeColor','none');
        end
    end
end

xlabel('\theta [deg]');
ylabel('z [m]');
zlabel('Pressure [MPa]');
title('3-D Hydrodynamic Pressure Field');
view(42,28);
grid on;
box on;
xlim([0 360]);
ylim([min(z) max(z)]);
zlim([0 max(P(:))/1e6*1.06 + eps]);
colorbar;

if ~isContinuousBoreBearing(bearing)

    for ip = 1:bearing.numberOfPads

        th1 = mod(bearing.pad(ip).theta1Deg,360);
        th2 = mod(bearing.pad(ip).theta2Deg,360);

        plot3([th1 th1],[min(z) max(z)],[0 0], ...
            'k--','LineWidth',1.15);

        plot3([th2 th2],[min(z) max(z)],[0 0], ...
            'k--','LineWidth',1.15);
    end
end

% ------------------------------------------------------------
% Plot 3: Mid-plane pressure
% ------------------------------------------------------------
[~,jmid] = min(abs(z));

figure('Name','03 - Midplane Pressure','Color','w');
plot(thetaDeg,P(:,jmid)/1e6,'LineWidth',2);
xlabel('\theta [deg]');
ylabel('Pressure [MPa]');
title('Mid-plane Pressure Distribution');
grid on;
xlim([0 360]);

% ------------------------------------------------------------
% Plot 4: Film thickness
% ------------------------------------------------------------
figure('Name','04 - Film Thickness','Color','w');
hPlot = h;
hPlot(~eq.activeMask) = NaN;
plot(thetaDeg,hPlot*1e6,'LineWidth',2);
xlabel('\theta [deg]');
ylabel('Film thickness [\mum]');
title('Circumferential Film Thickness');
grid on;
xlim([0 360]);

% ------------------------------------------------------------
% Plot 5 removed in V3.5: Journal equilibrium position plot disabled
% ------------------------------------------------------------
% Plot 6: Stiffness perturbation convergence
% ------------------------------------------------------------
if doPerturbationStudy
    figure('Name','06 - Stiffness Perturbation Convergence','Color','w');

    Kx = dxFractions(2:end);
    Ky = 100*KpertError(1:end-1);

    loglog(Kx,Ky,'o-','LineWidth',2,'MarkerSize',7);
    hold on;

    yline(100*perturbTolerance,'--','Tolerance','LineWidth',1.5);
    xline(dxPerturbSelected/Cclr,'--','Selected','LineWidth',1.5);

    xlabel('Finer displacement perturbation \Deltax/C');
    ylabel('Successive K matrix change [%]');
    title('Stiffness Perturbation Convergence');
    grid on;
end

% ------------------------------------------------------------
% Plot 7: Damping perturbation convergence
% ------------------------------------------------------------
if doPerturbationStudy
    figure('Name','07 - Damping Perturbation Convergence','Color','w');

    Cx = dvValues(2:end);
    Cy = 100*CpertError(1:end-1);

    loglog(Cx,Cy,'o-','LineWidth',2,'MarkerSize',7);
    hold on;

    yline(100*perturbTolerance,'--','Tolerance','LineWidth',1.5);
    xline(dvPerturbSelected,'--','Selected','LineWidth',1.5);

    xlabel('Finer velocity perturbation \Deltav [m/s]');
    ylabel('Successive C matrix change [%]');
    title('Damping Perturbation Convergence');
    grid on;
end

% ------------------------------------------------------------
% Plot 8 removed in V3.5: K matrix heat map disabled
% ------------------------------------------------------------
% Plot 9 removed in V3.5: C matrix heat map disabled
% ------------------------------------------------------------
% Plot 10 removed in V3.5: Root locus plot disabled
% ------------------------------------------------------------
% Plot 11: Stability margin vs journal mass
% ------------------------------------------------------------
figure('Name','11 - Stability Margin','Color','w');

semilogx(massSweep,maxRealEig,'LineWidth',2);
hold on;
yline(0,'k--','Neutral stability','LineWidth',1.2);

if isfinite(criticalMass)
    xline(criticalMass,'--', ...
        sprintf('M_{crit}=%.1f kg',criticalMass), ...
        'LineWidth',1.2);
end

xlabel('Journal mass [kg]');
ylabel('Maximum Real(\lambda) [1/s]');
title('Bearing-only Stability Margin');
grid on;

% ------------------------------------------------------------
% THD-specific plots
% ------------------------------------------------------------
if fullTHD

    % Plot 12: mean film temperature map
    figure('Name','12 - Mean Film Temperature','Color','w');

    contourf(thetaDeg,z,thermalState.TbulkHydroC',30,'LineColor','none');

    xlabel('\theta [deg]');
    ylabel('z [m]');
    title('Mean Oil-film Temperature [degC]');
    colorbar;
    grid on;

    % Plot 13: viscosity map
    figure('Name','13 - Effective Viscosity','Color','w');

    contourf(thetaDeg,z,muHydro'*1e3,30,'LineColor','none');

    xlabel('\theta [deg]');
    ylabel('z [m]');
    title('Effective Dynamic Viscosity [mPa.s]');
    colorbar;
    grid on;

    % Plot 14: mid-plane temperature vs theta
    figure('Name','14 - Circumferential Temperature','Color','w');

    plot(thetaDeg,thermalState.TbulkHydroC(:,jmid),'LineWidth',2);
    hold on;

    yline(TinC,'--','Supply temperature');
    yline(TbushBulkC,':','Bush bulk temperature');
    yline(TjournalBulkC,':','Journal bulk temperature');

    xlabel('\theta [deg]');
    ylabel('Temperature [degC]');
    title('Mid-plane Circumferential Oil Temperature');
    grid on;
    xlim([0 360]);

    % Plot 15: thermal convergence
    figure('Name','15 - THD Convergence','Color','w');

    semilogy(thermalState.history.iter, ...
             thermalState.history.errT,'o-','LineWidth',1.6);
    hold on;

    semilogy(thermalState.history.iter, ...
             thermalState.history.errMu,'s-','LineWidth',1.6);

    yline(thd.tolT,'--','Temperature tolerance');
    yline(thd.tolMu,'--','Viscosity tolerance');

    xlabel('THD outer iteration');
    ylabel('Relative change');
    title('THD Outer-loop Convergence');
    legend('Temperature','Viscosity','Location','best');
    grid on;

    % Plot 16: energy balance
    figure('Name','16 - THD Energy Balance','Color','w');

    vals = [PowerLoss energy.Qoil energy.Qbush energy.Qjournal]/1000;

    bar(vals);

    set(gca,'XTick',1:4);
    set(gca,'XTickLabel', ...
        {'Mechanical input','Oil enthalpy rise','To bush','To journal'});

    ylabel('Power [kW]');
    title(sprintf('THD Energy Diagnostic   Residual = %.2f %%', ...
        energy.residualPct));
    grid on;
end

%% ============================================================
% LOCAL FUNCTION 1: COUPLED EQUILIBRIUM + THD
% =============================================================


%% ============================================================
% 13) BENCHMARK-STYLE COMBINED SUMMARY
%     Text + true-scale bearing sketch + 3-D pressure
% =============================================================

figSummary = figure( ...
    'Name','17 - Benchmark Bearing Summary', ...
    'Color','w', ...
    'Position',[45 45 1650 875]);

% ------------------------------------------------------------
% LEFT PANEL: boxed numerical summary
% ------------------------------------------------------------

if N >= 0
    rotationText = 'CCW';
else
    rotationText = 'CW';
end

if fullTHD
    thermalText = sprintf([ ...
        '\nTHERMAL\n' ...
        'Mode        = THD\n' ...
        'T_in        = %.2f C\n' ...
        'T_mean      = %.2f C\n' ...
        'T_max       = %.2f C\n' ...
        'mu_mean     = %.4f mPa.s\n'], ...
        TinC,thermalState.TmeanC,thermalState.TmaxC, ...
        mean(muHydro(:))*1e3);
else
    thermalText = sprintf([ ...
        '\nTHERMAL\n' ...
        'Mode        = Isothermal\n' ...
        'mu          = %.4f mPa.s\n'], ...
        muIso*1e3);
end

if isfinite(criticalMass)
    stabilityText = sprintf([ ...
        '\nSTABILITY\n' ...
        'Mcrit       = %.3f kg\n' ...
        'Whirl freq  = %.3f Hz\n' ...
        'Whirl ratio = %.4f X\n'], ...
        criticalMass,instabilityHz,whirlRatio);
else
    stabilityText = sprintf([ ...
        '\nSTABILITY\n' ...
        'No stability crossing in selected mass range\n']);
end

leftBoxText = sprintf([ ...
    '%s\n' ...
    '----------------------------------------\n' ...
    'L           = %.4f m\n' ...
    'D           = %.4f m\n' ...
    'Cb          = %.3f um\n' ...
    '2Cb/D       = %.6f\n' ...
    'Speed       = %.0f rpm (%s)\n' ...
    'Load        = %.2f N\n' ...
    'Unit load   = %.5f MPa\n' ...
    'Sommerfeld  = %.5f\n' ...
    '\n' ...
    'e/Cb        = %.4f\n' ...
    'Attitude    = %.2f deg\n' ...
    'hmin        = %.3f um\n' ...
    'Pmax        = %.4f MPa\n' ...
    'Power loss  = %.4f kW\n' ...
    'Qside       = %.4f L/min\n' ...
    '\n' ...
    'STIFFNESS [N/m]\n' ...
    'Kxx = % .4E   Kxy = % .4E\n' ...
    'Kyx = % .4E   Kyy = % .4E\n' ...
    '\n' ...
    'DAMPING [N.s/m]\n' ...
    'Cxx = % .4E   Cxy = % .4E\n' ...
    'Cyx = % .4E   Cyy = % .4E\n' ...
    '%s' ...
    '%s'], ...
    bearing.displayName, ...
    L,D,bearing.Cb*1e6,2*bearing.Cb/D, ...
    N,rotationText,W,unitLoad/1e6,Sommerfeld, ...
    eq.epsilon,eq.phiDeg,eq.hmin*1e6,eq.Pmax/1e6, ...
    PowerLoss/1000,Qtotal*60000, ...
    K(1,1),K(1,2),K(2,1),K(2,2), ...
    Cmat(1,1),Cmat(1,2),Cmat(2,1),Cmat(2,2), ...
    stabilityText,thermalText);

annotation(figSummary,'textbox', ...
    [0.025 0.085 0.245 0.82], ...
    'String',leftBoxText, ...
    'Interpreter','none', ...
    'FitBoxToText','off', ...
    'BackgroundColor',[0.985 0.985 0.985], ...
    'EdgeColor',[0.55 0.55 0.55], ...
    'LineWidth',1.2, ...
    'Margin',10, ...
    'FontName','Courier New', ...
    'FontSize',10.5, ...
    'VerticalAlignment','top');

% ------------------------------------------------------------
% CENTER PANEL: BOOK-STYLE bearing sketch
% ------------------------------------------------------------
axGeo = axes('Parent',figSummary, ...
    'Position',[0.285 0.13 0.30 0.73]);

hold(axGeo,'on');
axis(axGeo,'equal');
axis(axGeo,'off');

% ------------------------------------------------------------
% IMPORTANT VISUALIZATION NOTE
% ------------------------------------------------------------
% A real journal clearance is only ~0.1 mm against a ~50 mm radius.
% Plotting literal dimensional scale makes the journal and bore visually
% indistinguishable. The textbook/DyRoBeS-style sketch therefore uses an
% exaggerated clearance while preserving the ACTUAL geometry ratios and
% journal-center direction.
%
% Display journal radius = 1.0
% Base clearance display gap = 0.12
% Local lobe clearance scales with h_centered/Cb.
% Journal displacement scales with q = e/Cb.
% ------------------------------------------------------------

displayRj  = 1.00;
displayCb  = 0.12;

[hCentered,~,geomCentered] = bearingFilmGeometry( ...
    bearing,[0;0],theta);

% Actual centered local clearance normalized by base clearance.
clearanceRatio = hCentered / bearing.Cb;

% Exaggerated bore radius, but exact circumferential geometry ratio.
RbDisplay = displayRj + displayCb*clearanceRatio;

% Equilibrium center shown consistently on the same exaggerated-clearance
% scale: x/Cb and y/Cb are preserved.
xJournalCenterDisplay = displayCb*q(1);
yJournalCenterDisplay = displayCb*q(2);

% Journal itself stays large, like the book illustration.
xJournal = xJournalCenterDisplay + displayRj*cos(theta);
yJournal = yJournalCenterDisplay + displayRj*sin(theta);

fill(axGeo,xJournal,yJournal,[1.00 1.00 1.00], ...
    'EdgeColor',[0.10 0.10 0.10], ...
    'LineWidth',2.2);

% ------------------------------------------------------------
% Draw actual load-carrying pad arcs separately.
% This guarantees that oil grooves are visibly open.
% ------------------------------------------------------------
xBore = RbDisplay.*cos(theta);
yBore = RbDisplay.*sin(theta);

if isContinuousBoreBearing(bearing)

    plot(axGeo,xBore,yBore, ...
        'Color',[0.00 0.25 0.95], ...
        'LineWidth',3.0);

else

    for ip = 1:bearing.numberOfPads

        padMask = geomCentered.activeMask & ...
                  (geomCentered.padIndex == ip);

        % Plot each contiguous pad segment independently, including pads
        % that wrap across 0 degrees.
        transitions = diff([false; padMask; false]);
        iStart = find(transitions==1);
        iEnd   = find(transitions==-1)-1;

        for iseg = 1:numel(iStart)
            idx = iStart(iseg):iEnd(iseg);

            plot(axGeo,xBore(idx),yBore(idx), ...
                'Color',[0.00 0.25 0.95], ...
                'LineWidth',3.0);
        end
    end
end

% ------------------------------------------------------------
% Pressure envelope similar to the book illustration
% ------------------------------------------------------------
Pmid = P(:,jmid);

if max(Pmid)>0
    pNorm = Pmid/max(Pmid);
else
    pNorm = zeros(size(Pmid));
end

pressureScale = 0.75;
Rpressure = RbDisplay + pressureScale*pNorm;

xPressure = Rpressure.*cos(theta);
yPressure = Rpressure.*sin(theta);

if isContinuousBoreBearing(bearing)

    pressureMask = Pmid > 0.005*max(Pmid);

    transitions = diff([false; pressureMask; false]);
    iStart = find(transitions==1);
    iEnd   = find(transitions==-1)-1;

    for iseg = 1:numel(iStart)
        idx = iStart(iseg):iEnd(iseg);

        plot(axGeo,xPressure(idx),yPressure(idx), ...
            'Color',[1.00 0.00 1.00], ...
            'LineWidth',3.0);

        hatchStep = max(1,round(numel(idx)/22));

        for kk = idx(1:hatchStep:end)
            plot(axGeo, ...
                [xBore(kk) xPressure(kk)], ...
                [yBore(kk) yPressure(kk)], ...
                'Color',[1.00 0.00 1.00], ...
                'LineWidth',0.95);
        end
    end

else

    for ip = 1:bearing.numberOfPads

        pressureMask = ...
            geomCentered.activeMask & ...
            (geomCentered.padIndex == ip) & ...
            (Pmid > 0.005*max(Pmid));

        transitions = diff([false; pressureMask; false]);
        iStart = find(transitions==1);
        iEnd   = find(transitions==-1)-1;

        for iseg = 1:numel(iStart)
            idx = iStart(iseg):iEnd(iseg);

            plot(axGeo,xPressure(idx),yPressure(idx), ...
                'Color',[1.00 0.00 1.00], ...
                'LineWidth',3.0);

            hatchStep = max(1,round(numel(idx)/18));

            for kk = idx(1:hatchStep:end)
                plot(axGeo, ...
                    [xBore(kk) xPressure(kk)], ...
                    [yBore(kk) yPressure(kk)], ...
                    'Color',[1.00 0.00 1.00], ...
                    'LineWidth',0.95);
            end
        end
    end
end

% ------------------------------------------------------------
% Bearing center, journal center, eccentricity vector
% ------------------------------------------------------------
plot(axGeo,0,0,'bo', ...
    'MarkerFaceColor','b', ...
    'MarkerSize',8);

plot(axGeo,xJournalCenterDisplay,yJournalCenterDisplay,'ro', ...
    'MarkerFaceColor','r', ...
    'MarkerSize',6);

plot(axGeo, ...
    [0 xJournalCenterDisplay], ...
    [0 yJournalCenterDisplay], ...
    'Color',[0.00 0.75 0.00], ...
    'LineWidth',1.5);

% X/Y reference axes
axisLen = 0.45;

plot(axGeo,[0 axisLen],[0 0], ...
    'Color',[0.00 0.00 0.60], ...
    'LineWidth',2.0);

plot(axGeo,[0 0],[0 axisLen], ...
    'Color',[0.00 0.00 0.60], ...
    'LineWidth',2.0);

text(axGeo,1.08*axisLen,0,'X', ...
    'Color',[0 0 0.6], ...
    'FontSize',16, ...
    'FontWeight','bold');

text(axGeo,0.02*axisLen,1.08*axisLen,'Y', ...
    'Color',[0 0 0.6], ...
    'FontSize',16, ...
    'FontWeight','bold');

% Load arrow
quiver(axGeo,0,0,0,-0.62,0, ...
    'Color','r', ...
    'LineWidth',2.6, ...
    'MaxHeadSize',0.75);

text(axGeo,0.06,-0.71,'W', ...
    'Color','r', ...
    'FontSize',18, ...
    'FontWeight','bold');

% Rotation arrow
thetaArrow = linspace(pi/4,2.15,100);
rArrow = 0.83;

plot(axGeo, ...
    rArrow*cos(thetaArrow), ...
    rArrow*sin(thetaArrow), ...
    'Color',[0 0.65 0], ...
    'LineWidth',2.8);

plot(axGeo, ...
    rArrow*cos(thetaArrow(end)), ...
    rArrow*sin(thetaArrow(end)), ...
    '<', ...
    'Color',[0 0.65 0], ...
    'MarkerFaceColor',[0 0.65 0], ...
    'MarkerSize',8);

% Minimum-film location marker on bearing surface
hForMin = h;
hForMin(~eq.activeMask) = inf;
[~,ihmin] = min(hForMin);

plot(axGeo, ...
    xBore(ihmin),yBore(ihmin), ...
    'o', ...
    'MarkerSize',8, ...
    'MarkerFaceColor','y', ...
    'MarkerEdgeColor','k');

% Plot limits
allGeometry = [ ...
    xBore(:); yBore(:); ...
    xJournal(:); yJournal(:); ...
    xPressure(:); yPressure(:)];

limGeo = 1.10*max(abs(allGeometry));

xlim(axGeo,[-limGeo limGeo]);
ylim(axGeo,[-limGeo limGeo]);

title(axGeo,'Bearing / Journal / Pressure Envelope', ...
    'FontSize',14, ...
    'FontWeight','bold');

text(axGeo,0,-1.03*limGeo, ...
    'Clearance exaggerated for visualization', ...
    'HorizontalAlignment','center', ...
    'FontSize',9);

% ------------------------------------------------------------
% RIGHT PANEL: 3-D pressure field with EXPLICIT groove openings
% ------------------------------------------------------------
ax3D = axes('Parent',figSummary, ...
    'Position',[0.625 0.14 0.34 0.71]);

hold(ax3D,'on');

if isContinuousBoreBearing(bearing)

    surf(ax3D,thetaDeg,z,(P/1e6)', ...
        'EdgeColor','none');

else

    % Plot EACH pad independently. No surface exists in the groove.
    for ip = 1:bearing.numberOfPads

        padMask = eq.activeMask & (eq.padIndex == ip);

        transitions = diff([false; padMask; false]);
        iStart = find(transitions==1);
        iEnd   = find(transitions==-1)-1;

        for iseg = 1:numel(iStart)

            idx = iStart(iseg):iEnd(iseg);

            % Need at least two theta stations for surf.
            if numel(idx) < 2
                continue;
            end

            thetaPad = thetaDeg(idx);
            Ppad = P(idx,:)/1e6;

            surf(ax3D,thetaPad,z,Ppad', ...
                'EdgeColor','none');
        end
    end
end

xlabel(ax3D,'\theta [deg]');
ylabel(ax3D,'z [m]');
zlabel(ax3D,'P [MPa]');

title(ax3D,'3-D Hydrodynamic Pressure Field', ...
    'FontSize',14, ...
    'FontWeight','bold');

view(ax3D,[-38 25]);
grid(ax3D,'off');
box(ax3D,'off');
xlim(ax3D,[0 360]);
ylim(ax3D,[min(z) max(z)]);
zlim(ax3D,[0 max(P(:))/1e6*1.06 + eps]);
colorbar(ax3D);

% Pad edge / groove labels
if ~isContinuousBoreBearing(bearing)

    zText = 0;

    for ip = 1:bearing.numberOfPads

        th1 = mod(bearing.pad(ip).theta1Deg,360);
        th2 = mod(bearing.pad(ip).theta2Deg,360);

        plot3(ax3D,[th1 th1],[min(z) max(z)],[0 0], ...
            'k--','LineWidth',1.0);

        plot3(ax3D,[th2 th2],[min(z) max(z)],[0 0], ...
            'k--','LineWidth',1.0);
    end
end

sgtitle(figSummary, ...
    sprintf('%s - Benchmark Summary',bearing.displayName), ...
    'FontSize',18, ...
    'FontWeight','bold');

annotation(figSummary,'textbox',[0.285 0.025 0.68 0.035], ...
    'String',['Bearing and journal are plotted at true dimensional scale.  ', ...
              'Pressure envelope is normalized only for visualization.'], ...
    'EdgeColor','none', ...
    'HorizontalAlignment','center', ...
    'FontSize',9.5);



%% ============================================================
% 14) JOURNAL-CENTER CLEARANCE ZOOM
% =============================================================
%
% This plot zooms directly into the CENTER-MOTION clearance region.
% The boundary is calculated numerically from the actual contact condition:
%
%     min_theta,z h(theta,z,q) = 0
%
% Therefore it remains valid for Plain, FixedLobe and TaperLand bearings.

[centerEnvelopeQx,centerEnvelopeQy] = ...
    journalCenterClearanceEnvelope(bearing,L,241);

figure('Name','18 - Journal Center Clearance Zoom','Color','w');
hold on;

plot(centerEnvelopeQx*bearing.Cb*1e6, ...
     centerEnvelopeQy*bearing.Cb*1e6, ...
     'k-','LineWidth',2.2);

plot(0,0,'k+','MarkerSize',11,'LineWidth',1.8);

plot(q(1)*bearing.Cb*1e6,q(2)*bearing.Cb*1e6, ...
    'o','MarkerSize',9,'LineWidth',2.0);

plot([0 q(1)*bearing.Cb*1e6], ...
     [0 q(2)*bearing.Cb*1e6], ...
     '--','LineWidth',1.2);

text(q(1)*bearing.Cb*1e6,q(2)*bearing.Cb*1e6, ...
    sprintf('  %.0f rpm',N), ...
    'VerticalAlignment','bottom');

axis equal;
grid on;
xlabel('Journal-center X [\mum]');
ylabel('Journal-center Y [\mum]');
title(sprintf(['Journal Center Zoom Relative to Actual Clearance Envelope\n' ...
               'e/C_b = %.4f, center = (%.3f, %.3f) \\mum'], ...
               eq.epsilon,q(1)*bearing.Cb*1e6,q(2)*bearing.Cb*1e6));

legend('Contact / clearance envelope','Bearing center', ...
       'Journal center','Eccentricity vector', ...
       'Location','best');

%% ============================================================
% 15) OPTIONAL SPEED SWEEP
% =============================================================

if strcmpi(analysisMode,'SpeedSweep')

    fprintf('\n====================================================\n');
    fprintf(' SPEED SWEEP ANALYSIS\n');
    fprintf('====================================================\n');

    speedRPM = speedStartRPM:speedStepRPM:speedEndRPM;

    if isempty(speedRPM) || abs(speedRPM(end)-speedEndRPM) > 1e-9
        speedRPM = [speedRPM speedEndRPM];
    end

    speedRPM = unique(speedRPM,'stable');
    nSpeed = numel(speedRPM);

    % Solve high-to-low for robust warm starting.
    solveOrder = nSpeed:-1:1;

    sweep.epsilon  = NaN(1,nSpeed);
    sweep.phiDeg   = NaN(1,nSpeed);
    sweep.qx       = NaN(1,nSpeed);
    sweep.qy       = NaN(1,nSpeed);
    sweep.hmin     = NaN(1,nSpeed);
    sweep.Pmax     = NaN(1,nSpeed);
    sweep.Qtotal   = NaN(1,nSpeed);
    sweep.Power    = NaN(1,nSpeed);
    sweep.Sommerfeld = NaN(1,nSpeed);

    sweep.Kxx = NaN(1,nSpeed);
    sweep.Kxy = NaN(1,nSpeed);
    sweep.Kyx = NaN(1,nSpeed);
    sweep.Kyy = NaN(1,nSpeed);

    sweep.Cxx = NaN(1,nSpeed);
    sweep.Cxy = NaN(1,nSpeed);
    sweep.Cyx = NaN(1,nSpeed);
    sweep.Cyy = NaN(1,nSpeed);

    sweep.Mcrit = NaN(1,nSpeed);
    sweep.whirlRatio = NaN(1,nSpeed);
    sweep.converged = false(1,nSpeed);

    % Validity / sensitivity flags
    sweep.nearContact = false(1,nSpeed);
    sweep.severeNearContact = false(1,nSpeed);
    sweep.validityLabel = strings(1,nSpeed);

    qWarmSweep = q;
    thermalWarmSweep = thermalState;

    for kk = solveOrder

        Ns = speedRPM(kk);
        omegas = 2*pi*Ns/60;

        fprintf('\nSpeed = %.1f rpm\n',Ns);

        try
            [eqS,thermalS] = solveCoupledBearing( ...
                R,L,bearing,omegas,W,Ntheta,Nz,qWarmSweep, ...
                productionPressureTol,maxPressureIter,omegaSOR, ...
                productionEquilibriumTol,maxEquilibriumIter, ...
                dqNewtonPerturb,maxQstep,maxEpsilon, ...
                fullTHD,muIso,oil,thd,thermalWarmSweep,false);

            [PS,FxS,FyS] = solvePressureVariableMu( ...
                eqS.q,[0;0],R,L,bearing,omegas,Ntheta,Nz,thermalS.muHydro, ...
                coefficientPressureTol,coefficientMaxPressureIter,omegaSOR,eqS.P);

            eqS.P = PS;
            eqS.Fx = FxS;
            eqS.Fy = FyS;
            eqS.Pmax = max(PS(:));

            [HS,~,geomS] = bearingFilmGeometry2D( ...
                bearing,eqS.q,eqS.theta,eqS.z);

            activeS2D = repmat(geomS.activeMask,1,numel(eqS.z));
            hActiveS = HS(activeS2D);

            eqS.h2D = HS;
            eqS.hmin = min(hActiveS);
            eqS.hmax = max(hActiveS);

            [~,~,QtotS] = sideLeakageVariableMu( ...
                PS,HS,thermalS.muHydro,R,eqS.theta,eqS.z, ...
                eqS.activeMask,omegas,bearing);

            [~,PowerS] = frictionLossVariableMu( ...
                PS,HS,thermalS.muHydro,R,L,omegas,W, ...
                eqS.theta,eqS.z,eqS.activeMask,bearing);

            if fullTHD
                muSomS = mean(thermalS.muHydro(:));
            else
                muSomS = muIso;
            end

            unitLoadS = W/(L*D);
            SommerfeldS = ...
                (muSomS*(abs(Ns)/60)/unitLoadS)*(R/Cclr)^2;

            sweep.epsilon(kk) = eqS.epsilon;
            sweep.phiDeg(kk) = eqS.phiDeg;
            sweep.qx(kk) = eqS.q(1);
            sweep.qy(kk) = eqS.q(2);
            sweep.hmin(kk) = eqS.hmin;
            sweep.Pmax(kk) = eqS.Pmax;
            sweep.Qtotal(kk) = QtotS;
            sweep.Power(kk) = PowerS;
            sweep.Sommerfeld(kk) = SommerfeldS;

            % -------------------------------------------------
            % Operating-point validity / sensitivity flag
            % -------------------------------------------------
            sweep.nearContact(kk) = ...
                (eqS.hmin < nearContactHminWarn) || ...
                (eqS.epsilon > nearContactEccWarn);

            sweep.severeNearContact(kk) = ...
                (eqS.hmin < nearContactHminSevere) || ...
                (eqS.epsilon > nearContactEccSevere);

            if sweep.severeNearContact(kk)
                sweep.validityLabel(kk) = "SEVERE NEAR-CONTACT";
            elseif sweep.nearContact(kk)
                sweep.validityLabel(kk) = "NEAR-CONTACT / SENSITIVE";
            else
                sweep.validityLabel(kk) = "NORMAL";
            end

            if speedSweepComputeKC

                if strcmpi(dynamicCoeffMethod,'DirectPerturbed')
                    [KS,CS] = calculateBearingKCDirectPerturbed( ...
                        eqS.q,R,L,bearing,omegas,Ntheta,Nz, ...
                        thermalS.muHydro,PS);
                else
                    [KS,CS] = calculateBearingKC( ...
                        eqS.q,dxPerturbSelected,dvPerturbSelected, ...
                        R,L,bearing,omegas,Ntheta,Nz,thermalS.muHydro,PS, ...
                        coefficientPressureTol, ...
                        coefficientMaxPressureIter,omegaSOR);
                end

                sweep.Kxx(kk) = KS(1,1);
                sweep.Kxy(kk) = KS(1,2);
                sweep.Kyx(kk) = KS(2,1);
                sweep.Kyy(kk) = KS(2,2);

                sweep.Cxx(kk) = CS(1,1);
                sweep.Cxy(kk) = CS(1,2);
                sweep.Cyx(kk) = CS(2,1);
                sweep.Cyy(kk) = CS(2,2);

                [mcritS,~,ratioS] = criticalMassFromKC(KS,CS,omegas);

                sweep.Mcrit(kk) = mcritS;
                sweep.whirlRatio(kk) = ratioS;
            end

            sweep.converged(kk) = true;

            qWarmSweep = eqS.q;
            thermalWarmSweep = thermalS;

            fprintf(['  e/Cb=%.4f  hmin=%.3f um  Pmax=%.3f MPa  ' ...
                     'Q=%.3f L/min  Pwr=%.3f kW\n'], ...
                eqS.epsilon,eqS.hmin*1e6,eqS.Pmax/1e6, ...
                QtotS*60000,PowerS/1000);

            if sweep.severeNearContact(kk)
                fprintf(['  *** WARNING: SEVERE NEAR-CONTACT CONDITION ***\n' ...
                         '      e/Cb = %.4f, hmin = %.3f um\n' ...
                         '      Hydrodynamic solution and K/C linearization may be highly sensitive.\n'], ...
                         eqS.epsilon,eqS.hmin*1e6);
            elseif sweep.nearContact(kk)
                fprintf(['  ** WARNING: NEAR-CONTACT / NUMERICALLY SENSITIVE POINT **\n' ...
                         '     e/Cb = %.4f, hmin = %.3f um\n' ...
                         '     Verify mesh, cavitation convergence and K/C before design use.\n'], ...
                         eqS.epsilon,eqS.hmin*1e6);
            end

        catch ME
            fprintf('  FAILED at %.1f rpm: %s\n',Ns,ME.message);
        end
    end

    valid = sweep.converged;

    fprintf('\n====================================================\n');
    fprintf(' SPEED SWEEP SUMMARY\n');
    fprintf('====================================================\n');
    fprintf([' RPM      e/Cb      X[um]      Y[um]      hmin[um]  ' ...
             'Pmax[MPa]  Q[L/min]  Power[kW]   Status\n']);

    for kk = 1:nSpeed
        if valid(kk)
            fprintf('%7.0f  %8.4f  %9.3f  %9.3f  %10.3f  %10.3f  %8.3f  %9.3f   %s\n', ...
                speedRPM(kk),sweep.epsilon(kk), ...
                sweep.qx(kk)*bearing.Cb*1e6, ...
                sweep.qy(kk)*bearing.Cb*1e6, ...
                sweep.hmin(kk)*1e6,sweep.Pmax(kk)/1e6, ...
                sweep.Qtotal(kk)*60000,sweep.Power(kk)/1000, ...
                sweep.validityLabel(kk));
        else
            fprintf('%7.0f  FAILED\n',speedRPM(kk));
        end
    end

    nNormal = nnz(valid & ~sweep.nearContact);
    nWarn   = nnz(valid & sweep.nearContact & ~sweep.severeNearContact);
    nSevere = nnz(valid & sweep.severeNearContact);

    fprintf('\nOperating-point classification:\n');
    fprintf('  NORMAL                    = %d points\n',nNormal);
    fprintf('  NEAR-CONTACT / SENSITIVE  = %d points\n',nWarn);
    fprintf('  SEVERE NEAR-CONTACT       = %d points\n',nSevere);

    figure('Name','19 - Speed Sweep Journal Center Locus','Color','w');
    hold on;

    plot(centerEnvelopeQx*bearing.Cb*1e6, ...
         centerEnvelopeQy*bearing.Cb*1e6, ...
         'k-','LineWidth',2.2);

    plot(0,0,'k+','MarkerSize',11,'LineWidth',1.8);

    normalMask = valid & ~sweep.nearContact;
    warnMask = valid & sweep.nearContact & ~sweep.severeNearContact;
    severeMask = valid & sweep.severeNearContact;

    % Full locus line first
    plot(sweep.qx(valid)*bearing.Cb*1e6, ...
         sweep.qy(valid)*bearing.Cb*1e6, ...
         '-','LineWidth',1.5);

    % Normal points
    plot(sweep.qx(normalMask)*bearing.Cb*1e6, ...
         sweep.qy(normalMask)*bearing.Cb*1e6, ...
         'o','LineWidth',1.5,'MarkerSize',6);

    % Near-contact warning points
    plot(sweep.qx(warnMask)*bearing.Cb*1e6, ...
         sweep.qy(warnMask)*bearing.Cb*1e6, ...
         's','LineWidth',1.8,'MarkerSize',8);

    % Severe near-contact points
    plot(sweep.qx(severeMask)*bearing.Cb*1e6, ...
         sweep.qy(severeMask)*bearing.Cb*1e6, ...
         'x','LineWidth',2.2,'MarkerSize',10);

    validIdx = find(valid);
    for jj = 1:numel(validIdx)
        kk = validIdx(jj);
        text(sweep.qx(kk)*bearing.Cb*1e6, ...
             sweep.qy(kk)*bearing.Cb*1e6, ...
             sprintf('  %.0f',speedRPM(kk)), ...
             'FontSize',8);
    end

    axis equal;
    grid on;
    xlabel('Journal-center X [\mum]');
    ylabel('Journal-center Y [\mum]');
    title('Journal Equilibrium Locus vs Speed - Exact Clearance Zoom');
    legend('Contact / clearance envelope','Bearing center', ...
           'Equilibrium locus','Normal point', ...
           'Near-contact / sensitive','Severe near-contact', ...
           'Location','best');

    figure('Name','20 - Minimum Film Thickness vs Speed','Color','w');
    hold on;
    plot(speedRPM(valid),sweep.hmin(valid)*1e6,'o-','LineWidth',1.8);
    yline(nearContactHminWarn*1e6,'--', ...
        sprintf('Warning = %.1f um',nearContactHminWarn*1e6));
    yline(nearContactHminSevere*1e6,':', ...
        sprintf('Severe = %.1f um',nearContactHminSevere*1e6));
    grid on;
    xlabel('Rotor speed [rpm]');
    ylabel('Minimum film thickness [\mum]');
    title('Minimum Film Thickness vs Rotor Speed');

    figure('Name','21 - Eccentricity Ratio vs Speed','Color','w');
    hold on;
    plot(speedRPM(valid),sweep.epsilon(valid),'o-','LineWidth',1.8);
    yline(nearContactEccWarn,'--', ...
        sprintf('Warning = %.2f',nearContactEccWarn));
    yline(nearContactEccSevere,':', ...
        sprintf('Severe = %.2f',nearContactEccSevere));
    grid on;
    xlabel('Rotor speed [rpm]');
    ylabel('Eccentricity ratio e/C_b');
    title('Journal Eccentricity Ratio vs Rotor Speed');

    figure('Name','22 - Maximum Pressure vs Speed','Color','w');
    plot(speedRPM(valid),sweep.Pmax(valid)/1e6,'o-','LineWidth',1.8);
    grid on;
    xlabel('Rotor speed [rpm]');
    ylabel('Maximum pressure [MPa]');
    title('Maximum Film Pressure vs Rotor Speed');

    figure('Name','23 - Side Leakage vs Speed','Color','w');
    plot(speedRPM(valid),sweep.Qtotal(valid)*60000,'o-','LineWidth',1.8);
    grid on;
    xlabel('Rotor speed [rpm]');
    ylabel('Total side leakage [L/min]');
    title('Total Side Leakage vs Rotor Speed');

    figure('Name','24 - Power Loss vs Speed','Color','w');
    plot(speedRPM(valid),sweep.Power(valid)/1000,'o-','LineWidth',1.8);
    grid on;
    xlabel('Rotor speed [rpm]');
    ylabel('Power loss [kW]');
    title('Bearing Power Loss vs Rotor Speed');

    if speedSweepComputeKC

        figure('Name','25 - Stiffness vs Speed','Color','w');
        hold on;
        plot(speedRPM(valid),sweep.Kxx(valid),'o-','LineWidth',1.5);
        plot(speedRPM(valid),sweep.Kxy(valid),'s-','LineWidth',1.5);
        plot(speedRPM(valid),sweep.Kyx(valid),'d-','LineWidth',1.5);
        plot(speedRPM(valid),sweep.Kyy(valid),'^-','LineWidth',1.5);
        grid on;
        xlabel('Rotor speed [rpm]');
        ylabel('Stiffness [N/m]');
        title('Bearing Stiffness Coefficients vs Rotor Speed');
        legend('Kxx','Kxy','Kyx','Kyy','Location','best');

        figure('Name','26 - Damping vs Speed','Color','w');
        hold on;
        plot(speedRPM(valid),sweep.Cxx(valid),'o-','LineWidth',1.5);
        plot(speedRPM(valid),sweep.Cxy(valid),'s-','LineWidth',1.5);
        plot(speedRPM(valid),sweep.Cyx(valid),'d-','LineWidth',1.5);
        plot(speedRPM(valid),sweep.Cyy(valid),'^-','LineWidth',1.5);
        grid on;
        xlabel('Rotor speed [rpm]');
        ylabel('Damping [N.s/m]');
        title('Bearing Damping Coefficients vs Rotor Speed');
        legend('Cxx','Cxy','Cyx','Cyy','Location','best');

        figure('Name','27 - Critical Mass vs Speed','Color','w');
        hold on;
        plot(speedRPM(valid),sweep.Mcrit(valid),'o-','LineWidth',1.8);

        plot(speedRPM(warnMask),sweep.Mcrit(warnMask), ...
            's','MarkerSize',8,'LineWidth',1.8);

        plot(speedRPM(severeMask),sweep.Mcrit(severeMask), ...
            'x','MarkerSize',10,'LineWidth',2.2);

        grid on;
        xlabel('Rotor speed [rpm]');
        ylabel('Critical journal mass [kg]');
        title('Bearing-Only Critical Journal Mass vs Rotor Speed');
        legend('Calculated M_{cr}','Near-contact / sensitive', ...
               'Severe near-contact','Location','best');
    end
end



% ---- RotorDynX unified handoff -------------------------------------------
moduleOut = struct();
moduleOut.engine = 'FixedGeometry';
moduleOut.bearingType = char(bearingType);
moduleOut.analysisMode = char(analysisMode);

if exist('eq','var')
    moduleOut.operatingPoint = eq;
end
if exist('thermalState','var')
    moduleOut.thermal = thermalState;
end
if exist('K','var')
    moduleOut.K = K;
elseif exist('Kmat','var')
    moduleOut.K = Kmat;
end
if exist('Cmat','var')
    moduleOut.C = Cmat;
elseif exist('C','var')
    moduleOut.C = C;
end
if exist('sweep','var')
    moduleOut.speedSweep = sweep;
end
if exist('bearing','var')
    moduleOut.bearingDefinition = bearing;
end

moduleOut.reference = struct();
moduleOut.reference.W = W;
moduleOut.reference.omega = omega;
moduleOut.reference.muRef = mean(muHydro(:));
moduleOut.reference.PowerLoss = PowerLoss;

% Add common geometry/operating fields to the handoff without changing
% validated fixed-geometry solver physics.
moduleOut.bearingDefinition.D = D;
moduleOut.bearingDefinition.Rj = R;
moduleOut.bearingDefinition.L = L;
moduleOut.bearingDefinition.W = W;
moduleOut.bearingDefinition.omega = omega;

end


function moduleOut = runRotorDynXTPJB(masterAnalysisMode)
    % Tilting-pad journal-bearing engine.
    %
    % Current capabilities:
    %   - Arbitrary pad count
    %   - LOP and LBP configurations
    %   - Preload and pivot offset
    %   - Line and spherical pivots
    %   - Circumferential pad tilt
    %   - Axial pad tilt for spherical pivots
    %   - Nested journal-force and pad-moment equilibrium
    %   - Isothermal and bulk heat-balance thermal models
    %   - Direct perturbed-Reynolds K/C calculation
    %   - Coupled massless-pad dynamic condensation
    %   - Single-point and speed-sweep analysis
    %
    % Static equilibrium satisfies the applied bearing load while each active
    % pad satisfies its applicable zero-moment condition about the pivot.

fprintf('\n====================================================\n');
fprintf(' RotorDynX Bearings - TPJB Engine\n');
fprintf(' TILTING-PAD JOURNAL BEARING SOLVER\n');
fprintf('====================================================\n\n');

%% ========================================================================
% 1) USER INPUT
% =========================================================================

% -------- Bearing dimensions ---------------------------------------------
D  = 1.75*0.0254;         % journal diameter [m] = 1.75 in
Rj = D/2;
L  = 0.75*0.0254;         % bearing axial length [m] = 0.75 in

% Assembled/pivot clearance
Cb = 0.0025*0.0254;       % assembled radial clearance [m] = 0.0025 in

% Pad preload:
% m = 1 - Cb/Cp
% Table 3.9-1 baseline: preload = 0.3 on ALL pads.
preload = 0.35;           % [-] preload
Cp = Cb/(1-preload);      % machined/pad radial clearance [m]

sidePadPreloadCases = []; % validation-only feature disabled

% -------- Operating condition --------------------------------------------
Nrpm = 10000;             % shaft speed [rpm]
omega = 2*pi*Nrpm/60;     % [rad/s]

W = 15*4.4482216152605;   % applied load [N] = 15 lbf

% -------- Thermal / viscosity model ---------------------------------------
%
% "Isothermal"
%   Uses muIsothermal directly everywhere in the bearing.
%
% "HeatBalance"
%   Solves the bearing repeatedly with an effective bulk oil temperature:
%
%       Tout = Tin + etaHeat*Power/(mDot*cp)
%       Teff = Tin + effectiveTempFraction*(Tout-Tin)
%
%   Viscosity at Teff is calculated from ASTM-D341/Walther using the
%   user-supplied kinematic viscosities at 40 C and 100 C.
%
% IMPORTANT:
%   HeatBalance is a BULK thermal correction, not a full THD solution.
%   Use actual lubricant data-sheet values for nu40_cSt and nu100_cSt
%   and actual bearing supply flow for Qsupply_Lmin.
thermalModel = "Isothermal";      % "Isothermal" or "HeatBalance"

% Isothermal viscosity (used directly when thermalModel="Isothermal")
muIsothermal = 1.5e-6*6894.757293168; % [Pa.s] = 1.5E-06 reyn
mu = muIsothermal;

% Heat-balance user inputs (used only when thermalModel="HeatBalance")
Tin_C = 50.0;                     % bearing oil inlet temperature [degC]
Qsupply_Lmin = 10.0;              % TOTAL oil flow through bearing [L/min]
rhoOil = 850.0;                   % oil density [kg/m^3]
cpOil = 2000.0;                   % oil specific heat [J/kg-K]
etaHeatToOil = 1.0;               % fraction of bearing power absorbed by oil
effectiveTempFraction = 0.50;     % Teff = Tin + f*(Tout-Tin)

% ASTM D341 viscosity-temperature inputs.
% REPLACE with the actual lubricant data-sheet values before using
% HeatBalance for engineering work.
nu40_cSt  = 32.0;                 % kinematic viscosity at 40 C [cSt]
nu100_cSt = 5.4;                  % kinematic viscosity at 100 C [cSt]

% Thermal iteration controls
thermalTolMu = 1e-4;              % relative viscosity convergence
thermalTolT_C = 1e-3;             % effective-temperature convergence [degC]
thermalMaxIter = 30;
thermalRelax = 0.50;              % under-relaxation for viscosity update

% -------- TPJB geometry --------------------------------------------------
nPads = 4;

padArcDeg = 72;           % angular pad extent [deg]

% Pivot offset measured from pad leading edge in direction of rotation:
%   0.50 = center pivot
%   0.60 = 60% offset
pivotOffset = 0.60;       % [-]

% Pivot type:
%   "Line"      = cylindrical / rocker / line-contact pivot.
%                 Pad is free to tilt circumferentially only:
%                     M_circ = 0
%                 Axial-tilt moment is a pivot reaction and may be nonzero.
%
%   "Spherical" = point-contact / ball-socket pivot.
%                 Pad is free to tilt in BOTH directions:
%                     M_circ = 0
%                     M_axial = 0
%
% The Practical Rotordynamics discussion distinguishes these two
% mechanical freedoms.  Use "Line" for the Table 3.9-1 baseline unless
% the benchmark explicitly specifies a spherical/point pivot.
pivotType = "Line";

% "LBP" -> load between two pads
% "LOP" -> load through one pad pivot
loadOrientation = "LBP";   % Dyrobes benchmark = load between pivots

% -------- Numerical mesh -------------------------------------------------
NthetaPad = 61;           % including pad leading/trailing boundary nodes
Nz = 31;                  % including axial boundary nodes

% Static nonlinear equilibrium
eqTolForce = 1e-6;        % normalized journal-force residual
eqMaxIter = 60;

% Outer journal-position Jacobian step
fdCenter = 2e-3;          % fraction of Cb

% Inner pad-tilt equilibrium
padMomentTol = 1e-8;      % normalized by W*Rj
padTiltScanMax = 8e-3;    % [rad], search envelope (+/-)
padTiltScanPts = 161;     % bracket scan points

% Spherical / point-pivot two-DOF equilibrium
pointPivotMomentTol = 1e-8; % normalized by W*Rj
pointPivotMaxIter = 25;
fdPadTilt2D = 2e-6;        % [rad]

% Line search
minLineSearch = 1/256;

% Static convergence assessment
% Active-pad moment checks are applied only to pads carrying a meaningful
% fraction of the bearing load. Nearly unloaded pads can have an arbitrary
% pressure-free tilt and should not prevent journal equilibrium convergence.
activePadLoadFraction = 0.0025;   % 0.25% of total bearing load
benchmarkForceTol = 2.0e-3;       % 0.20% normalized force residual

% Dynamic K/C extraction: rigid pivot, massless pads
computeDynamicKC = true;  % production requirement: always output K/C

% V0.9 requires strict static equilibrium before dynamic derivatives.
allowBenchmarkConvergence = false;

% Explicit generalized-matrix perturbations.
dynamicDx = 0.20e-6;        % journal displacement perturbation [m]
dynamicDalpha = 2.0e-6;     % pad-angle perturbation [rad]
dynamicDv = 1.0e-3;         % journal velocity perturbation [m/s]
dynamicDalphaDot = 1.0e-3;  % pad angular-rate perturbation [rad/s]

% Production dynamics
% Direct perturbed-Reynolds generalized K/C with coupled massless-pad
% condensation is ALWAYS evaluated after strict static convergence.
dynamicMethod = "DirectPerturbedReynolds";
perturbedPressureActiveTol = 1e-12; % relative to each pad Pmax

% Production plotting
plotGeometry = true;
plotPressureContour = true;
plotPressureCurves = true;
plotFilmThickness = true;
plotConvergence = true;
plotPadLoads = true;

% Clearance is too small relative to shaft radius to be visually obvious.
% This factor is ONLY for the geometry drawing; it does not affect physics.
geometryClearanceVisualScale = 18;
showPadTilt = true;
padTiltVisualAmplification = 20;   % drawing only; actual alpha is unchanged
showOriginalPadPosition = false;   % hide original untilted reference outline


% -------- Optional production speed sweep --------------------------------
% The normal single operating point is ALWAYS solved first.
% Enable this only when a speed-dependent bearing map is required.
runSpeedSweep = strcmpi(masterAnalysisMode,'SpeedSweep');

% Sweep definition [rpm]
speedSweepStartRPM = max(500,0.50*Nrpm);
speedSweepEndRPM   = 1.20*Nrpm;
speedSweepStepRPM  = 500;

% Full output at every sweep point.
% true = calculate equivalent K/C at every speed (recommended for rotor work)
speedSweepComputeKC = true;

% Heat-balance flow treatment during a speed sweep:
%   "Constant"       -> Qsupply_Lmin is constant at all speeds
%   "ScaleWithSpeed" -> Q scales linearly with rpm relative to Nrpm
speedSweepFlowMode = "Constant";

% Sweep plots
plotSpeedSweep = true;


%% ========================================================================
% 2) PREPARE PAD GEOMETRY
% =========================================================================

bearing.D = D;
bearing.Rj = Rj;
bearing.L = L;
bearing.Cb = Cb;
bearing.Cp = Cp;
bearing.preload = preload;
bearing.nPads = nPads;
bearing.loadOrientation = loadOrientation;
bearing.padArcDeg = padArcDeg;
bearing.pivotOffset = pivotOffset;
bearing.pivotType = char(pivotType);
bearing.loadOrientation = char(loadOrientation);
bearing.NthetaPad = NthetaPad;
bearing.Nz = Nz;
bearing.mu = mu;
bearing.omega = omega;
bearing.W = W;

bearing = prepareTPJBGeometry(bearing);

% Pad-specific preload support.
% For the 5-pad LOP geometry used in Table 3.9-1:
%   Pad 1 = directly loaded bottom pad
%   Pads 2 and 5 = bottom side pads
%   Pads 3 and 4 = upper / lightly-loaded pads
sidePadIndices = [2 5];

for i = 1:bearing.nPads
    bearing.pad(i).preload = preload;
    bearing.pad(i).CbPivot = bearing.Cp*(1-bearing.pad(i).preload);
end

fprintf('BEARING GEOMETRY\n');
fprintf('----------------------------------------------------\n');
fprintf('Journal diameter D       = %.3f mm\n',D*1e3);
fprintf('Bearing axial length L   = %.3f mm\n',L*1e3);
fprintf('Assembled clearance Cb   = %.3f um\n',Cb*1e6);
fprintf('Machined clearance Cp    = %.3f um\n',Cp*1e6);
fprintf('Preload m                = %.4f\n',preload);
fprintf('Number of pads           = %d\n',nPads);
fprintf('Pad arc                  = %.2f deg\n',padArcDeg);
fprintf('Pivot offset             = %.3f\n',pivotOffset);
fprintf('Pivot type               = %s\n',upper(pivotType));
if strcmpi(pivotType,'Line')
    fprintf('Pad rotational DOF       = circumferential tilt only\n');
    fprintf('Static moment condition  = M_circ = 0; M_axial may be nonzero\n');
else
    fprintf('Pad rotational DOF       = circumferential + axial tilt\n');
    fprintf('Static moment condition  = M_circ = 0 and M_axial = 0\n');
end
fprintf('Load orientation         = %s\n',upper(loadOrientation));
fprintf('Speed                    = %.1f rpm\n',Nrpm);
fprintf('Load                     = %.2f N\n',W);
fprintf('Viscosity                = %.6e Pa.s\n',bearing.mu);

fprintf('\nPRODUCTION SOLVER SETTINGS\n');
fprintf('----------------------------------------------------\n');
fprintf('Mesh per pad            = %d x %d\n',NthetaPad,Nz);
fprintf('Static equilibrium      = ENABLED\n');
fprintf('Dynamic K/C             = ENABLED\n');
fprintf('Dynamic method          = Direct perturbed Reynolds\n');
fprintf('Pad condensation        = Coupled massless-pad K-C\n');
fprintf('Power integration       = 2-D trapezoidal wall-shear quadrature\n');
fprintf('Thermal model           = %s\n',upper(thermalModel));
fprintf('Speed sweep option      = %s\n',tpjbTernary(runSpeedSweep,'ENABLED','DISABLED'));
if runSpeedSweep
    fprintf('Sweep K/C at each speed = %s\n',tpjbTernary(speedSweepComputeKC,'YES','NO'));
end

fprintf('\nPAD LAYOUT\n');
fprintf('----------------------------------------------------\n');
for i = 1:nPads
    fprintf(['Pad %d: LE=%8.3f deg | Pivot=%8.3f deg | ', ...
             'TE=%8.3f deg | m=%.3f | Cb,pivot=%.3f um\n'], ...
        i,bearing.pad(i).theta1Deg, ...
        bearing.pad(i).thetaPivotDeg, ...
        bearing.pad(i).theta2Deg, ...
        bearing.pad(i).preload, ...
        bearing.pad(i).CbPivot*1e6);
end

%% ========================================================================
% 3) INITIAL GUESS
% =========================================================================
%
% Unknown vector:
% u = [qx, qy, alpha_1 ... alpha_N]
% where qx = ex/Cb and qy = ey/Cb.

u0 = zeros(2+nPads,1);

% With external load in -Y, journal normally sits below bearing center.
u0(1) = 0.00;
u0(2) = -0.65;

% Small converging-wedge initial pad tilts.
for i = 1:nPads
    u0(2+i) = 0;
end

%% ========================================================================
% 4) STATIC JOURNAL + PAD EQUILIBRIUM
% =========================================================================

options.eqTolForce = eqTolForce;
options.eqMaxIter = eqMaxIter;
options.fdCenter = fdCenter;
options.padMomentTol = padMomentTol;
options.padTiltScanMax = padTiltScanMax;
options.padTiltScanPts = padTiltScanPts;
options.pointPivotMomentTol = pointPivotMomentTol;
options.pointPivotMaxIter = pointPivotMaxIter;
options.fdPadTilt2D = fdPadTilt2D;
options.minLineSearch = minLineSearch;
options.activePadLoadFraction = activePadLoadFraction;
options.benchmarkForceTol = benchmarkForceTol;
options.allowBenchmarkConvergence = allowBenchmarkConvergence;
options.dynamicDx = dynamicDx;
options.dynamicDalpha = dynamicDalpha;
options.dynamicDv = dynamicDv;
options.dynamicDalphaDot = dynamicDalphaDot;
options.perturbedPressureActiveTol = perturbedPressureActiveTol;

% V0.3 uses nested equilibrium:
%   inner loop  -> each pad tilt is solved from M_pivot = 0
%   outer loop  -> journal center is solved from Fx = 0, Fy = W
% -------------------------------------------------------------------------
% Thermal wrapper
% -------------------------------------------------------------------------
thermal = struct();
thermal.model = char(thermalModel);
thermal.converged = true;
thermal.iterations = 1;
thermal.Tin_C = Tin_C;
thermal.Tout_C = Tin_C;
thermal.Teff_C = Tin_C;
thermal.muEff = muIsothermal;
thermal.deltaT_C = 0;
thermal.mDot = NaN;
thermal.Qsupply_Lmin = Qsupply_Lmin;

tStaticThermalStage = tic;

if strcmpi(thermalModel,'Isothermal')

    bearing.mu = muIsothermal;
    [result,history] = solveTPJBStaticEquilibriumNested( ...
        bearing,u0(1:2),options);

    thermal.muEff = bearing.mu;
    thermal.iterations = 1;
    thermal.converged = true;

elseif strcmpi(thermalModel,'HeatBalance')

    if Qsupply_Lmin <= 0
        error('HeatBalance requires Qsupply_Lmin > 0.');
    end
    if rhoOil <= 0 || cpOil <= 0
        error('HeatBalance requires positive rhoOil and cpOil.');
    end
    if nu40_cSt <= 0 || nu100_cSt <= 0
        error('HeatBalance requires positive nu40_cSt and nu100_cSt.');
    end

    Qsupply_m3s = Qsupply_Lmin*1e-3/60;
    mDot = rhoOil*Qsupply_m3s;

    % Start from inlet-temperature viscosity from D341.
    muIter = viscosityD341(Tin_C,nu40_cSt,nu100_cSt,rhoOil);
    TeffOld = Tin_C;

    fprintf('\n====================================================\n');
    fprintf(' BULK HEAT-BALANCE ITERATION\n');
    fprintf('====================================================\n');
    fprintf('Tin = %.2f C | Supply flow = %.3f L/min | mDot = %.5f kg/s\n', ...
        Tin_C,Qsupply_Lmin,mDot);

    thermalConverged = false;

    for itThermal = 1:thermalMaxIter

        bearing.mu = muIter;

        [result,history] = solveTPJBStaticEquilibriumNested( ...
            bearing,u0(1:2),options);

        deltaT = etaHeatToOil*result.power/(mDot*cpOil);
        Tout_C = Tin_C + deltaT;
        Teff_C = Tin_C + effectiveTempFraction*deltaT;

        muTarget = viscosityD341( ...
            Teff_C,nu40_cSt,nu100_cSt,rhoOil);

        relMu = abs(muTarget-muIter)/max(abs(muIter),eps);
        dTeff = abs(Teff_C-TeffOld);

        fprintf(['Thermal %2d | mu = %.6e Pa.s | Power = %.4f kW | ', ...
                 'Tout = %.3f C | Teff = %.3f C | dMu/mu = %.3e\n'], ...
            itThermal,muIter,result.power/1e3,Tout_C,Teff_C,relMu);

        if relMu < thermalTolMu && dTeff < thermalTolT_C
            thermalConverged = true;
            muIter = muTarget;
            break;
        end

        muIter = (1-thermalRelax)*muIter + thermalRelax*muTarget;
        TeffOld = Teff_C;

        % Warm-start the next thermal iteration from the converged center.
        u0(1:2) = [result.qx;result.qy];
    end

    % Final consistent solve at the converged effective viscosity.
    bearing.mu = muIter;
    [result,history] = solveTPJBStaticEquilibriumNested( ...
        bearing,[result.qx;result.qy],options);

    deltaT = etaHeatToOil*result.power/(mDot*cpOil);
    Tout_C = Tin_C + deltaT;
    Teff_C = Tin_C + effectiveTempFraction*deltaT;

    thermal.model = 'HeatBalance';
    thermal.converged = thermalConverged;
    thermal.iterations = itThermal;
    thermal.Tin_C = Tin_C;
    thermal.Tout_C = Tout_C;
    thermal.Teff_C = Teff_C;
    thermal.deltaT_C = deltaT;
    thermal.muEff = bearing.mu;
    thermal.mDot = mDot;
    thermal.Qsupply_Lmin = Qsupply_Lmin;

    if ~thermalConverged
        warning(['Bulk heat balance reached thermalMaxIter without satisfying ', ...
                 'both viscosity and temperature convergence tolerances.']);
    end

else
    error('thermalModel must be "Isothermal" or "HeatBalance".');
end

% Save thermal state with the bearing result.
result.thermal = thermal;
timingStaticThermal_s = toc(tStaticThermalStage);

%% ========================================================================
% 5) FINAL REPORT
% =========================================================================

fprintf('\n====================================================\n');
fprintf(' FINAL TPJB STATIC EQUILIBRIUM\n');
fprintf('====================================================\n');

fprintf('Converged                = %s\n',tpjbTernary(result.converged,'YES','NO'));
fprintf('Iterations               = %d\n',result.iterations);
fprintf('Force convergence tol.   = %.3e (%.2f%% of load)\n', ...
    benchmarkForceTol,100*benchmarkForceTol);
fprintf('Active-pad load threshold= %.3f%% of bearing load\n', ...
    100*activePadLoadFraction);

fprintf('\nJOURNAL POSITION\n');
fprintf('----------------------------------------------------\n');
fprintf('qx = ex/Cb               = %.6f\n',result.qx);
fprintf('qy = ey/Cb               = %.6f\n',result.qy);
fprintf('Eccentricity ratio e/Cb  = %.6f\n',result.epsilon);
fprintf('Journal center X         = %.3f um\n',result.ex*1e6);
fprintf('Journal center Y         = %.3f um\n',result.ey*1e6);
fprintf('Journal center angle     = %.3f deg\n',result.centerAngleDeg);
fprintf('Attitude from load line  = %.3f deg\n',result.attitudeDeg);

fprintf('\nFORCE EQUILIBRIUM\n');
fprintf('----------------------------------------------------\n');
fprintf('Fluid reaction Fx        = %.6f N\n',result.Fx);
fprintf('Fluid reaction Fy        = %.6f N\n',result.Fy);
fprintf('Required Fy              = %.6f N\n',W);
fprintf('Force residual / W       = %.3e\n',result.forceResidual);

fprintf('\nPAD RESULTS\n');
fprintf('----------------------------------------------------\n');
fprintf(['Pad  State   a_circ[mrad]  b_axial[mrad]   Load[N]   ', ...
         'M_circ[N.m]   M_axial[N.m]   hmin[um]   hpivot[um]   Pmax[MPa]\n']);

for i = 1:nPads
    if result.pad(i).load > activePadLoadFraction*W
        padStateLabel = 'ACTIVE';
    else
        padStateLabel = 'IDLE  ';
    end

    fprintf('%3d  %s   %11.5f   %12.5f   %9.3f   %11.4e   %12.4e   %8.3f   %10.3f   %9.4f\n', ...
        i,padStateLabel, ...
        result.pad(i).alpha*1e3, ...
        result.pad(i).beta*1e3, ...
        result.pad(i).load, ...
        result.pad(i).momentCirc, ...
        result.pad(i).momentAxial, ...
        result.pad(i).hmin*1e6, ...
        result.pad(i).hPivot*1e6, ...
        result.pad(i).Pmax/1e6);
end

fprintf('\nGLOBAL PERFORMANCE\n');
fprintf('----------------------------------------------------\n');
fprintf('Minimum film thickness   = %.3f um\n',result.hmin*1e6);
fprintf('Minimum pivot film       = %.3f um\n',result.minPivotFilm*1e6);
fprintf('Maximum pressure         = %.4f MPa\n',result.Pmax/1e6);
fprintf('Maximum pivot load       = %.3f N\n',result.maxPivotLoad);
fprintf('Total friction power     = %.4f kW\n',result.power/1e3);
fprintf('Loaded pad               = %d\n',result.loadedPad);


fprintf('\nTHERMAL PERFORMANCE\n');
fprintf('----------------------------------------------------\n');
fprintf('Thermal model            = %s\n',upper(result.thermal.model));
fprintf('Effective viscosity      = %.6e Pa.s\n',result.thermal.muEff);

if strcmpi(result.thermal.model,'HeatBalance')
    fprintf('Heat-balance converged   = %s\n',tpjbTernary(result.thermal.converged,'YES','NO'));
    fprintf('Thermal iterations       = %d\n',result.thermal.iterations);
    fprintf('Oil inlet temperature    = %.3f C\n',result.thermal.Tin_C);
    fprintf('Oil outlet temperature   = %.3f C\n',result.thermal.Tout_C);
    fprintf('Effective oil temperature= %.3f C\n',result.thermal.Teff_C);
    fprintf('Oil temperature rise     = %.3f C\n',result.thermal.deltaT_C);
    fprintf('Oil supply flow          = %.3f L/min\n',result.thermal.Qsupply_Lmin);
    fprintf('Oil mass flow            = %.6f kg/s\n',result.thermal.mDot);
end

% Table 3.9-1 published values
book.hmin = 1.089*25.4e-6;
book.Pmax = 1559*6894.757293168;
book.maxPivotLoad = 8698*4.4482216152605;
book.power = 12.8*745.699872;


%% ========================================================================
% 5A) EXPLICIT GENERALIZED TPJB DYNAMIC COEFFICIENTS
% =========================================================================
%
% V0.9 uses the same direct-perturbation philosophy as the fixed-bearing
% solver, but now includes the active pad angles as generalized DOFs.
%
% Generalized coordinates:
%   q = [x  y  alpha_1 ... alpha_nA]^T
%
% Linearized hydrodynamic reactions:
%   [dF]   = -K_g [dx]
%   [dM]          [da]
%
% and for velocities:
%   [dF]   = -C_g [dv]
%   [dM]          [d(alpha)/dt]
%
% For massless, freely tilting pads:
%   dM = 0
%
% so pad DOFs are statically condensed:
%   A = -Kaa^{-1}Kaj
%   B = -Kaa^{-1}(Caj + Caa*A)
%   K_eq = Kjj + Kja*A
%   C_eq = Cjj + Kja*B + Cja*A
%
% This is NOT a separate physical criterion from Direct Perturbation.
% It is Direct Perturbation with the pad rotational DOFs shown explicitly.

if computeDynamicKC

    if ~result.strictConverged
        error(['Dynamic K/C requires strict static equilibrium. ', ...
               'Current static residual = %.3e; target = %.3e.'], ...
               result.forceResidual,eqTolForce);
    end

    fprintf('\n====================================================\n');
    fprintf(' TPJB DYNAMIC COEFFICIENTS - PRODUCTION\n');
    fprintf(' Linearized Reynolds / coupled massless-pad K-C condensation\n');
    fprintf('====================================================\n');

    tDynamicKCStage = tic;
    dyn = computeTPJBGeneralizedKC(bearing,result,options);
    timingDynamicKC_s = toc(tDynamicKCStage);
    dyn.timing.total_s = timingDynamicKC_s;
    result.dynamic = dyn;

    fprintf('Active pads in condensation = ');
    fprintf('%d ',dyn.activePads);
    fprintf('\n');

    fprintf('Dynamic pad DOF             = %s\n',dyn.padDynamicDOF);
    fprintf('Dynamic method              = Direct perturbed Reynolds (cached operator/factorization)\n');
    fprintf('Cavitation treatment        = frozen steady positive-pressure region\n');
    if strcmpi(bearing.pivotType,'Spherical') || strcmpi(bearing.pivotType,'Point')
        fprintf('Spherical dynamics status   = IMPLEMENTED / awaiting external benchmark validation\n');
    end

    fprintf('\nEQUIVALENT STIFFNESS [N/m]\n');
    fprintf('----------------------------------------------------\n');
    fprintf('Kxx = %14.6e\n',dyn.K(1,1));
    fprintf('Kxy = %14.6e\n',dyn.K(1,2));
    fprintf('Kyx = %14.6e\n',dyn.K(2,1));
    fprintf('Kyy = %14.6e\n',dyn.K(2,2));

    fprintf('\nEQUIVALENT DAMPING [N.s/m]\n');
    fprintf('----------------------------------------------------\n');
    fprintf('Cxx = %14.6e\n',dyn.C(1,1));
    fprintf('Cxy = %14.6e\n',dyn.C(1,2));
    fprintf('Cyx = %14.6e\n',dyn.C(2,1));
    fprintf('Cyy = %14.6e\n',dyn.C(2,2));

    fprintf('\nDYNAMIC SOLVER CHECK\n');
    fprintf('----------------------------------------------------\n');
    fprintf('rcond(Kaa)              = %.3e\n',dyn.rcondKaa);
    fprintf('rcond(Caa)              = %.3e\n',dyn.rcondCaa);
    fprintf('K cross/direct ratio    = %.3e\n',dyn.crossRatioK);
    fprintf('C cross/direct ratio    = %.3e\n',dyn.crossRatioC);

    fprintf('\nTPJB COMPUTATION TIMING\n');
    fprintf('----------------------------------------------------\n');
    fprintf('Static + thermal stage   = %.3f s\n',timingStaticThermal_s);
    if isfield(result,'staticTiming')
        fprintf('  Static equilibrium core= %.3f s\n',result.staticTiming.core_s);
        fprintf('  Local pad-root solves  = %d\n',result.staticTiming.localRootUses);
        fprintf('  Full-scan fallbacks    = %d\n',result.staticTiming.fullScanFallbacks);
    end
    fprintf('Dynamic K/C stage        = %.3f s\n',timingDynamicKC_s);
    if isfield(dyn,'timing')
        if isfield(dyn.timing,'cacheBuild_s')
            fprintf('  K/C cache build        = %.3f s\n',dyn.timing.cacheBuild_s);
        end
        if isfield(dyn.timing,'sensitivity_s')
            fprintf('  K/C sensitivities      = %.3f s\n',dyn.timing.sensitivity_s);
        end
    end

else
    fprintf('\nTPJB COMPUTATION TIMING\n');
    fprintf('----------------------------------------------------\n');
    fprintf('Static + thermal stage   = %.3f s\n',timingStaticThermal_s);
end


%% ========================================================================
% 5B) OPTIONAL PRODUCTION SPEED SWEEP
% =========================================================================
%
% This is NOT a mesh/sensitivity benchmark.  It is a production operating
% map using the same validated mesh and the same physics as the base point.
%
% At every speed:
%   1) update omega
%   2) solve static journal + pad equilibrium
%   3) if HeatBalance: converge Teff and viscosity
%   4) calculate equivalent K/C when requested
%
% Previous converged journal position is used as the next initial guess.

speedSweep = [];

if runSpeedSweep

    speedListRPM = speedSweepStartRPM:speedSweepStepRPM:speedSweepEndRPM;

    if isempty(speedListRPM)
        error('Speed sweep definition produced an empty RPM vector.');
    end

    if speedListRPM(end) < speedSweepEndRPM
        speedListRPM(end+1) = speedSweepEndRPM;
    end

    speedListRPM = unique(speedListRPM(:).');

    fprintf('\n====================================================\n');
    fprintf(' TPJB PRODUCTION SPEED SWEEP\n');
    fprintf('====================================================\n');
    fprintf('Speed range              = %.1f to %.1f rpm\n', ...
        speedListRPM(1),speedListRPM(end));
    fprintf('Number of speed points   = %d\n',numel(speedListRPM));
    fprintf('Thermal model            = %s\n',upper(thermalModel));
    fprintf('K/C at every speed       = %s\n', ...
        tpjbTernary(speedSweepComputeKC,'YES','NO'));

    nSp = numel(speedListRPM);

    speedSweep.rpm       = speedListRPM(:);
    speedSweep.epsilon   = nan(nSp,1);
    speedSweep.attitude  = nan(nSp,1);
    speedSweep.hmin_um   = nan(nSp,1);
    speedSweep.Pmax_MPa  = nan(nSp,1);
    speedSweep.power_kW  = nan(nSp,1);
    speedSweep.mu_Pas    = nan(nSp,1);
    speedSweep.Tin_C     = nan(nSp,1);
    speedSweep.Tout_C    = nan(nSp,1);
    speedSweep.Teff_C    = nan(nSp,1);
    speedSweep.qx        = nan(nSp,1);
    speedSweep.qy        = nan(nSp,1);
    speedSweep.ex_um     = nan(nSp,1);
    speedSweep.ey_um     = nan(nSp,1);
    speedSweep.Kxx       = nan(nSp,1);
    speedSweep.Kxy       = nan(nSp,1);
    speedSweep.Kyx       = nan(nSp,1);
    speedSweep.Kyy       = nan(nSp,1);
    speedSweep.Cxx       = nan(nSp,1);
    speedSweep.Cxy       = nan(nSp,1);
    speedSweep.Cyx       = nan(nSp,1);
    speedSweep.Cyy       = nan(nSp,1);
    speedSweep.converged = false(nSp,1);

    qSweep = [result.qx;result.qy];

    for is = 1:nSp

        rpmNow = speedListRPM(is);

        bSweep = bearing;
        bSweep.omega = 2*pi*rpmNow/60;

        % Optional supply-flow scaling for pump-fed systems where flow is
        % approximately proportional to shaft speed.
        if strcmpi(speedSweepFlowMode,'ScaleWithSpeed')
            Qsweep_Lmin = Qsupply_Lmin*(rpmNow/Nrpm);
        elseif strcmpi(speedSweepFlowMode,'Constant')
            Qsweep_Lmin = Qsupply_Lmin;
        else
            error('speedSweepFlowMode must be "Constant" or "ScaleWithSpeed".');
        end

        thermalCfg.model = char(thermalModel);
        thermalCfg.muIsothermal = muIsothermal;
        thermalCfg.Tin_C = Tin_C;
        thermalCfg.Qsupply_Lmin = Qsweep_Lmin;
        thermalCfg.rhoOil = rhoOil;
        thermalCfg.cpOil = cpOil;
        thermalCfg.etaHeatToOil = etaHeatToOil;
        thermalCfg.effectiveTempFraction = effectiveTempFraction;
        thermalCfg.nu40_cSt = nu40_cSt;
        thermalCfg.nu100_cSt = nu100_cSt;
        thermalCfg.thermalTolMu = thermalTolMu;
        thermalCfg.thermalTolT_C = thermalTolT_C;
        thermalCfg.thermalMaxIter = thermalMaxIter;
        thermalCfg.thermalRelax = thermalRelax;

        [rSweep,~,bSweep] = solveTPJBOperatingPoint( ...
            bSweep,qSweep,options,thermalCfg,false);

        qSweep = [rSweep.qx;rSweep.qy];

        if speedSweepComputeKC
            if ~rSweep.strictConverged
                error(['Speed sweep dynamic K/C requires strict static ', ...
                       'equilibrium at %.1f rpm.'],rpmNow);
            end
            dSweep = computeTPJBGeneralizedKC(bSweep,rSweep,options);
            rSweep.dynamic = dSweep;
        end

        speedSweep.epsilon(is)  = rSweep.epsilon;
        speedSweep.attitude(is) = rSweep.attitudeDeg;
        speedSweep.hmin_um(is)  = rSweep.hmin*1e6;
        speedSweep.Pmax_MPa(is) = rSweep.Pmax/1e6;
        speedSweep.power_kW(is) = rSweep.power/1e3;
        speedSweep.mu_Pas(is)   = rSweep.thermal.muEff;
        speedSweep.Tin_C(is)    = rSweep.thermal.Tin_C;
        speedSweep.Tout_C(is)   = rSweep.thermal.Tout_C;
        speedSweep.Teff_C(is)   = rSweep.thermal.Teff_C;
        speedSweep.qx(is)       = rSweep.qx;
        speedSweep.qy(is)       = rSweep.qy;
        speedSweep.ex_um(is)    = rSweep.ex*1e6;
        speedSweep.ey_um(is)    = rSweep.ey*1e6;
        speedSweep.converged(is)= rSweep.strictConverged;

        if speedSweepComputeKC
            speedSweep.Kxx(is) = rSweep.dynamic.K(1,1);
            speedSweep.Kxy(is) = rSweep.dynamic.K(1,2);
            speedSweep.Kyx(is) = rSweep.dynamic.K(2,1);
            speedSweep.Kyy(is) = rSweep.dynamic.K(2,2);
            speedSweep.Cxx(is) = rSweep.dynamic.C(1,1);
            speedSweep.Cxy(is) = rSweep.dynamic.C(1,2);
            speedSweep.Cyx(is) = rSweep.dynamic.C(2,1);
            speedSweep.Cyy(is) = rSweep.dynamic.C(2,2);
        end

        fprintf(['%7.0f rpm | eps %.5f | hmin %8.3f um | ', ...
                 'Pmax %7.4f MPa | Power %7.4f kW | mu %.4e'], ...
            rpmNow,rSweep.epsilon,rSweep.hmin*1e6, ...
            rSweep.Pmax/1e6,rSweep.power/1e3,rSweep.thermal.muEff);

        if strcmpi(thermalModel,'HeatBalance')
            fprintf(' | Teff %.2f C | Tout %.2f C', ...
                rSweep.thermal.Teff_C,rSweep.thermal.Tout_C);
        end

        if speedSweepComputeKC
            fprintf(' | Kxx %.3e | Cxx %.3e', ...
                rSweep.dynamic.K(1,1),rSweep.dynamic.C(1,1));
        end
        fprintf('\n');
    end

    fprintf('====================================================\n');
end

%% ========================================================================
% 5C) PRODUCTION NOTE
% =========================================================================
fprintf('\nNOTE\n');
fprintf('----------------------------------------------------\n');
fprintf(['The production solver computes the complete TPJB static equilibrium, ', ...
         'full pad pressure fields, thermal performance, performance quantities and dynamic K/C ', ...
         'at the selected production mesh. Validation sweeps are excluded ', ...
         'from the production workflow.\n']);
fprintf('====================================================\n');

%% ========================================================================
% 6) ROTORDYNX V1.6 PRODUCTION ENGINEERING PLOTS
% =========================================================================
%
% IMPORTANT:
%   The solver physics always uses the real clearances.
%   geometryClearanceVisualScale is used ONLY to make the shaft/pad gap
%   visible on the geometry drawing.

if plotGeometry
    plotTPJBProductionGeometry(bearing,result,W,activePadLoadFraction, ...
        geometryClearanceVisualScale,showPadTilt, ...
        padTiltVisualAmplification,showOriginalPadPosition);
end

if plotPressureContour
    plotTPJBPressureContours(bearing,result);
end

if plotPressureCurves
    plotTPJBPressureCurves(result,W,activePadLoadFraction);
end

if plotFilmThickness
    plotTPJBFilmThickness(bearing,result);
end

if plotConvergence
    figure('Name','RotorDynX - TPJB Static Convergence','Color','w', ...
        'Position',[180 140 820 500]);
    ax = axes;
    hold(ax,'on'); box(ax,'on');
    set(ax,'FontName','Arial','FontSize',11,'LineWidth',0.9, ...
        'XGrid','on','YGrid','on','GridAlpha',0.14,'YScale','log');

    plot(ax,history.iter,history.normResidual,'-o', ...
        'LineWidth',1.5,'MarkerSize',5);
    yline(ax,eqTolForce,'--',sprintf('Strict tolerance = %.1e',eqTolForce), ...
        'LabelHorizontalAlignment','left','LineWidth',0.9);

    xlabel(ax,'Outer equilibrium iteration');
    ylabel(ax,'Normalized force residual');
    title(ax,'RotorDynX TPJB — Static Equilibrium Convergence');
end

if plotPadLoads
    figure('Name','RotorDynX - TPJB Pad Loads','Color','w', ...
        'Position',[230 170 760 470]);
    ax = axes;
    hold(ax,'on'); box(ax,'on');
    set(ax,'FontName','Arial','FontSize',11,'LineWidth',0.9, ...
        'YGrid','on','GridAlpha',0.14);

    padLoads = arrayfun(@(p)p.load,result.pad)/1000;
    bar(ax,1:nPads,padLoads,0.62);
    xlabel(ax,'Pad number');
    ylabel(ax,'Pad load [kN]');
    title(ax,'RotorDynX TPJB — Pad Load Distribution');
    xticks(ax,1:nPads);

    for i = 1:nPads
        text(ax,i,padLoads(i),sprintf('%.3f',padLoads(i)), ...
            'HorizontalAlignment','center','VerticalAlignment','bottom', ...
            'FontName','Arial','FontSize',9);
    end
end




% -------------------------------------------------------------------------
% Speed-sweep plots
% -------------------------------------------------------------------------
if runSpeedSweep && plotSpeedSweep

    figure('Name','RotorDynX - TPJB Speed Sweep Performance', ...
        'Color','w','Position',[80 70 1100 760]);
    tl = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
    title(tl,'RotorDynX TPJB — Speed Sweep Performance');

    ax = nexttile(tl);
    plot(ax,speedSweep.rpm,speedSweep.epsilon,'-o','LineWidth',1.5);
    grid(ax,'on');
    xlabel(ax,'Speed [rpm]');
    ylabel(ax,'Eccentricity ratio e/C_b');
    title(ax,'Journal Eccentricity');

    ax = nexttile(tl);
    plot(ax,speedSweep.rpm,speedSweep.hmin_um,'-o','LineWidth',1.5);
    grid(ax,'on');
    xlabel(ax,'Speed [rpm]');
    ylabel(ax,'Minimum film thickness [\mum]');
    title(ax,'Minimum Film Thickness');

    ax = nexttile(tl);
    plot(ax,speedSweep.rpm,speedSweep.Pmax_MPa,'-o','LineWidth',1.5);
    grid(ax,'on');
    xlabel(ax,'Speed [rpm]');
    ylabel(ax,'Maximum pressure [MPa]');
    title(ax,'Maximum Film Pressure');

    ax = nexttile(tl);
    plot(ax,speedSweep.rpm,speedSweep.power_kW,'-o','LineWidth',1.5);
    grid(ax,'on');
    xlabel(ax,'Speed [rpm]');
    ylabel(ax,'Power loss [kW]');
    title(ax,'Friction Power');

    % Journal-center eccentricity map inside the available bearing clearance
    figure('Name','RotorDynX - TPJB Speed Sweep Eccentricity Map', ...
        'Color','w','Position',[110 80 860 760]);
    ax = axes('Position',[0.09 0.10 0.82 0.82]);
    hold(ax,'on');
    axis(ax,'equal');
    box(ax,'on');
    set(ax,'FontName','Arial','FontSize',11,'LineWidth',0.9);

    th = linspace(0,2*pi,720);
    Cb_um = bearing.Cb*1e6;
    plot(ax,Cb_um*cos(th),Cb_um*sin(th),'-','Color',[0.15 0.25 0.75],'LineWidth',2.0);
    plot(ax,0,0,'k+','MarkerSize',10,'LineWidth',1.4);

    cmap = parula(max(numel(speedSweep.rpm),2));
    for ii = 1:numel(speedSweep.rpm)-1
        plot(ax,speedSweep.ex_um(ii:ii+1),speedSweep.ey_um(ii:ii+1),'-', ...
            'Color',cmap(ii,:),'LineWidth',1.6);
    end

    scatter(ax,speedSweep.ex_um,speedSweep.ey_um,44,speedSweep.rpm, ...
        'filled','MarkerEdgeColor','k','LineWidth',0.4);

    % Start / end highlights
    plot(ax,speedSweep.ex_um(1),speedSweep.ey_um(1),'o', ...
        'MarkerSize',9,'MarkerFaceColor',[0.10 0.70 0.20],'MarkerEdgeColor','k','LineWidth',1.0);
    plot(ax,speedSweep.ex_um(end),speedSweep.ey_um(end),'s', ...
        'MarkerSize',9,'MarkerFaceColor',[0.90 0.15 0.15],'MarkerEdgeColor','k','LineWidth',1.0);

    % RPM labels (all points, consistent with previous engineering-style map)
    for ii = 1:numel(speedSweep.rpm)
        text(ax,speedSweep.ex_um(ii)+0.015*Cb_um, speedSweep.ey_um(ii)+0.015*Cb_um, ...
            sprintf('%g rpm',speedSweep.rpm(ii)), ...
            'FontSize',9,'Color',[0.15 0.15 0.15], ...
            'HorizontalAlignment','left','VerticalAlignment','bottom');
    end

    % Load direction arrow
    quiver(ax,0,0,0,-0.70*Cb_um,0,'Color',[0.85 0.10 0.10], ...
        'LineWidth',1.8,'MaxHeadSize',0.35);
    text(ax,0,-0.82*Cb_um,'W','HorizontalAlignment','center', ...
        'FontWeight','bold','FontSize',11,'Color',[0.85 0.10 0.10]);

    lim = 1.20*Cb_um;
    xlim(ax,[-lim lim]);
    ylim(ax,[-lim lim]);
    grid(ax,'on');
    xlabel(ax,'Journal center X [um]');
    ylabel(ax,'Journal center Y [um]');
    title(ax,'RotorDynX TPJB — Journal Center Locus During Speed Sweep');
    subtitle(ax,sprintf('Bearing center at origin, clearance circle radius = C_b = %.3f um',Cb_um));

    colormap(ax,cmap);
    if numel(speedSweep.rpm) > 1
        caxis(ax,[min(speedSweep.rpm) max(speedSweep.rpm)]);
    else
        caxis(ax,[speedSweep.rpm(1)-0.5 speedSweep.rpm(1)+0.5]);
    end
    cb = colorbar(ax);
    cb.Label.String = 'Speed [rpm]';

    txt = {
        'ECCENTRICITY SUMMARY'
        '-------------------'
        sprintf('e/C_b start   %8.5f',speedSweep.epsilon(1))
        sprintf('e/C_b end     %8.5f',speedSweep.epsilon(end))
        sprintf('X start     %8.3f um',speedSweep.ex_um(1))
        sprintf('Y start     %8.3f um',speedSweep.ey_um(1))
        sprintf('X end       %8.3f um',speedSweep.ex_um(end))
        sprintf('Y end       %8.3f um',speedSweep.ey_um(end))
        ' ' 
        sprintf('Min speed   %8.0f rpm',min(speedSweep.rpm))
        sprintf('Max speed   %8.0f rpm',max(speedSweep.rpm))
        sprintf('Points      %8d',numel(speedSweep.rpm))
        };
    annotation('textbox',[0.66 0.67 0.26 0.20],'String',txt,'FitBoxToText','on', ...
        'BackgroundColor','w','EdgeColor',[0.7 0.7 0.7],'FontName','Consolas','FontSize',9);

    if speedSweepComputeKC
        figure('Name','RotorDynX - TPJB Speed Sweep Dynamic Coefficients', ...
            'Color','w','Position',[120 90 1050 700]);
        tl = tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
        title(tl,'RotorDynX TPJB — Dynamic Coefficients vs Speed');

        ax = nexttile(tl);
        hold(ax,'on');
        plot(ax,speedSweep.rpm,speedSweep.Kxx,'-o','LineWidth',1.5);
        plot(ax,speedSweep.rpm,speedSweep.Kyy,'-s','LineWidth',1.5);
        plot(ax,speedSweep.rpm,speedSweep.Kxy,'--','LineWidth',1.0);
        plot(ax,speedSweep.rpm,speedSweep.Kyx,'--','LineWidth',1.0);
        grid(ax,'on');
        xlabel(ax,'Speed [rpm]');
        ylabel(ax,'Stiffness [N/m]');
        title(ax,'Equivalent Stiffness');
        legend(ax,{'Kxx','Kyy','Kxy','Kyx'},'Location','best','Box','off');

        ax = nexttile(tl);
        hold(ax,'on');
        plot(ax,speedSweep.rpm,speedSweep.Cxx,'-o','LineWidth',1.5);
        plot(ax,speedSweep.rpm,speedSweep.Cyy,'-s','LineWidth',1.5);
        plot(ax,speedSweep.rpm,speedSweep.Cxy,'--','LineWidth',1.0);
        plot(ax,speedSweep.rpm,speedSweep.Cyx,'--','LineWidth',1.0);
        grid(ax,'on');
        xlabel(ax,'Speed [rpm]');
        ylabel(ax,'Damping [N.s/m]');
        title(ax,'Equivalent Damping');
        legend(ax,{'Cxx','Cyy','Cxy','Cyx'},'Location','best','Box','off');
    end

    if strcmpi(thermalModel,'HeatBalance')
        figure('Name','RotorDynX - TPJB Speed Sweep Thermal', ...
            'Color','w','Position',[150 110 1000 650]);
        tl = tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
        title(tl,'RotorDynX TPJB — Thermal Response vs Speed');

        ax = nexttile(tl);
        hold(ax,'on');
        plot(ax,speedSweep.rpm,speedSweep.Teff_C,'-o','LineWidth',1.5);
        plot(ax,speedSweep.rpm,speedSweep.Tout_C,'-s','LineWidth',1.5);
        grid(ax,'on');
        xlabel(ax,'Speed [rpm]');
        ylabel(ax,'Oil temperature [degC]');
        title(ax,'Effective and Outlet Oil Temperature');
        legend(ax,{'T_{eff}','T_{out}'},'Location','best','Box','off');

        ax = nexttile(tl);
        plot(ax,speedSweep.rpm,speedSweep.mu_Pas,'-o','LineWidth',1.5);
        grid(ax,'on');
        xlabel(ax,'Speed [rpm]');
        ylabel(ax,'Effective viscosity [Pa.s]');
        title(ax,'Effective Oil Viscosity');
    end
end



% ---- RotorDynX unified handoff -------------------------------------------
moduleOut = struct();
moduleOut.engine = 'TPJB';
moduleOut.bearingType = 'TPJB';
moduleOut.analysisMode = char(masterAnalysisMode);
moduleOut.operatingPoint = result;
moduleOut.K = result.dynamic.K;
moduleOut.C = result.dynamic.C;
moduleOut.thermal = result.thermal;
moduleOut.bearingDefinition = bearing;
moduleOut.reference = struct();
moduleOut.reference.W = bearing.W;
moduleOut.reference.omega = bearing.omega;
moduleOut.reference.muRef = result.thermal.muEff;
moduleOut.reference.PowerLoss = result.power;
if exist('speedSweep','var') && ~isempty(speedSweep)
    moduleOut.speedSweep = speedSweep;
end

end


function [eq,thermalState] = solveCoupledBearing( ...
    R,L,bearing,omega,W,Ntheta,Nz,qInit, ...
    pressureTol,maxPressureIter,omegaSOR, ...
    eqTol,maxEqIter,dqPerturb,maxQstep,maxEpsilon, ...
    fullTHD,muIso,oil,thd,thermalWarm,printEq)

    if ~fullTHD

        muMap = muIso*ones(Ntheta,Nz);

        eq = solveMechanicalEquilibrium( ...
            R,L,bearing,omega,W,Ntheta,Nz,qInit,muMap, ...
            pressureTol,maxPressureIter,omegaSOR, ...
            eqTol,maxEqIter,dqPerturb,maxQstep,maxEpsilon,printEq);

        if ~eq.converged
            error(['Mechanical equilibrium did not converge. ', ...
                   'Residual = %.3e. Solver stopped before mesh ', ...
                   'refinement / K-C extraction.'],eq.residualNorm);
        end

        thermalState.muHydro = muMap;
        thermalState.TbulkHydroC = oil.TinC*ones(Ntheta,Nz);
        thermalState.TmeanC = oil.TinC;
        thermalState.TmaxC = oil.TinC;
        thermalState.TminC = oil.TinC;
        thermalState.iterations = 0;
        thermalState.T3D = [];
        thermalState.history.iter = [];
        thermalState.history.errT = [];
        thermalState.history.errMu = [];
        thermalState.history.Tmean = [];
        thermalState.history.Tmax = [];
        return;
    end

    if isempty(thermalWarm)
        TbulkHydroC = oil.TinC*ones(Ntheta,Nz);
    else
        TbulkHydroC = resizePeriodicField( ...
            thermalWarm.TbulkHydroC,Ntheta,Nz);
    end

    muMap = oilViscosityWalther(TbulkHydroC,oil);
    q = qInit;

    histIter = zeros(thd.maxIter,1);
    histErrT = nan(thd.maxIter,1);
    histErrMu = nan(thd.maxIter,1);
    histTmean = nan(thd.maxIter,1);
    histTmax = nan(thd.maxIter,1);

    for itT = 1:thd.maxIter

        muOld = muMap;
        Told = TbulkHydroC;

        eq = solveMechanicalEquilibrium( ...
            R,L,bearing,omega,W,Ntheta,Nz,q,muMap, ...
            pressureTol,maxPressureIter,omegaSOR, ...
            eqTol,maxEqIter,dqPerturb,maxQstep,maxEpsilon, ...
            printEq && itT==1);

        q = eq.q;

        if ~eq.converged
            error(['Mechanical equilibrium did not converge before THD. ', ...
                   'Residual = %.3e. Solver stopped to avoid wasting ', ...
                   'time on thermal iterations / finer meshes.'], ...
                   eq.residualNorm);
        end

        [TbulkNewC,T3D,~,~,~] = solveFilmEnergyTHD( ...
            eq.P,eq.h,muMap,R,L,bearing,omega, ...
            eq.theta,eq.z,eq.activeMask,oil,thd);

        TbulkHydroC = ...
            (1-thd.relax)*Told + thd.relax*TbulkNewC;

        muTarget = oilViscosityWalther(TbulkHydroC,oil);
        muMap = (1-thd.relax)*muOld + thd.relax*muTarget;

        % Grooves/supply regions are maintained at inlet-oil viscosity.
        if any(~eq.activeMask)
            muIn = oilViscosityWalther(oil.TinC,oil);
            muMap(~eq.activeMask,:) = muIn;
            TbulkHydroC(~eq.activeMask,:) = oil.TinC;
        end

        errT = max(abs(TbulkHydroC(:)-Told(:))) / ...
               max(max(abs(TbulkHydroC(:))),1);

        errMu = max(abs(muMap(:)-muOld(:))) / ...
                max(max(abs(muMap(:))),1e-12);

        histIter(itT) = itT;
        histErrT(itT) = errT;
        histErrMu(itT) = errMu;
        histTmean(itT) = mean(reshape(TbulkHydroC(eq.activeMask,:),[],1));
        histTmax(itT) = max(reshape(TbulkHydroC(eq.activeMask,:),[],1));

        fprintf(['THD %2d | Tmean = %7.3f C | Tmax = %7.3f C | ', ...
                 'muMean = %.5e | dT = %.3e | dmu = %.3e\n'], ...
                 itT,histTmean(itT),histTmax(itT), ...
                 mean(reshape(muMap(eq.activeMask,:),[],1)),errT,errMu);

        if errT < thd.tolT && errMu < thd.tolMu
            break;
        end
    end

    eq = solveMechanicalEquilibrium( ...
        R,L,bearing,omega,W,Ntheta,Nz,q,muMap, ...
        pressureTol,maxPressureIter,omegaSOR, ...
        eqTol,maxEqIter,dqPerturb,maxQstep,maxEpsilon,false);

    [TbulkHydroC,T3D,TminC,TmaxC,TmeanC] = solveFilmEnergyTHD( ...
        eq.P,eq.h,muMap,R,L,bearing,omega, ...
        eq.theta,eq.z,eq.activeMask,oil,thd);

    muMap = oilViscosityWalther(TbulkHydroC,oil);

    if any(~eq.activeMask)
        muIn = oilViscosityWalther(oil.TinC,oil);
        muMap(~eq.activeMask,:) = muIn;
        TbulkHydroC(~eq.activeMask,:) = oil.TinC;
    end

    thermalState.muHydro = muMap;
    thermalState.TbulkHydroC = TbulkHydroC;
    thermalState.T3D = T3D;
    thermalState.TminC = TminC;
    thermalState.TmaxC = TmaxC;
    thermalState.TmeanC = TmeanC;
    thermalState.iterations = itT;

    thermalState.history.iter = histIter(1:itT);
    thermalState.history.errT = histErrT(1:itT);
    thermalState.history.errMu = histErrMu(1:itT);
    thermalState.history.Tmean = histTmean(1:itT);
    thermalState.history.Tmax = histTmax(1:itT);
end

%% ============================================================
% LOCAL FUNCTION 2: MECHANICAL EQUILIBRIUM
% =============================================================

function eq = solveMechanicalEquilibrium( ...
    R,L,bearing,omega,W,Ntheta,Nz,qInit,muMap, ...
    pressureTol,maxPressureIter,omegaSOR, ...
    eqTol,maxEqIter,dqPerturb,maxQstep,maxEpsilon,printEq)

    q = qInit(:);
    Pwarm = zeros(Ntheta,Nz);

    converged = false;
    finalResidualNorm = inf;

    for it = 1:maxEqIter

        [P,Fx,Fy,h,theta,z,geom] = solvePressureVariableMu( ...
            q,[0;0],R,L,bearing,omega,Ntheta,Nz,muMap, ...
            pressureTol,maxPressureIter,omegaSOR,Pwarm);

        Pwarm = P;

        residual = [Fx;Fy-W];
        residualNorm = norm(residual)/max(W,1);

        if printEq
            fprintf(['Eq %2d | eps = %.5f | Fx = %9.2f N | ', ...
                     'Fy = %9.2f N | Residual = %.3e\n'], ...
                     it,norm(q),Fx,Fy,residualNorm);
        end

        finalResidualNorm = residualNorm;

        if residualNorm <= eqTol
            converged = true;
            break;
        end

        J = zeros(2,2);

        for d = 1:2

            qp = q;
            qm = q;
            qp(d) = qp(d)+dqPerturb;
            qm(d) = qm(d)-dqPerturb;

            [~,Fxp,Fyp] = solvePressureVariableMu( ...
                qp,[0;0],R,L,bearing,omega,Ntheta,Nz,muMap, ...
                pressureTol,maxPressureIter,omegaSOR,P);

            [~,Fxm,Fym] = solvePressureVariableMu( ...
                qm,[0;0],R,L,bearing,omega,Ntheta,Nz,muMap, ...
                pressureTol,maxPressureIter,omegaSOR,P);

            J(:,d) = ([Fxp;Fyp]-[Fxm;Fym])/(2*dqPerturb);
        end

        dq = -J\residual;

        % ============================================================
        % GEOMETRY-AWARE NEWTON STEP CONTROL
        % ============================================================
        %
        % Plain bearing:
        %   epsilon < 1 is a meaningful geometric restriction.
        %
        % Pad/lobe bearing:
        %   epsilon = e/Cb may legitimately exceed 1 because Cp > Cb.
        %   Therefore DO NOT cap epsilon.  The real geometric constraint
        %   is positive film thickness on every active pad.
        % ============================================================

        if strcmpi(bearing.type,'Plain')
            maxStepLocal = maxQstep;
        else
            % Pad/lobe geometry can require substantially larger
            % normalized journal motion than the plain-bearing case.
            maxStepLocal = max(0.30,maxQstep);
        end

        if norm(dq) > maxStepLocal
            dq = dq*maxStepLocal/norm(dq);
        end

        if strcmpi(bearing.type,'Plain')

            qTrial = q+dq;

            % Preserve the original plain-bearing protection.
            if norm(qTrial) >= maxEpsilon
                qTrial = qTrial*(maxEpsilon/norm(qTrial));
            end

        else

            % --------------------------------------------------------
            % Pad/lobe geometry-aware backtracking
            % --------------------------------------------------------
            % The Newton step is reduced only if it would drive the
            % journal too close to / through an active pad surface.
            %
            % This replaces the incorrect epsilon <= 0.95 limiter.
            % --------------------------------------------------------

            thetaCheck = (0:Ntheta-1)'*(2*pi/Ntheta);

            minAllowedFilm = 0.02*bearing.Cb;   % 2% Cb safety floor

            stepFactor = 1.0;
            acceptedStep = false;
            qTrial = q;

            for ls = 1:14

                qCandidate = q + stepFactor*dq;

                zCheck = [-L/2 0 L/2];

                [HCandidate,~,geomCandidate] = ...
                    bearingFilmGeometry2D( ...
                    bearing,qCandidate,thetaCheck,zCheck);

                active2D = repmat(geomCandidate.activeMask,1,numel(zCheck));

                hActiveCandidate = ...
                    HCandidate(active2D);

                if ~isempty(hActiveCandidate) && ...
                        min(hActiveCandidate) > minAllowedFilm

                    qTrial = qCandidate;
                    acceptedStep = true;
                    break;
                end

                stepFactor = 0.5*stepFactor;
            end

            if ~acceptedStep
                error(['Fixed-lobe equilibrium step could not maintain ', ...
                       'positive film thickness. Check load, clearance, ', ...
                       'preload, pad geometry, or initial journal position.']);
            end
        end

        q = qTrial;
    end

    [P,Fx,Fy,h,theta,z,geom] = solvePressureVariableMu( ...
        q,[0;0],R,L,bearing,omega,Ntheta,Nz,muMap, ...
        pressureTol,maxPressureIter,omegaSOR,Pwarm);

    eq.q = q;
    eq.P = P;
    eq.Fx = Fx;
    eq.Fy = Fy;
    eq.h = h;              % centerline / legacy 1-D display profile
    eq.h2D = geom.h2D;      % full hydrodynamic h(theta,z)
    eq.theta = theta;
    eq.z = z;
    eq.activeMask = geom.activeMask;
    eq.boundaryMask = geom.boundaryMask;
    eq.padIndex = geom.padIndex;

    finalResidual = [Fx;Fy-W];
    finalResidualNorm = norm(finalResidual)/max(W,1);

    if finalResidualNorm <= eqTol
        converged = true;
    end

    eq.converged = converged;
    eq.residualNorm = finalResidualNorm;
    eq.iterations = it;

    eq.epsilon = norm(q);
    eq.phiDeg = mod(atan2d(q(2),q(1)),360);

    active2D = repmat(geom.activeMask,1,Nz);
    hActive = geom.h2D(active2D);

    eq.hmin = min(hActive);
    eq.hmax = max(hActive);
    eq.Pmax = max(P(:));
end

%% ============================================================
% LOCAL FUNCTION 3: VARIABLE-VISCOSITY REYNOLDS SOLVER
% =============================================================

function [P,Fx,Fy,h,theta,z,geom] = solvePressureVariableMu( ...
    q,qdot,R,L,bearing,omega,Ntheta,Nz,muMap, ...
    tol,maxIter,omegaSOR,Pinit)

    theta = (0:Ntheta-1)'*(2*pi/Ntheta);
    dtheta = 2*pi/Ntheta;

    z = linspace(-L/2,L/2,Nz);
    dz = z(2)-z(1);

    % Centerline profile retained for plotting / legacy THD interfaces.
    [h,~,geom] = bearingFilmGeometry(bearing,q,theta);

    % Full hydrodynamic geometry.  For ordinary bearings this is simply
    % replicated in z; tapered-land side lands make it genuinely 2-D.
    [H,dHdtheta,geom2D] = bearingFilmGeometry2D(bearing,q,theta,z);

    geom.h2D = H;
    geom.axialTaperMask = geom2D.axialTaperMask;

    active2D = repmat(geom.activeMask,1,Nz);

    if any(H(active2D)<=0)
        error('Non-positive film thickness encountered on an active pad/land.');
    end

    xdot = bearing.Cb*qdot(1);
    ydot = bearing.Cb*qdot(2);

    hdotTheta = -xdot*cos(theta)-ydot*sin(theta);
    hdot = repmat(hdotTheta,1,Nz);

    if isscalar(muMap)
        muMap = muMap*ones(Ntheta,Nz);
    end

    if ~isequal(size(muMap),[Ntheta Nz])
        error('muMap size must be Ntheta x Nz.');
    end

    [mobilityTheta,mobilityAxial] = ...
        reynoldsTransportFields(H,muMap,R,omega,bearing);

    RHS = ...
        6*omega*R^2*dHdtheta + 12*R^2*hdot;

    if nargin<13 || isempty(Pinit) || ...
            ~isequal(size(Pinit),[Ntheta Nz])
        PinitLocal = zeros(Ntheta,Nz);
    else
        PinitLocal = max(Pinit,0);
    end

    % Ambient pressure at axial ends, supply-groove/pad-edge nodes and any
    % internal 2-D prescribed-pressure region (e.g. pressure-dam relief track).
    active2D = repmat(geom.activeMask,1,Nz);
    solveMask2D = active2D & ~geom2D.fixedPressureMask2D;
    solveMask2D(:,1) = false;
    solveMask2D(:,end) = false;

    pressureSolver = 'SparseActiveSet';
    if isfield(bearing,'pressureSolver')
        pressureSolver = bearing.pressureSolver;
    end

    if strcmpi(pressureSolver,'SparseActiveSet')

        sparseMaxAS = 40;
        sparseCavTol = 1e-10;

        if isfield(bearing,'sparseMaxActiveSetIter')
            sparseMaxAS = bearing.sparseMaxActiveSetIter;
        end

        if isfield(bearing,'sparseCavitationTol')
            sparseCavTol = bearing.sparseCavitationTol;
        end

        try
            P = solveReynoldsSparseActiveSet( ...
                mobilityTheta,mobilityAxial,RHS,R,dtheta,dz,solveMask2D, ...
                Ntheta,Nz,tol,sparseCavTol,sparseMaxAS,PinitLocal);
        catch ME
            warning('Sparse Reynolds solver failed (%s). Falling back to projected SOR.', ...
                ME.message);

            P = solveReynoldsProjectedSOR( ...
                mobilityTheta,mobilityAxial,RHS,R,dtheta,dz,solveMask2D, ...
                geom2D,Ntheta,Nz,tol,maxIter,omegaSOR,PinitLocal);
        end

    elseif strcmpi(pressureSolver,'SOR')

        P = solveReynoldsProjectedSOR( ...
            mobilityTheta,mobilityAxial,RHS,R,dtheta,dz,solveMask2D, ...
            geom2D,Ntheta,Nz,tol,maxIter,omegaSOR,PinitLocal);

    else
        error('Unknown pressureSolver "%s". Use "SparseActiveSet" or "SOR".', ...
            pressureSolver);
    end

    % Re-enforce fixed boundaries exactly.
    P(:,1) = 0;
    P(:,end) = 0;
    P(~geom.activeMask,:) = 0;
    P(geom2D.fixedPressureMask2D) = 0;
    P = max(P,0);

    % ---------------------------------------------------------
    % Vectorized pressure-force integration
    % ---------------------------------------------------------
    wz = ones(Nz,1);
    wz([1 end]) = 0.5;

    intPz = P*wz*dz;
    activeForce = double(geom.activeMask);

    Fx = -R*dtheta*sum(cos(theta).*intPz.*activeForce);
    Fy = -R*dtheta*sum(sin(theta).*intPz.*activeForce);
end


function P = solveReynoldsSparseActiveSet( ...
    mobilityTheta,mobilityAxial,RHS,R,dtheta,dz,solveMask, ...
    Ntheta,Nz,linearTol,cavitationTol,maxActiveSetIter,Pinit)

    % ============================================================
    % SPARSE FINITE-DIFFERENCE REYNOLDS SOLVER
    %
    % Discrete equation:
    %
    %   Ap*Pp - Ae*Pe - Aw*Pw - An*Pn - As*Ps = -RHS
    %
    % Cavitation is represented as a pressure complementarity problem:
    %
    %   P >= 0
    %   w = M*P - b >= 0
    %   P.*w = 0
    %
    % solved here using an active-set iteration.
    % ============================================================

    if ~isequal(size(solveMask),[Ntheta Nz])
        error('solveMask must be Ntheta x Nz.');
    end

    unknownLinear = find(solveMask);
    nUnknown = numel(unknownLinear);

    if nUnknown == 0
        P = zeros(Ntheta,Nz);
        return;
    end

    idMap = zeros(Ntheta,Nz);
    idMap(unknownLinear) = 1:nUnknown;

    % Maximum 5 nonzeros per equation.
    I = zeros(5*nUnknown,1);
    J = zeros(5*nUnknown,1);
    V = zeros(5*nUnknown,1);
    b = zeros(nUnknown,1);

    nzCount = 0;

    for row = 1:nUnknown

        linearIndex = unknownLinear(row);
        [i,j] = ind2sub([Ntheta Nz],linearIndex);

        ip = i+1;
        if ip>Ntheta, ip=1; end

        im = i-1;
        if im<1, im=Ntheta; end

        Ae = 0.5*(mobilityTheta(i,j)+mobilityTheta(ip,j))/dtheta^2;
        Aw = 0.5*(mobilityTheta(i,j)+mobilityTheta(im,j))/dtheta^2;
        An = R^2*0.5*(mobilityAxial(i,j)+mobilityAxial(i,j+1))/dz^2;
        As = R^2*0.5*(mobilityAxial(i,j)+mobilityAxial(i,j-1))/dz^2;

        Ap = Ae+Aw+An+As;

        nzCount = nzCount+1;
        I(nzCount) = row;
        J(nzCount) = row;
        V(nzCount) = Ap;

        % East neighbor
        col = idMap(ip,j);
        if col>0
            nzCount = nzCount+1;
            I(nzCount) = row;
            J(nzCount) = col;
            V(nzCount) = -Ae;
        end

        % West neighbor
        col = idMap(im,j);
        if col>0
            nzCount = nzCount+1;
            I(nzCount) = row;
            J(nzCount) = col;
            V(nzCount) = -Aw;
        end

        % North axial neighbor
        col = idMap(i,j+1);
        if col>0
            nzCount = nzCount+1;
            I(nzCount) = row;
            J(nzCount) = col;
            V(nzCount) = -An;
        end

        % South axial neighbor
        col = idMap(i,j-1);
        if col>0
            nzCount = nzCount+1;
            I(nzCount) = row;
            J(nzCount) = col;
            V(nzCount) = -As;
        end

        b(row) = -RHS(i,j);
    end

    I = I(1:nzCount);
    J = J(1:nzCount);
    V = V(1:nzCount);

    M = sparse(I,J,V,nUnknown,nUnknown);

    % ------------------------------------------------------------
    % Initial pressure-active set
    % ------------------------------------------------------------
    p = zeros(nUnknown,1);

    if ~isempty(Pinit) && isequal(size(Pinit),[Ntheta Nz]) && ...
            any(Pinit(unknownLinear)>0)

        pInit = max(Pinit(unknownLinear),0);

        scaleInit = max(max(pInit),1);
        pressureActive = pInit > max(linearTol*scaleInit,1e-12);

        % Include locally positive-source nodes to permit immediate growth.
        pressureActive = pressureActive | (b>0);

        if ~any(pressureActive)
            pressureActive = true(nUnknown,1);
        end

    else
        pressureActive = true(nUnknown,1);
    end

    converged = false;

    for ia = 1:maxActiveSetIter

        p(:) = 0;

        freeIdx = find(pressureActive);

        if ~isempty(freeIdx)
            Mf = M(freeIdx,freeIdx);
            bf = b(freeIdx);

            pf = Mf\bf;
            p(freeIdx) = pf;
        end

        pressureScale = max(max(abs(p)),1);
        pTol = max(cavitationTol*pressureScale, ...
                   linearTol*pressureScale);

        % Any negative free pressure violates P >= 0.
        negativeFree = pressureActive & (p < -pTol);

        if any(negativeFree)
            pressureActive(negativeFree) = false;
            continue;
        end

        p(p<0) = 0;

        % Complementarity residual.
        w = M*p-b;

        residualScale = max(norm(b,inf),1);
        wTol = max(cavitationTol*residualScale, ...
                   linearTol*residualScale);

        % A cavitated node with negative residual wants to rebuild pressure.
        release = (~pressureActive) & (w < -wTol);

        if any(release)
            pressureActive(release) = true;
            continue;
        end

        converged = true;
        break;
    end

    if ~converged
        error('Sparse active-set cavitation did not converge in %d iterations.', ...
            maxActiveSetIter);
    end

    % Final complementarity quality check.
    p = max(p,0);
    w = M*p-b;

    pressureScale = max(max(p),1);
    residualScale = max(norm(b,inf),1);

    compPressureErr = max(max(-p),0)/pressureScale;
    compResidualErr = max(max(-w),0)/residualScale;

    if max(compPressureErr,compResidualErr) > max(10*linearTol,1e-7)
        error('Sparse active-set complementarity residual too large (%.3e).', ...
            max(compPressureErr,compResidualErr));
    end

    P = zeros(Ntheta,Nz);
    P(unknownLinear) = p;
end


function P = solveReynoldsProjectedSOR( ...
    mobilityTheta,mobilityAxial,RHS,R,dtheta,dz,solveMask, ...
    geom,Ntheta,Nz,tol,maxIter,omegaSOR,Pinit)

    % Legacy projected SOR retained for validation and automatic fallback.

    if isempty(Pinit) || ~isequal(size(Pinit),[Ntheta Nz])
        P = zeros(Ntheta,Nz);
    else
        P = max(Pinit,0);
    end

    P(:,1) = 0;
    P(:,end) = 0;
    if isfield(geom,'fixedPressureMask2D')
        P(geom.fixedPressureMask2D) = 0;
    else
        P(~geom.activeMask,:) = 0;
        P(geom.boundaryMask,:) = 0;
    end

    for it = 1:maxIter

        maxChange = 0;
        maxPnow = max(max(P(:)),1);

        for j = 2:Nz-1

            for i = 1:Ntheta

                if ~solveMask(i,j)
                    P(i,j) = 0;
                    continue;
                end

                ip = i+1;
                if ip>Ntheta, ip=1; end

                im = i-1;
                if im<1, im=Ntheta; end

                Ae = 0.5*(mobilityTheta(i,j)+mobilityTheta(ip,j))/dtheta^2;
                Aw = 0.5*(mobilityTheta(i,j)+mobilityTheta(im,j))/dtheta^2;

                An = R^2*0.5*(mobilityAxial(i,j)+mobilityAxial(i,j+1))/dz^2;
                As = R^2*0.5*(mobilityAxial(i,j)+mobilityAxial(i,j-1))/dz^2;

                Ap = Ae+Aw+An+As;

                Pgs = ...
                    (Ae*P(ip,j)+Aw*P(im,j)+ ...
                     An*P(i,j+1)+As*P(i,j-1)-RHS(i,j)) / Ap;

                Pgs = max(Pgs,0);

                Pnew = ...
                    (1-omegaSOR)*P(i,j)+omegaSOR*Pgs;

                Pnew = max(Pnew,0);

                delta = abs(Pnew-P(i,j));
                if delta>maxChange
                    maxChange = delta;
                end

                P(i,j) = Pnew;
            end
        end

        if maxChange/maxPnow<tol
            break;
        end
    end
end

%% ============================================================
% LOCAL FUNCTION 4: FILM THD ENERGY SOLVER
% =============================================================

function [TbulkHydroC,T3Dhydro,TminC,TmaxC,TmeanC] = ...
    solveFilmEnergyTHD( ...
    Phydro,hHydro,muHydro,R,L,bearing,omega, ...
    thetaHydro,zHydro,activeHydro,oil,thd)

    Nh = length(thetaHydro);
    Nzh = length(zHydro);

    Nt = min(Nh,thd.maxNtheta);
    if mod(Nt,2)==0, Nt = Nt-1; end
    Nt = max(Nt,31);

    Nzt = min(Nzh,thd.maxNz);
    if mod(Nzt,2)==0, Nzt = Nzt-1; end
    Nzt = max(Nzt,7);

    thetaT = (0:Nt-1)'*(2*pi/Nt);
    zT = linspace(-L/2,L/2,Nzt);

    P = interpPeriodic2(thetaHydro,zHydro,Phydro,thetaT,zT);
    mu = interpPeriodic2(thetaHydro,zHydro,muHydro,thetaT,zT);
    h = interp1Periodic(thetaHydro,hHydro,thetaT);

    % Rebuild exact pad/groove mask on thermal circumferential mesh.
    [~,~,geomT] = bearingFilmGeometry(bearing,[0;0],thetaT);
    activeT = geomT.activeMask;
    boundaryT = geomT.boundaryMask;

    dtheta = 2*pi/Nt;
    dz = zT(2)-zT(1);

    dpdtheta = zeros(Nt,Nzt);
    dpdz = zeros(Nt,Nzt);

    for i = 1:Nt

        if ~activeT(i)
            continue;
        end

        ip = i+1; if ip>Nt, ip=1; end
        im = i-1; if im<1, im=Nt; end

        dpdtheta(i,:) = (P(ip,:)-P(im,:))/(2*dtheta);
    end

    dpdz(:,2:end-1) = (P(:,3:end)-P(:,1:end-2))/(2*dz);
    dpdz(:,1) = (P(:,2)-P(:,1))/dz;
    dpdz(:,end) = (P(:,end)-P(:,end-1))/dz;

    dpdx = dpdtheta/R;

    Ny = thd.Ny;
    s = linspace(0,1,Ny);
    ds = s(2)-s(1);

    T = oil.TinC*ones(Nt,Nzt,Ny);
    U = omega*R;

    % ------------------------------------------------------------
    % THERMAL INLET FOR PLAIN BEARING
    % ------------------------------------------------------------
    % Plain bearing has no geometric groove mask, therefore the fresh-oil
    % inlet must be imposed explicitly at supplyGrooveAngleDeg.
    thetaIn = mod(oil.supplyGrooveAngleDeg*pi/180,2*pi);

    [~,iThermalInlet] = min( ...
        abs(wrapToPiLocal(thetaT-thetaIn)));

    for iter = 1:thd.energyMaxIter

        mu3 = oilViscosityWalther(T,oil);
        rho3 = oilDensity(T,oil);

        maxDelta = 0;

        for i = 1:Nt

            % ========================================================
            % THERMAL INLET / GROOVE BOUNDARY
            % ========================================================

            if strcmpi(bearing.type,'Plain')

                % Plain bearing:
                % explicitly impose fresh oil at the supply groove line.
                if i == iThermalInlet
                    T(i,:,:) = oil.TinC;
                    continue;
                end

            else

                % Pad/lobe bearing:
                % inter-pad grooves and pad edges act as fresh-oil
                % thermal boundaries.
                if ~activeT(i) || boundaryT(i)
                    T(i,:,:) = oil.TinC;
                    continue;
                end
            end

            im = i-1; if im<1, im=Nt; end
            ip = i+1; if ip>Nt, ip=1; end

            for j = 1:Nzt

                hj = h(i);
                dy = hj*ds;

                aW = oil.k/max(dy,eps);

                TbcBush = ...
                    (aW*T(i,j,2)+oil.hBush*oil.TbushBulkC) / ...
                    max(aW+oil.hBush,eps);

                TbcJournal = ...
                    (aW*T(i,j,Ny-1)+oil.hJournal*oil.TjournalBulkC) / ...
                    max(aW+oil.hJournal,eps);

                Tline = squeeze(T(i,j,:));
                Tline(1) = TbcBush;
                Tline(end) = TbcJournal;

                for k = 2:Ny-1

                    sk = s(k);
                    muk = mu3(i,j,k);
                    rhok = rho3(i,j,k);

                    u = U*sk + ...
                        (dpdx(i,j)/(2*muk))*(sk*hj)*(sk*hj-hj);

                    w = ...
                        (dpdz(i,j)/(2*muk))*(sk*hj)*(sk*hj-hj);

                    dudY = U/hj + ...
                        (dpdx(i,j)/(2*muk))*(2*sk*hj-hj);

                    dwdY = ...
                        (dpdz(i,j)/(2*muk))*(2*sk*hj-hj);

                    Phi = muk*(dudY^2+dwdY^2);

                    atheta = rhok*oil.cp*abs(u)/(R*dtheta);

                    if u>=0
                        TupTheta = T(im,j,k);
                    else
                        TupTheta = T(ip,j,k);
                    end

                    if abs(w)>0 && Nzt>1
                        az = rhok*oil.cp*abs(w)/dz;

                        if w>=0
                            jm = max(j-1,1);
                            TupZ = T(i,jm,k);
                        else
                            jp = min(j+1,Nzt);
                            TupZ = T(i,jp,k);
                        end
                    else
                        az = 0;
                        TupZ = T(i,j,k);
                    end

                    ay = oil.k/max(dy^2,eps);
                    ap = atheta+az+2*ay;

                    Tstar = ...
                        (atheta*TupTheta+az*TupZ+ ...
                         ay*Tline(k-1)+ay*T(i,j,k+1)+Phi) / ...
                         max(ap,eps);

                    Tcandidate = ...
                        (1-thd.energyRelax)*T(i,j,k) + ...
                        thd.energyRelax*Tstar;

                    maxDelta = ...
                        max(maxDelta,abs(Tcandidate-T(i,j,k)));

                    Tline(k) = Tcandidate;
                end

                T(i,j,:) = Tline;
            end
        end

        scaleT = max(max(abs(T(:))),1);

        if maxDelta/scaleT<thd.energyTol
            break;
        end
    end

    TbulkT = mean(T,3);

    TbulkHydroC = interpPeriodic2( ...
        thetaT,zT,TbulkT,thetaHydro,zHydro);

    T3Dhydro = zeros(Nh,Nzh,Ny);

    for k = 1:Ny
        T3Dhydro(:,:,k) = interpPeriodic2( ...
            thetaT,zT,T(:,:,k),thetaHydro,zHydro);
    end

    % Reset hydro-grid groove temperatures exactly to inlet temperature.
    TbulkHydroC(~activeHydro,:) = oil.TinC;
    for k = 1:Ny
        Tk = T3Dhydro(:,:,k);
        Tk(~activeHydro,:) = oil.TinC;
        T3Dhydro(:,:,k) = Tk;
    end

    Tactive = T3Dhydro(repmat(activeHydro,1,Nzh,Ny));

    if isempty(Tactive)
        TminC = oil.TinC;
        TmaxC = oil.TinC;
        TmeanC = oil.TinC;
    else
        TminC = min(Tactive);
        TmaxC = max(Tactive);
        TmeanC = mean(Tactive);
    end
end

%% ============================================================
% LOCAL FUNCTION 5: THERMAL ENERGY BALANCE DIAGNOSTIC
% =============================================================

function energy = thermalEnergyBalance( ...
    thermalState,eq,muHydro,qzLeft,qzRight, ...
    R,L,omega,PowerLoss,oil)

    theta = eq.theta;
    z = eq.z;
    h = eq.h;

    Ntheta = length(theta);
    Nz = length(z);

    dtheta = 2*pi/Ntheta;
    dz = z(2)-z(1);

    Tbulk = thermalState.TbulkHydroC;
    T3D = thermalState.T3D;

    % --------------------------------------------------------
    % 1) Mixed outlet oil temperature
    % --------------------------------------------------------

    rhoLeft = oilDensity(Tbulk(:,1),oil);
    rhoRight = oilDensity(Tbulk(:,end),oil);

    mdotLeftLocal = ...
        rhoLeft .* abs(qzLeft) * R*dtheta;

    mdotRightLocal = ...
        rhoRight .* abs(qzRight) * R*dtheta;

    mdotLeft = sum(mdotLeftLocal);
    mdotRight = sum(mdotRightLocal);

    mdotTot = mdotLeft+mdotRight;

    Hleft = ...
        sum(mdotLeftLocal .* oil.cp .* Tbulk(:,1));

    Hright = ...
        sum(mdotRightLocal .* oil.cp .* Tbulk(:,end));

    if mdotTot>0
        ToutMixC = ...
            (Hleft+Hright)/(mdotTot*oil.cp);
    else
        ToutMixC = oil.TinC;
    end

    Qoil = ...
        mdotTot*oil.cp*(ToutMixC-oil.TinC);

    % --------------------------------------------------------
    % 2) Heat transfer to bush and journal
    % --------------------------------------------------------

    if isempty(T3D)

        TbushWall = Tbulk;
        TjournalWall = Tbulk;

    else

        TbushWall = T3D(:,:,1);
        TjournalWall = T3D(:,:,end);
    end

    wz = ones(1,Nz);
    wz([1 end]) = 0.5;

    Qbush = 0;
    Qjournal = 0;

    for i = 1:Ntheta

        if ~eq.activeMask(i)
            continue;
        end

        qBushLocal = ...
            oil.hBush*(TbushWall(i,:)-oil.TbushBulkC);

        qJournalLocal = ...
            oil.hJournal*(TjournalWall(i,:)-oil.TjournalBulkC);

        areaStrip = R*dtheta;

        Qbush = ...
            Qbush + sum(qBushLocal.*wz)*dz*areaStrip;

        Qjournal = ...
            Qjournal + sum(qJournalLocal.*wz)*dz*areaStrip;
    end

    Qwalls = Qbush+Qjournal;

    % --------------------------------------------------------
    % 3) Overall diagnostic
    % --------------------------------------------------------

    Qaccounted = Qoil+Qwalls;

    residualW = PowerLoss-Qaccounted;

    residualPct = ...
        100*residualW/max(abs(PowerLoss),eps);

    energy.available = true;
    energy.ToutMixC = ToutMixC;

    energy.mdotLeft = mdotLeft;
    energy.mdotRight = mdotRight;
    energy.mdotTotal = mdotTot;

    energy.Qoil = Qoil;

    energy.Qbush = Qbush;
    energy.Qjournal = Qjournal;
    energy.Qwalls = Qwalls;

    energy.Qaccounted = Qaccounted;

    energy.residualW = residualW;
    energy.residualPct = residualPct;

    % Note:
    % This is a first-pass overall diagnostic because the hydrodynamic
    % model does not explicitly solve a feed-groove mass-flow boundary.
    % Makeup oil is assumed equal to total side leakage.
end

%% ============================================================
% LOCAL FUNCTION 6A: DIRECT PERTURBED-REYNOLDS K/C
% =============================================================

function [K,Cmat,info] = calculateBearingKCDirectPerturbed( ...
    q,R,L,bearing,omega,Ntheta,Nz,muMap,Pbase)

    % ============================================================
    % FIRST-ORDER PERTURBED REYNOLDS EQUATIONS
    %
    % Base discrete Reynolds equation:
    %
    %       M(h,mu) * p0 = b(h,hDot)
    %
    % For a physical displacement x_j:
    %
    %       M0 * p_xj = b_xj - M_xj * p0
    %
    % For a physical velocity xdot_j:
    %
    %       M0 * p_xdotj = b_xdotj
    %
    % because mobility does not depend on journal velocity.
    %
    % The equilibrium positive-pressure region is held fixed during
    % the first-order solution (frozen cavitation boundary).
    %
    % For THD, muMap is the converged equilibrium viscosity field and
    % is frozen during the perturbation, consistent with the previous
    % finite-difference implementation.
    % ============================================================

    theta = (0:Ntheta-1)'*(2*pi/Ntheta);
    dtheta = 2*pi/Ntheta;

    z = linspace(-L/2,L/2,Nz);
    dz = z(2)-z(1);

    [h,~,geom] = bearingFilmGeometry(bearing,q,theta);
    [H,~,geom2D] = bearingFilmGeometry2D(bearing,q,theta,z);

    active2D = repmat(geom.activeMask,1,Nz);

    if any(H(active2D)<=0)
        error('Non-positive film thickness in direct K/C extraction.');
    end

    if isscalar(muMap)
        muMap = muMap*ones(Ntheta,Nz);
    end

    if ~isequal(size(muMap),[Ntheta Nz])
        error('muMap size must be Ntheta x Nz in direct K/C extraction.');
    end

    if ~isequal(size(Pbase),[Ntheta Nz])
        error('Pbase size must be Ntheta x Nz in direct K/C extraction.');
    end

    % Geometric Reynolds unknowns exclude axial ambient boundaries,
    % pad/groove edges and internal prescribed-pressure tracks.
    active2D = repmat(geom.activeMask,1,Nz);
    solveMask = active2D & ~geom2D.fixedPressureMask2D;
    solveMask(:,1) = false;
    solveMask(:,end) = false;

    % Frozen equilibrium cavitation region.
    % SparseActiveSet produces exact zeros on cavitated nodes, but use a
    % tiny relative threshold to protect against roundoff/fallback solves.
    pScale = max(Pbase(:));
    pActiveTol = max(1e-12*max(pScale,1),1e-12);

    pressureActiveMask = solveMask & (Pbase > pActiveTol);

    activeLinear = find(pressureActiveMask);
    nActive = numel(activeLinear);

    if nActive == 0
        error('No positive-pressure nodes available for direct K/C extraction.');
    end

    idMap = zeros(Ntheta,Nz);
    idMap(activeLinear) = 1:nActive;

    [mobilityTheta,mobilityAxial,kappaTheta,kappaAxial] = ...
        reynoldsTransportFields(H,muMap,R,omega,bearing);

    % Assemble the base operator only once.
    M0 = assembleFrozenActiveReynoldsOperator( ...
        mobilityTheta,mobilityAxial,R,dtheta,dz,pressureActiveMask,idMap, ...
        activeLinear,Ntheta,Nz);

    % ------------------------------------------------------------
    % Film-thickness derivatives with respect to PHYSICAL x and y
    % ------------------------------------------------------------
    dhdx = -cos(theta);
    dhdy = -sin(theta);

    dhdx2D = repmat(dhdx,1,Nz);
    dhdy2D = repmat(dhdy,1,Nz);

    % Mobility derivatives with turbulence included.
    %
    % In Auto mode, the regime blend selected at the equilibrium
    % operating point is treated as frozen during the first-order
    % perturbation.  The local Re dependence inside kappa remains
    % differentiated analytically.
    %
    % a_theta = h^3/(mu*kappa_theta)
    % a_z     = h^3/(mu*kappa_z)
    %
    % Re is proportional to h for frozen mu and rho, therefore:
    % d(a)/dh = (a/h) * [3 - n*(kappa-1)/kappa]
    Hmat = H;

    dMobThetaDh = ...
        (mobilityTheta./Hmat) .* ...
        (3 - 0.90*(kappaTheta-1)./kappaTheta);

    dMobAxialDh = ...
        (mobilityAxial./Hmat) .* ...
        (3 - 0.96*(kappaAxial-1)./kappaAxial);

    dMobThetaDx = dMobThetaDh .* dhdx2D;
    dMobThetaDy = dMobThetaDh .* dhdy2D;

    dMobAxialDx = dMobAxialDh .* dhdx2D;
    dMobAxialDy = dMobAxialDh .* dhdy2D;

    % ------------------------------------------------------------
    % Derivatives of b = -RHS
    %
    % RHS = 6*w*R^2*h_theta + 12*R^2*h_dot
    %
    % h_theta,x = +sin(theta)
    % h_theta,y = -cos(theta)
    % h_dot,xdot = -cos(theta)
    % h_dot,ydot = -sin(theta)
    % ------------------------------------------------------------
    dbdx_theta = -6*omega*R^2*sin(theta);
    dbdy_theta = +6*omega*R^2*cos(theta);

    dbdxdot_theta = +12*R^2*cos(theta);
    dbdydot_theta = +12*R^2*sin(theta);

    dbdx = repmat(dbdx_theta,1,Nz);
    dbdy = repmat(dbdy_theta,1,Nz);
    dbdxdot = repmat(dbdxdot_theta,1,Nz);
    dbdydot = repmat(dbdydot_theta,1,Nz);

    % Mobility-operator derivative acting on the base pressure.
    MxP0 = applyReynoldsOperatorDerivative( ...
        dMobThetaDx,dMobAxialDx,Pbase,R,dtheta,dz,activeLinear,Ntheta,Nz);

    MyP0 = applyReynoldsOperatorDerivative( ...
        dMobThetaDy,dMobAxialDy,Pbase,R,dtheta,dz,activeLinear,Ntheta,Nz);

    rhsPx = dbdx(activeLinear) - MxP0;
    rhsPy = dbdy(activeLinear) - MyP0;

    rhsPxdot = dbdxdot(activeLinear);
    rhsPydot = dbdydot(activeLinear);

    % One sparse factorization / four right-hand sides.
    RHSall = [rhsPx rhsPy rhsPxdot rhsPydot];
    Pall = M0\RHSall;

    Px = zeros(Ntheta,Nz);
    Py = zeros(Ntheta,Nz);
    Pxdot = zeros(Ntheta,Nz);
    Pydot = zeros(Ntheta,Nz);

    Px(activeLinear) = Pall(:,1);
    Py(activeLinear) = Pall(:,2);
    Pxdot(activeLinear) = Pall(:,3);
    Pydot(activeLinear) = Pall(:,4);

    % ------------------------------------------------------------
    % Convert pressure perturbations directly to force derivatives.
    %
    % dF/dx = integral(-p_x*n dA)
    % K      = -dF/dx
    %
    % dF/dv = integral(-p_v*n dA)
    % C      = -dF/dv
    % ------------------------------------------------------------
    dFdx = integratePressurePerturbationForce( ...
        Px,R,dtheta,dz,theta,geom.activeMask);

    dFdy = integratePressurePerturbationForce( ...
        Py,R,dtheta,dz,theta,geom.activeMask);

    dFdxdot = integratePressurePerturbationForce( ...
        Pxdot,R,dtheta,dz,theta,geom.activeMask);

    dFdydot = integratePressurePerturbationForce( ...
        Pydot,R,dtheta,dz,theta,geom.activeMask);

    K = -[dFdx dFdy];
    Cmat = -[dFdxdot dFdydot];

    info.nPressureActive = nActive;
    info.pressureActiveMask = pressureActiveMask;
    info.Px = Px;
    info.Py = Py;
    info.Pxdot = Pxdot;
    info.Pydot = Pydot;
end


function M = assembleFrozenActiveReynoldsOperator( ...
    mobilityTheta,mobilityAxial,R,dtheta,dz,pressureActiveMask,idMap, ...
    activeLinear,Ntheta,Nz)

    nUnknown = numel(activeLinear);

    I = zeros(5*nUnknown,1);
    J = zeros(5*nUnknown,1);
    V = zeros(5*nUnknown,1);

    nzCount = 0;

    for row = 1:nUnknown

        linearIndex = activeLinear(row);
        [i,j] = ind2sub([Ntheta Nz],linearIndex);

        ip = i+1;
        if ip>Ntheta, ip=1; end

        im = i-1;
        if im<1, im=Ntheta; end

        Ae = 0.5*(mobilityTheta(i,j)+mobilityTheta(ip,j))/dtheta^2;
        Aw = 0.5*(mobilityTheta(i,j)+mobilityTheta(im,j))/dtheta^2;
        An = R^2*0.5*(mobilityAxial(i,j)+mobilityAxial(i,j+1))/dz^2;
        As = R^2*0.5*(mobilityAxial(i,j)+mobilityAxial(i,j-1))/dz^2;

        Ap = Ae+Aw+An+As;

        nzCount = nzCount+1;
        I(nzCount) = row;
        J(nzCount) = row;
        V(nzCount) = Ap;

        if pressureActiveMask(ip,j)
            nzCount = nzCount+1;
            I(nzCount) = row;
            J(nzCount) = idMap(ip,j);
            V(nzCount) = -Ae;
        end

        if pressureActiveMask(im,j)
            nzCount = nzCount+1;
            I(nzCount) = row;
            J(nzCount) = idMap(im,j);
            V(nzCount) = -Aw;
        end

        if pressureActiveMask(i,j+1)
            nzCount = nzCount+1;
            I(nzCount) = row;
            J(nzCount) = idMap(i,j+1);
            V(nzCount) = -An;
        end

        if pressureActiveMask(i,j-1)
            nzCount = nzCount+1;
            I(nzCount) = row;
            J(nzCount) = idMap(i,j-1);
            V(nzCount) = -As;
        end
    end

    I = I(1:nzCount);
    J = J(1:nzCount);
    V = V(1:nzCount);

    M = sparse(I,J,V,nUnknown,nUnknown);
end


function MprimeP = applyReynoldsOperatorDerivative( ...
    dMobilityTheta,dMobilityAxial,Pbase,R,dtheta,dz,activeLinear,Ntheta,Nz)

    nUnknown = numel(activeLinear);
    MprimeP = zeros(nUnknown,1);

    for row = 1:nUnknown

        linearIndex = activeLinear(row);
        [i,j] = ind2sub([Ntheta Nz],linearIndex);

        ip = i+1;
        if ip>Ntheta, ip=1; end

        im = i-1;
        if im<1, im=Ntheta; end

        dAe = 0.5*(dMobilityTheta(i,j)+dMobilityTheta(ip,j))/dtheta^2;
        dAw = 0.5*(dMobilityTheta(i,j)+dMobilityTheta(im,j))/dtheta^2;
        dAn = R^2*0.5*(dMobilityAxial(i,j)+dMobilityAxial(i,j+1))/dz^2;
        dAs = R^2*0.5*(dMobilityAxial(i,j)+dMobilityAxial(i,j-1))/dz^2;

        dAp = dAe+dAw+dAn+dAs;

        MprimeP(row) = ...
            dAp*Pbase(i,j) ...
            - dAe*Pbase(ip,j) ...
            - dAw*Pbase(im,j) ...
            - dAn*Pbase(i,j+1) ...
            - dAs*Pbase(i,j-1);
    end
end


function dF = integratePressurePerturbationForce( ...
    Ppert,R,dtheta,dz,theta,activeMask)

    Nz = size(Ppert,2);

    wz = ones(Nz,1);
    wz([1 end]) = 0.5;

    intPz = Ppert*wz*dz;
    activeForce = double(activeMask);

    dFx = -R*dtheta*sum(cos(theta).*intPz.*activeForce);
    dFy = -R*dtheta*sum(sin(theta).*intPz.*activeForce);

    dF = [dFx;dFy];
end


%% ============================================================
% LOCAL FUNCTION 6B: LEGACY FINITE-DIFFERENCE K/C EXTRACTION
% =============================================================

function [K,Cmat] = calculateBearingKC( ...
    q,dxPerturb,dvPerturb, ...
    R,L,bearing,omega,Ntheta,Nz,muMap,Pbase, ...
    pressureTol,maxPressureIter,omegaSOR)

    K = calculateBearingKOnly( ...
        q,dxPerturb, ...
        R,L,bearing,omega,Ntheta,Nz,muMap,Pbase, ...
        pressureTol,maxPressureIter,omegaSOR);

    Cmat = calculateBearingCOnly( ...
        q,dvPerturb, ...
        R,L,bearing,omega,Ntheta,Nz,muMap,Pbase, ...
        pressureTol,maxPressureIter,omegaSOR);
end

function K = calculateBearingKOnly( ...
    q,dxPerturb, ...
    R,L,bearing,omega,Ntheta,Nz,muMap,Pbase, ...
    pressureTol,maxPressureIter,omegaSOR)

    dq = dxPerturb/bearing.Cb;
    K = zeros(2,2);

    for d = 1:2

        qp = q;
        qm = q;

        qp(d) = qp(d)+dq;
        qm(d) = qm(d)-dq;

        [~,Fxp,Fyp] = solvePressureVariableMu( ...
            qp,[0;0],R,L,bearing,omega,Ntheta,Nz,muMap, ...
            pressureTol,maxPressureIter,omegaSOR,Pbase);

        [~,Fxm,Fym] = solvePressureVariableMu( ...
            qm,[0;0],R,L,bearing,omega,Ntheta,Nz,muMap, ...
            pressureTol,maxPressureIter,omegaSOR,Pbase);

        K(:,d) = ...
            -([Fxp;Fyp]-[Fxm;Fym])/(2*dxPerturb);
    end
end

function Cmat = calculateBearingCOnly( ...
    q,dvPerturb, ...
    R,L,bearing,omega,Ntheta,Nz,muMap,Pbase, ...
    pressureTol,maxPressureIter,omegaSOR)

    Cmat = zeros(2,2);

    for d = 1:2

        vp = [0;0];
        vm = [0;0];

        vp(d) = dvPerturb;
        vm(d) = -dvPerturb;

        qdotp = vp/bearing.Cb;
        qdotm = vm/bearing.Cb;

        [~,Fxp,Fyp] = solvePressureVariableMu( ...
            q,qdotp,R,L,bearing,omega,Ntheta,Nz,muMap, ...
            pressureTol,maxPressureIter,omegaSOR,Pbase);

        [~,Fxm,Fym] = solvePressureVariableMu( ...
            q,qdotm,R,L,bearing,omega,Ntheta,Nz,muMap, ...
            pressureTol,maxPressureIter,omegaSOR,Pbase);

        Cmat(:,d) = ...
            -([Fxp;Fyp]-[Fxm;Fym])/(2*dvPerturb);
    end
end

%% ============================================================
% LOCAL FUNCTION 7: SIDE LEAKAGE
% =============================================================

function [Qleft,Qright,Qtotal,qzLeft,qzRight] = ...
    sideLeakageVariableMu(P,h,muMap,R,theta,z,activeMask,omega,bearing)

    Ntheta = length(theta);
    Nz = length(z);

    dtheta = 2*pi/Ntheta;
    dz = z(2)-z(1);

    if Nz>=3

        dpdzLeft = ...
            (-3*P(:,1)+4*P(:,2)-P(:,3))/(2*dz);

        dpdzRight = ...
            (3*P(:,end)-4*P(:,end-1)+P(:,end-2))/(2*dz);

    else

        dpdzLeft = ...
            (P(:,2)-P(:,1))/dz;

        dpdzRight = ...
            (P(:,end)-P(:,end-1))/dz;
    end

    if isvector(h)
        H = repmat(h(:),1,Nz);
    else
        H = h;
    end

    [~,~,~,kappaAxial] = ...
        reynoldsTransportFields(H,muMap,R,omega,bearing);

    qzLeft = ...
        -(H(:,1).^3./(12*muMap(:,1).*kappaAxial(:,1))).*dpdzLeft;

    qzRight = ...
        -(H(:,end).^3./(12*muMap(:,end).*kappaAxial(:,end))).*dpdzRight;

    qzLeft(~activeMask) = 0;
    qzRight(~activeMask) = 0;

    Qleft = ...
        sum(abs(qzLeft))*R*dtheta;

    Qright = ...
        sum(abs(qzRight))*R*dtheta;

    Qexternal = Qleft+Qright;

    % ---------------------------------------------------------
    % PRESSURE-DAM RELIEF-TRACK DISCHARGE
    %
    % A centered/side relief track is an internal P=0 outlet.
    % The old leakage calculation counted only the two external
    % axial bearing ends, which under-reported the book "Qside"
    % for pressure-dam relief-track cases.
    %
    % Here we integrate the axial Poiseuille flux entering every
    % interface between a pressurized land cell and the relief track.
    % ---------------------------------------------------------
    Qrelief = 0;

    if strcmpi(bearing.type,'PressureDam') && ...
            ~strcmpi(bearing.reliefMode,'None') && ...
            bearing.reliefAxialLength > 0

        reliefMask = pressureDamReliefMask(bearing,theta,z);

        if any(reliefMask(:))

            % Axial interfaces j <-> j+1.
            for j = 1:Nz-1

                leftRelief  = reliefMask(:,j);
                rightRelief = reliefMask(:,j+1);

                % Exactly one side of the face is relief.
                faceIsOutlet = xor(leftRelief,rightRelief);

                if ~any(faceIsOutlet)
                    continue;
                end

                % Pressurized-side node index for each theta row.
                pLand = zeros(Ntheta,1);
                hLand = zeros(Ntheta,1);
                muLand = zeros(Ntheta,1);
                kapLand = zeros(Ntheta,1);

                idxLR = faceIsOutlet & ~leftRelief & rightRelief;
                idxRL = faceIsOutlet & leftRelief & ~rightRelief;

                pLand(idxLR) = P(idxLR,j);
                hLand(idxLR) = H(idxLR,j);
                muLand(idxLR) = muMap(idxLR,j);
                kapLand(idxLR) = kappaAxial(idxLR,j);

                pLand(idxRL) = P(idxRL,j+1);
                hLand(idxRL) = H(idxRL,j+1);
                muLand(idxRL) = muMap(idxRL,j+1);
                kapLand(idxRL) = kappaAxial(idxRL,j+1);

                validFace = faceIsOutlet & activeMask & (pLand > 0);

                if ~any(validFace)
                    continue;
                end

                % Relief pressure is prescribed zero.
                % Face-normal axial flux magnitude into the outlet.
                qFace = zeros(Ntheta,1);

                qFace(validFace) = ...
                    (hLand(validFace).^3 ./ ...
                    (12*muLand(validFace).*kapLand(validFace))) .* ...
                    (pLand(validFace)/dz);

                Qrelief = ...
                    Qrelief + sum(qFace(validFace))*R*dtheta;
            end
        end
    end

    Qtotal = Qexternal + Qrelief;

    % Store the relief contribution for reporting without changing
    % the historical function output signature.
    if strcmpi(bearing.type,'PressureDam') && ...
            ~strcmpi(bearing.reliefMode,'None')

        fprintf('Relief-track discharge   = %.4f L/min\n',Qrelief*60000);
        fprintf('External end leakage     = %.4f L/min\n',Qexternal*60000);
    end
end

%% ============================================================
% LOCAL FUNCTION 8: FRICTION / POWER
% =============================================================

function [Tfric,PowerLoss,Feq,fricCoeff] = ...
    frictionLossVariableMu( ...
    P,h,muMap,R,L,omega,W,theta,z,activeMask,bearing)

    Ntheta = length(theta);
    Nz = length(z);

    dtheta = 2*pi/Ntheta;
    dz = z(2)-z(1);

    U = omega*R;

    if isvector(h)
        H = repmat(h(:),1,Nz);
    else
        H = h;
    end

    [~,~,~,~,Cf] = ...
        reynoldsTransportFields(H,muMap,R,omega,bearing);

    dpdtheta = zeros(Ntheta,Nz);

    for i = 1:Ntheta

        ip = i+1;
        if ip>Ntheta, ip=1; end

        im = i-1;
        if im<1, im=Ntheta; end

        dpdtheta(i,:) = ...
            (P(ip,:)-P(im,:))/(2*dtheta);
    end

    dpdx = dpdtheta/R;

    wz = ones(1,Nz);
    wz([1 end]) = 0.5;

    journalTorque = 0;

    for i = 1:Ntheta

        if ~activeMask(i)
            continue;
        end

        tauWall = ...
            -Cf(i,:).*muMap(i,:)*U./H(i,:) ...
            -0.5*H(i,:).*dpdx(i,:);

        intTauZ = ...
            sum(tauWall.*wz)*dz;

        journalTorque = ...
            journalTorque + ...
            intTauZ*(R*dtheta)*R;
    end

    Tfric = abs(journalTorque);

    PowerLoss = ...
        abs(journalTorque*omega);

    Feq = Tfric/R;

    fricCoeff = ...
        Feq/max(W,eps);
end

%% ============================================================
% LOCAL FUNCTION: LAMINAR / TURBULENT REYNOLDS TRANSPORT
% =============================================================

function [mobilityTheta,mobilityAxial,kappaTheta,kappaAxial,Cf,Re,blend] = ...
    reynoldsTransportFields(h,muMap,R,omega,bearing)

    Nz = size(muMap,2);

    if isvector(h)
        Ntheta = numel(h);

        if isscalar(muMap)
            muMap = muMap*ones(Ntheta,Nz);
        end

        H = repmat(h(:),1,Nz);

    else
        H = h;
        Ntheta = size(H,1);

        if isscalar(muMap)
            muMap = muMap*ones(size(H));
        end

        if ~isequal(size(H),size(muMap))
            error('2-D film thickness and viscosity maps must have the same size.');
        end
    end

    rho = 850.0;
    if isfield(bearing,'turbulenceDensity')
        rho = bearing.turbulenceDensity;
    end

    model = 'Laminar';
    if isfield(bearing,'turbulenceModel')
        model = bearing.turbulenceModel;
    end

    U = abs(omega*R);

    Re = rho*U.*H./muMap;

    % Full Constantinescu factors.
    kappaThetaFull = ...
        1 + (0.0136/12)*Re.^0.90;

    kappaAxialFull = ...
        1 + (0.0043/12)*Re.^0.96;

    CfFull = ...
        1 + 0.0012*Re.^0.94;

    if strcmpi(model,'Constantinescu')

        % Forced turbulent correlation everywhere.
        blend = 1.0;

    elseif strcmpi(model,'Laminar')

        % Forced laminar solution.
        blend = 0.0;

    elseif strcmpi(model,'Auto')

        % --------------------------------------------------------
        % AUTO REGIME SELECTION
        %
        % Use the maximum local film Reynolds number to choose the
        % bearing operating regime.  The regime/blend is then frozen
        % for a given Reynolds solve and for the direct K/C
        % linearization around that equilibrium.
        %
        % ReMax <= ReL : exactly laminar
        % ReMax >= ReT : full Constantinescu
        % between     : smooth cubic transition
        % --------------------------------------------------------
        ReL = 200.0;
        ReT = 1000.0;

        if isfield(bearing,'autoReLaminarMax')
            ReL = bearing.autoReLaminarMax;
        end

        if isfield(bearing,'autoReTurbulentMin')
            ReT = bearing.autoReTurbulentMin;
        end

        if ReT <= ReL
            error('autoReTurbulentMin must be greater than autoReLaminarMax.');
        end

        ReMax = max(Re(:));

        if ReMax <= ReL
            blend = 0.0;
        elseif ReMax >= ReT
            blend = 1.0;
        else
            xi = (ReMax-ReL)/(ReT-ReL);

            % Smoothstep: continuous first derivative at both limits.
            blend = xi^2*(3-2*xi);
        end

    else

        error(['Unknown turbulenceModel "%s". Use "Laminar", ', ...
               '"Constantinescu", or "Auto".'],model);
    end

    % Blend the transport/shear corrections from the laminar state.
    % blend=0 -> exact laminar result
    % blend=1 -> full Constantinescu result
    kappaTheta = ...
        1 + blend*(kappaThetaFull-1);

    kappaAxial = ...
        1 + blend*(kappaAxialFull-1);

    Cf = ...
        1 + blend*(CfFull-1);

    mobilityTheta = ...
        H.^3./(muMap.*kappaTheta);

    mobilityAxial = ...
        H.^3./(muMap.*kappaAxial);
end


%% ============================================================
% LOCAL FUNCTION: BEARING DEFINITION / FIXED-LOBE GENERATOR
% =============================================================

function bearing = prepareBearingDefinition(bearing)

    if ~isfield(bearing,'Cb') || bearing.Cb<=0
        error('bearing.Cb must be a positive radial clearance.');
    end

    if strcmpi(bearing.type,'Plain')

        bearing.numberOfPads = 1;
        bearing.identicalPads = true;

        if ~isfield(bearing,'displayName')
            bearing.displayName = 'Plain Cylindrical Journal Bearing';
        end

        return;
    end

    if strcmpi(bearing.type,'PressureDam')

        if bearing.numberOfPads ~= 2
            error('PressureDam V3.21 requires exactly two cylindrical pads.');
        end

        for p = 1:2
            th1 = mod(bearing.pad(p).theta1Deg,360);
            th2 = mod(bearing.pad(p).theta2Deg,360);
            arcDeg = mod(th2-th1,360);

            if arcDeg <= 0
                error('PressureDam pad %d has zero/invalid circumferential arc.',p);
            end

            bearing.pad(p).theta1Deg = th1;
            bearing.pad(p).theta2Deg = th2;
            bearing.pad(p).arcDeg = arcDeg;
        end

        if bearing.pocketPad < 1 || bearing.pocketPad > 2
            error('pocketPad must be 1 or 2.');
        end

        if bearing.reliefPad < 1 || bearing.reliefPad > 2
            error('reliefPad must be 1 or 2.');
        end

        if bearing.pocketPad == bearing.reliefPad && ...
                ~strcmpi(bearing.reliefMode,'None')
            error('Pressure pocket and relief track cannot coexist on the same pad.');
        end

        if bearing.pocketDepth < 0
            error('pocketDepth must be >= 0.');
        end

        pocketPadArc = bearing.pad(bearing.pocketPad).arcDeg;

        if bearing.pocketArcDeg < 0 || bearing.pocketArcDeg > pocketPadArc
            error('pocketArcDeg must satisfy 0 <= pocketArcDeg <= pocket-pad arc.');
        end

        if bearing.pocketAxialLength < 0
            error('pocketAxialLength must be >= 0.');
        end

        if ~isfield(bearing,'L')
            error('PressureDam preparation requires bearing.L.');
        end

        if bearing.pocketAxialLength > bearing.L + 1e-12
            error('pocketAxialLength cannot exceed total bearing axial length.');
        end

        if bearing.reliefAxialLength < 0 || bearing.reliefAxialLength > bearing.L
            error('reliefAxialLength must satisfy 0 <= value <= L.');
        end

        validModes = {'None','Center','Side'};
        if ~any(strcmpi(bearing.reliefMode,validModes))
            error('reliefMode must be "None", "Center", or "Side".');
        end

        if bearing.reliefDepth < 0
            error('reliefDepth must be >= 0.');
        end

        bearing.pocketStepDeg = mod( ...
            bearing.pad(bearing.pocketPad).theta1Deg + bearing.pocketArcDeg,360);

        bearing.displayName = 'Pressure-Dam Journal Bearing';
        bearing.identicalPads = false;
        return;
    end

    if strcmpi(bearing.type,'WornBearing')

        if bearing.numberOfPads ~= 2
            error('WornBearing V3.22 requires exactly two cylindrical pads.');
        end

        for p = 1:2
            th1 = mod(bearing.pad(p).theta1Deg,360);
            th2 = mod(bearing.pad(p).theta2Deg,360);
            arcDeg = mod(th2-th1,360);

            if arcDeg <= 0
                error('WornBearing pad %d has zero/invalid arc.',p);
            end

            bearing.pad(p).theta1Deg = th1;
            bearing.pad(p).theta2Deg = th2;
            bearing.pad(p).arcDeg = arcDeg;
        end

        if bearing.wearPad < 1 || bearing.wearPad > 2
            error('wearPad must be 1 or 2.');
        end

        if bearing.wearDepth < 0
            error('wearDepth must be >= 0.');
        end

        bearing.wearCenterDeg = mod(bearing.wearCenterDeg,360);

        if bearing.wearArcDeg <= 0 || ...
                bearing.wearArcDeg > bearing.pad(bearing.wearPad).arcDeg
            error('wearArcDeg must satisfy 0 < wearArcDeg <= worn-pad arc.');
        end

        if bearing.wearAxialFraction <= 0 || bearing.wearAxialFraction > 1
            error('wearAxialFraction must satisfy 0 < value <= 1.');
        end

        if ~strcmpi(bearing.wearProfile,'CircularArc')
            error('V3.23 supports wearProfile = "CircularArc".');
        end

        bearing.wearStartDeg = mod( ...
            bearing.wearCenterDeg-0.5*bearing.wearArcDeg,360);
        bearing.wearEndDeg = mod( ...
            bearing.wearCenterDeg+0.5*bearing.wearArcDeg,360);

        rb = bearing.Rj + bearing.Cb;
        u = bearing.wearDepth;
        beta = 0.5*bearing.wearArcDeg*pi/180;

        den = 2*(rb*(1-cos(beta)) + u);

        if den <= 0
            error('Degenerate worn circular-arc geometry.');
        end

        aw = (2*rb*u + u^2)/den;
        Rw = rb + u - aw;

        if Rw <= 0
            error('Invalid worn circular-arc radius.');
        end

        bearing.wearCircleOffset = aw;
        bearing.wearCircleRadius = Rw;

        bearing.identicalPads = false;
        bearing.displayName = 'Worn-Pocket Journal Bearing';
        return;
    end

    if ~(strcmpi(bearing.type,'FixedLobe') || ...
         strcmpi(bearing.type,'TaperLand'))

        error(['bearing.type must be "Plain", "FixedLobe", "TaperLand", ', ...
               '"PressureDam", or "WornBearing".']);
    end

    if bearing.numberOfPads < 1 || ...
            abs(bearing.numberOfPads-round(bearing.numberOfPads))>0
        error('numberOfPads must be a positive integer.');
    end

    Npad = bearing.numberOfPads;

    if bearing.identicalPads

        p1 = bearing.pad(1);
        pitch = 360/Npad;

        for p = 1:Npad

            shift = (p-1)*pitch;

            bearing.pad(p).theta1Deg = mod(p1.theta1Deg+shift,360);
            bearing.pad(p).theta2Deg = mod(p1.theta2Deg+shift,360);

            if strcmpi(bearing.type,'FixedLobe')

                bearing.pad(p).preload = p1.preload;
                bearing.pad(p).offset = p1.offset;

            else

                bearing.pad(p).undercut = p1.undercut;
                bearing.pad(p).taperArcDeg = p1.taperArcDeg;
                bearing.pad(p).arcCenterMode = p1.arcCenterMode;
                bearing.pad(p).arcCenterAngleDeg = p1.arcCenterAngleDeg;
                bearing.pad(p).axialTaperFraction = p1.axialTaperFraction;
            end
        end

    else

        if numel(bearing.pad) < Npad
            error('Define all pads/lobes when identicalPads=false.');
        end
    end

    if strcmpi(bearing.type,'FixedLobe')

        % Geometry-aware display name.
        preloadList = zeros(1,Npad);

        for p = 1:Npad
            preloadList(p) = bearing.pad(p).preload;
        end

        if Npad == 2
            if all(abs(preloadList) < 1e-12)
                bearing.displayName = 'Two-Axial-Groove Journal Bearing';
            else
                bearing.displayName = 'Elliptical (Lemon Bore) Journal Bearing';
            end

        elseif Npad == 3

            if all(abs(preloadList) < 1e-12)
                bearing.displayName = 'Three-Axial-Groove Journal Bearing';
            else
                bearing.displayName = 'Three-Lobe Journal Bearing';
            end

        elseif Npad == 4

            if all(abs(preloadList) < 1e-12)
                bearing.displayName = 'Four-Axial-Groove Journal Bearing';
            else
                bearing.displayName = 'Four-Lobe Journal Bearing';
            end

        else

            bearing.displayName = ...
                sprintf('%d-Lobe Fixed-Lobe Journal Bearing',Npad);
        end

        % Validate and precompute circular-lobe geometry.
        for p = 1:Npad

            m = bearing.pad(p).preload;
            alpha = bearing.pad(p).offset;

            if m < 0 || m >= 1
                error('Pad %d preload must satisfy 0 <= m < 1.',p);
            end

            arcDeg = mod( ...
                bearing.pad(p).theta2Deg-bearing.pad(p).theta1Deg, ...
                360);

            if arcDeg<=0
                error('Pad %d has zero arc length.',p);
            end

            if alpha < 0
                error('Pad %d offset must be non-negative.',p);
            end

            Cp = bearing.Cb/(1-m);
            centerOffset = m*Cp;

            thetaPDeg = mod( ...
                bearing.pad(p).theta1Deg + alpha*arcDeg, ...
                360);

            bearing.pad(p).arcDeg = arcDeg;
            bearing.pad(p).Cp = Cp;
            bearing.pad(p).centerOffset = centerOffset;
            bearing.pad(p).thetaPDeg = thetaPDeg;
        end

    else

        % --------------------------------------------------------
        % TAPERED-LAND GEOMETRY -- OFFSET CIRCULAR ARC
        %
        % The book defines the taper as an offset circular arc,
        % specified by arc-center offset r_a, center angle theta_a,
        % and arc radius R_a.  Design inputs are commonly:
        %   undercut u
        %   taper circumferential arc theta_T
        %
        % With theta_a fixed, r_a and R_a follow from the two
        % clearance constraints:
        %   h0(theta1)        = Cb + u
        %   h0(theta1+thetaT) = Cb
        %
        % Any remaining circumferential pad arc is a flat trailing
        % land at clearance Cb.
        %
        % Current V3.16 supports no axial side lands only.
        % --------------------------------------------------------
        bearing.displayName = 'Tapered-Land Journal Bearing';

        if ~isfield(bearing,'Rj') || bearing.Rj<=0
            error('TaperLand requires bearing.Rj = journal radius.');
        end

        Rj = bearing.Rj;
        pitchDeg = 360/Npad;

        for p = 1:Npad

            arcDeg = mod( ...
                bearing.pad(p).theta2Deg-bearing.pad(p).theta1Deg, ...
                360);

            if arcDeg<=0
                error('Tapered-land lobe %d has zero arc length.',p);
            end

            undercut = bearing.pad(p).undercut;
            taperArcDeg = bearing.pad(p).taperArcDeg;
            axialFrac = bearing.pad(p).axialTaperFraction;

            if undercut < 0
                error('Tapered-land lobe %d undercut must be >= 0.',p);
            end

            if taperArcDeg <= 0 || taperArcDeg > arcDeg
                error(['Tapered-land lobe %d taperArcDeg must satisfy ', ...
                       '0 < taperArcDeg <= total lobe arc.'],p);
            end

            if axialFrac <= 0 || axialFrac > 1
                error('axialTaperFraction must satisfy 0 < value <= 1.');
            end

            % axialTaperFraction < 1 activates symmetric axial side lands.
            % The side-land clearance is the minimum radial clearance Cb.

            th1Deg = mod(bearing.pad(p).theta1Deg,360);
            thEndDeg = mod(th1Deg+taperArcDeg,360);

            mode = bearing.pad(p).arcCenterMode;

            if strcmpi(mode,'LeadingGrooveCenter')

                grooveDeg = pitchDeg-arcDeg;

                if grooveDeg < -1e-10
                    error('Pad/lobe arc exceeds pitch; cannot define leading groove.');
                end

                thetaADeg = mod(th1Deg-0.5*max(grooveDeg,0),360);

            elseif strcmpi(mode,'LeadingEdge')

                thetaADeg = th1Deg;

            elseif strcmpi(mode,'Manual')

                thetaADeg = mod(bearing.pad(p).arcCenterAngleDeg,360);

                if ~isfinite(thetaADeg)
                    error('Manual tapered-land arc center requires arcCenterAngleDeg.');
                end

            else

                error(['Unknown arcCenterMode "%s". Use ', ...
                       '"LeadingGrooveCenter", "LeadingEdge", or "Manual".'],mode);
            end

            % Exact circle geometry from the two specified radial
            % clearances at the taper start and taper end.
            rLead = Rj + bearing.Cb + undercut;
            rEnd  = Rj + bearing.Cb;

            d1 = (th1Deg-thetaADeg)*pi/180;
            d2 = (thEndDeg-thetaADeg)*pi/180;

            denominator = ...
                2*(rLead*cos(d1)-rEnd*cos(d2));

            if abs(denominator) < 1e-14
                error('Degenerate tapered-land offset-arc geometry on lobe %d.',p);
            end

            ra = ...
                (rLead^2-rEnd^2)/denominator;

            Ra2 = ...
                rLead^2 + ra^2 - 2*rLead*ra*cos(d1);

            if Ra2 <= 0
                error('Invalid tapered-land arc radius on lobe %d.',p);
            end

            Ra = sqrt(Ra2);

            bearing.pad(p).arcDeg = arcDeg;
            bearing.pad(p).leadingClearance = bearing.Cb + undercut;
            bearing.pad(p).trailingClearance = bearing.Cb;
            bearing.pad(p).flatTrailingLandDeg = arcDeg-taperArcDeg;
            bearing.pad(p).sideLandFractionEach = 0.5*(1-axialFrac);

            bearing.pad(p).thetaADeg = thetaADeg;
            bearing.pad(p).ra = ra;
            bearing.pad(p).Ra = Ra;
        end
    end
end

%% ============================================================
% LOCAL FUNCTION: FILM THICKNESS FOR ALL SUPPORTED GEOMETRIES
% =============================================================

function [h,dhdtheta,geom] = bearingFilmGeometry(bearing,q,theta)

    theta = theta(:);

    Ntheta = numel(theta);

    Cb = bearing.Cb;

    xj = Cb*q(1);
    yj = Cb*q(2);

    h = Cb*ones(Ntheta,1);
    dhdtheta = zeros(Ntheta,1);

    geom.activeMask = true(Ntheta,1);
    geom.boundaryMask = false(Ntheta,1);
    geom.padIndex = ones(Ntheta,1);

    if strcmpi(bearing.type,'Plain')

        h = ...
            Cb - xj*cos(theta) - yj*sin(theta);

        dhdtheta = ...
            xj*sin(theta) - yj*cos(theta);

        return;
    end

    if strcmpi(bearing.type,'PressureDam')

        % -----------------------------------------------------
        % Independent 2-pad / 2-axial-groove base geometry.
        % Centerline profile includes the top-pad pocket.  Relief
        % track is handled rigorously in the 2-D geometry function.
        % -----------------------------------------------------
        geom.activeMask(:) = false;
        geom.boundaryMask(:) = false;
        geom.padIndex(:) = 0;

        thetaDeg = mod(theta*180/pi,360);

        if Ntheta>1
            dthetaDeg = 360/Ntheta;
        else
            dthetaDeg = 360;
        end

        h(:) = Cb;
        dhdtheta(:) = 0;

        for p = 1:2

            th1 = bearing.pad(p).theta1Deg;
            arcDeg = bearing.pad(p).arcDeg;
            relDeg = mod(thetaDeg-th1,360);
            inside = relDeg <= arcDeg + 1e-10;

            hp = Cb - xj*cos(theta) - yj*sin(theta);
            dhp = xj*sin(theta) - yj*cos(theta);

            h(inside) = hp(inside);
            dhdtheta(inside) = dhp(inside);

            geom.activeMask(inside) = true;
            geom.padIndex(inside) = p;

            th2 = mod(th1+arcDeg,360);
            d1 = abs(wrapToPiLocal((thetaDeg-th1)*pi/180));
            d2 = abs(wrapToPiLocal((thetaDeg-th2)*pi/180));

            [mis1,i1] = min(d1);
            [mis2,i2] = min(d2);

            geom.boundaryMask(i1) = true;
            geom.boundaryMask(i2) = true;

            if max(mis1,mis2)*180/pi > 0.51*dthetaDeg
                warning('PressureDam pad %d edge is poorly aligned with theta mesh.',p);
            end
        end

        % Centerline passes through the central pressure pocket.
        p = bearing.pocketPad;
        th1 = bearing.pad(p).theta1Deg;
        relDeg = mod(thetaDeg-th1,360);

        inPocketTheta = ...
            (geom.padIndex==p) & ...
            (relDeg <= bearing.pocketArcDeg + 1e-10);

        if bearing.pocketAxialLength > 0 && bearing.pocketDepth > 0
            h(inPocketTheta) = h(inPocketTheta) + bearing.pocketDepth;
            % Sharp pocket step: derivative is intentionally left as the
            % smooth journal term here. The 2-D Reynolds solver replaces
            % h_theta by a conservative numerical derivative of H.
        end

        geom.pocketThetaMask = inPocketTheta;
        return;
    end

    if strcmpi(bearing.type,'WornBearing')

        geom.activeMask(:) = false;
        geom.boundaryMask(:) = false;
        geom.padIndex(:) = 0;

        thetaDeg = mod(theta*180/pi,360);

        if Ntheta>1
            dthetaDeg = 360/Ntheta;
        else
            dthetaDeg = 360;
        end

        h(:) = Cb;
        dhdtheta(:) = 0;

        % Two cylindrical pads separated by ambient-pressure axial grooves.
        for p = 1:2

            th1 = bearing.pad(p).theta1Deg;
            arcDeg = bearing.pad(p).arcDeg;
            relDeg = mod(thetaDeg-th1,360);
            inside = relDeg <= arcDeg + 1e-10;

            hp = Cb - xj*cos(theta) - yj*sin(theta);
            dhp = xj*sin(theta) - yj*cos(theta);

            h(inside) = hp(inside);
            dhdtheta(inside) = dhp(inside);

            geom.activeMask(inside) = true;
            geom.padIndex(inside) = p;

            th2 = mod(th1+arcDeg,360);
            d1 = abs(wrapToPiLocal((thetaDeg-th1)*pi/180));
            d2 = abs(wrapToPiLocal((thetaDeg-th2)*pi/180));

            [~,i1] = min(d1);
            [~,i2] = min(d2);

            geom.boundaryMask(i1) = true;
            geom.boundaryMask(i2) = true;
        end

        % Smooth circular worn arc in the loaded pad.
        centerRad = bearing.wearCenterDeg*pi/180;
        delta = wrapToPiLocal(theta-centerRad);
        halfArc = 0.5*bearing.wearArcDeg*pi/180;

        inWearTheta = ...
            (geom.padIndex==bearing.wearPad) & ...
            (abs(delta) <= halfArc + 1e-12);

        aw = bearing.wearCircleOffset;
        Rw = bearing.wearCircleRadius;
        rb = bearing.Rj + bearing.Cb;

        radicand = Rw^2 - aw^2.*sin(delta).^2;

        if any(radicand(inWearTheta) <= 0)
            error('Invalid worn-circle intersection.');
        end

        rootTerm = sqrt(max(radicand,0));
        rWear = aw*cos(delta) + rootTerm;
        wearAdd = rWear-rb;

        drdtheta = ...
            -aw*sin(delta) ...
            - (aw^2.*sin(delta).*cos(delta))./max(rootTerm,eps);

        h(inWearTheta) = ...
            h(inWearTheta) + wearAdd(inWearTheta);

        dhdtheta(inWearTheta) = ...
            dhdtheta(inWearTheta) + drdtheta(inWearTheta);

        geom.wearThetaMask = inWearTheta;
        return;
    end

    % General pad/lobe bearing.
    geom.activeMask = false(Ntheta,1);
    geom.boundaryMask = false(Ntheta,1);
    geom.padIndex = zeros(Ntheta,1);

    thetaDeg = mod(theta*180/pi,360);

    if Ntheta>1
        dthetaDeg = 360/Ntheta;
    else
        dthetaDeg = 360;
    end

    % Groove nodes retain a benign Cb value but are excluded by activeMask.
    h(:) = Cb;
    dhdtheta(:) = 0;

    for p = 1:bearing.numberOfPads

        th1 = mod(bearing.pad(p).theta1Deg,360);
        arcDeg = bearing.pad(p).arcDeg;

        relDeg = mod(thetaDeg-th1,360);

        inside = relDeg <= arcDeg + 1e-10;

        if any(geom.activeMask & inside)
            error('Pad/lobe arcs overlap. Check theta1/theta2 inputs.');
        end

        if strcmpi(bearing.type,'FixedLobe')

            thp = bearing.pad(p).thetaPDeg*pi/180;

            Cp = bearing.pad(p).Cp;
            d = bearing.pad(p).centerOffset;

            hp = ...
                Cp - d*cos(theta-thp) ...
                - xj*cos(theta) - yj*sin(theta);

            dhp = ...
                d*sin(theta-thp) ...
                + xj*sin(theta) - yj*cos(theta);

        elseif strcmpi(bearing.type,'TaperLand')

            % ----------------------------------------------------
            % Offset-circular-arc tapered-land profile.
            %
            % Bearing-surface radial coordinate for an arc centered
            % at (ra,thetaA) with radius Ra:
            %
            % r_s(theta) = ra*cos(Delta)
            %              + sqrt(Ra^2-ra^2*sin^2(Delta))
            %
            % h0 = r_s - Rj
            %
            % After taperArcDeg, the remaining trailing land is flat
            % at the minimum radial clearance Cb.
            % ----------------------------------------------------
            taperArcDeg = bearing.pad(p).taperArcDeg;

            thetaA = bearing.pad(p).thetaADeg*pi/180;
            ra = bearing.pad(p).ra;
            Ra = bearing.pad(p).Ra;
            Rj = bearing.Rj;

            baseClearance = Cb*ones(Ntheta,1);
            baseSlope = zeros(Ntheta,1);

            inTaper = inside & (relDeg <= taperArcDeg + 1e-10);

            Delta = theta-thetaA;

            radicand = ...
                Ra^2 - ra^2.*sin(Delta).^2;

            if any(radicand(inTaper) <= 0)
                error('Invalid tapered-land circle intersection on lobe %d.',p);
            end

            rootTerm = sqrt(max(radicand,0));

            surfaceRadius = ...
                ra*cos(Delta) + rootTerm;

            baseClearance(inTaper) = ...
                surfaceRadius(inTaper)-Rj;

            % Exact derivative d(h0)/dtheta.
            drdtheta = ...
                -ra*sin(Delta) ...
                - (ra^2.*sin(Delta).*cos(Delta))./max(rootTerm,eps);

            baseSlope(inTaper) = drdtheta(inTaper);

            hp = ...
                baseClearance ...
                - xj*cos(theta) - yj*sin(theta);

            dhp = ...
                baseSlope ...
                + xj*sin(theta) - yj*cos(theta);

        else

            error('Unsupported non-plain bearing type in bearingFilmGeometry.');
        end

        h(inside) = hp(inside);
        dhdtheta(inside) = dhp(inside);

        geom.activeMask(inside) = true;
        geom.padIndex(inside) = p;

        % Closest nodes to exact lobe leading/trailing edges are ambient.
        th2 = mod(th1+arcDeg,360);

        d1 = abs(wrapToPiLocal((thetaDeg-th1)*pi/180));
        d2 = abs(wrapToPiLocal((thetaDeg-th2)*pi/180));

        [mis1,i1] = min(d1);
        [mis2,i2] = min(d2);

        geom.boundaryMask(i1) = true;
        geom.boundaryMask(i2) = true;

        if max(mis1,mis2)*180/pi > 0.51*dthetaDeg
            warning('Pad/lobe %d edge is poorly aligned with theta mesh.',p);
        end
    end

    if ~any(geom.activeMask)
        error('No active pad/lobe nodes were generated.');
    end
end


%% ============================================================
% LOCAL FUNCTION: FULL 2-D FILM GEOMETRY h(theta,z)
% =============================================================

function [H,dHdtheta,geom] = ...
    bearingFilmGeometry2D(bearing,q,theta,z)

    theta = theta(:);
    z = z(:).';

    Ntheta = numel(theta);
    Nz = numel(z);

    % Start from the already validated circumferential geometry.
    [h1D,dh1D,geom] = bearingFilmGeometry(bearing,q,theta);

    H = repmat(h1D,1,Nz);
    dHdtheta = repmat(dh1D,1,Nz);

    geom.axialTaperMask = true(1,Nz);

    % Generic fixed-pressure mask.  Circumferential pad/groove edges are
    % ambient. Special families may add internal 2-D pressure boundaries.
    geom.fixedPressureMask2D = repmat(geom.boundaryMask,1,Nz);

    % ---------------------------------------------------------
    % Pressure-dam family: top-pad pocket + optional bottom-pad relief
    % ---------------------------------------------------------
    if strcmpi(bearing.type,'PressureDam')

        Cb = bearing.Cb;
        xj = Cb*q(1);
        yj = Cb*q(2);

        thetaDeg = mod(theta*180/pi,360);

        % Rebuild the pure cylindrical 2-pad baseline first.  This avoids
        % applying the centerline pocket across the full axial width.
        hBase = Cb - xj*cos(theta) - yj*sin(theta);
        dhBase = xj*sin(theta) - yj*cos(theta);

        for j = 1:Nz
            H(:,j) = hBase;
            dHdtheta(:,j) = dhBase;
        end

        % Preserve inactive axial-groove theta nodes at benign Cb values.
        inactive = ~geom.activeMask;
        H(inactive,:) = Cb;
        dHdtheta(inactive,:) = 0;

        % ---------------- TOP-PAD PRESSURE POCKET ----------------
        p = bearing.pocketPad;
        th1 = bearing.pad(p).theta1Deg;
        relDeg = mod(thetaDeg-th1,360);

        pocketTheta = ...
            (geom.padIndex==p) & ...
            (relDeg <= bearing.pocketArcDeg + 1e-10);

        pocketAxial = false(1,Nz);

        if bearing.pocketAxialLength > 0 && bearing.pocketDepth > 0
            pocketHalf = 0.5*bearing.pocketAxialLength;
            pocketAxial = abs(z) <= pocketHalf + 1e-12;

            H(pocketTheta,pocketAxial) = ...
                H(pocketTheta,pocketAxial) + bearing.pocketDepth;
        end

        % ---------------- BOTTOM-PAD RELIEF TRACK ----------------
        reliefMask2D = pressureDamReliefMask(bearing,theta,z);

        if any(reliefMask2D(:))
            % Deep physical groove for geometry/contact visualization.
            H(reliefMask2D) = H(reliefMask2D) + bearing.reliefDepth;
        end

        % Fixed-pressure 2-D mask.  Existing circumferential pad edges are
        % ambient, and the deep relief track is also prescribed at ambient.
        geom.fixedPressureMask2D = ...
            repmat(geom.boundaryMask,1,Nz) | reliefMask2D;

        geom.pocketMask2D = false(Ntheta,Nz);
        if any(pocketAxial)
            geom.pocketMask2D(pocketTheta,pocketAxial) = true;
        end
        geom.reliefMask2D = reliefMask2D;

        % Pressure-dam pocket has a true circumferential step/discontinuity.
        % Use a conservative periodic finite-difference derivative of H so
        % the step source appears in Reynolds RHS rather than being missed.
        if Ntheta > 1
            dthetaLocal = theta(2)-theta(1);
            dHdtheta = periodicThetaDerivative(H,dthetaLocal);
        end

        return;
    end

    % ---------------------------------------------------------
    % Worn-pocket family: constant-depth wear in loaded pad
    % ---------------------------------------------------------
    if strcmpi(bearing.type,'WornBearing')

        Cb = bearing.Cb;
        xj = Cb*q(1);
        yj = Cb*q(2);

        thetaDeg = mod(theta*180/pi,360);

        % Rebuild pure cylindrical two-pad baseline.
        hBase = Cb - xj*cos(theta) - yj*sin(theta);
        dhBase = xj*sin(theta) - yj*cos(theta);

        for j = 1:Nz
            H(:,j) = hBase;
            dHdtheta(:,j) = dhBase;
        end

        inactive = ~geom.activeMask;
        H(inactive,:) = Cb;
        dHdtheta(inactive,:) = 0;

        centerRad = bearing.wearCenterDeg*pi/180;
        delta = wrapToPiLocal(theta-centerRad);
        halfArc = 0.5*bearing.wearArcDeg*pi/180;

        wearTheta = ...
            (geom.padIndex==bearing.wearPad) & ...
            (abs(delta) <= halfArc + 1e-12);

        wearAxial = false(1,Nz);

        if bearing.wearAxialFraction >= 1-1e-12
            wearAxial(:) = true;
        else
            wearHalf = 0.5*bearing.wearAxialFraction*(max(z)-min(z));
            wearAxial = abs(z) <= wearHalf + 1e-12;
        end

        aw = bearing.wearCircleOffset;
        Rw = bearing.wearCircleRadius;
        rb = bearing.Rj + bearing.Cb;

        radicand = Rw^2 - aw^2.*sin(delta).^2;

        if any(radicand(wearTheta) <= 0)
            error('Invalid worn-circle intersection.');
        end

        rootTerm = sqrt(max(radicand,0));
        rWear = aw*cos(delta) + rootTerm;
        wearAdd = rWear-rb;

        drdtheta = ...
            -aw*sin(delta) ...
            - (aw^2.*sin(delta).*cos(delta))./max(rootTerm,eps);

        for j = find(wearAxial)
            H(wearTheta,j) = ...
                H(wearTheta,j) + wearAdd(wearTheta);

            dHdtheta(wearTheta,j) = ...
                dHdtheta(wearTheta,j) + drdtheta(wearTheta);
        end

        geom.wearMask2D = false(Ntheta,Nz);
        geom.wearMask2D(wearTheta,wearAxial) = true;

        geom.fixedPressureMask2D = repmat(geom.boundaryMask,1,Nz);

        return;
    end

    if ~strcmpi(bearing.type,'TaperLand')
        return;
    end

    % All identical tapered lobes in the current implementation share the
    % same axial taper fraction.  Side lands occupy equal widths at both ends.
    axialFrac = bearing.pad(1).axialTaperFraction;

    if axialFrac >= 1-1e-12
        return;
    end

    Llocal = max(z)-min(z);

    if Llocal <= 0
        error('Invalid axial grid in bearingFilmGeometry2D.');
    end

    zmid = 0.5*(max(z)+min(z));
    taperHalfWidth = 0.5*axialFrac*Llocal;

    taperAxial = abs(z-zmid) <= taperHalfWidth + 1e-12;
    sideAxial = ~taperAxial;

    geom.axialTaperMask = taperAxial;

    if ~any(sideAxial)
        return;
    end

    % On the axial side lands, the bearing surface is the minimum-clearance
    % cylindrical land Cb throughout each active circumferential lobe.
    % Journal eccentricity still acts normally.
    Cb = bearing.Cb;
    xj = Cb*q(1);
    yj = Cb*q(2);

    hSide = ...
        Cb - xj*cos(theta) - yj*sin(theta);

    dhSide = ...
        xj*sin(theta) - yj*cos(theta);

    activeTheta = geom.activeMask;

    for j = find(sideAxial)
        H(activeTheta,j) = hSide(activeTheta);
        dHdtheta(activeTheta,j) = dhSide(activeTheta);
    end
end


%% ============================================================
% LOCAL FUNCTION 9: WALTHER / ASTM D341 VISCOSITY MODEL
% =============================================================

function mu = oilViscosityWalther(TC,oil)

    T1 = 40+273.15;
    T2 = 100+273.15;

    Y1 = ...
        log10(log10(oil.nu40_cSt+0.7));

    Y2 = ...
        log10(log10(oil.nu100_cSt+0.7));

    X1 = log10(T1);
    X2 = log10(T2);

    B = ...
        (Y1-Y2)/(X2-X1);

    A = ...
        Y1+B*X1;

    TK = TC+273.15;

    Y = ...
        A-B*log10(TK);

    nu_cSt = ...
        10.^(10.^Y)-0.7;

    rho = ...
        oilDensity(TC,oil);

    mu = ...
        rho.*nu_cSt*1e-6;

    mu = max(mu,1e-5);
end

%% ============================================================
% LOCAL FUNCTION 10: DENSITY MODEL
% =============================================================

function rho = oilDensity(TC,oil)

    rho = ...
        oil.rho40.* ...
        (1-oil.alphaRho.*(TC-40));

    rho = max(rho,500);
end

%% ============================================================
% LOCAL FUNCTION 11: PERIODIC INTERPOLATION
% =============================================================

function Vq = ...
    interpPeriodic2(theta,z,V,thetaQ,zQ)

    theta = theta(:);
    thetaQ = thetaQ(:);

    thetaExt = ...
        [theta;2*pi];

    Vext = ...
        [V;V(1,:)];

    [ZZ,TT] = ...
        meshgrid(z,thetaExt);

    [ZZQ,TTQ] = ...
        meshgrid(zQ,thetaQ);

    Vq = ...
        interp2(ZZ,TT,Vext,ZZQ,TTQ,'linear');
end

function vq = ...
    interp1Periodic(theta,v,thetaQ)

    theta = theta(:);
    v = v(:);

    thetaExt = ...
        [theta;2*pi];

    vExt = ...
        [v;v(1)];

    vq = ...
        interp1(thetaExt,vExt,thetaQ,'linear');
end

function Vnew = ...
    resizePeriodicField(Vold,NthetaNew,NzNew)

    [NthetaOld,NzOld] = size(Vold);

    thetaOld = ...
        (0:NthetaOld-1)'*(2*pi/NthetaOld);

    zOld = ...
        linspace(-0.5,0.5,NzOld);

    thetaNew = ...
        (0:NthetaNew-1)'*(2*pi/NthetaNew);

    zNew = ...
        linspace(-0.5,0.5,NzNew);

    Vnew = ...
        interpPeriodic2( ...
        thetaOld,zOld,Vold,thetaNew,zNew);
end

%% ============================================================
% LOCAL FUNCTION 12: STABILITY
% =============================================================


function reliefMask = pressureDamReliefMask(bearing,theta,z)
%PRESSUREDAMRELIEFMASK
% 2-D logical mask of the internal relief track used by the PressureDam family.

    theta = theta(:);
    z = z(:).';

    Ntheta = numel(theta);
    Nz = numel(z);

    reliefMask = false(Ntheta,Nz);

    if ~strcmpi(bearing.type,'PressureDam') || ...
            strcmpi(bearing.reliefMode,'None') || ...
            bearing.reliefAxialLength <= 0
        return;
    end

    thetaDeg = mod(theta*180/pi,360);

    p = bearing.reliefPad;
    th1 = bearing.pad(p).theta1Deg;
    arcDeg = bearing.pad(p).arcDeg;

    relDeg = mod(thetaDeg-th1,360);
    reliefTheta = relDeg <= arcDeg + 1e-10;

    reliefAxial = false(1,Nz);

    if strcmpi(bearing.reliefMode,'Center')

        halfTrack = 0.5*bearing.reliefAxialLength;
        reliefAxial = abs(z) <= halfTrack + 1e-12;

    elseif strcmpi(bearing.reliefMode,'Side')

        perSide = 0.5*bearing.reliefAxialLength;

        reliefAxial = ...
            (z <= min(z)+perSide+1e-12) | ...
            (z >= max(z)-perSide-1e-12);
    end

    reliefMask(reliefTheta,reliefAxial) = true;
end


function dHdtheta = periodicThetaDerivative(H,dtheta)
%PERIODICTHETADERIVATIVE
% Conservative periodic finite-difference derivative in theta.
% Used for discontinuous pressure-dam/step geometry so the pocket step
% contributes to the Reynolds wedge source.

    [Ntheta,Nz] = size(H);
    dHdtheta = zeros(Ntheta,Nz);

    for i = 1:Ntheta
        ip = i+1;
        if ip>Ntheta, ip=1; end

        im = i-1;
        if im<1, im=Ntheta; end

        dHdtheta(i,:) = (H(ip,:)-H(im,:))/(2*dtheta);
    end
end


function tf = isContinuousBoreBearing(bearing)
% True for full-circumference bearing surfaces with no ambient-pressure
% circumferential grooves/pad edges.
    tf = strcmpi(bearing.type,'Plain');
end


function [qxEnv,qyEnv] = journalCenterClearanceEnvelope(bearing,L,nAngle)
% Exact contact boundary in journal-center space.
%
% q = [x/Cb ; y/Cb]. For each direction, find the largest center motion
% that keeps all active film thicknesses positive.

    alpha = linspace(0,2*pi,nAngle).';
    thetaProbe = linspace(0,2*pi,721).';
    zProbe = linspace(-L/2,L/2,41);

    qxEnv = zeros(size(alpha));
    qyEnv = zeros(size(alpha));

    for ia = 1:numel(alpha)

        direction = [cos(alpha(ia)); sin(alpha(ia))];

        rLo = 0;
        rHi = 1;

        for ie = 1:12
            [H,~,geom] = bearingFilmGeometry2D( ...
                bearing,rHi*direction,thetaProbe,zProbe);

            active2D = repmat(geom.activeMask,1,numel(zProbe));
            margin = min(H(active2D));

            if margin <= 0
                break;
            end

            rLo = rHi;
            rHi = 1.5*rHi;
        end

        for ib = 1:45
            rMid = 0.5*(rLo+rHi);

            [H,~,geom] = bearingFilmGeometry2D( ...
                bearing,rMid*direction,thetaProbe,zProbe);

            active2D = repmat(geom.activeMask,1,numel(zProbe));
            margin = min(H(active2D));

            if margin > 0
                rLo = rMid;
            else
                rHi = rMid;
            end
        end

        rContact = 0.5*(rLo+rHi);

        qxEnv(ia) = rContact*cos(alpha(ia));
        qyEnv(ia) = rContact*sin(alpha(ia));
    end
end


function [criticalMass,instabilityRad,whirlRatio] = ...
    criticalMassFromKC(K,Cmat,omega)
% Fast closed-form bearing-only stability calculation for speed sweeps.

    kxx = K(1,1); kxy = K(1,2);
    kyx = K(2,1); kyy = K(2,2);

    cxx = Cmat(1,1); cxy = Cmat(1,2);
    cyx = Cmat(2,1); cyy = Cmat(2,2);

    criticalMass = NaN;
    instabilityRad = NaN;
    whirlRatio = NaN;

    denKappa = cxx+cyy;

    if abs(denKappa) < eps
        return;
    end

    kappa0 = ...
        (kxx*cyy + kyy*cxx - kxy*cyx - kyx*cxy) / denKappa;

    denOmega = cxx*cyy-cxy*cyx;

    if abs(denOmega) < eps
        return;
    end

    omega0sq = ...
        ((kxx-kappa0)*(kyy-kappa0)-kxy*kyx) / denOmega;

    if ~(isfinite(omega0sq) && omega0sq > 0)
        return;
    end

    criticalMass = kappa0/omega0sq;

    if ~(isfinite(criticalMass) && criticalMass > 0)
        criticalMass = NaN;
        return;
    end

    instabilityRad = sqrt(omega0sq);
    whirlRatio = instabilityRad/max(abs(omega),eps);
end


function margin = ...
    stabilityMargin(m,K,Cmat)

    M = m*eye(2);

    A = ...
        [zeros(2) eye(2); ...
         -M\K -M\Cmat];

    eigVals = eig(A);

    margin = ...
        max(real(eigVals));
end

%% ============================================================
% LOCAL FUNCTION 13: UTILITIES
% =============================================================

function d = angleDiffDeg(a,b)

    d = ...
        mod(a-b+180,360)-180;
end

function y = ternary(cond,a,b)

    if cond
        y = a;
    else
        y = b;
    end
end

function x = wrapToPiLocal(x)

    x = ...
        mod(x+pi,2*pi)-pi;
end

function plotTPJBProductionGeometry( ...
    bearing,result,W,activePadLoadFraction,visualScale, ...
    showPadTilt,tiltAmp,showOriginalPad)

    % ==============================================================
    % RotorDynX TPJB production geometry + tilted-pad pressure map
    %
    % IMPORTANT:
    %   - Solver uses the REAL pad tilt alpha and REAL clearances.
    %   - visualScale affects clearance DRAWING only.
    %   - tiltAmp affects pad-tilt DRAWING only.
    % ==============================================================

    fig = figure('Name','RotorDynX - TPJB Geometry + Tilt + Pressure', ...
        'Color','w','Position',[55 35 1260 845]);

    ax = axes(fig,'Position',[0.045 0.075 0.665 0.845]);
    hold(ax,'on');
    axis(ax,'equal');
    box(ax,'on');

    set(ax,'FontName','Arial','FontSize',11,'LineWidth',0.9, ...
        'XGrid','on','YGrid','on','GridAlpha',0.10);

    % Engineering palette
    colPad      = [0.05 0.25 0.85];
    colPadIdle  = [0.58 0.63 0.75];
    colJournal  = [0.04 0.10 0.35];
    colPressure = [0.96 0.00 0.82];
    colLoad     = [0.88 0.05 0.05];
    colRotation = [0.05 0.55 0.10];
    colPivot    = [0.05 0.25 0.85];
    colGuide    = [0.72 0.76 0.86];
    colOriginal = [0.62 0.62 0.62];

    R = bearing.Rj;
    th360 = linspace(0,2*pi,720);

    % --------------------------------------------------------------
    % Shaft / journal at the solved eccentric position
    % --------------------------------------------------------------
    xj = (result.ex + R*cos(th360))*1e3;
    yj = (result.ey + R*sin(th360))*1e3;

    fill(ax,xj,yj,[0.94 0.94 0.94], ...
        'EdgeColor',colJournal,'LineWidth',1.8);

    plot(ax,result.ex*1e3,result.ey*1e3,'o', ...
        'MarkerSize',5,'MarkerFaceColor',colJournal, ...
        'MarkerEdgeColor',colJournal);

    % Bearing center
    plot(ax,0,0,'+','MarkerSize',10,'LineWidth',1.4, ...
        'Color',[0.1 0.1 0.1]);

    % Eccentricity line
    plot(ax,[0 result.ex]*1e3,[0 result.ey]*1e3,'--', ...
        'Color',[0.28 0.28 0.28],'LineWidth',0.9);

    % Global pressure scale
    pGlobal = max(arrayfun(@(p)max(p.P(:)),result.pad));
    if pGlobal <= 0
        pGlobal = 1;
    end

    % --------------------------------------------------------------
    % Pads + pivots + TILT + pressure distribution
    % --------------------------------------------------------------
    for ip = 1:bearing.nPads

        pd = bearing.pad(ip);
        th = result.pad(ip).theta(:);

        isActive = result.pad(ip).load > activePadLoadFraction*W;
        if isActive
            padColor = colPad;
            padLW = 2.0;
        else
            padColor = colPadIdle;
            padLW = 1.2;
        end

        % Visualized pad radial location only.
        rIn = R + visualScale*pd.CbPivot;
        rOut = rIn + 0.075*R;

        % Untilted reference pad coordinates.
        xi0 = rIn*cos(th);
        yi0 = rIn*sin(th);
        xo0 = rOut*cos(th);
        yo0 = rOut*sin(th);

        % Visual pivot point used as rigid-body rotation center.
        % The pivot direction is exact; radial location is drawing-only.
        tp = pd.thetaPivot;
        rPivotBody = rOut;
        xpiv = rPivotBody*cos(tp);
        ypiv = rPivotBody*sin(tp);

        % Actual solved pad tilt [rad].
        alphaActual = result.pad(ip).alpha;

        if showPadTilt
            alphaDraw = tiltAmp*alphaActual;
        else
            alphaDraw = 0;
        end

        % Rotate complete pad rigidly about its pivot.
        [xi,yi] = rotateRigidAboutPoint(xi0,yi0,xpiv,ypiv,alphaDraw);
        [xo,yo] = rotateRigidAboutPoint(xo0,yo0,xpiv,ypiv,alphaDraw);

        % Original pad outline before tilt.
        if showPadTilt && showOriginalPad
            plot(ax,[xi0;flipud(xo0);xi0(1)]*1e3, ...
                    [yi0;flipud(yo0);yi0(1)]*1e3, ...
                    '--','Color',colOriginal,'LineWidth',0.75);
        end

        % Tilted pad body.
        fill(ax,[xi;flipud(xo)],[yi;flipud(yo)],[0.90 0.94 1.00], ...
            'EdgeColor',padColor,'LineWidth',2.4);

        % Reinforce complete tilted pad boundary as solid lines
        plot(ax,xi*1e3,yi*1e3,'-','Color',padColor,'LineWidth',2.4);
        plot(ax,xo*1e3,yo*1e3,'-','Color',padColor,'LineWidth',2.4);
        % Explicitly close leading and trailing pad ends
        plot(ax,[xi(1) xo(1)]*1e3,[yi(1) yo(1)]*1e3,'-', ...
            'Color',padColor,'LineWidth',2.4);
        plot(ax,[xi(end) xo(end)]*1e3,[yi(end) yo(end)]*1e3,'-', ...
            'Color',padColor,'LineWidth',2.4);

        % Pivot radial guide line: clarifies true LBP definition.
        rGuide1 = 0.80*R;
        rGuide2 = rOut + 0.10*R;
        plot(ax,[rGuide1*cos(tp) rGuide2*cos(tp)]*1e3, ...
                [rGuide1*sin(tp) rGuide2*sin(tp)]*1e3, ...
                '--','Color',colGuide,'LineWidth',0.8);

        % Pivot marker (fixed point).
        rpMark = rOut + 0.055*R;
        plot(ax,rpMark*cos(tp)*1e3,rpMark*sin(tp)*1e3,'v', ...
            'MarkerSize',7,'LineWidth',1.2, ...
            'Color',colPivot,'MarkerFaceColor','w');

        % Pad label including the ACTUAL, non-amplified tilt.
        rt = rOut + 0.16*R;
        text(ax,rt*cos(tp)*1e3,rt*sin(tp)*1e3, ...
            sprintf('Pad %d\nTilt = %+.3f mrad',ip,alphaActual*1e3), ...
            'HorizontalAlignment','center','VerticalAlignment','middle', ...
            'FontName','Arial','FontSize',9,'Color',padColor);

        % ----------------------------------------------------------
        % Pressure distribution directly on the TILTED pad.
        % Pressure is evaluated from the solved field and only its
        % DRAWING coordinates are rotated with the pad.
        % ----------------------------------------------------------
        pTheta = max(result.pad(ip).P,[],2);
        pTheta = max(pTheta,0);
        pNorm = pTheta/pGlobal;

        pAmp = 0.34*R;
        rBase = rIn - 0.010*R;
        rPressure = rBase + pAmp*pNorm;

        xb0 = rBase*cos(th);
        yb0 = rBase*sin(th);
        xp0 = rPressure.*cos(th);
        yp0 = rPressure.*sin(th);

        [xb,yb] = rotateRigidAboutPoint(xb0,yb0,xpiv,ypiv,alphaDraw);
        [xp,yp] = rotateRigidAboutPoint(xp0,yp0,xpiv,ypiv,alphaDraw);

        if any(pTheta > 0)
            % Pressure envelope
            plot(ax,xp*1e3,yp*1e3,'-','Color',colPressure,'LineWidth',2.0);

            % Pressure ribs
            ribIdx = unique(round(linspace(1,numel(th),28)));
            for kk = ribIdx(:).'
                if pTheta(kk) <= 0
                    continue;
                end
                plot(ax,[xb(kk) xp(kk)]*1e3,[yb(kk) yp(kk)]*1e3,'-', ...
                    'Color',colPressure,'LineWidth',0.65);
            end

            % Peak pressure marker
            [~,iPk] = max(pTheta);
            plot(ax,xp(iPk)*1e3,yp(iPk)*1e3,'o', ...
                'MarkerSize',4,'MarkerFaceColor',colPressure, ...
                'MarkerEdgeColor',colPressure);
        end
    end

    % --------------------------------------------------------------
    % Load arrow
    % --------------------------------------------------------------
    arrowLength = 0.60*R*1e3;
    quiver(ax,0,0,0,-arrowLength,0, ...
        'Color',colLoad,'LineWidth',2.0,'MaxHeadSize',0.35);
    text(ax,0,-0.72*R*1e3,'W', ...
        'HorizontalAlignment','center','FontWeight','bold','FontSize',11);

    % --------------------------------------------------------------
    % Shaft rotation arrow
    % --------------------------------------------------------------
    rr = 0.72*R;
    tt = linspace(-25,35,50)*pi/180;
    xr = rr*cos(tt)*1e3;
    yr = rr*sin(tt)*1e3;
    plot(ax,xr,yr,'-','Color',colRotation,'LineWidth',2.0);

    p1 = [xr(end-1) yr(end-1)];
    p2 = [xr(end) yr(end)];
    d = p2-p1;
    quiver(ax,p1(1),p1(2),d(1),d(2),0, ...
        'Color',colRotation,'LineWidth',1.8,'MaxHeadSize',2.0);

    % --------------------------------------------------------------
    % Axes / title
    % --------------------------------------------------------------
    lim = (R + visualScale*bearing.Cp + 0.55*R)*1e3;
    xlim(ax,[-lim lim]);
    ylim(ax,[-lim lim]);

    xlabel(ax,'X [mm]');
    ylabel(ax,'Y [mm]');
    grid off
    axis off
    title(ax,sprintf('RotorDynX TPJB — Tilted Pads Performance Summary — %s', ...
        upper(bearing.loadOrientation)), ...
        'FontName','Arial','FontWeight','bold');

    subtitle(ax,sprintf(['Clearance drawing x%.0f | Pad tilt drawing x%.0f | ', ...
        'actual solver geometry unchanged'],visualScale,tiltAmp));

    % --------------------------------------------------------------
    % Side performance summary
    %
    % V1.3A:
    % Use a classic uipanel + uicontrol text instead of an auxiliary
    % axes. This is much more robust when the GUI later decorates/
    % repositions the MATLAB figure for RotorDynX branding.
    % --------------------------------------------------------------
    K = result.dynamic.K;
    C = result.dynamic.C;

    txt = {
        'PERFORMANCE SUMMARY'
        '----------------------'
        sprintf('D        %8.3f mm',2*R*1e3)
        sprintf('L        %8.3f mm',bearing.L*1e3)
        sprintf('Cb       %8.3f um',bearing.Cb*1e6)
        sprintf('Cp       %8.3f um',bearing.Cp*1e6)
        sprintf('Preload  %8.3f',bearing.preload)
        sprintf('Pads     %8d',bearing.nPads)
        sprintf('Arc      %8.2f deg', ...
            rad2deg(bearing.pad(1).theta2-bearing.pad(1).theta1))
        sprintf('Offset   %8.3f',bearing.pivotOffset)
        ' '
        sprintf('e/Cb     %8.5f',result.epsilon)
        sprintf('Att.     %8.3f deg',result.attitudeDeg)
        sprintf('hmin     %8.3f um',result.hmin*1e6)
        sprintf('hpivot   %8.3f um', ...
            min(arrayfun(@(p)p.hPivot,result.pad))*1e6)
        sprintf('Pmax     %8.4f MPa',result.Pmax/1e6)
        sprintf('Power    %8.4f kW',result.power/1e3)
        sprintf('Thermal  %8s',upper(result.thermal.model))
        sprintf('mu_eff   %8.3e Pa.s',result.thermal.muEff)
        sprintf('PivotLd  %8.2f N', ...
            max(arrayfun(@(p)p.load,result.pad)))
        ' '
        };

    if strcmpi(result.thermal.model,'HeatBalance')
        txt{end+1} = ' '; %#ok<AGROW>
        txt{end+1} = 'THERMAL [degC]'; %#ok<AGROW>
        txt{end+1} = sprintf('Tin      %8.2f',result.thermal.Tin_C); %#ok<AGROW>
        txt{end+1} = sprintf('Tout     %8.2f',result.thermal.Tout_C); %#ok<AGROW>
        txt{end+1} = sprintf('Teff     %8.2f',result.thermal.Teff_C); %#ok<AGROW>
        txt{end+1} = sprintf('DeltaT   %8.2f',result.thermal.deltaT_C); %#ok<AGROW>
    end

    txt{end+1} = ' '; %#ok<AGROW>
    txt{end+1} = 'PAD TILT ANGLE [mrad]'; %#ok<AGROW>

    for ip = 1:bearing.nPads
        txt{end+1} = sprintf('Pad %-2d  %+8.3f', ...
            ip,result.pad(ip).alpha*1e3); %#ok<AGROW>
    end

    txt = [txt; {
        ' '
        'STIFFNESS [N/m]'
        sprintf('Kxx  % .3e',K(1,1))
        sprintf('Kxy  % .3e',K(1,2))
        sprintf('Kyx  % .3e',K(2,1))
        sprintf('Kyy  % .3e',K(2,2))
        ' '
        'DAMPING [N.s/m]'
        sprintf('Cxx  % .3e',C(1,1))
        sprintf('Cxy  % .3e',C(1,2))
        sprintf('Cyx  % .3e',C(2,1))
        sprintf('Cyy  % .3e',C(2,2))
        }];

    % Convert result lines to one multiline string.
    txtBlock = sprintf('%s\n',txt{:});

    panelBg = [0.965 0.975 0.988];

    pSummary = uipanel(fig, ...
        'Units','normalized', ...
        'Position',[0.735 0.085 0.245 0.805], ...
        'Title','RESULTS', ...
        'FontName','Arial', ...
        'FontSize',10.5, ...
        'FontWeight','bold', ...
        'ForegroundColor',[0.025 0.145 0.275], ...
        'BackgroundColor',panelBg, ...
        'BorderType','etchedin');

    uicontrol(pSummary, ...
        'Style','text', ...
        'Units','normalized', ...
        'Position',[0.035 0.075 0.93 0.895], ...
        'String',txtBlock, ...
        'HorizontalAlignment','left', ...
        'FontName','Consolas', ...
        'FontSize',9.0, ...
        'ForegroundColor',[0.08 0.08 0.10], ...
        'BackgroundColor',panelBg);

    uicontrol(pSummary, ...
        'Style','text', ...
        'Units','normalized', ...
        'Position',[0.035 0.012 0.93 0.050], ...
        'String','Blue: tilted pad   |   Magenta: pressure   |   Red: load   |   Green: rotation', ...
        'HorizontalAlignment','left', ...
        'FontName','Arial', ...
        'FontSize',7.8, ...
        'ForegroundColor',[0.28 0.30 0.34], ...
        'BackgroundColor',panelBg);

    % Keep the main bearing graphic visually balanced with the result panel.
    lim = (R + visualScale*bearing.Cp + 0.55*R)*1e3;
    xlim(ax,[-lim lim]);
    ylim(ax,[-lim lim]);
end


function [xr,yr] = rotateRigidAboutPoint(x,y,xp,yp,ang)
    % Rigid 2-D rotation about pivot point.
    ca = cos(ang);
    sa = sin(ang);

    dx = x-xp;
    dy = y-yp;

    xr = xp + ca.*dx - sa.*dy;
    yr = yp + sa.*dx + ca.*dy;
end


function plotTPJBPressureContours(bearing,result)

    nPads = bearing.nPads;
    nCol = ceil(sqrt(nPads));
    nRow = ceil(nPads/nCol);

    figure('Name','RotorDynX - TPJB Pressure Distribution','Color','w', ...
        'Position',[70 70 1100 760]);
    tl = tiledlayout(nRow,nCol,'TileSpacing','compact','Padding','compact');
    title(tl,'RotorDynX TPJB — 2-D Hydrodynamic Pressure Distribution');

    pGlobal = max(arrayfun(@(p)max(p.P(:)),result.pad))/1e6;
    if pGlobal <= 0, pGlobal = 1; end

    for ip = 1:nPads
        ax = nexttile(tl);
        thetaDeg = rad2deg(result.pad(ip).theta);
        zmm = result.pad(ip).z*1e3;
        Pmpa = result.pad(ip).P'/1e6;

        contourf(ax,thetaDeg,zmm,Pmpa,24,'LineStyle','none');
        caxis(ax,[0 pGlobal]);
        grid(ax,'on');
        set(ax,'FontName','Arial','FontSize',10,'GridAlpha',0.10);
        xlabel(ax,'\theta [deg]');
        ylabel(ax,'Axial z [mm]');
        title(ax,sprintf('Pad %d | Load %.1f N | Pmax %.3f MPa', ...
            ip,result.pad(ip).load,max(result.pad(ip).P(:))/1e6));
        colorbar(ax);
    end
end


function plotTPJBPressureCurves(result,W,activePadLoadFraction)

    nPads = numel(result.pad);
    figure('Name','RotorDynX - TPJB Circumferential Pressure','Color','w', ...
        'Position',[150 110 930 540]);
    ax = axes;
    hold(ax,'on'); box(ax,'on');
    set(ax,'FontName','Arial','FontSize',11,'LineWidth',0.9, ...
        'XGrid','on','YGrid','on','GridAlpha',0.12);

    leg = cell(1,nPads);
    for ip = 1:nPads
        th = rad2deg(result.pad(ip).theta);
        p = max(result.pad(ip).P,[],2)/1e6;
        active = result.pad(ip).load > activePadLoadFraction*W;

        if active
            plot(ax,th,p,'-','LineWidth',1.8);
            leg{ip}=sprintf('Pad %d ACTIVE',ip);
        else
            plot(ax,th,p,'--','LineWidth',1.0);
            leg{ip}=sprintf('Pad %d IDLE',ip);
        end
    end

    xlabel(ax,'Circumferential angle \theta [deg]');
    ylabel(ax,'Maximum axial pressure [MPa]');
    title(ax,'RotorDynX TPJB — Circumferential Pressure Profiles');
    legend(ax,leg,'Location','best','Box','off');
end


function plotTPJBFilmThickness(bearing,result)

    nPads = bearing.nPads;
    figure('Name','RotorDynX - TPJB Film Thickness','Color','w', ...
        'Position',[160 120 930 540]);
    ax = axes;
    hold(ax,'on'); box(ax,'on');
    set(ax,'FontName','Arial','FontSize',11,'LineWidth',0.9, ...
        'XGrid','on','YGrid','on','GridAlpha',0.12);

    leg = cell(1,nPads);
    for ip = 1:nPads
        th = rad2deg(result.pad(ip).theta);
        h = result.pad(ip).h*1e6;
        plot(ax,th,h,'-','LineWidth',1.6);
        leg{ip}=sprintf('Pad %d',ip);

        [hmin,idx] = min(h);
        plot(ax,th(idx),hmin,'o','MarkerSize',4,'LineWidth',0.9);
    end

    xlabel(ax,'Circumferential angle \theta [deg]');
    ylabel(ax,'Film thickness h [\mum]');
    title(ax,sprintf('RotorDynX TPJB — Film Thickness | Global h_{min} = %.3f \\mum', ...
        result.hmin*1e6));
    legend(ax,leg,'Location','best','Box','off');
end



function [result,history,bearing] = solveTPJBOperatingPoint( ...
    bearing,qGuess,options,thermalCfg,printThermal)

    if nargin < 5
        printThermal = false;
    end

    thermal = struct();
    thermal.model = char(thermalCfg.model);
    thermal.converged = true;
    thermal.iterations = 1;
    thermal.Tin_C = thermalCfg.Tin_C;
    thermal.Tout_C = thermalCfg.Tin_C;
    thermal.Teff_C = thermalCfg.Tin_C;
    thermal.muEff = thermalCfg.muIsothermal;
    thermal.deltaT_C = 0;
    thermal.mDot = NaN;
    thermal.Qsupply_Lmin = thermalCfg.Qsupply_Lmin;

    if strcmpi(thermalCfg.model,'Isothermal')

        bearing.mu = thermalCfg.muIsothermal;
        [result,history] = solveTPJBStaticEquilibriumNested( ...
            bearing,qGuess,options);

        thermal.muEff = bearing.mu;
        thermal.converged = true;

    elseif strcmpi(thermalCfg.model,'HeatBalance')

        if thermalCfg.Qsupply_Lmin <= 0
            error('HeatBalance requires Qsupply_Lmin > 0.');
        end

        Qsupply_m3s = thermalCfg.Qsupply_Lmin*1e-3/60;
        mDot = thermalCfg.rhoOil*Qsupply_m3s;

        muIter = viscosityD341(thermalCfg.Tin_C, ...
            thermalCfg.nu40_cSt,thermalCfg.nu100_cSt,thermalCfg.rhoOil);
        TeffOld = thermalCfg.Tin_C;
        thermalConverged = false;
        qLocal = qGuess;

        if printThermal
            fprintf('\n====================================================\n');
            fprintf(' BULK HEAT-BALANCE ITERATION\n');
            fprintf('====================================================\n');
        end

        for itThermal = 1:thermalCfg.thermalMaxIter

            bearing.mu = muIter;
            [result,history] = solveTPJBStaticEquilibriumNested( ...
                bearing,qLocal,options);

            deltaT = thermalCfg.etaHeatToOil*result.power / ...
                (mDot*thermalCfg.cpOil);
            Tout_C = thermalCfg.Tin_C + deltaT;
            Teff_C = thermalCfg.Tin_C + ...
                thermalCfg.effectiveTempFraction*deltaT;

            muTarget = viscosityD341(Teff_C, ...
                thermalCfg.nu40_cSt,thermalCfg.nu100_cSt,thermalCfg.rhoOil);

            relMu = abs(muTarget-muIter)/max(abs(muIter),eps);
            dTeff = abs(Teff_C-TeffOld);

            if printThermal
                fprintf(['Thermal %2d | mu %.6e Pa.s | Power %.4f kW | ', ...
                         'Tout %.3f C | Teff %.3f C | dMu/mu %.3e\n'], ...
                    itThermal,muIter,result.power/1e3,Tout_C,Teff_C,relMu);
            end

            if relMu < thermalCfg.thermalTolMu && ...
                    dTeff < thermalCfg.thermalTolT_C
                thermalConverged = true;
                muIter = muTarget;
                break;
            end

            muIter = (1-thermalCfg.thermalRelax)*muIter + ...
                thermalCfg.thermalRelax*muTarget;
            TeffOld = Teff_C;
            qLocal = [result.qx;result.qy];
        end

        bearing.mu = muIter;
        [result,history] = solveTPJBStaticEquilibriumNested( ...
            bearing,[result.qx;result.qy],options);

        deltaT = thermalCfg.etaHeatToOil*result.power / ...
            (mDot*thermalCfg.cpOil);
        Tout_C = thermalCfg.Tin_C + deltaT;
        Teff_C = thermalCfg.Tin_C + ...
            thermalCfg.effectiveTempFraction*deltaT;

        thermal.model = 'HeatBalance';
        thermal.converged = thermalConverged;
        thermal.iterations = itThermal;
        thermal.Tin_C = thermalCfg.Tin_C;
        thermal.Tout_C = Tout_C;
        thermal.Teff_C = Teff_C;
        thermal.deltaT_C = deltaT;
        thermal.muEff = bearing.mu;
        thermal.mDot = mDot;
        thermal.Qsupply_Lmin = thermalCfg.Qsupply_Lmin;

    else
        error('Thermal model must be "Isothermal" or "HeatBalance".');
    end

    result.thermal = thermal;
end


function mu = viscosityD341(T_C,nu40_cSt,nu100_cSt,rhoOil)
    % ASTM D341 / Walther two-point viscosity-temperature correlation.
    % nu is in cSt and absolute temperature is in K.
    %
    % log10(log10(nu + 0.7)) = A - B*log10(T_K)

    T1 = 40 + 273.15;
    T2 = 100 + 273.15;
    T  = T_C + 273.15;

    Y1 = log10(log10(nu40_cSt + 0.7));
    Y2 = log10(log10(nu100_cSt + 0.7));

    X1 = log10(T1);
    X2 = log10(T2);

    B = (Y1-Y2)/(X2-X1);
    A = Y1 + B*X1;

    Y = A - B*log10(T);
    nu_cSt = 10^(10^Y) - 0.7;

    if ~isfinite(nu_cSt) || nu_cSt <= 0
        error('ASTM D341 produced invalid viscosity at %.3f C.',T_C);
    end

    mu = nu_cSt*1e-6*rhoOil;  % cSt -> m^2/s -> Pa.s
end


function bearing = prepareTPJBGeometry(bearing)

    n = bearing.nPads;
    arc = bearing.padArcDeg;
    off = bearing.pivotOffset;

    if n < 3
        error('TPJB should contain at least 3 pads.');
    end

    if arc <= 0 || arc >= 360/n
        error('padArcDeg must be >0 and smaller than pad pitch.');
    end

    if off <= 0 || off >= 1
        error('pivotOffset must satisfy 0 < pivotOffset < 1.');
    end

    padPitchDeg = 360/n;

    % Load acts at 270 deg (-Y).
    loadAngleDeg = 270;

    switch upper(bearing.loadOrientation)

        case 'LOP'
            % One pivot exactly on the load line.
            firstPivotDeg = loadAngleDeg;

        case 'LBP'
            % Load line midway between two adjacent pivots.
            firstPivotDeg = loadAngleDeg - 0.5*padPitchDeg;

        otherwise
            error('loadOrientation must be "LOP" or "LBP".');
    end

    for i = 1:n

        pivotDeg = mod(firstPivotDeg + (i-1)*padPitchDeg,360);

        theta1Deg = pivotDeg - off*arc;
        theta2Deg = theta1Deg + arc;

        bearing.pad(i).thetaPivotDeg = mod(pivotDeg,360);
        bearing.pad(i).theta1Deg = theta1Deg;
        bearing.pad(i).theta2Deg = theta2Deg;

        bearing.pad(i).thetaPivot = deg2rad(pivotDeg);
        bearing.pad(i).theta1 = deg2rad(theta1Deg);
        bearing.pad(i).theta2 = deg2rad(theta2Deg);
    end
end


function [result,history] = solveTPJBStaticEquilibriumNested(bearing,q,options)

    history.iter = [];
    history.normResidual = [];

    converged = false;

    fprintf('\n====================================================\n');
    fprintf(' NESTED STATIC TPJB EQUILIBRIUM\n');
    fprintf('====================================================\n');
    fprintf('Inner solve : M_pivot(i) = 0 for every pad\n');
    fprintf('Outer solve : Fx = 0, Fy = W\n');
    fprintf('Static acceleration: warm-started pad-tilt roots with full-scan fallback\n');

    bestNorm = inf;
    bestQ = q;
    bestState = [];

    % V1.3 FAST STATIC:
    % Carry the converged pad tilts from one nearby journal-center state
    % to the next.  Jacobian and line-search states are extremely close in
    % q-space, so rescanning 161 tilt values per pad is unnecessary.
    %
    % The local solver always falls back to the original full loaded-branch
    % scan if the nearby physical root cannot be bracketed.  Therefore the
    % physical root-selection logic is preserved.
    alphaGuess = nan(bearing.nPads,1);

    tStaticCore = tic;
    fullScanFallbacks = 0;
    localRootUses = 0;

    for iter = 1:options.eqMaxIter

        [state,alphaState,stats0] = tpjbStateNestedWarm( ...
            bearing,q,options,alphaGuess);

        fullScanFallbacks = fullScanFallbacks + stats0.fullScanFallbacks;
        localRootUses = localRootUses + stats0.localRootUses;

        alphaGuess = alphaState;

        r = [state.Fx/bearing.W; ...
             (state.Fy-bearing.W)/bearing.W];

        normResidual = norm(r,2);

        history.iter(end+1,1) = iter;
        history.normResidual(end+1,1) = normResidual;

        padLoads = arrayfun(@(p)p.load,state.pad);
        activePadMask = padLoads > options.activePadLoadFraction*bearing.W;

        if any(activePadMask)
            activeMom = arrayfun(@(p)p.momentCirc,state.pad(activePadMask));
            maxMnorm = max(abs(activeMom))/(bearing.W*bearing.Rj);
        else
            maxMnorm = 0;
        end

        fprintf(['Eq %2d | eps = %.5f | Fx = %10.2f N | Fy = %10.2f N | ', ...
                 'max|M_active|/(WR) = %.3e | Force residual = %.3e\n'], ...
            iter,state.epsilon,state.Fx,state.Fy,maxMnorm,normResidual);

        if normResidual < bestNorm
            bestNorm = normResidual;
            bestQ = q;
            bestState = state;
        end

        strictConverged = ...
            normResidual < options.eqTolForce && ...
            maxMnorm < 10*options.padMomentTol;

        benchmarkConverged = ...
            normResidual < options.benchmarkForceTol && ...
            maxMnorm < 2e-4;

        if strictConverged || ...
                (options.allowBenchmarkConvergence && benchmarkConverged)
            converged = true;
            bestState = state;
            bestQ = q;
            break;
        end

        % ---------------------------------------------------------
        % Numerical 2x2 Jacobian after re-equilibrating ALL pad tilts.
        % Warm-start each perturbed state from the current solved tilts.
        % ---------------------------------------------------------
        J = zeros(2,2);

        fdOuter = options.fdCenter;
        if normResidual < 1e-3
            fdOuter = min(fdOuter,5e-4);
        end
        if normResidual < 1e-5
            fdOuter = min(fdOuter,1e-4);
        end

        for j = 1:2

            dq = zeros(2,1);
            dq(j) = fdOuter;

            [sp,~,statsp] = tpjbStateNestedWarm( ...
                bearing,q+dq,options,alphaState);
            [sm,~,statsm] = tpjbStateNestedWarm( ...
                bearing,q-dq,options,alphaState);

            fullScanFallbacks = fullScanFallbacks + ...
                statsp.fullScanFallbacks + statsm.fullScanFallbacks;
            localRootUses = localRootUses + ...
                statsp.localRootUses + statsm.localRootUses;

            rp = [sp.Fx/bearing.W; ...
                  (sp.Fy-bearing.W)/bearing.W];

            rm = [sm.Fx/bearing.W; ...
                  (sm.Fy-bearing.W)/bearing.W];

            J(:,j) = (rp-rm)/(2*dq(j));
        end

        if rcond(J) < 1e-12
            delta = -pinv(J)*r;
        else
            delta = -J\r;
        end

        delta = max(min(delta,0.20),-0.20);

        % ---------------------------------------------------------
        % Backtracking on OUTER force residual.
        % Warm-start every trial from the current solved pad tilts.
        % ---------------------------------------------------------
        lambda = 1;
        accepted = false;

        while lambda >= options.minLineSearch

            qTry = q + lambda*delta;

            if hypot(qTry(1),qTry(2)) > 1.25
                lambda = lambda/2;
                continue;
            end

            try
                [sTry,alphaTry,statsTry] = tpjbStateNestedWarm( ...
                    bearing,qTry,options,alphaState);

                fullScanFallbacks = fullScanFallbacks + statsTry.fullScanFallbacks;
                localRootUses = localRootUses + statsTry.localRootUses;

                rTry = [sTry.Fx/bearing.W; ...
                        (sTry.Fy-bearing.W)/bearing.W];

                if sTry.hmin > 0 && norm(rTry,2) < normResidual
                    q = qTry;
                    alphaGuess = alphaTry;
                    accepted = true;
                    break;
                end
            catch
                % Invalid trial film or no valid pad root -> reduce step.
            end

            lambda = lambda/2;
        end

        if ~accepted
            warning(['TPJB outer journal-position line search failed at ', ...
                     'iteration %d. Returning best state reached.'],iter);
            break;
        end
    end

    if isempty(bestState)
        [bestState,~,statsBest] = tpjbStateNestedWarm( ...
            bearing,bestQ,options,alphaGuess);
        fullScanFallbacks = fullScanFallbacks + statsBest.fullScanFallbacks;
        localRootUses = localRootUses + statsBest.localRootUses;
    end

    result = bestState;
    result.converged = converged;

    padLoadsFinal = arrayfun(@(p)p.load,result.pad);
    activeFinal = padLoadsFinal > options.activePadLoadFraction*bearing.W;

    if any(activeFinal)
        activeMomFinal = arrayfun(@(p)p.momentCirc,result.pad(activeFinal));
        maxMnormFinal = max(abs(activeMomFinal))/(bearing.W*bearing.Rj);
    else
        maxMnormFinal = 0;
    end

    result.strictConverged = ...
        result.forceResidual < options.eqTolForce && ...
        maxMnormFinal < 10*options.padMomentTol;

    result.iterations = iter;

    result.staticTiming.core_s = toc(tStaticCore);
    result.staticTiming.localRootUses = localRootUses;
    result.staticTiming.fullScanFallbacks = fullScanFallbacks;

    fprintf('Static root acceleration  : local roots = %d | full-scan fallbacks = %d\n', ...
        localRootUses,fullScanFallbacks);
end


function [state,alphaOut,stats] = tpjbStateNestedWarm( ...
    bearing,q,options,alphaGuess)

    n = bearing.nPads;

    if nargin < 4 || isempty(alphaGuess)
        alphaGuess = nan(n,1);
    end

    qx = q(1);
    qy = q(2);

    ex = qx*bearing.Cb;
    ey = qy*bearing.Cb;

    Fx = 0;
    Fy = 0;
    moments = zeros(n,1);

    globalHmin = inf;
    globalPmax = 0;

    padState = [];
    alphaOut = nan(n,1);

    stats.localRootUses = 0;
    stats.fullScanFallbacks = 0;

    for i = 1:n

        if strcmpi(bearing.pivotType,'Line')

            [pad,usedLocal] = solvePadTiltEquilibriumLineWarm( ...
                bearing,i,ex,ey,options,alphaGuess(i));

            if usedLocal
                stats.localRootUses = stats.localRootUses + 1;
            else
                stats.fullScanFallbacks = stats.fullScanFallbacks + 1;
            end

            alphaOut(i) = pad.alpha;

        elseif strcmpi(bearing.pivotType,'Spherical') || ...
                strcmpi(bearing.pivotType,'Point')

            [pad,usedLocal] = solvePadTiltEquilibriumSphericalWarmV14( ...
                bearing,i,ex,ey,options,alphaGuess(i));

            if usedLocal
                stats.localRootUses = stats.localRootUses + 1;
            else
                stats.fullScanFallbacks = stats.fullScanFallbacks + 1;
            end

            alphaOut(i) = pad.alpha;

        else
            error('pivotType must be "Line" or "Spherical".');
        end

        Fx = Fx + pad.Fx;
        Fy = Fy + pad.Fy;

        moments(i) = max(abs([pad.momentCirc pad.momentAxialFree]));

        globalHmin = min(globalHmin,pad.hmin);
        globalPmax = max(globalPmax,pad.Pmax);

        if i == 1
            padState = repmat(pad,n,1);
        else
            padState(i) = pad;
        end
    end

    epsilon = hypot(qx,qy);
    centerAngleDeg = mod(atan2d(ey,ex),360);

    attitudeDeg = abs(rad2deg(tpjbWrapToPiLocal( ...
        deg2rad(centerAngleDeg-270))));

    loads = arrayfun(@(p)p.load,padState);
    [maxPivotLoad,loadedPad] = max(loads);

    powers = arrayfun(@(p)p.power,padState);
    pivotFilms = arrayfun(@(p)p.hPivot,padState);

    state.qx = qx;
    state.qy = qy;
    state.ex = ex;
    state.ey = ey;
    state.epsilon = epsilon;
    state.centerAngleDeg = centerAngleDeg;
    state.attitudeDeg = attitudeDeg;

    state.Fx = Fx;
    state.Fy = Fy;
    state.moments = moments;

    state.forceResidual = hypot(Fx/bearing.W, ...
        (Fy-bearing.W)/bearing.W);

    state.pad = padState;
    state.hmin = globalHmin;
    state.minPivotFilm = min(pivotFilms);
    state.Pmax = globalPmax;
    state.maxPivotLoad = maxPivotLoad;
    state.power = sum(powers);
    state.loadedPad = loadedPad;
end


function state = tpjbStateNested(bearing,q,options)

    n = bearing.nPads;

    qx = q(1);
    qy = q(2);

    ex = qx*bearing.Cb;
    ey = qy*bearing.Cb;

    Fx = 0;
    Fy = 0;
    moments = zeros(n,1);

    globalHmin = inf;
    globalPmax = 0;

    padState = [];

    for i = 1:n

        if strcmpi(bearing.pivotType,'Line')
            pad = solvePadTiltEquilibriumLine(bearing,i,ex,ey,options);
        elseif strcmpi(bearing.pivotType,'Spherical') || ...
                strcmpi(bearing.pivotType,'Point')
            pad = solvePadTiltEquilibriumSpherical(bearing,i,ex,ey,options);
        else
            error('pivotType must be "Line" or "Spherical".');
        end

        Fx = Fx + pad.Fx;
        Fy = Fy + pad.Fy;

        % Outer diagnostic uses the free circumferential moment.
        % For spherical pivots both components are solved to zero.
        moments(i) = max(abs([pad.momentCirc pad.momentAxialFree]));

        globalHmin = min(globalHmin,pad.hmin);
        globalPmax = max(globalPmax,pad.Pmax);

        if i == 1
            padState = repmat(pad,n,1);
        else
            padState(i) = pad;
        end
    end

    epsilon = hypot(qx,qy);
    centerAngleDeg = mod(atan2d(ey,ex),360);

    attitudeDeg = abs(rad2deg(tpjbWrapToPiLocal( ...
        deg2rad(centerAngleDeg-270))));

    loads = arrayfun(@(p)p.load,padState);
    [maxPivotLoad,loadedPad] = max(loads);

    powers = arrayfun(@(p)p.power,padState);
    pivotFilms = arrayfun(@(p)p.hPivot,padState);

    state.qx = qx;
    state.qy = qy;
    state.ex = ex;
    state.ey = ey;
    state.epsilon = epsilon;
    state.centerAngleDeg = centerAngleDeg;
    state.attitudeDeg = attitudeDeg;

    state.Fx = Fx;
    state.Fy = Fy;
    state.moments = moments;

    state.forceResidual = hypot(Fx/bearing.W, ...
        (Fy-bearing.W)/bearing.W);

    state.pad = padState;
    state.hmin = globalHmin;
    state.minPivotFilm = min(pivotFilms);
    state.Pmax = globalPmax;
    state.maxPivotLoad = maxPivotLoad;
    state.power = sum(powers);
    state.loadedPad = loadedPad;
end


function [pad,usedLocal] = solvePadTiltEquilibriumLineWarm( ...
    bearing,padIndex,ex,ey,options,alphaGuess)

    % Fast local physical-root search around the previously converged pad
    % tilt.  If anything looks ambiguous, revert to the original validated
    % full scan.  This preserves the loaded-branch selection logic.

    usedLocal = false;

    if nargin < 6 || ~isfinite(alphaGuess)
        pad = solvePadTiltEquilibriumLine( ...
            bearing,padIndex,ex,ey,options);
        return;
    end

    activeLoadTol = options.activePadLoadFraction*bearing.W;
    amax = options.padTiltScanMax;

    % Evaluate the previous root first.
    try
        p0 = solveSingleTPJBPad( ...
            bearing,padIndex,ex,ey,alphaGuess,0);

        if p0.hmin > 0 && p0.load > activeLoadTol
            m0 = p0.moment/(bearing.W*bearing.Rj);
            if abs(m0) < options.padMomentTol
                pad = p0;
                usedLocal = true;
                return;
            end
        end
    catch
        % Fall through to local bracket expansion.
    end

    % Local bracket expansion.  Start much finer than the old global scan
    % spacing and expand geometrically around the previous physical root.
    scanSpacing = 2*amax/max(options.padTiltScanPts-1,1);
    step = max(0.5*scanSpacing,2.5e-5);

    bracketFound = false;

    for iexp = 1:10

        alo = max(-amax,alphaGuess-step);
        ahi = min( amax,alphaGuess+step);

        try
            plo = solveSingleTPJBPad( ...
                bearing,padIndex,ex,ey,alo,0);
            phi = solveSingleTPJBPad( ...
                bearing,padIndex,ex,ey,ahi,0);

            validLo = plo.hmin > 0 && plo.load > activeLoadTol;
            validHi = phi.hmin > 0 && phi.load > activeLoadTol;

            if validLo && validHi
                Mlo = plo.moment;
                Mhi = phi.moment;

                if abs(Mlo)/(bearing.W*bearing.Rj) < options.padMomentTol
                    pad = plo; usedLocal = true; return;
                end
                if abs(Mhi)/(bearing.W*bearing.Rj) < options.padMomentTol
                    pad = phi; usedLocal = true; return;
                end

                if Mlo*Mhi < 0
                    bracketFound = true;
                    break;
                end
            end
        catch
            % keep expanding
        end

        if alo <= -amax && ahi >= amax
            break;
        end

        step = min(2*step,2*amax);
    end

    if bracketFound

        % Same loaded-branch bisection criterion as the validated solver.
        for it = 1:80

            amid = 0.5*(alo+ahi);

            try
                pmid = solveSingleTPJBPad( ...
                    bearing,padIndex,ex,ey,amid,0);
            catch
                break;
            end

            Mmid = pmid.moment;
            Mnorm = abs(Mmid)/(bearing.W*bearing.Rj);

            if pmid.load > activeLoadTol && Mnorm < options.padMomentTol
                pad = pmid;
                usedLocal = true;
                return;
            end

            if Mlo*Mmid <= 0
                ahi = amid;
                Mhi = Mmid; %#ok<NASGU>
            else
                alo = amid;
                Mlo = Mmid;
            end
        end

        try
            padTry = solveSingleTPJBPad( ...
                bearing,padIndex,ex,ey,0.5*(alo+ahi),0);

            if padTry.load > activeLoadTol
                pad = padTry;
                usedLocal = true;
                return;
            end
        catch
        end
    end

    % Conservative fallback to the original validated global branch scan.
    pad = solvePadTiltEquilibriumLine( ...
        bearing,padIndex,ex,ey,options);
end


function pad = solvePadTiltEquilibriumLine(bearing,padIndex,ex,ey,options)

    % ---------------------------------------------------------
    % Robust 1-D pad-moment equilibrium on the PHYSICALLY LOADED branch.
    %
    % Important:
    % M_pivot = 0 also has a trivial solution whenever P = 0 everywhere.
    % V0.3 incorrectly accepted that zero-pressure state as an equilibrium.
    % V0.3A therefore searches for M=0 only on states carrying a
    % meaningful hydrodynamic load.  An unloaded pad is accepted only if
    % no loaded equilibrium branch exists.
    % ---------------------------------------------------------

    amax = options.padTiltScanMax;
    avec = linspace(-amax,amax,options.padTiltScanPts);

    valid = false(size(avec));
    loaded = false(size(avec));
    M = nan(size(avec));
    Ld = nan(size(avec));
    padScan = cell(size(avec));

    % For strict equilibrium we must distinguish a genuinely
    % load-carrying pad from a weak pad that has no physical M=0 loaded
    % branch.  Use the same threshold as the global active-pad logic.
    %
    % A weak pad must NOT be accepted merely because its moment is
    % "small enough"; that created a discontinuous pad state and prevented
    % the outer journal force residual from converging below ~1e-3.
    activeLoadTol = options.activePadLoadFraction*bearing.W;

    for k = 1:numel(avec)
        try
            pk = solveSingleTPJBPad(bearing,padIndex,ex,ey,avec(k),0);

            if pk.hmin > 0
                valid(k) = true;
                M(k) = pk.moment;
                Ld(k) = pk.load;
                padScan{k} = pk;

                loaded(k) = pk.load > activeLoadTol;

            end
        catch
            % invalid film geometry
        end
    end

    if ~any(valid)
        error('No valid positive-film tilt found for pad %d.',padIndex);
    end

    % ---------------------------------------------------------
    % 1) First search for a NONTRIVIAL loaded M=0 root.
    % ---------------------------------------------------------
    brackets = [];

    for k = 1:numel(avec)-1

        if valid(k) && valid(k+1) && loaded(k) && loaded(k+1)

            if abs(M(k))/(bearing.W*bearing.Rj) < options.padMomentTol
                pad = padScan{k};
                return;
            end

            if M(k)*M(k+1) < 0
                brackets(end+1,:) = [k k+1]; %#ok<AGROW>
            end
        end
    end

    if ~isempty(brackets)

        % If multiple loaded roots exist, prefer the root carrying the
        % largest mean pad load. This rejects a near-cavitation/trivial root.
        meanLoads = zeros(size(brackets,1),1);

        for ib = 1:size(brackets,1)
            meanLoads(ib) = 0.5*( ...
                Ld(brackets(ib,1)) + Ld(brackets(ib,2)));
        end

        [~,ibest] = max(meanLoads);

        ia = brackets(ibest,1);
        ib = brackets(ibest,2);

        alo = avec(ia);
        ahi = avec(ib);

        plo = padScan{ia};
        phi = padScan{ib};

        Mlo = plo.moment;
        Mhi = phi.moment;

        % Loaded-branch bisection.
        for it = 1:80

            amid = 0.5*(alo+ahi);
            pmid = solveSingleTPJBPad( ...
                bearing,padIndex,ex,ey,amid,0);

            Mmid = pmid.moment;
            Mnorm = abs(Mmid)/(bearing.W*bearing.Rj);

            if pmid.load > activeLoadTol && Mnorm < options.padMomentTol
                pad = pmid;
                return;
            end

            % Standard sign bracket. Both original bracket endpoints are
            % pressure-carrying, so the physical root is retained.
            if Mlo*Mmid <= 0
                ahi = amid;
                Mhi = Mmid; %#ok<NASGU>
            else
                alo = amid;
                Mlo = Mmid;
            end
        end

        pad = solveSingleTPJBPad( ...
            bearing,padIndex,ex,ey,0.5*(alo+ahi),0);

        if pad.load > activeLoadTol
            return;
        end
    end

    % ---------------------------------------------------------
    % 2) No loaded M=0 root exists -> the pad is hydrodynamically idle.
    %
    % For a massless free pad, a weak nonzero-load state with nonzero
    % pivot moment is NOT an equilibrium.  The pad continues to rotate
    % until it reaches a pressure-free / minimum-load branch.
    %
    % Choose the minimum-load valid scan state.  If several points have
    % essentially the same minimum load, prefer the one nearest zero tilt.
    % ---------------------------------------------------------
    validIdx = find(valid);

    if ~isempty(validIdx)

        validLoads = Ld(validIdx);
        minLoad = min(validLoads);

        % Treat loads within a very small absolute/numerical band of the
        % minimum as equivalent, then choose the least arbitrary tilt.
        loadBand = max(1e-8*bearing.W,1e-6);
        nearMin = validIdx(validLoads <= minLoad + loadBand);

        [~,jj] = min(abs(avec(nearMin)));
        pad = padScan{nearMin(jj)};

        if pad.load <= activeLoadTol
            return;
        end
    end

    % If every valid state still carries meaningful load, then a physical
    % loaded equilibrium should have existed.  Do not hide that failure.
    error(['Could not find a physical pad-moment equilibrium for pad %d. ', ...
           'No active loaded M=0 root was bracketed and no idle branch ', ...
           'below the active-pad threshold was found.'],padIndex);
end



function [pad,usedLocal] = solvePadTiltEquilibriumSphericalWarmV14( ...
    bearing,padIndex,ex,ey,options,alphaGuess)

    usedLocal = false;

    try
        [pline,usedLineLocal] = solvePadTiltEquilibriumLineWarm( ...
            bearing,padIndex,ex,ey,options,alphaGuess);

        loadTol = options.activePadLoadFraction*bearing.W;

        if pline.load <= loadTol
            pad = solveSingleTPJBPad( ...
                bearing,padIndex,ex,ey,pline.alpha,0);
            usedLocal = usedLineLocal;
            return;
        end

        x = [pline.alpha; 0];
        scaleM = bearing.W*bearing.Rj;

        for it = 1:options.pointPivotMaxIter

            p = solveSingleTPJBPad( ...
                bearing,padIndex,ex,ey,x(1),x(2));

            r = [p.momentCirc; p.momentAxial]/scaleM;

            if norm(r,inf) < options.pointPivotMomentTol
                pad = p;
                usedLocal = true;
                return;
            end

            J = zeros(2,2);

            for j = 1:2
                dx = zeros(2,1);
                dx(j) = options.fdPadTilt2D;

                pp = solveSingleTPJBPad( ...
                    bearing,padIndex,ex,ey,x(1)+dx(1),x(2)+dx(2));

                pm = solveSingleTPJBPad( ...
                    bearing,padIndex,ex,ey,x(1)-dx(1),x(2)-dx(2));

                rp = [pp.momentCirc; pp.momentAxial]/scaleM;
                rm = [pm.momentCirc; pm.momentAxial]/scaleM;

                J(:,j) = (rp-rm)/(2*options.fdPadTilt2D);
            end

            if rcond(J) < 1e-12
                delta = -pinv(J)*r;
            else
                delta = -J\r;
            end

            delta = max(min(delta,2e-3),-2e-3);

            lambda = 1;
            accepted = false;

            while lambda >= 1/128
                xt = x + lambda*delta;

                try
                    pt = solveSingleTPJBPad( ...
                        bearing,padIndex,ex,ey,xt(1),xt(2));

                    rt = [pt.momentCirc; pt.momentAxial]/scaleM;

                    if pt.hmin > 0 && pt.load > loadTol && ...
                            norm(rt,inf) < norm(r,inf)
                        x = xt;
                        accepted = true;
                        break;
                    end
                catch
                end

                lambda = lambda/2;
            end

            if ~accepted
                break;
            end
        end

        p = solveSingleTPJBPad( ...
            bearing,padIndex,ex,ey,x(1),x(2));

        if p.load > loadTol && ...
                max(abs([p.momentCirc p.momentAxial]))/scaleM < 1e-5
            pad = p;
            usedLocal = true;
            return;
        end

    catch
    end

    pad = solvePadTiltEquilibriumSpherical( ...
        bearing,padIndex,ex,ey,options);
end


function pad = solvePadTiltEquilibriumSpherical(bearing,padIndex,ex,ey,options)

    % ---------------------------------------------------------
    % Spherical / point pivot:
    %   alpha = circumferential rocking tilt
    %   beta  = axial tilt
    %
    % Start from the physical loaded line-pivot solution so we do not
    % converge to the trivial P=0 branch. Then solve the two free moments:
    %   M_circ  = 0
    %   M_axial = 0
    % ---------------------------------------------------------

    p0 = solvePadTiltEquilibriumLine(bearing,padIndex,ex,ey,options);

    % A genuinely unloaded pad is allowed to remain unloaded.
    loadTol = options.activePadLoadFraction*bearing.W;
    if p0.load <= loadTol
        pad = solveSingleTPJBPad( ...
            bearing,padIndex,ex,ey,p0.alpha,0);
        return;
    end

    x = [p0.alpha; 0];  % [alpha; beta]

    scaleM = bearing.W*bearing.Rj;

    for it = 1:options.pointPivotMaxIter

        p = solveSingleTPJBPad( ...
            bearing,padIndex,ex,ey,x(1),x(2));

        r = [p.momentCirc; p.momentAxial]/scaleM;

        if norm(r,inf) < options.pointPivotMomentTol
            pad = p;
            return;
        end

        J = zeros(2,2);

        for j = 1:2
            dx = zeros(2,1);
            dx(j) = options.fdPadTilt2D;

            pp = solveSingleTPJBPad( ...
                bearing,padIndex,ex,ey,x(1)+dx(1),x(2)+dx(2));

            pm = solveSingleTPJBPad( ...
                bearing,padIndex,ex,ey,x(1)-dx(1),x(2)-dx(2));

            rp = [pp.momentCirc; pp.momentAxial]/scaleM;
            rm = [pm.momentCirc; pm.momentAxial]/scaleM;

            J(:,j) = (rp-rm)/(2*options.fdPadTilt2D);
        end

        if rcond(J) < 1e-12
            delta = -pinv(J)*r;
        else
            delta = -J\r;
        end

        % Avoid nonphysical large angle jumps.
        delta = max(min(delta,2e-3),-2e-3);

        lambda = 1;
        accepted = false;

        while lambda >= 1/128
            xt = x + lambda*delta;

            try
                pt = solveSingleTPJBPad( ...
                    bearing,padIndex,ex,ey,xt(1),xt(2));

                rt = [pt.momentCirc; pt.momentAxial]/scaleM;

                if pt.hmin > 0 && pt.load > loadTol && ...
                        norm(rt,inf) < norm(r,inf)
                    x = xt;
                    accepted = true;
                    break;
                end
            catch
            end

            lambda = lambda/2;
        end

        if ~accepted
            break;
        end
    end

    pad = solveSingleTPJBPad( ...
        bearing,padIndex,ex,ey,x(1),x(2));

    if pad.load > loadTol && ...
            max(abs([pad.momentCirc pad.momentAxial]))/scaleM < 1e-5
        return;
    end

    error(['Spherical-pivot two-moment equilibrium did not converge for ', ...
           'pad %d.'],padIndex);
end


function [res,state] = tpjbResidualLegacy(bearing,u)

    n = bearing.nPads;

    qx = u(1);
    qy = u(2);

    ex = qx*bearing.Cb;
    ey = qy*bearing.Cb;

    alphas = u(3:end);

    Fx = 0;
    Fy = 0;

    moments = zeros(n,1);

    globalHmin = inf;
    globalPmax = 0;

    % Initialize from the first solved pad. MATLAB does not allow assigning
    % a populated struct into a preallocated fieldless struct array.
    padState = [];

    for i = 1:n

        pad = solveSingleTPJBPad( ...
            bearing,i,ex,ey,alphas(i),0);

        Fx = Fx + pad.Fx;
        Fy = Fy + pad.Fy;

        moments(i) = pad.moment;

        globalHmin = min(globalHmin,pad.hmin);
        globalPmax = max(globalPmax,pad.Pmax);

        if i == 1
            padState = repmat(pad,n,1);
        else
            padState(i) = pad;
        end
    end

    % Required fluid reaction = [0,+W]
    res = zeros(2+n,1);
    res(1) = Fx;
    res(2) = Fy-bearing.W;
    res(3:end) = moments;

    epsilon = hypot(qx,qy);
    centerAngleDeg = mod(atan2d(ey,ex),360);

    % Load direction is 270 deg. Report shortest geometric angle from it.
    attitudeDeg = abs(rad2deg(tpjbWrapToPiLocal( ...
        deg2rad(centerAngleDeg-270))));

    loads = arrayfun(@(p)p.load,padState);
    [maxPivotLoad,loadedPad] = max(loads);
    powers = arrayfun(@(p)p.power,padState);
    pivotFilms = arrayfun(@(p)p.hPivot,padState);

    state.qx = qx;
    state.qy = qy;
    state.ex = ex;
    state.ey = ey;
    state.epsilon = epsilon;
    state.centerAngleDeg = centerAngleDeg;
    state.attitudeDeg = attitudeDeg;

    state.Fx = Fx;
    state.Fy = Fy;
    state.moments = moments;

    state.forceResidual = hypot(Fx/bearing.W,(Fy-bearing.W)/bearing.W);

    state.pad = padState;
    state.hmin = globalHmin;
    state.minPivotFilm = min(pivotFilms);
    state.Pmax = globalPmax;
    state.maxPivotLoad = maxPivotLoad;
    state.power = sum(powers);
    state.loadedPad = loadedPad;
end


function pad = solveSingleTPJBPad(bearing,padIndex,ex,ey,alpha,beta,varargin)

    % Optional dynamic arguments: vx, vy, alphaDot, betaDot
    vx = 0; vy = 0; alphaDot = 0; betaDot = 0;
    if numel(varargin) >= 1, vx = varargin{1}; end
    if numel(varargin) >= 2, vy = varargin{2}; end
    if numel(varargin) >= 3, alphaDot = varargin{3}; end
    if numel(varargin) >= 4, betaDot = varargin{4}; end

    pd = bearing.pad(padIndex);

    theta = linspace(pd.theta1,pd.theta2,bearing.NthetaPad).';
    z = linspace(-bearing.L/2,bearing.L/2,bearing.Nz);

    dtheta = theta(2)-theta(1);
    dz = z(2)-z(1);

    tp = pd.thetaPivot;

    % ---------------------------------------------------------
    % TPJB film thickness
    % ---------------------------------------------------------
    % Pad-specific preload geometry:
    %   m_i = 1 - Cb_i/Cp
    %   Cb_i = local pivot/assembled clearance of pad i.
    %
    % The journal-center coordinates remain referenced to the original
    % baseline assembled clearance bearing.Cb, while each pad can be
    % radially repositioned through its own CbPivot.
    CbPad = pd.CbPivot;

    h = ...
        bearing.Cp ...
        - ex*cos(theta) ...
        - ey*sin(theta) ...
        - (bearing.Cp-CbPad)*cos(theta-tp) ...
        - bearing.Rj*alpha*sin(theta-tp);

    dhdtheta = ...
          ex*sin(theta) ...
        - ey*cos(theta) ...
        + (bearing.Cp-CbPad)*sin(theta-tp) ...
        - bearing.Rj*alpha*cos(theta-tp);

    if min(h) <= 0
        error('Non-positive TPJB film thickness on pad %d.',padIndex);
    end

    % Axial tilt for a spherical / point pivot.
    % Pivot is assumed at the axial center z=0.
    % Small-angle term beta*z changes the radial film thickness linearly
    % across the pad width. For a line pivot beta=0.
    H = repmat(h,1,bearing.Nz) + beta*repmat(z,numel(theta),1);
    dHdtheta = repmat(dhdtheta,1,bearing.Nz);

    if min(H(:)) <= 0
        error('Non-positive TPJB 2-D film thickness on pad %d.',padIndex);
    end

    % Squeeze-film velocity term.
    Z = repmat(z,numel(theta),1);
    dhdt1D = ...
        -vx*cos(theta) ...
        -vy*sin(theta) ...
        -bearing.Rj*alphaDot*sin(theta-tp);

    dHdt = repmat(dhdt1D,1,bearing.Nz) + betaDot*Z;

    P = solvePadReynolds( ...
        H,dHdtheta,dHdt,bearing.Rj,bearing.mu,bearing.omega, ...
        dtheta,dz);

    % ---------------------------------------------------------
    % Pressure force on JOURNAL
    % ---------------------------------------------------------
    dA = bearing.Rj*dtheta*dz;

    TH = repmat(theta,1,bearing.Nz);

    FxDensity = -P.*cos(TH);
    FyDensity = -P.*sin(TH);

    Fx = sum(FxDensity(:))*dA;
    Fy = sum(FyDensity(:))*dA;

    % ---------------------------------------------------------
    % Pad moments about the pivot.
    %
    % momentCirc:
    %   rocking/circumferential tilt moment. This is the free moment for
    %   BOTH line and spherical pivots.
    %
    % momentAxial:
    %   axial-tilt moment generated by pressure centroid offset along z.
    %   It is a reaction moment for a LINE pivot, but must be zero for a
    %   SPHERICAL / POINT pivot.
    % ---------------------------------------------------------
    momentCircDensity = P.*sin(TH-tp);
    momentCirc = sum(momentCircDensity(:))*bearing.Rj*dA;

    Z = repmat(z,numel(theta),1);
    momentAxialDensity = P.*Z;
    momentAxial = sum(momentAxialDensity(:))*dA;

    pad.index = padIndex;
    pad.preload = pd.preload;
    pad.CbPivot = pd.CbPivot;
    pad.alpha = alpha;
    pad.beta = beta;
    pad.theta = theta;
    pad.thetaDeg = mod(rad2deg(theta),360);
    pad.z = z;
    pad.h = h;
    pad.P = P;

    % Film thickness at pivot
    hPivot = ...
        bearing.Cp ...
        - ex*cos(tp) ...
        - ey*sin(tp) ...
        - (bearing.Cp-CbPad) ...
        - bearing.Rj*alpha*sin(0);   % z=0, so axial tilt contributes zero

    % Journal-surface tangential shear, laminar Couette + Poiseuille.
    % tau_j = mu*U/h + h/(2R)*dP/dtheta
    U = bearing.omega*bearing.Rj;
    dPdtheta = zeros(size(P));
    dPdtheta(2:end-1,:) = (P(3:end,:)-P(1:end-2,:))/(2*dtheta);
    dPdtheta(1,:) = (P(2,:)-P(1,:))/dtheta;
    dPdtheta(end,:) = (P(end,:)-P(end-1,:))/dtheta;

    Tau = bearing.mu*U./H + H./(2*bearing.Rj).*dPdtheta;

    % ---------------------------------------------------------
    % Friction / power integration
    %
    % IMPORTANT:
    % Pressure-force integration can use a simple rectangular sum here
    % because P = 0 on all pad boundaries. Wall shear Tau, however, is
    % NONZERO at circumferential and axial boundaries.
    %
    % The old sum(Tau(:))*R*dtheta*dz counted both end nodes with full
    % weights. With NthetaPad=61 and Nz=31 the resulting geometric bias is:
    %
    %   (61/60)*(31/30) = 1.05056
    %
    % i.e. about +5.06 percent -- exactly the nearly constant power bias
    % observed against Practical Rotordynamics Table 3.9-1.
    %
    % Use 2-D trapezoidal quadrature for wall shear / friction power.
    % ---------------------------------------------------------
    tauThetaInt = trapz(theta,Tau,1);     % integrate in theta
    tauAreaInt  = trapz(z,tauThetaInt);   % integrate in z

    frictionForce = bearing.Rj*tauAreaInt;
    frictionTorque = bearing.Rj*frictionForce;
    power = frictionTorque*bearing.omega;

    pad.Fx = Fx;
    pad.Fy = Fy;
    pad.load = hypot(Fx,Fy);
    pad.moment = momentCirc;          % legacy alias
    pad.momentCirc = momentCirc;
    pad.momentAxial = momentAxial;

    if strcmpi(bearing.pivotType,'Line')
        pad.momentAxialFree = 0;      % not a free DOF; pivot reacts this moment
    else
        pad.momentAxialFree = momentAxial;
    end

    pad.hmin = min(H(:));
    pad.hPivot = hPivot;
    pad.Pmax = max(P(:));
    pad.frictionForce = frictionForce;
    pad.frictionTorque = frictionTorque;
    pad.power = power;
end


function P = solvePadReynolds(H,dHdtheta,dHdt,R,mu,omega,dtheta,dz)

    [Nt,Nz] = size(H);

    % Unknowns only at interior nodes.
    map = zeros(Nt,Nz);
    count = 0;

    for i = 2:Nt-1
        for j = 2:Nz-1
            count = count+1;
            map(i,j) = count;
        end
    end

    I = zeros(5*count,1);
    J = zeros(5*count,1);
    V = zeros(5*count,1);
    b = zeros(count,1);

    nzCount = 0;

    a = H.^3;

    for i = 2:Nt-1
        for j = 2:Nz-1

            row = map(i,j);

            ae = 0.5*(a(i,j)+a(i+1,j))/dtheta^2;
            aw = 0.5*(a(i,j)+a(i-1,j))/dtheta^2;

            an = R^2*0.5*(a(i,j)+a(i,j+1))/dz^2;
            as = R^2*0.5*(a(i,j)+a(i,j-1))/dz^2;

            ap = ae+aw+an+as;

            % We assemble -L(P) = -RHS so diagonal is positive.
            nzCount=nzCount+1; I(nzCount)=row; J(nzCount)=row; V(nzCount)=ap;

            if i+1 <= Nt-1
                nzCount=nzCount+1;
                I(nzCount)=row; J(nzCount)=map(i+1,j); V(nzCount)=-ae;
            end

            if i-1 >= 2
                nzCount=nzCount+1;
                I(nzCount)=row; J(nzCount)=map(i-1,j); V(nzCount)=-aw;
            end

            if j+1 <= Nz-1
                nzCount=nzCount+1;
                I(nzCount)=row; J(nzCount)=map(i,j+1); V(nzCount)=-an;
            end

            if j-1 >= 2
                nzCount=nzCount+1;
                I(nzCount)=row; J(nzCount)=map(i,j-1); V(nzCount)=-as;
            end

            rhs = 6*mu*omega*R^2*dHdtheta(i,j) + ...
                  12*mu*R^2*dHdt(i,j);
            b(row) = -rhs;
        end
    end

    A = sparse(I(1:nzCount),J(1:nzCount),V(1:nzCount),count,count);

    % Reynolds cavitation: active-set P>=0.
    active = true(count,1);
    pvec = zeros(count,1);

    for k = 1:40

        idx = find(active);

        if isempty(idx)
            break;
        end

        pnew = zeros(count,1);
        pnew(idx) = A(idx,idx)\b(idx);

        bad = pnew < 0;

        if ~any(bad & active)
            pvec = max(pnew,0);
            break;
        end

        active(bad) = false;
        pvec = max(pnew,0);
    end

    P = zeros(Nt,Nz);

    for i = 2:Nt-1
        for j = 2:Nz-1
            P(i,j) = pvec(map(i,j));
        end
    end
end




function dyn = computeTPJBGeneralizedKC(bearing,eq,options)

    pivotIsLine = strcmpi(bearing.pivotType,'Line');
    pivotIsSpherical = strcmpi(bearing.pivotType,'Spherical') || ...
                       strcmpi(bearing.pivotType,'Point');

    if ~(pivotIsLine || pivotIsSpherical)
        error('Unsupported TPJB pivot type for dynamic K/C.');
    end

    loads = arrayfun(@(p)p.load,eq.pad);
    activePads = find(loads > options.activePadLoadFraction*bearing.W);

    if isempty(activePads)
        error('No load-carrying pads available for dynamic condensation.');
    end

    nA = numel(activePads);

    if pivotIsLine
        dofPerPad = 1;
        nG = 2 + nA;
        dynDofLabel = 'alpha';
    else
        dofPerPad = 2;
        nG = 2 + 2*nA;
        dynDofLabel = 'alpha+beta';
    end

    Kg = zeros(nG,nG);
    Cg = zeros(nG,nG);

    tCache = tic;
    padCache = cell(1,bearing.nPads);

    for ip = 1:bearing.nPads
        padCache{ip} = prepareTPJBDynamicPadCache( ...
            bearing,eq.pad(ip),options);
    end

    timingCache_s = toc(tCache);
    tSensitivity = tic;

    for col = 1:nG

        dFdisp = [0;0];
        dFvel  = [0;0];

        if pivotIsLine
            dMdisp = zeros(nA,1);
            dMvel  = zeros(nA,1);
        else
            dMdisp = zeros(2*nA,1);
            dMvel  = zeros(2*nA,1);
        end

        for ip = 1:bearing.nPads

            p0 = eq.pad(ip);

            [Hq,dHqdtheta,isRelevant] = ...
                tpjbGeneralizedFilmDerivativeV14( ...
                    bearing,p0,ip,activePads,col,pivotIsLine);

            if ~isRelevant
                continue;
            end

            [Pq,Pv] = solvePadPerturbedReynoldsCached( ...
                bearing,p0,Hq,dHqdtheta,padCache{ip});

            [dFx_q,dFy_q,dMc_q,dMa_q] = ...
                integratePadPressureSensitivityV14(bearing,p0,Pq);

            [dFx_v,dFy_v,dMc_v,dMa_v] = ...
                integratePadPressureSensitivityV14(bearing,p0,Pv);

            dFdisp = dFdisp + [dFx_q;dFy_q];
            dFvel  = dFvel  + [dFx_v;dFy_v];

            rowPad = find(activePads == ip,1);

            if ~isempty(rowPad)
                if pivotIsLine
                    dMdisp(rowPad) = dMc_q;
                    dMvel(rowPad)  = dMc_v;
                else
                    rCirc = 2*rowPad - 1;
                    rAx   = 2*rowPad;
                    dMdisp(rCirc) = dMc_q;
                    dMdisp(rAx)   = dMa_q;
                    dMvel(rCirc)  = dMc_v;
                    dMvel(rAx)    = dMa_v;
                end
            end
        end

        Kg(:,col) = -[dFdisp;dMdisp];
        Cg(:,col) = -[dFvel;dMvel];
    end

    timingSensitivity_s = toc(tSensitivity);

    Kjj = Kg(1:2,1:2);
    Kjp = Kg(1:2,3:end);
    Kpj = Kg(3:end,1:2);
    Kpp = Kg(3:end,3:end);

    Cjj = Cg(1:2,1:2);
    Cjp = Cg(1:2,3:end);
    Cpj = Cg(3:end,1:2);
    Cpp = Cg(3:end,3:end);

    if rcond(Kpp) < 1e-12
        Apad = -pinv(Kpp)*Kpj;
        Bpad = -pinv(Kpp)*(Cpj + Cpp*Apad);
    else
        Apad = -(Kpp\Kpj);
        Bpad = -(Kpp\(Cpj + Cpp*Apad));
    end

    KpadRelax = Kjp*Apad;
    CpadVel   = Kjp*Bpad;
    CpadDisp  = Cjp*Apad;

    Keq = Kjj + KpadRelax;
    Ceq = Cjj + CpadVel + CpadDisp;

    if rcond(Cpp) < 1e-12
        CeqSeparated = Cjj - Cjp*(pinv(Cpp)*Cpj);
    else
        CeqSeparated = Cjj - Cjp*(Cpp\Cpj);
    end

    dyn.method = 'DirectPerturbedReynoldsCached';
    dyn.pivotType = bearing.pivotType;
    dyn.padDynamicDOF = dynDofLabel;
    dyn.dofPerActivePad = dofPerPad;
    dyn.activePads = activePads(:).';

    dyn.Kgeneral = Kg;
    dyn.Cgeneral = Cg;

    dyn.Kjj = Kjj;
    dyn.Kja = Kjp;
    dyn.Kaj = Kpj;
    dyn.Kaa = Kpp;

    dyn.Cjj = Cjj;
    dyn.Cja = Cjp;
    dyn.Caj = Cpj;
    dyn.Caa = Cpp;

    dyn.K = Keq;
    dyn.C = Ceq;

    dyn.KdirectJournal = Kjj;
    dyn.KpadRelax = KpadRelax;
    dyn.CdirectJournal = Cjj;
    dyn.CpadVelocity = CpadVel;
    dyn.CpadDisplacement = CpadDisp;

    dyn.Aalpha = Apad;
    dyn.Balpha = Bpad;
    dyn.Apad = Apad;
    dyn.Bpad = Bpad;
    dyn.CseparatedLegacy = CeqSeparated;

    dyn.rcondKaa = rcond(Kpp);
    dyn.rcondCaa = rcond(Cpp);

    kden = sqrt(max(abs(Keq(1,1)*Keq(2,2)),eps));
    cden = sqrt(max(abs(Ceq(1,1)*Ceq(2,2)),eps));

    dyn.crossRatioK = max(abs([Keq(1,2) Keq(2,1)]))/kden;
    dyn.crossRatioC = max(abs([Ceq(1,2) Ceq(2,1)]))/cden;

    dyn.timing.cacheBuild_s = timingCache_s;
    dyn.timing.sensitivity_s = timingSensitivity_s;
end


function [Hq,dHqdtheta,isRelevant] = ...
    tpjbGeneralizedFilmDerivativeV14( ...
        bearing,pad,ip,activePads,col,pivotIsLine)

    theta = pad.theta;
    z = pad.z;

    Hq = zeros(numel(theta),numel(z));
    dHqdtheta = zeros(numel(theta),numel(z));
    isRelevant = true;

    if col == 1
        Hq1D = -cos(theta);
        dHq1D = sin(theta);
        Hq = repmat(Hq1D,1,numel(z));
        dHqdtheta = repmat(dHq1D,1,numel(z));

    elseif col == 2
        Hq1D = -sin(theta);
        dHq1D = -cos(theta);
        Hq = repmat(Hq1D,1,numel(z));
        dHqdtheta = repmat(dHq1D,1,numel(z));

    elseif pivotIsLine
        k = col-2;
        targetPad = activePads(k);

        if ip ~= targetPad
            isRelevant = false;
            return;
        end

        tp = bearing.pad(ip).thetaPivot;
        Hq1D = -bearing.Rj*sin(theta-tp);
        dHq1D = -bearing.Rj*cos(theta-tp);
        Hq = repmat(Hq1D,1,numel(z));
        dHqdtheta = repmat(dHq1D,1,numel(z));

    else
        localCol = col - 2;
        k = ceil(localCol/2);
        dofType = mod(localCol-1,2) + 1; % 1=alpha, 2=beta
        targetPad = activePads(k);

        if ip ~= targetPad
            isRelevant = false;
            return;
        end

        if dofType == 1
            tp = bearing.pad(ip).thetaPivot;
            Hq1D = -bearing.Rj*sin(theta-tp);
            dHq1D = -bearing.Rj*cos(theta-tp);
            Hq = repmat(Hq1D,1,numel(z));
            dHqdtheta = repmat(dHq1D,1,numel(z));
        else
            % Axial tilt: H = H0 + beta*z
            Hq = repmat(z,numel(theta),1);
            dHqdtheta = zeros(size(Hq));
        end
    end
end


function [dFx,dFy,dMc,dMa] = ...
    integratePadPressureSensitivityV14(bearing,pad,Ps)

    theta = pad.theta;
    z = pad.z;

    dtheta = theta(2)-theta(1);
    dz = z(2)-z(1);

    TH = repmat(theta,1,numel(z));
    Z  = repmat(z,numel(theta),1);
    dA = bearing.Rj*dtheta*dz;

    dFx = sum((-Ps.*cos(TH)),'all')*dA;
    dFy = sum((-Ps.*sin(TH)),'all')*dA;

    tp = bearing.pad(pad.index).thetaPivot;
    dMc = sum((Ps.*sin(TH-tp)),'all')*bearing.Rj*dA;
    dMa = sum((Ps.*Z),'all')*dA;
end


function [Hq,dHqdtheta,isRelevant] = ...
    tpjbGeneralizedFilmDerivative(bearing,pad,ip,activePads,col)

    theta = pad.theta;
    z = pad.z;

    Hq1D = zeros(size(theta));
    dHq1D = zeros(size(theta));
    isRelevant = true;

    if col == 1
        % Journal X displacement
        Hq1D = -cos(theta);
        dHq1D = sin(theta);

    elseif col == 2
        % Journal Y displacement
        Hq1D = -sin(theta);
        dHq1D = -cos(theta);

    else
        % Pad rotational coordinate alpha_k.
        k = col-2;
        targetPad = activePads(k);

        if ip ~= targetPad
            isRelevant = false;
        else
            tp = bearing.pad(ip).thetaPivot;
            Hq1D = -bearing.Rj*sin(theta-tp);
            dHq1D = -bearing.Rj*cos(theta-tp);
        end
    end

    Hq = repmat(Hq1D,1,numel(z));
    dHqdtheta = repmat(dHq1D,1,numel(z));
end


function cache = prepareTPJBDynamicPadCache( ...
    bearing,pad,options)

    theta = pad.theta;
    z = pad.z;

    dtheta = theta(2)-theta(1);
    dz = z(2)-z(1);

    H0 = repmat(pad.h,1,numel(z)) + ...
         pad.beta*repmat(z,numel(theta),1);

    P0 = pad.P;

    [A,map,count] = buildPadReynoldsOperator( ...
        H0,bearing.Rj,dtheta,dz);

    % Positive-pressure active region from the converged steady solution.
    pmax0 = max(P0(:));
    pTol = max(options.perturbedPressureActiveTol*pmax0,0);

    interiorMap = map(2:end-1,2:end-1);
    Pint = P0(2:end-1,2:end-1);

    p0vec = zeros(count,1);
    p0vec(interiorMap(:)) = Pint(:);

    active = false(count,1);
    active(interiorMap(:)) = Pint(:) > pTol;
    ids = find(active);

    cache.H0 = H0;
    cache.map = map;
    cache.count = count;
    cache.ids = ids;
    cache.p0vec = p0vec;
    cache.interiorMap = interiorMap;
    cache.dtheta = dtheta;
    cache.dz = dz;
    cache.empty = isempty(ids);

    if cache.empty
        cache.Aactive = sparse(0,0);
        cache.linearSolver = [];
        cache.useDecomposition = false;
        return;
    end

    Aactive = A(ids,ids);
    cache.Aactive = Aactive;

    % Reuse one factorization for every displacement/velocity RHS on this
    % pad. decomposition is available in MATLAB R2021a; fallback retains
    % the exact sparse backslash solve if needed.
    try
        cache.linearSolver = decomposition(Aactive,'lu');
        cache.useDecomposition = true;
    catch
        cache.linearSolver = [];
        cache.useDecomposition = false;
    end
end


function [Pq,Pv] = solvePadPerturbedReynoldsCached( ...
    bearing,pad,Hq,dHqdtheta,cache)

    Pq = zeros(size(pad.P));
    Pv = zeros(size(pad.P));

    if cache.empty
        return;
    end

    H0 = cache.H0;
    map = cache.map;
    count = cache.count;
    ids = cache.ids;
    p0vec = cache.p0vec;
    interiorMap = cache.interiorMap;
    dtheta = cache.dtheta;
    dz = cache.dz;

    % ---------------------------------------------------------
    % Displacement derivative:
    % A_q comes from d(H^3)/dq = 3*H^2*Hq.
    % ---------------------------------------------------------
    a_q = 3*H0.^2.*Hq;

    Aq = buildPadReynoldsCoefficientDerivative( ...
        a_q,bearing.Rj,dtheta,dz,map,count);

    % Vectorized RHS assembly over interior nodes.
    bq = zeros(count,1);
    rhsQ = -6*bearing.mu*bearing.omega*bearing.Rj^2 * ...
           dHqdtheta(2:end-1,2:end-1);
    bq(interiorMap(:)) = rhsQ(:);

    rhsDisp = bq(ids) - Aq(ids,ids)*p0vec(ids);

    % ---------------------------------------------------------
    % Velocity derivative:
    % For unit generalized velocity, dH/dt = Hq.
    % ---------------------------------------------------------
    bv = zeros(count,1);
    rhsV = -12*bearing.mu*bearing.Rj^2 * ...
           Hq(2:end-1,2:end-1);
    bv(interiorMap(:)) = rhsV(:);

    if cache.useDecomposition
        pqActive = cache.linearSolver\rhsDisp;
        pvActive = cache.linearSolver\bv(ids);
    else
        pqActive = cache.Aactive\rhsDisp;
        pvActive = cache.Aactive\bv(ids);
    end

    pq = zeros(count,1);
    pv = zeros(count,1);
    pq(ids) = pqActive;
    pv(ids) = pvActive;

    % Vectorized map back to pressure-sensitivity fields.
    Pq(2:end-1,2:end-1) = pq(interiorMap);
    Pv(2:end-1,2:end-1) = pv(interiorMap);
end


function [Pq,Pv] = solvePadPerturbedReynolds( ...
    bearing,pad,Hq,dHqdtheta,options)

    theta = pad.theta;
    z = pad.z;

    dtheta = theta(2)-theta(1);
    dz = z(2)-z(1);

    H0 = repmat(pad.h,1,numel(z)) + ...
         pad.beta*repmat(z,numel(theta),1);

    P0 = pad.P;

    [A,map,count] = buildPadReynoldsOperator( ...
        H0,bearing.Rj,dtheta,dz);

    % Positive-pressure active region from the converged steady solution.
    pmax0 = max(P0(:));
    pTol = max(options.perturbedPressureActiveTol*pmax0,0);

    active = false(count,1);
    p0vec = zeros(count,1);

    for i = 2:size(H0,1)-1
        for j = 2:size(H0,2)-1
            id = map(i,j);
            p0vec(id) = P0(i,j);
            active(id) = P0(i,j) > pTol;
        end
    end

    ids = find(active);

    Pq = zeros(size(P0));
    Pv = zeros(size(P0));

    if isempty(ids)
        return;
    end

    % ---------------------------------------------------------
    % Displacement derivative:
    % A_q comes from d(H^3)/dq = 3*H^2*Hq.
    % ---------------------------------------------------------
    a_q = 3*H0.^2.*Hq;

    Aq = buildPadReynoldsCoefficientDerivative( ...
        a_q,bearing.Rj,dtheta,dz,map,count);

    bq = zeros(count,1);

    for i = 2:size(H0,1)-1
        for j = 2:size(H0,2)-1
            row = map(i,j);
            rhs_q = 6*bearing.mu*bearing.omega*bearing.Rj^2 * ...
                    dHqdtheta(i,j);
            bq(row) = -rhs_q;
        end
    end

    rhsDisp = bq(ids) - Aq(ids,ids)*p0vec(ids);
    pq = zeros(count,1);
    pq(ids) = A(ids,ids)\rhsDisp;

    % ---------------------------------------------------------
    % Velocity derivative:
    % Geometry is unchanged; only squeeze term contributes:
    % 12*mu*R^2*dH/dt.
    %
    % For unit generalized velocity, dH/dt = Hq.
    % ---------------------------------------------------------
    bv = zeros(count,1);

    for i = 2:size(H0,1)-1
        for j = 2:size(H0,2)-1
            row = map(i,j);
            rhs_v = 12*bearing.mu*bearing.Rj^2*Hq(i,j);
            bv(row) = -rhs_v;
        end
    end

    pv = zeros(count,1);
    pv(ids) = A(ids,ids)\bv(ids);

    for i = 2:size(H0,1)-1
        for j = 2:size(H0,2)-1
            id = map(i,j);
            Pq(i,j) = pq(id);
            Pv(i,j) = pv(id);
        end
    end
end


function [A,map,count] = buildPadReynoldsOperator(H,R,dtheta,dz)

    [Nt,Nz] = size(H);

    map = zeros(Nt,Nz);
    count = 0;

    for i = 2:Nt-1
        for j = 2:Nz-1
            count = count+1;
            map(i,j) = count;
        end
    end

    I = zeros(5*count,1);
    J = zeros(5*count,1);
    V = zeros(5*count,1);
    nzc = 0;

    a = H.^3;

    for i = 2:Nt-1
        for j = 2:Nz-1

            row = map(i,j);

            ae = 0.5*(a(i,j)+a(i+1,j))/dtheta^2;
            aw = 0.5*(a(i,j)+a(i-1,j))/dtheta^2;

            an = R^2*0.5*(a(i,j)+a(i,j+1))/dz^2;
            as = R^2*0.5*(a(i,j)+a(i,j-1))/dz^2;

            ap = ae+aw+an+as;

            nzc=nzc+1; I(nzc)=row; J(nzc)=row; V(nzc)=ap;

            if i+1 <= Nt-1
                nzc=nzc+1;
                I(nzc)=row; J(nzc)=map(i+1,j); V(nzc)=-ae;
            end
            if i-1 >= 2
                nzc=nzc+1;
                I(nzc)=row; J(nzc)=map(i-1,j); V(nzc)=-aw;
            end
            if j+1 <= Nz-1
                nzc=nzc+1;
                I(nzc)=row; J(nzc)=map(i,j+1); V(nzc)=-an;
            end
            if j-1 >= 2
                nzc=nzc+1;
                I(nzc)=row; J(nzc)=map(i,j-1); V(nzc)=-as;
            end
        end
    end

    A = sparse(I(1:nzc),J(1:nzc),V(1:nzc),count,count);
end


function Aq = buildPadReynoldsCoefficientDerivative( ...
    aq,R,dtheta,dz,map,count)

    [Nt,Nz] = size(aq);

    I = zeros(5*count,1);
    J = zeros(5*count,1);
    V = zeros(5*count,1);
    nzc = 0;

    for i = 2:Nt-1
        for j = 2:Nz-1

            row = map(i,j);

            dae = 0.5*(aq(i,j)+aq(i+1,j))/dtheta^2;
            daw = 0.5*(aq(i,j)+aq(i-1,j))/dtheta^2;

            dan = R^2*0.5*(aq(i,j)+aq(i,j+1))/dz^2;
            das = R^2*0.5*(aq(i,j)+aq(i,j-1))/dz^2;

            dap = dae+daw+dan+das;

            nzc=nzc+1; I(nzc)=row; J(nzc)=row; V(nzc)=dap;

            if i+1 <= Nt-1
                nzc=nzc+1;
                I(nzc)=row; J(nzc)=map(i+1,j); V(nzc)=-dae;
            end
            if i-1 >= 2
                nzc=nzc+1;
                I(nzc)=row; J(nzc)=map(i-1,j); V(nzc)=-daw;
            end
            if j+1 <= Nz-1
                nzc=nzc+1;
                I(nzc)=row; J(nzc)=map(i,j+1); V(nzc)=-dan;
            end
            if j-1 >= 2
                nzc=nzc+1;
                I(nzc)=row; J(nzc)=map(i,j-1); V(nzc)=-das;
            end
        end
    end

    Aq = sparse(I(1:nzc),J(1:nzc),V(1:nzc),count,count);
end


function [dFx,dFy,dMc] = ...
    integratePadPressureSensitivity(bearing,pad,Ps)

    theta = pad.theta;
    z = pad.z;

    dtheta = theta(2)-theta(1);
    dz = z(2)-z(1);

    TH = repmat(theta,1,numel(z));
    dA = bearing.Rj*dtheta*dz;

    dFx = sum((-Ps.*cos(TH)),'all')*dA;
    dFy = sum((-Ps.*sin(TH)),'all')*dA;

    tp = bearing.pad(pad.index).thetaPivot;
    dMc = sum((Ps.*sin(TH-tp)),'all')*bearing.Rj*dA;
end


function x = tpjbWrapToPiLocal(x)
    x = mod(x+pi,2*pi)-pi;
end


function out = tpjbTernary(cond,a,b)
    if cond
        out = a;
    else
        out = b;
    end
end

% - V1.4A: increased pad-tilt drawing amplification and removed dashed reference

% - V1.4B: tilted pads retained as solid filled bodies with reinforced solid edges

% - V1.4C: reduced visual tilt amplification to x20 and explicitly closed both pad ends
