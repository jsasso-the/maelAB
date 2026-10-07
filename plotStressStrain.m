% Engineering stress-strain analysis for the M003 tensile test data.
%
% Set the material folder name(s) below and run. The script:
%   1. finds the material folder inside  <rootFolder>\M003
%   2. finds the .DAT file inside that folder (searches subfolders too)
%   3. reads the data and computes stress, strain and their uncertainties
%   4. draws one figure with the stress-strain plot and a results table
%
% To plot several data sets together, add more specimen blocks (k = 2, 3, ...).
clear; clc; close all;

%% ===================== USER SETTINGS =====================
% ---- Where the data lives (set once) ----
rootFolder = 'C:\Users\jsasso\OneDrive - Syracuse University\MAE Solids datasets';
labFolder  = 'M003';

% ---- Specimens / data sets ----
% One block per data set. All blocks are drawn on the same graph and listed
% side by side in the table.
%   folder      : material folder name inside M003. Case doesn't matter and
%                 part of the name works (e.g. 'alum' finds 'Aluminum 6061').
%   file        : '' = use the only .DAT file in the folder. If the folder
%                 has more than one, put the file name here, e.g. 'run2.dat'.
%   label       : name for the legend and table ('' = use the folder name).
%   shape       : 'rect' (width x thickness) or 'round' (diameter).
%   width, thickness, diameter, gaugeLength : [value uncertainty]
%                 in mm (units = 'SI') or in (units = 'US').
k = 1;
S(k).folder      = 'Aluminum';
S(k).file        = '';
S(k).label       = '';
S(k).shape       = 'rect';
S(k).width       = [12.70 0.01];
S(k).thickness   = [3.18  0.01];
S(k).diameter    = [NaN   NaN];     % only used when shape = 'round'
S(k).gaugeLength = [50.80 0.50];

% ---- Copy/uncomment to add another data set to the same figure ----
% k = 2;
% S(k).folder      = 'Steel';
% S(k).file        = '';
% S(k).label       = '';
% S(k).shape       = 'round';
% S(k).diameter    = [6.35 0.01];
% S(k).gaugeLength = [25.40 0.50];

% ---- What the plot shows (true/false) ----
show.curve      = true;    % engineering stress-strain curve
show.offsetLine = true;    % 0.2 % offset line
show.errorBars  = true;    % stress and strain error bars along the curve
show.yield      = true;    % yield point (0.2 % offset)
show.ultimate   = true;    % ultimate point
show.rupture    = true;    % rupture point
show.labels     = true;    % write the stress value next to each point
show.fitPoints  = false;   % highlight the points used to fit Young's modulus
show.zoom       = true;    % extra small plot zoomed in on the elastic/yield region
show.table      = true;    % results table in the figure

nErrorBars     = 15;           % number of error bars drawn along each curve
plotTitle      = '';           % '' = automatic title
strainLim      = [];           % x axis limits, e.g. [0 0.25]   ([] = auto)
stressLim      = [];           % y axis limits, e.g. [0 400]    ([] = auto)
legendLocation = 'best';

% ---- DAT file columns ----
% Column number, or part of the column's header text (e.g. 'Load').
% printFileInfo = true prints the header and first rows of each DAT file in
% the Command Window, so you can check which column is which.
printFileInfo = true;
colForce      = 2;
colStrain     = 3;
strainType    = 'strain';  % 'strain'    : column is strain (or % strain, see strainScale)
                           % 'extension' : column is extension/displacement; it
                           %               is divided by the gauge length
forceScale    = 1;         % force column x forceScale  -> N (SI) or lbf (US). kN: 1000
strainScale   = 1;         % strain column x strainScale -> mm/mm, or -> mm / in
                           % for 'extension'.  Strain in %: 0.01

% ---- Units ----
units = 'SI';   % 'SI': N, mm, MPa, GPa, MJ/m^3     'US': lbf, in, ksi, Msi, in-lbf/in^3

% ---- Instrument uncertainties ----
% [absolute  percent-of-reading], combined as sqrt(abs^2 + (pct*reading)^2).
% Absolute values are in the units of the DAT column (before scaling).
uForce  = [0 0.5];
uStrain = [0 0.5];

