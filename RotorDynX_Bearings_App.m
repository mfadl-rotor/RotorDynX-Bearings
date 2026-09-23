function RotorDynX_Bearings_App
% RotorDynX Bearings
% Graphical front end for the RotorDynX hydrodynamic bearing solver.
%
% The application collects case inputs, runs the solver through a temporary
% working copy, and opens the selected native MATLAB result figures.
%
% Solver equations and numerical methods remain in RotorDynX_Bearings.m.
%
% MATLAB R2021a compatible.
% Public release: 1.0.0

%% ------------------------------------------------------------------------
% Theme
% -------------------------------------------------------------------------
C.navy   = [0.025 0.145 0.275];
C.blue   = [0.000 0.405 0.760];
C.blue2  = [0.060 0.300 0.520];
C.bg     = [0.955 0.965 0.975];
C.panel  = [0.985 0.990 0.997];
C.white  = [1 1 1];
C.border = [0.78 0.82 0.87];
C.text   = [0.08 0.11 0.15];
C.muted  = [0.38 0.44 0.52];
C.green  = [0.05 0.55 0.25];
C.red    = [0.78 0.10 0.10];

%% ------------------------------------------------------------------------
% Main window
% -------------------------------------------------------------------------
fig = uifigure( ...
    'Name','RotorDynX Bearings', ...
    'Color',C.bg, ...
    'Position',[25 35 1580 900], ...
    'Resize','on');

appDir = fileparts(mfilename('fullpath'));
logoPath = fullfile(appDir,'RotorDynX_Logo.png');


root = uigridlayout(fig,[3 1]);
root.RowHeight = {78,'1x',30};
root.Padding = [8 8 8 8];
root.RowSpacing = 7;

%% Header
header = uipanel(root,'BorderType','none','BackgroundColor',C.navy);

hg = uigridlayout(header,[1 9]);
hg.ColumnWidth = {54,310,115,'1x',88,88,88,98,88};
hg.Padding = [14 7 12 7];
hg.ColumnSpacing = 9;
hg.BackgroundColor = C.navy;

% RotorDynX logo
if isfile(logoPath)
    logoImg = uiimage(hg,'ImageSource',logoPath);
    logoImg.Tooltip = 'RotorDynX Bearings';
else
    % Safe fallback if the logo asset is not beside the app file.
    badge = uilabel(hg, ...
        'Text','R', ...
        'HorizontalAlignment','center', ...
        'VerticalAlignment','center', ...
        'FontSize',22, ...
        'FontWeight','bold', ...
        'FontColor','w', ...
        'BackgroundColor',C.blue);
end

% Brand
brand = uilabel(hg, ...
    'Text','RotorDynX  Bearings', ...
    'FontSize',24, ...
    'FontWeight','bold', ...
    'FontColor','w');

% Version badge
ver = uilabel(hg, ...
    'Text','1.0.0', ...
    'HorizontalAlignment','center', ...
    'FontSize',10, ...
    'FontWeight','bold', ...
    'FontColor',[0.82 0.91 1.00], ...
    'BackgroundColor',[0.055 0.205 0.355]);

% Engineering subtitle
subtitle = uilabel(hg, ...
    'Text','Hydrodynamic Bearing Analysis   |   Static   •   Dynamic   •   Thermal', ...
    'HorizontalAlignment','center', ...
    'FontSize',11, ...
    'FontAngle','italic', ...
    'FontColor',[0.82 0.89 0.96]);

% Header actions
uibutton(hg,'Text','New', ...
    'FontWeight','bold', ...
    'BackgroundColor',C.blue, ...
    'FontColor','w', ...
    'ButtonPushedFcn',@newCase);

uibutton(hg,'Text','Open', ...
    'FontWeight','bold', ...
    'BackgroundColor',[0.070 0.255 0.430], ...
    'FontColor','w', ...
    'ButtonPushedFcn',@openCase);

uibutton(hg,'Text','Save', ...
    'FontWeight','bold', ...
    'BackgroundColor',[0.070 0.255 0.430], ...
    'FontColor','w', ...
    'ButtonPushedFcn',@saveCase);

uibutton(hg,'Text','Backend', ...
    'FontWeight','bold', ...
    'BackgroundColor',[0.070 0.255 0.430], ...
    'FontColor','w', ...
    'ButtonPushedFcn',@chooseBackend);

uibutton(hg,'Text','About', ...
    'FontWeight','bold', ...
    'BackgroundColor',[0.070 0.255 0.430], ...
    'FontColor','w', ...
    'ButtonPushedFcn',@showAbout);

%% ------------------------------------------------------------------------
% One-page body: General | Bearing Data | Operating/Oil | Plots
% -------------------------------------------------------------------------
body = uigridlayout(root,[1 4]);
body.ColumnWidth = {325,410,410,'1x'};
body.ColumnSpacing = 8;
body.Padding = [0 0 0 0];

% ========================= 1. GENERAL ====================================
pGeneral = cardPanel(body,'CASE / ANALYSIS');
g1 = uigridlayout(pGeneral,[11 3]);
g1.ColumnWidth = {118,'1x',62};
g1.RowHeight = {30,30,30,8,30,30,30,30,30,'1x',62};
g1.Padding = [12 10 12 10];
g1.RowSpacing = 8;

makeLabel(g1,'Comment',1);
commentField = uieditfield(g1,'text','Value','RotorDynX bearing case');
commentField.Layout.Row=1; commentField.Layout.Column=[2 3];

makeLabel(g1,'Bearing Type',2);
bearingDD = uidropdown(g1, ...
    'Items',{'Plain','FixedLobe','TaperLand','PressureDam','WornBearing','TPJB'}, ...
    'Value','Plain', ...
    'ValueChangedFcn',@bearingChanged);
bearingDD.Layout.Row=2; bearingDD.Layout.Column=[2 3];

makeLabel(g1,'Analysis',3);
analysisDD = uidropdown(g1, ...
    'Items',{'SinglePoint','SpeedSweep'}, ...
    'Value','SinglePoint', ...
    'ValueChangedFcn',@analysisChanged);
analysisDD.Layout.Row=3; analysisDD.Layout.Column=[2 3];

sep1 = uilabel(g1,'Text','OPERATING POINT','FontWeight','bold','FontColor',C.blue2);
sep1.Layout.Row=5; sep1.Layout.Column=[1 3];

makeLabel(g1,'Speed',6);
rpmField = uieditfield(g1,'numeric','Value',3600,'Limits',[1 Inf]);
rpmField.Layout.Row=6; rpmField.Layout.Column=2;
unitLabel(g1,'rpm',6);

makeLabel(g1,'Load',7);
loadField = uieditfield(g1,'numeric','Value',4448.22,'Limits',[0 Inf]);
loadField.Layout.Row=7; loadField.Layout.Column=2;
unitLabel(g1,'N',7);