% ---- Analysis settings ----
offsetStrain   = 0.002;        % 0.2 % offset
fitRange       = [0.10 0.40];  % Young's modulus fit: stress range as a fraction of ultimate
fitStrainRange = [];           % or set a strain range, e.g. [0.0005 0.002] (overrides fitRange)
breakDrop      = 0.10;         % rupture = last point before stress drops by more than
                               % this fraction of ultimate between two readings
%% =========================================================

%% Settings -> config struct
cfg = struct('colForce', colForce, 'colStrain', colStrain, 'strainType', strainType, ...
    'forceScale', forceScale, 'strainScale', strainScale, 'uForce', uForce, ...
    'uStrain', uStrain, 'offsetStrain', offsetStrain, 'fitRange', fitRange, ...
    'fitStrainRange', fitStrainRange, 'breakDrop', breakDrop);
cfg.U = unitSet(units);
if ~any(strcmpi(cfg.strainType, {'strain', 'extension'}))
    error('strainType must be ''strain'' or ''extension''.');
end

%% Find folders and files, read data, analyze
labPath = findSubfolder(rootFolder, labFolder);
nSpec = numel(S);
R = cell(1, nSpec);
for i = 1:nSpec
    sp = fillDefaults(S(i));
    sp.folderPath = findSubfolder(labPath, sp.folder);
    sp.filePath   = findDatFile(sp.folderPath, sp.file);
    if isempty(sp.label)
        [~, sp.label] = fileparts(sp.folderPath);
    end

    [data, headers, headerLines] = readDat(sp.filePath);
    if printFileInfo
        printDatInfo(sp.filePath, data, headers, headerLines);
    end
    iF = pickColumn(cfg.colForce,  headers, size(data, 2), 'colForce');
    iX = pickColumn(cfg.colStrain, headers, size(data, 2), 'colStrain');

    R{i} = analyzeSpecimen(data(:, iF), data(:, iX), sp, cfg);
end
R = [R{:}];

%% Figure layout: plot on the left; table and zoom plot on the right
fig = figure('Name', 'Engineering Stress-Strain', 'NumberTitle', 'off', 'Color', 'w');
hasRight = show.table || show.zoom;
if hasRight
    set(fig, 'Position', [50 50 1500 800]);
    mainPos  = [0.05 0.08 0.52 0.85];
    if show.table && show.zoom
        tablePos = [0.61 0.47 0.38 0.48];
        zoomPos  = [0.65 0.08 0.32 0.31];
    elseif show.table
        tablePos = [0.61 0.08 0.38 0.87];
    else
        zoomPos  = [0.65 0.08 0.32 0.85];
    end
else
    set(fig, 'Position', [100 100 1000 650]);
    mainPos  = [0.08 0.10 0.88 0.82];
end

%% Main plot
ax = axes(fig, 'Position', mainPos);
drawCurves(ax, R, show, nErrorBars, cfg.U, false);
xlabel(ax, 'Engineering Strain (mm/mm)');
if strcmp(cfg.U.name, 'US'), xlabel(ax, 'Engineering Strain (in/in)'); end
ylabel(ax, sprintf('Engineering Stress (%s)', cfg.U.stress));
if isempty(plotTitle)
    plotTitle = ['Engineering Stress-Strain: ' strjoin({R.label}, ', ')];
end
title(ax, plotTitle, 'Interpreter', 'none');
grid(ax, 'on'); box(ax, 'on');
if ~isempty(strainLim), xlim(ax, strainLim); else, xlim(ax, [0 1.05*max([R.epsR])]); end
if ~isempty(stressLim), ylim(ax, stressLim); else, ylim(ax, [0 1.15*max([R.sigU])]); end
lg = legend(ax, 'Location', legendLocation, 'Interpreter', 'none');
if isempty(get(lg, 'String')), delete(lg); end

%% Zoom plot (elastic region and 0.2 % offset)
if show.zoom
    az = axes(fig, 'Position', zoomPos);
    drawCurves(az, R, show, nErrorBars, cfg.U, true);
    ey = [R.epsY]; sy = [R.sigY];
    if all(isnan(ey)), ey = 3*offsetStrain; sy = max([R.sigU]); end
    xlim(az, [0 2*max(ey)]);
    ylim(az, [0 1.3*max(sy)]);
    title(az, 'Zoom: elastic region and 0.2% offset');
    xlabel(az, 'Strain'); ylabel(az, sprintf('Stress (%s)', cfg.U.stress));
    grid(az, 'on'); box(az, 'on');
end

%% Results table
[rowNames, cellData] = buildTable(R, cfg.U);
if show.table
    uitable(fig, 'Data', cellData, 'RowName', rowNames, ...
        'ColumnName', {R.label}, 'Units', 'normalized', 'Position', tablePos, ...
        'ColumnWidth', repmat({150}, 1, nSpec), 'FontSize', 10);
end

% Also print the table in the Command Window
fprintf('\n%-34s', 'Quantity');
fprintf('%-26s', R.label);
fprintf('\n%s\n', repmat('-', 1, 34 + 26*nSpec));
for r = 1:numel(rowNames)
    fprintf('%-34s', rowNames{r});
    fprintf('%-26s', cellData{r, :});
    fprintf('\n');
end


%% ===================== LOCAL FUNCTIONS =====================

function U = unitSet(name)
% Unit labels and conversion factors.
%   stressFactor : force/area -> stress unit (N/mm^2 = MPa;  lbf/in^2 -> ksi)
%   energyFactor : stress unit -> energy-per-volume unit
    switch upper(name)
        case 'SI'
            U = struct('name', 'SI', 'len', 'mm', 'force', 'N', 'stress', 'MPa', ...
                'modulus', 'GPa', 'energy', 'MJ/m^3', 'stressFactor', 1, 'energyFactor', 1);
        case 'US'
            U = struct('name', 'US', 'len', 'in', 'force', 'lbf', 'stress', 'ksi', ...
                'modulus', 'Msi', 'energy', 'in-lbf/in^3', 'stressFactor', 1e-3, 'energyFactor', 1e3);
        otherwise
            error('units must be ''SI'' or ''US''.');
    end
end

function sp = fillDefaults(sp)
    if ~isfield(sp, 'folder') || isempty(sp.folder), error('Every specimen needs a folder name.'); end
    defaults = {'file', ''; 'label', ''; 'shape', 'rect'; 'width', [NaN NaN]; ...
        'thickness', [NaN NaN]; 'diameter', [NaN NaN]; 'gaugeLength', [NaN NaN]};
    for j = 1:size(defaults, 1)
        if ~isfield(sp, defaults{j, 1}) || isempty(sp.(defaults{j, 1}))
            sp.(defaults{j, 1}) = defaults{j, 2};
        end
    end
    for f = {'width', 'thickness', 'diameter', 'gaugeLength'}
        if isscalar(sp.(f{1})), sp.(f{1}) = [sp.(f{1}) 0]; end   % no uncertainty given
    end
end

function p = findSubfolder(parent, name)
% Folder inside 'parent' whose name matches 'name': exact match first
% (ignoring case), otherwise the one folder whose name contains 'name'.
    if ~isfolder(parent), error('Folder not found: %s', parent); end
    d = dir(parent);
    d = d([d.isdir] & ~ismember({d.name}, {'.', '..'}));
    names = {d.name};
    hit = strcmpi(names, name);
    if ~any(hit)
        hit = ~cellfun(@isempty, strfind(lower(names), lower(name)));
    end
    if nnz(hit) == 1
        p = fullfile(parent, names{hit});
    elseif nnz(hit) > 1
        error('"%s" matches more than one folder in %s:\n  %s\nUse a more specific name.', ...
            name, parent, strjoin(names(hit), '\n  '));
    else
        error('No folder matching "%s" in %s.\nFolders there:\n  %s', ...
            name, parent, strjoin(names, '\n  '));
    end
end