makeLabel(g1,'Load angle',8);
loadAngleField = uieditfield(g1,'numeric','Value',270);
loadAngleField.Layout.Row=8; loadAngleField.Layout.Column=2;
loadAngleField.Enable='off';
loadAngleField.Tooltip='RotorDynX backend currently uses the fixed -Y load convention.'
unitLabel(g1,'deg',8);

makeLabel(g1,'Units',9);
unitsDD = uidropdown(g1,'Items',{'SI'},'Value','SI');
unitsDD.Layout.Row=9; unitsDD.Layout.Column=[2 3];

runBtn = uibutton(g1, ...
    'Text','▶   RUN ANALYSIS', ...
    'FontSize',16,'FontWeight','bold', ...
    'BackgroundColor',C.blue,'FontColor','w', ...
    'ButtonPushedFcn',@runAnalysis);
runBtn.Layout.Row=11; runBtn.Layout.Column=[1 3];

% ========================= 2. BEARING DATA ================================
pBearing = cardPanel(body,'BEARING DATA');
g2 = uigridlayout(pBearing,[15 3]);
g2.ColumnWidth = {165,'1x',60};
g2.RowHeight = repmat({29},1,15);
g2.Padding = [12 10 12 10];
g2.RowSpacing = 6;

makeLabel(g2,'Axial length, L',1);
LField = uieditfield(g2,'numeric','Value',76.2,'Limits',[0 Inf]);
LField.Layout.Row=1; LField.Layout.Column=2; unitLabel(g2,'mm',1);

makeLabel(g2,'Journal diameter, D',2);
DField = uieditfield(g2,'numeric','Value',127.0,'Limits',[0 Inf]);
DField.Layout.Row=2; DField.Layout.Column=2; unitLabel(g2,'mm',2);

makeLabel(g2,'Radial clearance, Cb',3);
CbField = uieditfield(g2,'numeric','Value',0.127,'Limits',[0 Inf]);
CbField.Layout.Row=3; CbField.Layout.Column=2; unitLabel(g2,'mm',3);

makeLabel(g2,'Number of pads/lobes',4);
nPadsField = uieditfield(g2,'numeric','Value',2,'Limits',[1 12]);
nPadsField.Layout.Row=4; nPadsField.Layout.Column=2; unitLabel(g2,'-',4);

makeLabel(g2,'Leading edge',5);
leadField = uieditfield(g2,'numeric','Value',10);
leadField.Layout.Row=5; leadField.Layout.Column=2; unitLabel(g2,'deg',5);

makeLabel(g2,'Trailing edge',6);
trailField = uieditfield(g2,'numeric','Value',170);
trailField.Layout.Row=6; trailField.Layout.Column=2; unitLabel(g2,'deg',6);

makeLabel(g2,'Preload, m',7);
preloadField = uieditfield(g2,'numeric','Value',0.50);
preloadField.Layout.Row=7; preloadField.Layout.Column=2; unitLabel(g2,'-',7);

makeLabel(g2,'Offset / pivot offset',8);
offsetField = uieditfield(g2,'numeric','Value',0.50);
offsetField.Layout.Row=8; offsetField.Layout.Column=2; unitLabel(g2,'-',8);

makeLabel(g2,'Pad arc',9);
padArcField = uieditfield(g2,'numeric','Value',72);
padArcField.Layout.Row=9; padArcField.Layout.Column=2; unitLabel(g2,'deg',9);

makeLabel(g2,'Pivot type',10);
pivotDD = uidropdown(g2,'Items',{'Line','Spherical'},'Value','Line');
pivotDD.Layout.Row=10; pivotDD.Layout.Column=[2 3];

makeLabel(g2,'Load orientation',11);
loadOrientDD = uidropdown(g2,'Items',{'LBP','LOP'},'Value','LBP');
loadOrientDD.Layout.Row=11; loadOrientDD.Layout.Column=[2 3];

makeLabel(g2,'Taper undercut',12);
undercutField = uieditfield(g2,'numeric','Value',0.06096,'Limits',[0 Inf]);
undercutField.Layout.Row=12; undercutField.Layout.Column=2; unitLabel(g2,'mm',12);

makeLabel(g2,'Taper arc',13);
taperArcField = uieditfield(g2,'numeric','Value',75);
taperArcField.Layout.Row=13; taperArcField.Layout.Column=2; unitLabel(g2,'deg',13);

makeLabel(g2,'Wear / pocket depth',14);
specialDepthField = uieditfield(g2,'numeric','Value',0.03175,'Limits',[0 Inf]);
specialDepthField.Layout.Row=14; specialDepthField.Layout.Column=2; unitLabel(g2,'mm',14);

makeLabel(g2,'Wear / pocket arc',15);
specialArcField = uieditfield(g2,'numeric','Value',100);
specialArcField.Layout.Row=15; specialArcField.Layout.Column=2; unitLabel(g2,'deg',15);

% ========================= 3. OIL / THERMAL / SWEEP ======================
pOil = cardPanel(body,'LUBRICANT / THERMAL / SPEED');
g3 = uigridlayout(pOil,[16 3]);
g3.ColumnWidth = {165,'1x',60};
g3.RowHeight = repmat({29},1,16);
g3.Padding = [12 10 12 10];
g3.RowSpacing = 6;

makeLabel(g3,'Thermal model',1);
thermalDD = uidropdown(g3,'Items',{'Isothermal','HeatBalance'}, ...
    'Value','Isothermal','ValueChangedFcn',@thermalChanged);
thermalDD.Layout.Row=1; thermalDD.Layout.Column=[2 3];

makeLabel(g3,'Dynamic viscosity',2);
muField = uieditfield(g3,'numeric','Value',0.01034214,'Limits',[0 Inf]);
muField.Layout.Row=2; muField.Layout.Column=2; unitLabel(g3,'Pa·s',2);

makeLabel(g3,'Inlet temperature',3);
TinField = uieditfield(g3,'numeric','Value',50);
TinField.Layout.Row=3; TinField.Layout.Column=2; unitLabel(g3,'°C',3);

makeLabel(g3,'Supply flow',4);
QField = uieditfield(g3,'numeric','Value',10,'Limits',[0 Inf]);
QField.Layout.Row=4; QField.Layout.Column=2; unitLabel(g3,'L/min',4);

makeLabel(g3,'Oil density',5);
rhoField = uieditfield(g3,'numeric','Value',850,'Limits',[0 Inf]);
rhoField.Layout.Row=5; rhoField.Layout.Column=2; unitLabel(g3,'kg/m³',5);

makeLabel(g3,'Oil specific heat',6);
cpField = uieditfield(g3,'numeric','Value',2000,'Limits',[0 Inf]);
cpField.Layout.Row=6; cpField.Layout.Column=2; unitLabel(g3,'J/kg-K',6);

makeLabel(g3,'ν @ 40 °C',7);
nu40Field = uieditfield(g3,'numeric','Value',32,'Limits',[0 Inf]);
nu40Field.Layout.Row=7; nu40Field.Layout.Column=2; unitLabel(g3,'cSt',7);