function f = findDatFile(folder, fileName)
% The .DAT file in 'folder' (or its subfolders). If fileName is given,
% the file with that name (the .dat extension can be left off).
    files = listDat(folder);
    if isempty(files), error('No .DAT file found in %s', folder); end
    [~, names, exts] = cellfun(@fileparts, files, 'UniformOutput', false);
    if ~isempty(fileName)
        [~, want] = fileparts(fileName);
        hit = strcmpi(strcat(names, exts), fileName) | strcmpi(names, want);
        if ~any(hit)
            error('File "%s" not found in %s.\n.DAT files there:\n  %s', ...
                fileName, folder, strjoin(strcat(names, exts), '\n  '));
        end
        files = files(hit);
    end
    if numel(files) > 1
        error(['More than one .DAT file in %s:\n  %s\n' ...
            'Set S(k).file to the one you want.'], folder, strjoin(files, '\n  '));
    end
    f = files{1};
end

function files = listDat(folder)
% All .dat files (any case) in folder and its subfolders.
    d = dir(folder);
    files = {};
    for j = 1:numel(d)
        if any(strcmp(d(j).name, {'.', '..'})), continue; end
        p = fullfile(folder, d(j).name);
        if d(j).isdir
            files = [files, listDat(p)]; %#ok<AGROW>
        else
            [~, ~, e] = fileparts(d(j).name);
            if strcmpi(e, '.dat'), files{end+1} = p; end %#ok<AGROW>
        end
    end
end

function [data, headers, headerLines] = readDat(fn)
% Reads a text DAT file. Rows made only of numbers are data; everything
% before the first data row is header. Works with tab, comma, semicolon or
% space delimiters.
    txt = fileread(fn);
    lines = regexp(txt, '\r\n|\n|\r', 'split');
    clean = regexprep(lines, '["'']', '');
    clean = strtrim(regexprep(clean, '[,;\t]', ' '));
    numPat = '^([-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?\s*)+$';
    isNum = ~cellfun(@isempty, regexp(clean, numPat, 'once'));
    if ~any(isNum), error('No numeric data rows found in %s', fn); end

    nTok = cellfun(@numel, regexp(clean, '\S+', 'match'));
    nCols = mode(nTok(isNum));
    keep = isNum & nTok == nCols;
    data = sscanf(strjoin(clean(keep), ' '), '%f');
    data = reshape(data, nCols, []).';

    first = find(isNum, 1);
    headerLines = lines(1:first-1);
    headerLines = headerLines(~cellfun(@isempty, strtrim(headerLines)));

    % Column names: every header line that splits into nCols pieces is
    % joined column by column (e.g. a name line + a units line -> 'Load (N)')
    headers = {};
    for j = 1:numel(headerLines)
        tok = regexp(strtrim(headerLines{j}), '\t|,|;|\s{2,}', 'split');
        tok = strtrim(regexprep(tok, '"', ''));
        if numel(tok) == nCols
            if isempty(headers), headers = tok;
            else, headers = strtrim(strcat(headers, {' '}, tok)); end
        end
    end
end

function printDatInfo(fn, data, headers, headerLines)
    fprintf('\n=== %s ===\n', fn);
    fprintf('%d data rows, %d columns\n', size(data, 1), size(data, 2));
    if ~isempty(headerLines)
        fprintf('Header lines:\n');
        fprintf('   %s\n', headerLines{1:min(end, 10)});
    end
    for c = 1:size(data, 2)
        if isempty(headers), h = ''; else, h = headers{c}; end
        fprintf('  col %d  %-25s first values: %s\n', c, h, ...
            sprintf('%g  ', data(1:min(3, end), c)));
    end
end

function c = pickColumn(sel, headers, nCols, settingName)
% Column index from a number or from (part of) the column header text.
    if isnumeric(sel)
        c = sel;
    else
        if isempty(headers)
            error('%s = ''%s'': the DAT file has no column names. Use a column number.', settingName, sel);
        end
        hit = find(~cellfun(@isempty, strfind(lower(headers), lower(sel))));
        if numel(hit) ~= 1
            error('%s = ''%s'' matches %d columns. Columns are:\n  %s', ...
                settingName, sel, numel(hit), strjoin(headers, '\n  '));
        end
        c = hit;
    end
    if c < 1 || c > nCols
        error('%s = %d, but the DAT file has %d columns.', settingName, c, nCols);
    end
end

function R = analyzeSpecimen(Fraw, Xraw, sp, cfg)
% Stress, strain, uncertainties and material properties for one data set.
    U = cfg.U;
    ok = ~isnan(Fraw) & ~isnan(Xraw);
    F = Fraw(ok) * cfg.forceScale;
    X = Xraw(ok) * cfg.strainScale;

    % --- Measurements ---
    L = sp.gaugeLength(1);  uL = sp.gaugeLength(2);
    if strcmpi(sp.shape, 'round')
        d = sp.diameter(1);  ud = sp.diameter(2);
        A  = pi*d^2/4;
        uA = A * 2*ud/d;
    elseif strcmpi(sp.shape, 'rect')
        w = sp.width(1);  uw = sp.width(2);
        t = sp.thickness(1);  ut = sp.thickness(2);
        A  = w*t;
        uA = A * sqrt((uw/w)^2 + (ut/t)^2);
    else
        error('%s: shape must be ''rect'' or ''round''.', sp.label);
    end
    if isnan(A), error('%s: cross-section dimensions are missing.', sp.label); end
    isExt = strcmpi(cfg.strainType, 'extension');
    if isExt && isnan(L), error('%s: gaugeLength is needed for strainType = ''extension''.', sp.label); end

    % --- Stress and strain with point-by-point uncertainty ---
    uF  = sqrt((cfg.uForce(1)*cfg.forceScale)^2 + (cfg.uForce(2)/100*F).^2);
    sig  = U.stressFactor * F/A;
    uSig = U.stressFactor * sqrt((uF/A).^2 + (F*uA/A^2).^2);

    uX = sqrt((cfg.uStrain(1)*cfg.strainScale)^2 + (cfg.uStrain(2)/100*X).^2);
    if isExt
        eps  = X/L;
        uEps = sqrt((uX/L).^2 + (X*uL/L^2).^2);
    else
        eps  = X;
        uEps = uX;
    end

    % --- Ultimate ---
    [sigU, iU] = max(sig);

    % --- Rupture: last point before a sudden drop in stress after ultimate ---
    iR = numel(sig);
    j = find(diff(sig(iU:end)) < -cfg.breakDrop*sigU, 1);
    if ~isempty(j)
        iR = iU + j - 1;
    else
        last = find(sig(iU:end) > 0.10*sigU, 1, 'last');  % drop trailing after-break readings
        iR = iU + last - 1;
    end
    idx = (1:iR)';
    eps = eps(idx); uEps = uEps(idx); sig = sig(idx); uSig = uSig(idx);

    % --- Young's modulus: linear fit on the loading part of the curve ---
    iTop = find(sig >= cfg.fitRange(2)*sigU, 1);
    if ~isempty(cfg.fitStrainRange)
        fitSel = eps >= cfg.fitStrainRange(1) & eps <= cfg.fitStrainRange(2) & idx <= iU;
    else
        fitSel = sig >= cfg.fitRange(1)*sigU & idx <= iTop;
    end
    if nnz(fitSel) < 3
        error('%s: fewer than 3 points in the modulus fit range. Adjust fitRange/fitStrainRange.', sp.label);
    end
    ef = eps(fitSel); sf = sig(fitSel);
    p = polyfit(ef, sf, 1);
    E = p(1); b = p(2);
    res = sf - polyval(p, ef);
    seE = sqrt(sum(res.^2)/(numel(ef) - 2)) / sqrt(sum((ef - mean(ef)).^2));
    % Statistical fit error + scale errors (area, gauge length, percent-of-reading terms)
    uE = sqrt(seE^2 + E^2*((uA/A)^2 + isExt*(uL/L)^2 + (cfg.uForce(2)/100)^2 + (cfg.uStrain(2)/100)^2));

    % --- Yield: 0.2 % offset line  sig = E*(eps - offset) + b ---
    i0 = find(fitSel, 1);
    [epsY, sigY] = offsetYield(eps, sig, E, b, cfg.offsetStrain, i0);
    [eHi, sHi] = offsetYield(eps, sig, E + uE, b, cfg.offsetStrain, i0);
    [eLo, sLo] = offsetYield(eps, sig, E - uE, b, cfg.offsetStrain, i0);
    uSigY = NaN; uEpsY = NaN;
    if ~isnan(sigY)
        k = find(eps >= epsY, 1);
        uSigY = sqrt(uSig(k)^2 + (abs(sHi - sLo)/2)^2);
        uEpsY = sqrt(uEps(k)^2 + (abs(eHi - eLo)/2)^2);
    end

    % --- Modulus of resilience: sigY^2 / (2E) ---
    Ur  = sigY^2/(2*E);
    uUr = Ur*sqrt((2*uSigY/sigY)^2 + (uE/E)^2);

    % --- Modulus of toughness: area under the curve up to rupture ---
    % Stress uncertainty treated as systematic (integrated along the curve);
    % strain uncertainty enters through the final strain.
    Ut  = trapz(eps, sig);
    uUt = sqrt(trapz(eps, uSig)^2 + (Ut/eps(end)*uEps(end))^2);

    % --- Pack results ---
    R.label = sp.label; R.file = sp.filePath; R.shape = sp.shape;
    R.width = sp.width; R.thickness = sp.thickness; R.diameter = sp.diameter;
    R.gaugeLength = sp.gaugeLength; R.A = A; R.uA = uA;
    [R.Fmax, iFm] = max(F); R.uFmax = uF(iFm);
    R.eps = eps; R.uEps = uEps; R.sig = sig; R.uSig = uSig; R.fitSel = fitSel;
    R.E = E; R.uE = uE; R.b = b; R.offset = cfg.offsetStrain;
    R.epsY = epsY; R.uEpsY = uEpsY; R.sigY = sigY; R.uSigY = uSigY;
    R.epsU = eps(iU); R.uEpsU = uEps(iU); R.sigU = sigU; R.uSigU = uSig(iU);
    R.epsR = eps(end); R.uEpsR = uEps(end); R.sigR = sig(end); R.uSigR = uSig(end);
    R.Ur = Ur*U.energyFactor; R.uUr = uUr*U.energyFactor;
    R.Ut = Ut*U.energyFactor; R.uUt = uUt*U.energyFactor;