makeLabel(g3,'ν @ 100 °C',8);
nu100Field = uieditfield(g3,'numeric','Value',5.4,'Limits',[0 Inf]);
nu100Field.Layout.Row=8; nu100Field.Layout.Column=2; unitLabel(g3,'cSt',8);

makeLabel(g3,'Turbulence model',9);
turbDD = uidropdown(g3,'Items',{'Auto','Laminar','Constantinescu'},'Value','Auto');
turbDD.Layout.Row=9; turbDD.Layout.Column=[2 3];

sweepHdr = uilabel(g3,'Text','SPEED SWEEP','FontWeight','bold','FontColor',C.blue2);
sweepHdr.Layout.Row=10; sweepHdr.Layout.Column=[1 3];

makeLabel(g3,'Start speed',11);
sweepStartField = uieditfield(g3,'numeric','Value',4000,'Limits',[1 Inf]);
sweepStartField.Layout.Row=11; sweepStartField.Layout.Column=2; unitLabel(g3,'rpm',11);

makeLabel(g3,'End speed',12);
sweepEndField = uieditfield(g3,'numeric','Value',48000,'Limits',[1 Inf]);
sweepEndField.Layout.Row=12; sweepEndField.Layout.Column=2; unitLabel(g3,'rpm',12);

makeLabel(g3,'Increment',13);
sweepStepField = uieditfield(g3,'numeric','Value',4000,'Limits',[1 Inf]);
sweepStepField.Layout.Row=13; sweepStepField.Layout.Column=2; unitLabel(g3,'rpm',13);

makeLabel(g3,'K/C at each speed',14);
sweepKCCheck = uicheckbox(g3,'Text','Enable','Value',true);
sweepKCCheck.Layout.Row=14; sweepKCCheck.Layout.Column=[2 3];

makeLabel(g3,'Flow vs speed',15);
sweepFlowDD = uidropdown(g3,'Items',{'Constant','ScaleWithSpeed'},'Value','Constant');
sweepFlowDD.Layout.Row=15; sweepFlowDD.Layout.Column=[2 3];

backendStatus = uilabel(g3,'Text','Backend: auto-detect', ...
    'FontColor',C.muted,'FontAngle','italic');
backendStatus.Layout.Row=16; backendStatus.Layout.Column=[1 3];

% ========================= 4. PLOT SELECTION ==============================
pPlots = cardPanel(body,'PLOTS TO OPEN');
pg = uigridlayout(pPlots,[16 1]);
pg.RowHeight = [repmat({30},1,14), {'1x'}, {44}];
pg.Padding = [12 10 12 10];
pg.RowSpacing = 5;

plotChecks = struct();
plotChecks.summary = makeCheck(pg,'Bearing performance summary',true,1);
plotChecks.pressure2d = makeCheck(pg,'Pressure distribution / contour',true,2);
plotChecks.pressure3d = makeCheck(pg,'3-D pressure field',false,3);
plotChecks.pressureCirc = makeCheck(pg,'Circumferential / mid-plane pressure',false,4);
plotChecks.film = makeCheck(pg,'Film thickness',true,5);
plotChecks.clearance = makeCheck(pg,'Journal center / clearance',false,6);
plotChecks.convergence = makeCheck(pg,'Static / K-C convergence',false,7);
plotChecks.padLoads = makeCheck(pg,'Pad load distribution',false,8);
plotChecks.stability = makeCheck(pg,'Stability margin / critical mass',false,9);
plotChecks.thermal = makeCheck(pg,'Thermal / heat-balance plots',false,10);
plotChecks.sweepPerf = makeCheck(pg,'Speed-sweep performance',false,11);
plotChecks.sweepLocus = makeCheck(pg,'Speed-sweep center locus',false,12);
plotChecks.sweepKC = makeCheck(pg,'Speed-sweep K & C',false,13);
plotChecks.sweepThermal = makeCheck(pg,'Speed-sweep thermal',false,14);

plotNote = uilabel(pg, ...
    'Text',['Each checked result opens in its own MATLAB figure window.' newline ...
            'Unselected backend figures are closed automatically.'], ...
    'FontColor',C.muted,'FontAngle','italic','WordWrap','on');
plotNote.Layout.Row=15;

selectAllBtn = uibutton(pg,'Text','Select Recommended', ...
    'FontWeight','bold','BackgroundColor',[0.90 0.94 0.98], ...
    'ButtonPushedFcn',@selectRecommended);
selectAllBtn.Layout.Row=16;

%% Footer
footer = uilabel(root, ...
    'Text','● Ready', ...
    'FontColor',C.muted,'FontAngle','italic');
footer.Layout.Row=3;

%% Backend state
backendPath = '';

%% Initial state
bearingChanged();
analysisChanged();
thermalChanged();
detectBackend();