end

function [eY, sY] = offsetYield(eps, sig, E, b, off, i0)
% First point (after i0) where the curve falls below the offset line;
% linear interpolation between the two readings on either side.
    g = sig - (E*(eps - off) + b);
    k = find(g(i0+1:end) <= 0 & g(i0:end-1) > 0, 1) + i0;
    if isempty(k)
        eY = NaN; sY = NaN;
        return;
    end
    a = g(k-1)/(g(k-1) - g(k));
    eY = eps(k-1) + a*(eps(k) - eps(k-1));
    sY = sig(k-1) + a*(sig(k) - sig(k-1));
end

function drawCurves(ax, R, show, nErrorBars, U, isZoom)
    hold(ax, 'on');
    C = lines(max(numel(R), 1));
    for i = 1:numel(R)
        r = R(i); c = C(i, :);
        vis = 'on'; if isZoom, vis = 'off'; end

        if show.curve
            plot(ax, r.eps, r.sig, '-', 'Color', c, 'LineWidth', 1.5, ...
                'DisplayName', r.label, 'HandleVisibility', vis);
        end
        if show.errorBars && ~isZoom
            n = numel(r.eps);
            k = unique(round(linspace(1, n, min(nErrorBars, n))));
            h = errorbar(ax, r.eps(k), r.sig(k), r.uSig(k), r.uSig(k), r.uEps(k), r.uEps(k));
            set(h, 'LineStyle', 'none', 'Color', c, 'HandleVisibility', 'off');
        end
        if show.fitPoints
            plot(ax, r.eps(r.fitSel), r.sig(r.fitSel), '.', 'Color', 0.6*c, ...
                'MarkerSize', 10, 'DisplayName', [r.label ' modulus fit'], 'HandleVisibility', vis);
        end
        if show.offsetLine
            sTop = r.sigU;
            if ~isnan(r.sigY), sTop = 1.15*r.sigY; end
            e0 = r.offset - r.b/r.E;                    % where the line crosses zero stress
            e1 = r.offset + (sTop - r.b)/r.E;
            plot(ax, [e0 e1], [0 sTop], '--', 'Color', c, 'LineWidth', 1, ...
                'DisplayName', sprintf('%s 0.2%% offset (E = %.3g %s)', r.label, ...
                r.E/1000, U.modulus), 'HandleVisibility', vis);
        end
        if show.yield && ~isnan(r.sigY)
            plotPoint(ax, r.epsY, r.sigY, 'o', c, show.labels, 'Yield', U, isZoom);
        end
        if show.ultimate && ~isZoom
            plotPoint(ax, r.epsU, r.sigU, '^', c, show.labels, 'Ultimate', U, isZoom);
        end
        if show.rupture && ~isZoom
            plotPoint(ax, r.epsR, r.sigR, 's', c, show.labels, 'Rupture', U, isZoom);
        end
    end

    % One legend entry per point type (black outline), shared by all curves
    if ~isZoom
        names = {'Yield (0.2% offset)', 'Ultimate', 'Rupture'};
        marks = {'o', '^', 's'};
        on = [show.yield, show.ultimate, show.rupture];
        for j = find(on)
            plot(ax, NaN, NaN, marks{j}, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', [0.85 0.85 0.85], ...
                'MarkerSize', 8, 'LineStyle', 'none', 'DisplayName', names{j});
        end
        if show.errorBars
            plot(ax, NaN, NaN, 'k+', 'DisplayName', ['Error bars (' char(177) ' uncertainty)']);
        end
    end
    hold(ax, 'off');
end

function plotPoint(ax, x, y, marker, c, withLabel, name, U, isZoom)
    plot(ax, x, y, marker, 'MarkerSize', 8, 'MarkerFaceColor', c, ...
        'MarkerEdgeColor', 'k', 'LineWidth', 1, 'HandleVisibility', 'off');
    if withLabel && ~isZoom
        text(ax, x, y, sprintf('  %s: %.4g %s', name, y, U.stress), ...
            'VerticalAlignment', 'bottom', 'FontSize', 9, 'Color', 0.7*c);
    end
end

function [rows, D] = buildTable(R, U)
    L = U.len; S = U.stress;
    rows = { ...
        sprintf('Width (%s)', L); ...
        sprintf('Thickness (%s)', L); ...
        sprintf('Diameter (%s)', L); ...
        sprintf('Gauge length (%s)', L); ...
        sprintf('Area (%s^2)', L); ...
        sprintf('Max force (%s)', U.force); ...
        sprintf('Young''s modulus E (%s)', U.modulus); ...
        sprintf('Yield stress (%s)', S); ...
        'Yield strain'; ...
        sprintf('Ultimate stress (%s)', S); ...
        'Ultimate strain'; ...
        sprintf('Rupture stress (%s)', S); ...
        'Rupture strain'; ...
        sprintf('Mod. of resilience (%s)', U.energy); ...
        sprintf('Mod. of toughness (%s)', U.energy)};
    D = cell(numel(rows), numel(R));
    for i = 1:numel(R)
        r = R(i);
        isRound = strcmpi(r.shape, 'round');
        if isRound, w = [NaN NaN]; t = [NaN NaN]; d = r.diameter;
        else,       w = r.width;   t = r.thickness; d = [NaN NaN]; end
        D(:, i) = { ...
            pm(w(1), w(2)); pm(t(1), t(2)); pm(d(1), d(2)); ...
            pm(r.gaugeLength(1), r.gaugeLength(2)); pm(r.A, r.uA); ...
            pm(r.Fmax, r.uFmax); pm(r.E/1000, r.uE/1000); ...
            pm(r.sigY, r.uSigY); pm(r.epsY, r.uEpsY); ...
            pm(r.sigU, r.uSigU); pm(r.epsU, r.uEpsU); ...
            pm(r.sigR, r.uSigR); pm(r.epsR, r.uEpsR); ...
            pm(r.Ur, r.uUr); pm(r.Ut, r.uUt)};
    end
end

function s = pm(v, u)
% 'value ± uncertainty', uncertainty rounded to 2 significant figures and
% the value rounded to the same decimal place.
    if isnan(v)
        s = '-';
    elseif isnan(u) || u == 0
        s = sprintf('%.4g', v);
    else
        dec = max(0, 1 - floor(log10(abs(u))));
        s = sprintf('%.*f %s %.*f', dec, v, char(177), dec, u);
    end
end