%% ========================================================================
% Nested helpers
% =========================================================================

    function p = cardPanel(parent,titleText)
        p = uipanel(parent, ...
            'Title',titleText, ...
            'FontWeight','bold', ...
            'ForegroundColor',C.navy, ...
            'BackgroundColor',C.panel);
    end

    function makeLabel(parent,txt,row)
        h = uilabel(parent,'Text',txt,'FontWeight','bold','FontColor',C.text);
        h.Layout.Row=row; h.Layout.Column=1;
    end

    function unitLabel(parent,txt,row)
        h = uilabel(parent,'Text',txt,'FontColor',C.muted);
        h.Layout.Row=row; h.Layout.Column=3;
    end

    function h = makeCheck(parent,txt,val,row)
        h = uicheckbox(parent,'Text',txt,'Value',val,'FontColor',C.text);
        h.Layout.Row=row;
    end

    function detectBackend()
        candidates = { ...
            'RotorDynX_Bearings.m', ...
            'RotorDynX_Bearings_Backend_V1_4_SPHERICAL_TPJB.m', ...
            'RotorDynX_Bearings_Backend_V1_4_SPHERICAL_TPJB(1).m'};

        appDir = fileparts(mfilename('fullpath'));

        for ii=1:numel(candidates)
            p = fullfile(appDir,candidates{ii});
            if isfile(p)
                backendPath = p;
                backendStatus.Text = ['Backend: ' candidates{ii}];
                backendStatus.FontColor = C.green;
                return;
            end

            q = which(candidates{ii});
            if ~isempty(q)
                backendPath = q;
                backendStatus.Text = ['Backend: ' candidates{ii}];
                backendStatus.FontColor = C.green;
                return;
            end
        end

        backendStatus.Text = 'Backend: not found — click Backend';
        backendStatus.FontColor = C.red;
    end

    function chooseBackend(varargin)
        [f,p] = uigetfile('*.m','Select RotorDynX solver backend');
        if isequal(f,0), return; end
        backendPath = fullfile(p,f);
        backendStatus.Text = ['Backend: ' f];
        backendStatus.FontColor = C.green;
    end

    function bearingChanged(varargin)
        bt = string(bearingDD.Value);

        if bt == "TPJB"
            thermalDD.Items = {'Isothermal','HeatBalance'};
            if ~any(strcmp(thermalDD.Value,thermalDD.Items))
                thermalDD.Value = 'Isothermal';
            end
        else
            thermalDD.Items = {'Isothermal','FilmTHD'};
            if ~any(strcmp(thermalDD.Value,thermalDD.Items))
                thermalDD.Value = 'Isothermal';
            end
        end

        % Keep the one-page form stable; enable only inputs relevant to the
        % selected bearing family.
        setEnable({nPadsField,leadField,trailField,preloadField,offsetField},true);
        setEnable({padArcField,pivotDD,loadOrientDD,undercutField,taperArcField, ...
                   specialDepthField,specialArcField},false);

        switch bt
            case "Plain"
                nPadsField.Value = 1;

            case "FixedLobe"
                nPadsField.Value = max(2,nPadsField.Value);
                leadField.Value = 10;
                trailField.Value = 170;
                preloadField.Value = 0.50;
                offsetField.Value = 0.50;

            case "TaperLand"
                nPadsField.Value = 3;
                leadField.Value = 100;
                trailField.Value = 200;
                undercutField.Value = 0.06096;
                taperArcField.Value = 75;
                setEnable({undercutField,taperArcField},true);

            case "PressureDam"
                nPadsField.Value = 2;
                leadField.Value = 10;
                trailField.Value = 170;
                specialDepthField.Value = 0.381;
                specialArcField.Value = 125;
                setEnable({specialDepthField,specialArcField},true);

            case "WornBearing"
                nPadsField.Value = 2;
                leadField.Value = 10;
                trailField.Value = 170;
                specialDepthField.Value = 0.03175;
                specialArcField.Value = 100;
                setEnable({specialDepthField,specialArcField},true);

            case "TPJB"
                DField.Value = 44.45;
                LField.Value = 19.05;
                CbField.Value = 0.0635;
                nPadsField.Value = 4;
                preloadField.Value = 0.35;
                padArcField.Value = 72;
                offsetField.Value = 0.60;
                rpmField.Value = 10000;
                loadField.Value = 66.723;
                muField.Value = 0.01034214;
                setEnable({padArcField,pivotDD,loadOrientDD},true);
                setEnable({leadField,trailField},false);
        end

        updatePlotAvailability();
    end

    function setEnable(handles,tf)
        if tf, v='on'; else, v='off'; end
        for kk=1:numel(handles)
            handles{kk}.Enable = v;
        end
    end

    function analysisChanged(varargin)
        isSweep = strcmpi(analysisDD.Value,'SpeedSweep');
        if isSweep, en='on'; else, en='off'; end
        sweepStartField.Enable = en;
        sweepEndField.Enable = en;
        sweepStepField.Enable = en;
        sweepKCCheck.Enable = en;
        sweepFlowDD.Enable = en;
        updatePlotAvailability();
    end

    function thermalChanged(varargin)
        hb = ~strcmpi(thermalDD.Value,'Isothermal');
        if hb, en='on'; else, en='off'; end
        TinField.Enable = en;
        QField.Enable = en;
        rhoField.Enable = en;
        cpField.Enable = en;
        nu40Field.Enable = en;
        nu100Field.Enable = en;
        updatePlotAvailability();
    end

    function updatePlotAvailability()
        bt = string(bearingDD.Value);
        sweep = strcmpi(analysisDD.Value,'SpeedSweep');
        thermal = ~strcmpi(thermalDD.Value,'Isothermal');

        % Available in both engines
        setCheckEnable(plotChecks.summary,true);
        setCheckEnable(plotChecks.pressure2d,true);
        setCheckEnable(plotChecks.pressure3d,bt ~= "TPJB");
        setCheckEnable(plotChecks.pressureCirc,true);
        setCheckEnable(plotChecks.film,true);
        setCheckEnable(plotChecks.clearance,bt ~= "TPJB");
        setCheckEnable(plotChecks.stability,bt ~= "TPJB");

        % TPJB-specific
        setCheckEnable(plotChecks.padLoads,bt == "TPJB");
        setCheckEnable(plotChecks.convergence,bt == "TPJB");

        % Thermal figures
        setCheckEnable(plotChecks.thermal,thermal && bt ~= "TPJB");

        % Sweep
        setCheckEnable(plotChecks.sweepPerf,sweep);
        setCheckEnable(plotChecks.sweepLocus,sweep);
        setCheckEnable(plotChecks.sweepKC,sweep && sweepKCCheck.Value);
        setCheckEnable(plotChecks.sweepThermal,sweep && strcmpi(thermalDD.Value,'HeatBalance') && bt == "TPJB");
    end

    function setCheckEnable(h,tf)
        if tf
            h.Enable='on';
        else
            h.Enable='off';
            h.Value=false;
        end
    end

    function selectRecommended(varargin)
        fields = fieldnames(plotChecks);
        for ii=1:numel(fields)
            h = plotChecks.(fields{ii});
            h.Value = false;
        end

        plotChecks.summary.Value = true;
        plotChecks.pressure2d.Value = true;
        plotChecks.film.Value = true;

        if strcmpi(bearingDD.Value,'TPJB')
            plotChecks.pressureCirc.Value = true;
            plotChecks.padLoads.Value = true;
        else
            plotChecks.pressure3d.Value = true;
            plotChecks.clearance.Value = true;
        end

        if strcmpi(analysisDD.Value,'SpeedSweep')
            plotChecks.sweepPerf.Value = true;
            plotChecks.sweepLocus.Value = true;
            if sweepKCCheck.Value
                plotChecks.sweepKC.Value = true;
            end
        end
    end

    function runAnalysis(~,~)
        if isempty(backendPath) || ~isfile(backendPath)
            chooseBackend();
            if isempty(backendPath) || ~isfile(backendPath)
                return;
            end
        end

        runBtn.Enable = 'off';
        runBtn.Text = 'SOLVING...';
        footer.Text = '● Running RotorDynX solver...';
        drawnow;

        tempFile = fullfile(tempdir,'RotorDynX_Bearings_GUI_Run.m');

        try
            raw = fileread(backendPath);
            patched = buildPatchedBackend(raw);
            writeTextFile(tempFile,patched);

            % Keep the app alive: the source script starts with close all.
            % The patched backend removes that destructive line.
            figsBefore = findall(groot,'Type','figure');

            oldDefaultVis = get(groot,'DefaultFigureVisible');
            set(groot,'DefaultFigureVisible','off');
            cleanupVis = onCleanup(@()set(groot,'DefaultFigureVisible',oldDefaultVis)); %#ok<NASGU>

            t0 = tic;
            evalin('base','clear RotorDynXResult');
            evalin('base',sprintf('run(''%s'');',strrep(tempFile,'''','''''')));
            elapsed = toc(t0);

            figsAfter = findall(groot,'Type','figure');
            newFigs = setdiff(figsAfter,figsBefore);

            selectedNames = selectedFigureNames();

            opened = {};
            generatedNames = strings(0);

            for ii=1:numel(newFigs)
                f = newFigs(ii);
                try
                    nm = string(get(f,'Name'));
                    generatedNames(end+1) = nm; %#ok<AGROW>

                    if any(strcmp(nm,selectedNames))
                        decoratePlotFigure(f,nm);
                        set(f,'Visible','on');
                        opened{end+1} = char(nm); %#ok<AGROW>
                    else
                        close(f);
                    end
                catch
                end
            end

            % Report selected figures that were unavailable for this case.
            missing = selectedNames(~ismember(selectedNames,generatedNames));

            footer.Text = sprintf('● Converged   |   %.2f s   |   %d plot window(s) opened   |   RotorDynX 1.0.0', ...
                elapsed,numel(opened));

            if ~isempty(missing)
                msg = sprintf(['Analysis completed.\n\n' ...
                    'These selected plots were not generated for this case:\n%s'], ...
                    strjoin(cellstr(missing),newline));
                uialert(fig,msg,'RotorDynX Plot Availability','Icon','info');
            end

        catch ME
            footer.Text = '● Solver failed';
            uialert(fig,getReport(ME,'extended','hyperlinks','off'), ...
                'RotorDynX Solver Error','Icon','error');
        end

        runBtn.Enable = 'on';
        runBtn.Text = '▶   RUN ANALYSIS';
    end

    function patched = buildPatchedBackend(raw)
        patched = raw;

        % Do not let the backend close the GUI.
        patched = regexprep(patched, ...
            '(?m)^\s*clear;\s*clc;\s*close all;\s*$', ...
            'clc;', 'once');

        % Master selectors
        patched = patchOnce(patched, ...
            '(?m)^bearingType\s*=\s*".*?";', ...
            sprintf('bearingType = "%s";',bearingDD.Value));
        patched = patchOnce(patched, ...
            '(?m)^analysisMode\s*=\s*".*?";', ...
            sprintf('analysisMode = "%s";',analysisDD.Value));

        % Split backend engines so similarly named variables are patched safely.
        splitToken = 'function moduleOut = runRotorDynXTPJB(masterAnalysisMode)';
        k = strfind(patched,splitToken);
        if isempty(k)
            error('Cannot locate TPJB engine in backend.');
        end
        k = k(1);
        fixedPart = patched(1:k-1);
        tpPart = patched(k:end);

        % ---------------- Fixed geometry engine ----------------
        fixedPart = patchOnce(fixedPart,'(?m)^singlePointRPM\s*=\s*[^;]+;', ...
            sprintf('singlePointRPM = %.12g;',rpmField.Value));
        fixedPart = patchOnce(fixedPart,'(?m)^speedStartRPM\s*=\s*[^;]+;', ...
            sprintf('speedStartRPM = %.12g;',sweepStartField.Value));
        fixedPart = patchOnce(fixedPart,'(?m)^speedEndRPM\s*=\s*[^;]+;', ...
            sprintf('speedEndRPM = %.12g;',sweepEndField.Value));
        fixedPart = patchOnce(fixedPart,'(?m)^speedStepRPM\s*=\s*[^;]+;', ...
            sprintf('speedStepRPM = %.12g;',sweepStepField.Value));
        fixedPart = patchOnce(fixedPart,'(?m)^speedSweepComputeKC\s*=\s*(true|false);', ...
            sprintf('speedSweepComputeKC = %s;',tfstr(sweepKCCheck.Value)));
        fixedPart = patchOnce(fixedPart,'(?m)^turbulenceModel\s*=\s*".*?";', ...
            sprintf('turbulenceModel = "%s";',turbDD.Value));
        fixedPart = patchOnce(fixedPart,'(?m)^fullTHD\s*=\s*(true|false);', ...
            sprintf('fullTHD = %s;',tfstr(strcmpi(thermalDD.Value,'FilmTHD'))));

        % First fixed-engine D, L, clearance, load, viscosity definitions.
        fixedPart = patchOnce(fixedPart,'(?m)^D\s*=\s*5\.0\*0\.0254;[^\n]*', ...
            sprintf('D = %.15g;               %% journal diameter [m]',DField.Value/1000));
        fixedPart = patchOnce(fixedPart,'(?m)^L\s*=\s*3\.0\*0\.0254;[^\n]*', ...
            sprintf('L = %.15g;               %% bearing axial length [m]',LField.Value/1000));
        fixedPart = patchOnce(fixedPart,'(?m)^bearing\.Cb\s*=\s*0\.005\*0\.0254;[^\n]*', ...
            sprintf('bearing.Cb = %.15g;       %% base radial clearance [m]',CbField.Value/1000));
        fixedPart = patchOnce(fixedPart,'(?m)^W\s*=\s*1000\*4\.4482216152605;[^\n]*', ...
            sprintf('W = %.15g;                %% applied load [N]',loadField.Value));
        fixedPart = patchOnce(fixedPart,'(?m)^muIso\s*=\s*1\.5e-6\*6894\.757293168;[^\n]*', ...
            sprintf('muIso = %.15g;            %% Pa.s',muField.Value));
        fixedPart = patchOnce(fixedPart,'(?m)^TinC\s*=\s*45;[^\n]*', ...
            sprintf('TinC = %.15g;              %% degC',TinField.Value));
        fixedPart = patchOnce(fixedPart,'(?m)^nu40_cSt\s*=\s*46\.0;[^\n]*', ...
            sprintf('nu40_cSt = %.15g;',nu40Field.Value));
        fixedPart = patchOnce(fixedPart,'(?m)^nu100_cSt\s*=\s*7\.0;[^\n]*', ...
            sprintf('nu100_cSt = %.15g;',nu100Field.Value));
        fixedPart = patchOnce(fixedPart,'(?m)^rho40\s*=\s*860;[^\n]*', ...
            sprintf('rho40 = %.15g;',rhoField.Value));
        fixedPart = patchOnce(fixedPart,'(?m)^cpOil\s*=\s*2000;[^\n]*', ...
            sprintf('cpOil = %.15g;',cpField.Value));

        % Fixed-lobe family
        fixedPart = patchBearingBranch(fixedPart,bearingDD.Value);

        % ---------------- TPJB engine --------------------------
        tpPart = patchOnce(tpPart,'(?m)^D\s*=\s*1\.75\*0\.0254;[^\n]*', ...
            sprintf('D = %.15g;               %% journal diameter [m]',DField.Value/1000));
        tpPart = patchOnce(tpPart,'(?m)^L\s*=\s*0\.75\*0\.0254;[^\n]*', ...
            sprintf('L = %.15g;               %% axial length [m]',LField.Value/1000));
        tpPart = patchOnce(tpPart,'(?m)^Cb\s*=\s*0\.0025\*0\.0254;[^\n]*', ...
            sprintf('Cb = %.15g;              %% assembled clearance [m]',CbField.Value/1000));
        tpPart = patchOnce(tpPart,'(?m)^preload\s*=\s*0\.35;[^\n]*', ...
            sprintf('preload = %.15g;         %% preload',preloadField.Value));
        tpPart = patchOnce(tpPart,'(?m)^Nrpm\s*=\s*10000;[^\n]*', ...
            sprintf('Nrpm = %.15g;            %% shaft speed [rpm]',rpmField.Value));
        tpPart = patchOnce(tpPart,'(?m)^W\s*=\s*15\*4\.4482216152605;[^\n]*', ...
            sprintf('W = %.15g;               %% applied load [N]',loadField.Value));
        tpPart = patchOnce(tpPart,'(?m)^thermalModel\s*=\s*".*?";[^\n]*', ...
            sprintf('thermalModel = "%s";',ternaryText(strcmpi(thermalDD.Value,'HeatBalance'),'HeatBalance','Isothermal')));
        tpPart = patchOnce(tpPart,'(?m)^muIsothermal\s*=\s*1\.5e-6\*6894\.757293168;[^\n]*', ...
            sprintf('muIsothermal = %.15g;    %% Pa.s',muField.Value));
        tpPart = patchOnce(tpPart,'(?m)^Tin_C\s*=\s*50\.0;[^\n]*', ...
            sprintf('Tin_C = %.15g;',TinField.Value));
        tpPart = patchOnce(tpPart,'(?m)^Qsupply_Lmin\s*=\s*10\.0;[^\n]*', ...
            sprintf('Qsupply_Lmin = %.15g;',QField.Value));
        tpPart = patchOnce(tpPart,'(?m)^rhoOil\s*=\s*850\.0;[^\n]*', ...
            sprintf('rhoOil = %.15g;',rhoField.Value));
        tpPart = patchOnce(tpPart,'(?m)^cpOil\s*=\s*2000\.0;[^\n]*', ...
            sprintf('cpOil = %.15g;',cpField.Value));
        tpPart = patchOnce(tpPart,'(?m)^nu40_cSt\s*=\s*32\.0;[^\n]*', ...
            sprintf('nu40_cSt = %.15g;',nu40Field.Value));
        tpPart = patchOnce(tpPart,'(?m)^nu100_cSt\s*=\s*5\.4;[^\n]*', ...
            sprintf('nu100_cSt = %.15g;',nu100Field.Value));
        tpPart = patchOnce(tpPart,'(?m)^nPads\s*=\s*4;', ...
            sprintf('nPads = %d;',round(nPadsField.Value)));
        tpPart = patchOnce(tpPart,'(?m)^padArcDeg\s*=\s*72;', ...
            sprintf('padArcDeg = %.15g;',padArcField.Value));
        tpPart = patchOnce(tpPart,'(?m)^pivotOffset\s*=\s*0\.60;[^\n]*', ...
            sprintf('pivotOffset = %.15g;     %% [-]',offsetField.Value));
        tpPart = patchOnce(tpPart,'(?m)^pivotType\s*=\s*".*?";', ...
            sprintf('pivotType = "%s";',pivotDD.Value));
        tpPart = patchOnce(tpPart,'(?m)^loadOrientation\s*=\s*".*?";[^\n]*', ...
            sprintf('loadOrientation = "%s";',loadOrientDD.Value));
        tpPart = patchOnce(tpPart,'(?m)^speedSweepStartRPM\s*=\s*[^;]+;', ...
            sprintf('speedSweepStartRPM = %.15g;',sweepStartField.Value));
        tpPart = patchOnce(tpPart,'(?m)^speedSweepEndRPM\s*=\s*[^;]+;', ...
            sprintf('speedSweepEndRPM = %.15g;',sweepEndField.Value));
        tpPart = patchOnce(tpPart,'(?m)^speedSweepStepRPM\s*=\s*[^;]+;', ...
            sprintf('speedSweepStepRPM = %.15g;',sweepStepField.Value));
        tpPart = patchOnce(tpPart,'(?m)^speedSweepComputeKC\s*=\s*(true|false);', ...
            sprintf('speedSweepComputeKC = %s;',tfstr(sweepKCCheck.Value)));
        tpPart = patchOnce(tpPart,'(?m)^speedSweepFlowMode\s*=\s*".*?";', ...
            sprintf('speedSweepFlowMode = "%s";',sweepFlowDD.Value));

        patched = [fixedPart tpPart];
    end

    function s = patchBearingBranch(s,bt)
        switch string(bt)
            case "FixedLobe"
                s = patchOnce(s,'(?m)^\s*bearing\.numberOfPads\s*=\s*2;', ...
                    sprintf('    bearing.numberOfPads = %d;',round(nPadsField.Value)));
                s = patchOnce(s,'(?m)^\s*bearing\.pad\(1\)\.theta1Deg\s*=\s*10;[^\n]*', ...
                    sprintf('    bearing.pad(1).theta1Deg = %.15g;',leadField.Value));
                s = patchOnce(s,'(?m)^\s*bearing\.pad\(1\)\.theta2Deg\s*=\s*170;[^\n]*', ...
                    sprintf('    bearing.pad(1).theta2Deg = %.15g;',trailField.Value));
                s = patchOnce(s,'(?m)^\s*bearing\.pad\(1\)\.preload\s*=\s*0\.50;[^\n]*', ...
                    sprintf('    bearing.pad(1).preload = %.15g;',preloadField.Value));
                s = patchOnce(s,'(?m)^\s*bearing\.pad\(1\)\.offset\s*=\s*0\.50;[^\n]*', ...
                    sprintf('    bearing.pad(1).offset = %.15g;',offsetField.Value));

            case "TaperLand"
                s = patchOnce(s,'(?m)^\s*bearing\.numberOfPads\s*=\s*3;', ...
                    sprintf('    bearing.numberOfPads = %d;',round(nPadsField.Value)));
                s = patchOnce(s,'(?m)^\s*bearing\.pad\(1\)\.theta1Deg\s*=\s*100;[^\n]*', ...
                    sprintf('    bearing.pad(1).theta1Deg = %.15g;',leadField.Value));
                s = patchOnce(s,'(?m)^\s*bearing\.pad\(1\)\.theta2Deg\s*=\s*200;[^\n]*', ...
                    sprintf('    bearing.pad(1).theta2Deg = %.15g;',trailField.Value));
                s = patchOnce(s,'(?m)^\s*bearing\.pad\(1\)\.undercut\s*=\s*0\.0024\*0\.0254;[^\n]*', ...
                    sprintf('    bearing.pad(1).undercut = %.15g;',undercutField.Value/1000));
                s = patchOnce(s,'(?m)^\s*bearing\.pad\(1\)\.taperArcDeg\s*=\s*75;', ...
                    sprintf('    bearing.pad(1).taperArcDeg = %.15g;',taperArcField.Value));

            case "PressureDam"
                s = patchOnce(s,'(?m)^\s*bearing\.pocketArcDeg\s*=\s*125;', ...
                    sprintf('    bearing.pocketArcDeg = %.15g;',specialArcField.Value));
                s = patchOnce(s,'(?m)^\s*bearing\.pocketDepth\s*=\s*0\.015\*0\.0254;[^\n]*', ...
                    sprintf('    bearing.pocketDepth = %.15g;',specialDepthField.Value/1000));

            case "WornBearing"
                s = patchOnce(s,'(?m)^\s*bearing\.wearDepth\s*=\s*0\.00125\*0\.0254;[^\n]*', ...
                    sprintf('    bearing.wearDepth = %.15g;',specialDepthField.Value/1000));
                s = patchOnce(s,'(?m)^\s*bearing\.wearArcDeg\s*=\s*100;[^\n]*', ...
                    sprintf('    bearing.wearArcDeg = %.15g;',specialArcField.Value));
        end
    end

    function out = patchOnce(in,pattern,replacement)
        if isempty(regexp(in,pattern,'once'))
            error('RotorDynX GUI could not patch expected backend input:\n%s',pattern);
        end
        out = regexprep(in,pattern,replacement,'once');
    end

    function names = selectedFigureNames()
        bt = string(bearingDD.Value);
        names = strings(0);

        if bt == "TPJB"
            if plotChecks.summary.Value
                names(end+1) = "RotorDynX - TPJB Geometry + Tilt + Pressure";
            end
            if plotChecks.pressure2d.Value
                names(end+1) = "RotorDynX - TPJB Pressure Distribution";
            end
            if plotChecks.pressureCirc.Value
                names(end+1) = "RotorDynX - TPJB Circumferential Pressure";
            end
            if plotChecks.film.Value
                names(end+1) = "RotorDynX - TPJB Film Thickness";
            end
            if plotChecks.convergence.Value
                names(end+1) = "RotorDynX - TPJB Static Convergence";
            end
            if plotChecks.padLoads.Value
                names(end+1) = "RotorDynX - TPJB Pad Loads";
            end
            if plotChecks.sweepPerf.Value
                names(end+1) = "RotorDynX - TPJB Speed Sweep Performance";
            end
            if plotChecks.sweepLocus.Value
                names(end+1) = "RotorDynX - TPJB Speed Sweep Eccentricity Map";
            end
            if plotChecks.sweepKC.Value
                names(end+1) = "RotorDynX - TPJB Speed Sweep Dynamic Coefficients";
            end
            if plotChecks.sweepThermal.Value
                names(end+1) = "RotorDynX - TPJB Speed Sweep Thermal";
            end
        else
            if plotChecks.summary.Value
                names(end+1) = "17 - Benchmark Bearing Summary";
            end
            if plotChecks.pressure2d.Value
                names(end+1) = "01 - Pressure Contour";
            end
            if plotChecks.pressure3d.Value
                names(end+1) = "02 - 3D Pressure";
            end
            if plotChecks.pressureCirc.Value
                names(end+1) = "03 - Midplane Pressure";
            end
            if plotChecks.film.Value
                names(end+1) = "04 - Film Thickness";
            end
            if plotChecks.stability.Value
                names(end+1) = "11 - Stability Margin";
            end
            if plotChecks.thermal.Value
                names = [names, "12 - Mean Film Temperature","13 - Effective Viscosity", ...
                                "14 - Circumferential Temperature","15 - THD Convergence", ...
                                "16 - THD Energy Balance"];
            end
            if plotChecks.clearance.Value
                names(end+1) = "18 - Journal Center Clearance Zoom";
            end
            if plotChecks.sweepLocus.Value
                names(end+1) = "19 - Speed Sweep Journal Center Locus";
            end
            if plotChecks.sweepPerf.Value
                names = [names, "20 - Minimum Film Thickness vs Speed", ...
                                "21 - Eccentricity Ratio vs Speed", ...
                                "22 - Maximum Pressure vs Speed", ...
                                "23 - Side Leakage vs Speed", ...
                                "24 - Power Loss vs Speed"];
            end
            if plotChecks.sweepKC.Value
                names = [names, "25 - Stiffness vs Speed", ...
                                "26 - Damping vs Speed", ...
                                "27 - Critical Mass vs Speed"];
            end
        end

        names = unique(names,'stable');
    end

    function decoratePlotFigure(f,plotName)
        % Add a restrained RotorDynX header to a native MATLAB figure.
        % Existing backend plot objects are preserved; only their vertical
        % positions are compressed slightly to make room for the header.

        try
            set(f,'Color',C.bg);
        catch
        end

        % Reserve top 8% for the application header.
        headerH = 0.075;
        contentScale = 1 - headerH - 0.015;

        % Reposition axes/colorbars without changing plot data.
        ax = findall(f,'Type','axes');
        for ia = 1:numel(ax)
            try
                oldUnits = ax(ia).Units;
                ax(ia).Units = 'normalized';
                p = ax(ia).Position;
                p(2) = 0.015 + contentScale*p(2);
                p(4) = contentScale*p(4);
                ax(ia).Position = p;
                ax(ia).Units = oldUnits;
            catch
            end
        end

        cb = findall(f,'Type','ColorBar');
        for ic = 1:numel(cb)
            try
                oldUnits = cb(ic).Units;
                cb(ic).Units = 'normalized';
                p = cb(ic).Position;
                p(2) = 0.015 + contentScale*p(2);
                p(4) = contentScale*p(4);
                cb(ic).Position = p;
                cb(ic).Units = oldUnits;
            catch
            end
        end

        % Reposition figure annotations where possible.
        allObjs = findall(f);
        for io = 1:numel(allObjs)
            try
                cls = class(allObjs(io));
                if contains(cls,'annotation') || contains(lower(cls),'textbox')
                    if isprop(allObjs(io),'Position') && isprop(allObjs(io),'Units')
                        oldUnits = allObjs(io).Units;
                        allObjs(io).Units = 'normalized';
                        p = allObjs(io).Position;
                        if numel(p) == 4
                            p(2) = 0.015 + contentScale*p(2);
                            p(4) = contentScale*p(4);
                            allObjs(io).Position = p;
                        end
                        allObjs(io).Units = oldUnits;
                    end
                end
            catch
            end
        end

        % Navy header strip.
        annotation(f,'rectangle',[0 1-headerH 1 headerH], ...
            'FaceColor',C.navy, ...
            'Color',C.navy, ...
            'LineWidth',0.1);

        % Logo icon if available.
        if isfile(logoPath)
            try
                aLogo = axes('Parent',f, ...
                    'Units','normalized', ...
                    'Position',[0.008 1-headerH+0.006 0.048 headerH-0.012], ...
                    'Color','none', ...
                    'XColor','none','YColor','none');
                I = imread(logoPath);
                image(aLogo,I);
                axis(aLogo,'image');
                axis(aLogo,'off');
                uistack(aLogo,'top');
            catch
            end
        end

        % Software identity.
        annotation(f,'textbox',[0.062 1-headerH+0.010 0.30 headerH-0.018], ...
            'String','RotorDynX  Bearings', ...
            'Color','w', ...
            'FontWeight','bold', ...
            'FontSize',12, ...
            'EdgeColor','none', ...
            'VerticalAlignment','middle');

        % Current plot label on the right.
        prettyName = regexprep(char(plotName),'^\d+\s*-\s*','');
        annotation(f,'textbox',[0.53 1-headerH+0.010 0.45 headerH-0.018], ...
            'String',sprintf('%s   |   V1',prettyName), ...
            'Color',[0.86 0.92 0.98], ...
            'FontSize',9.5, ...
            'FontAngle','italic', ...
            'EdgeColor','none', ...
            'HorizontalAlignment','right', ...
            'VerticalAlignment','middle');

        try
            set(f,'Name',['RotorDynX | ' char(plotName)]);
        catch
        end
    end

    function writeTextFile(pathStr,txt)
        fid = fopen(pathStr,'w');
        if fid < 0
            error('Cannot create temporary backend file.');
        end
        cleaner = onCleanup(@()fclose(fid)); 
        fwrite(fid,txt,'char');
    end

    function out = ternaryText(tf,a,b)
        if tf, out=a; else, out=b; end
    end

    function s = tfstr(tf)
        if tf, s='true'; else, s='false'; end
    end

    function newCase(~,~)
        bearingDD.Value = 'Plain';
        analysisDD.Value = 'SinglePoint';
        commentField.Value = 'RotorDynX bearing case';
        DField.Value = 127;
        LField.Value = 76.2;
        CbField.Value = 0.127;
        rpmField.Value = 3600;
        loadField.Value = 4448.22;
        loadAngleField.Value = 270;
        muField.Value = 0.01034214;
        turbDD.Value = 'Auto';
        bearingChanged();
        thermalDD.Value = 'Isothermal';
        analysisChanged();
        thermalChanged();
        selectRecommended();
        footer.Text = '● New case';
    end

    function saveCase(~,~)
        S = collectCase();
        [f,p] = uiputfile('*.mat','Save RotorDynX case','RotorDynX_case.mat');
        if isequal(f,0), return; end
        save(fullfile(p,f),'S');
        footer.Text = ['● Saved: ' f];
    end

    function openCase(~,~)
        [f,p] = uigetfile('*.mat','Open RotorDynX case');
        if isequal(f,0), return; end
        x = load(fullfile(p,f),'S');
        if ~isfield(x,'S')
            uialert(fig,'Selected MAT-file does not contain a RotorDynX case.','Open Case');
            return;
        end
        applyCase(x.S);
        footer.Text = ['● Opened: ' f];
    end

    function S = collectCase()
        S.comment = commentField.Value;
        S.bearingType = bearingDD.Value;
        S.analysis = analysisDD.Value;
        S.Dmm = DField.Value;
        S.Lmm = LField.Value;
        S.Cbmm = CbField.Value;
        S.rpm = rpmField.Value;
        S.loadN = loadField.Value;
        S.loadAngle = loadAngleField.Value;
        S.nPads = nPadsField.Value;
        S.leading = leadField.Value;
        S.trailing = trailField.Value;
        S.preload = preloadField.Value;
        S.offset = offsetField.Value;
        S.padArc = padArcField.Value;
        S.pivotType = pivotDD.Value;
        S.loadOrientation = loadOrientDD.Value;
        S.undercutmm = undercutField.Value;
        S.taperArc = taperArcField.Value;
        S.specialDepthmm = specialDepthField.Value;
        S.specialArc = specialArcField.Value;
        S.thermal = thermalDD.Value;
        S.mu = muField.Value;
        S.TinC = TinField.Value;
        S.Q_Lmin = QField.Value;
        S.rho = rhoField.Value;
        S.cp = cpField.Value;
        S.nu40 = nu40Field.Value;
        S.nu100 = nu100Field.Value;
        S.turbulence = turbDD.Value;
        S.sweepStart = sweepStartField.Value;
        S.sweepEnd = sweepEndField.Value;
        S.sweepStep = sweepStepField.Value;
        S.sweepKC = sweepKCCheck.Value;
        S.sweepFlow = sweepFlowDD.Value;
    end

    function applyCase(S)
        setIfField(commentField,S,'comment');
        setIfField(bearingDD,S,'bearingType');
        setIfField(analysisDD,S,'analysis');
        setIfField(DField,S,'Dmm');
        setIfField(LField,S,'Lmm');
        setIfField(CbField,S,'Cbmm');
        setIfField(rpmField,S,'rpm');
        setIfField(loadField,S,'loadN');
        setIfField(loadAngleField,S,'loadAngle');
        setIfField(nPadsField,S,'nPads');
        setIfField(leadField,S,'leading');
        setIfField(trailField,S,'trailing');
        setIfField(preloadField,S,'preload');
        setIfField(offsetField,S,'offset');
        setIfField(padArcField,S,'padArc');
        setIfField(pivotDD,S,'pivotType');
        setIfField(loadOrientDD,S,'loadOrientation');
        setIfField(undercutField,S,'undercutmm');
        setIfField(taperArcField,S,'taperArc');
        setIfField(specialDepthField,S,'specialDepthmm');
        setIfField(specialArcField,S,'specialArc');
        setIfField(thermalDD,S,'thermal');
        setIfField(muField,S,'mu');
        setIfField(TinField,S,'TinC');
        setIfField(QField,S,'Q_Lmin');
        setIfField(rhoField,S,'rho');
        setIfField(cpField,S,'cp');
        setIfField(nu40Field,S,'nu40');
        setIfField(nu100Field,S,'nu100');
        setIfField(turbDD,S,'turbulence');
        setIfField(sweepStartField,S,'sweepStart');
        setIfField(sweepEndField,S,'sweepEnd');
        setIfField(sweepStepField,S,'sweepStep');
        setIfField(sweepKCCheck,S,'sweepKC');
        setIfField(sweepFlowDD,S,'sweepFlow');

        bearingChanged();
        analysisChanged();
        thermalChanged();
    end

    function setIfField(h,S,name)
        if isfield(S,name)
            try, h.Value = S.(name); catch, end
        end
    end

    function showAbout(~,~)
        uialert(fig, ...
            sprintf(['RotorDynX Bearings 1.0.0' ...
            'Hydrodynamic bearing analysis for static, dynamic and thermal studies.' ...
            'The graphical interface changes case inputs and plot selection only. ' ...
            'Solver physics and numerical methods remain in RotorDynX_Bearings.m.']), ...
            'About RotorDynX');
    end
end
