% Stress-strain curve from an MTS .DAT file, with a 0.2% offset line, error
% bars, and the yield, ultimate and rupture points, plus a table of the
% results in the same figure window.
%
% Folder layout:
%   MAE Solids datasets\M003\<material folder>\...\<file>.dat
% Set "material" below to the material folder name; the script finds the
% folder, finds the .dat file inside it, reads it, and makes the figure.
%
% DAT file (MTS 793 export): a few header lines, then a tab-delimited line of
% channel names (Axial Force, Axial Displacement, Axial Strain), a line of
% units (lbf, in, in/in), then the data.
clear; clc; close all;

%% ===================== USER SETTINGS =====================
material = 'Aluminum';         % <-- material folder inside M003 (not case sensitive; a partial name works)

baseFolder  = 'C:\Users\jsasso\OneDrive - Syracuse University\MAE Solids datasets';
testFolder  = 'M003';
datFileName = '';              % '' = find the .dat file automatically, or e.g. 'specimen.dat'

% ---- Stress ----
% [] = plot axial force (lbf) directly as the stress axis.
% Give the cross-sectional area [in^2] to get true engineering stress (psi),
% e.g. round bar: specimenArea = pi*0.505^2/4;  flat bar: specimenArea = 0.5*0.125;
specimenArea = [];

% ---- Strain ----
% 'auto'         = use the Axial Strain column if it actually changes; if it is
%                  flat (extensometer not attached/recording), use
%                  Axial Displacement / gaugeLength instead
% 'strain'       = always use the Axial Strain column (extensometer, in/in)
% 'displacement' = always use Axial Displacement / gaugeLength
strainSource = 'auto';
gaugeLength  = 2.0;            % [in] specimen gauge length, used for displacement-based strain
zeroStart    = true;           % shift strain so the curve starts at 0

% ---- 0.2% offset / elastic fit ----
offset    = 0.002;             % offset strain (0.002 = 0.2%)
fitRange  = [0.10 0.40];       % fit elastic slope between these fractions of ultimate stress
breakDrop = 0.10;              % after the ultimate, points below this fraction of
                               % ultimate are post-break and are removed

% ---- Error bars ----
stressErrPct = 1.0;            % +/- percent of reading (load cell accuracy)
strainErrAbs = 5e-5;           % +/- strain, same units as the strain axis
nErrorBars   = 15;             % number of points along the curve that get error bars

saveFigure = false;            % true = save .png and .fig into the material folder
%% =========================================================

%% Locate the folder and the .dat file
baseFolder = resolveBaseFolder(baseFolder);
testPath   = findSubfolder(baseFolder, testFolder);
matPath    = findSubfolder(testPath, material);
[~, matName] = fileparts(matPath);
datFile    = findDatFile(matPath, datFileName);
fprintf('Material folder: %s\nDAT file:        %s\n', matPath, datFile);

%% Read the data
[data, names, units] = readMtsDat(datFile);
iF = findCol(names, 'Axial Force');
F  = data(:, iF);
fUnit = units{iF};

useDisp = strcmpi(strainSource, 'displacement');
if strcmpi(strainSource, 'auto')
    iE = findCol(names, 'Axial Strain');
    eCol = data(isfinite(data(:, iE)), iE);
    scale = 1 + 99*contains(units{iE}, '%');
    % a real test goes well past 0.1% strain; less than that is sensor noise
    useDisp = isempty(eCol) || max(eCol) - min(eCol) < 1e-3*scale;
    if useDisp
        fprintf(['Axial Strain column is flat (range %.3g) - extensometer was not recording.\n' ...
            'Using Axial Displacement / gauge length (%g in) for strain.\n'], ...
            max(eCol) - min(eCol), gaugeLength);
    end
end
if useDisp
    iD = findCol(names, 'Axial Displacement');
    e  = data(:, iD) / gaugeLength;
    eUnit = 'in/in';
else
    iE = findCol(names, 'Axial Strain');
    e  = data(:, iE);
    eUnit = units{iE};
end

good = isfinite(F) & isfinite(e);
F = F(good);
e = e(good);
if numel(F) < 5, error('Not enough data points in %s.', datFile); end
if zeroStart, e = e - e(1); end

% Strain recorded in percent instead of in/in
if contains(eUnit, '%')
    strainScale = 100;
else
    strainScale = 1;
end
offsetVal = offset * strainScale;

if max(e) - min(e) < 1e-4 * strainScale
    warning(['The strain barely changes (range %.3g %s). The extensometer may not have ' ...
        'been recording; set strainSource = ''auto'' or ''displacement''.'], max(e) - min(e), eUnit);
end

%% Stress
if isempty(specimenArea)
    s = F;
    sUnit  = fUnit;
    sLabel = sprintf('Stress - Axial Force (%s)', sUnit);
else
    s = F / specimenArea;
    switch lower(fUnit)
        case 'lbf', sUnit = 'psi';
        case 'kip', sUnit = 'ksi';
        case 'n',   sUnit = 'MPa';    % area in mm^2
        otherwise,  sUnit = [fUnit '/area'];
    end
    sLabel = sprintf('Stress (%s)', sUnit);
end

%% Ultimate and rupture
[sU, iU] = max(s);
iBreak = find(s(iU:end) < breakDrop * sU, 1);
if ~isempty(iBreak)                 % drop post-break points
    n = iU + iBreak - 2;
    s = s(1:n);
    e = e(1:n);
end
eU = e(iU);
iR = numel(s);
sR = s(iR);
eR = e(iR);

%% Elastic modulus (linear fit) and 0.2% offset yield
idxFit = find(s(1:iU) >= fitRange(1)*sU & s(1:iU) <= fitRange(2)*sU);
if numel(idxFit) < 2
    error('Fewer than 2 points in the elastic fit range. Widen fitRange.');
end
p = polyfit(e(idxFit), s(idxFit), 1);
E = p(1);
b = p(2);

sY = NaN;
eY = NaN;
if isfinite(E) && E > 0
    % offset line: s = E*(e - offsetVal) + b; yield is where the curve
    % first drops below it
    g  = s - (E*(e - offsetVal) + b);
    k0 = idxFit(1);
    k  = find(g(k0:end) <= 0, 1) + k0 - 1;
    if ~isempty(k) && k > 1
        t  = g(k-1) / (g(k-1) - g(k));
        eY = e(k-1) + t*(e(k) - e(k-1));
        sY = s(k-1) + t*(s(k) - s(k-1));
    end
else
    warning('Elastic slope is not positive (E = %.3g); 0.2%% offset yield cannot be found.', E);
end
if isnan(sY)
    warning('The curve never crosses the 0.2% offset line; no yield point.');
end

%% Figure: plot on the left, table on the right
fig = figure('Name', sprintf('%s stress-strain', matName), 'NumberTitle', 'off', ...
    'Color', 'w', 'Position', [80 80 1400 650]);
ax = axes(fig, 'Position', [0.06 0.11 0.56 0.80]);
hold(ax, 'on');

hCurve = plot(ax, e, s, '-', 'LineWidth', 1.5, 'Color', [0 0.3 0.6]);

% Error bars on evenly spaced points along the curve
ib   = unique(round(linspace(1, iR, min(nErrorBars, iR))));
sErr = stressErrPct/100 * abs(s(ib));
eErr = strainErrAbs * ones(size(ib(:)));
hErr = errorbar(ax, e(ib), s(ib), sErr, sErr, eErr, eErr, 'LineStyle', 'none', ...
    'Color', [0.5 0.5 0.5], 'CapSize', 4);

% 0.2% offset line, from zero stress up to a bit past yield
hOff = gobjects(0);
if isfinite(E) && E > 0
    if isfinite(sY), sTop = 1.15*sY; else, sTop = sU; end
    sLine = [0 sTop];
    eLine = (sLine - b)/E + offsetVal;
    hOff  = plot(ax, eLine, sLine, '--', 'LineWidth', 1.2, 'Color', [0.85 0.33 0.1]);
end

% Key points
hY = gobjects(0);
if isfinite(sY)
    hY = plot(ax, eY, sY, 'o', 'MarkerSize', 9, 'LineWidth', 1.5, ...
        'MarkerFaceColor', [0.47 0.67 0.19], 'MarkerEdgeColor', 'k');
    text(ax, eY, sY, sprintf('  Yield (%.4g, %.4g)', eY, sY), ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'left');
end
hU = plot(ax, eU, sU, '^', 'MarkerSize', 9, 'LineWidth', 1.5, ...
    'MarkerFaceColor', [0.93 0.69 0.13], 'MarkerEdgeColor', 'k');
text(ax, eU, sU, sprintf('Ultimate (%.4g, %.4g)', eU, sU), ...
    'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center');
hR = plot(ax, eR, sR, 's', 'MarkerSize', 9, 'LineWidth', 1.5, ...
    'MarkerFaceColor', [0.64 0.08 0.18], 'MarkerEdgeColor', 'k');
text(ax, eR, sR, sprintf('Rupture (%.4g, %.4g)  ', eR, sR), ...
    'VerticalAlignment', 'top', 'HorizontalAlignment', 'right');
hold(ax, 'off');

grid(ax, 'on');
box(ax, 'on');
xlabel(ax, sprintf('Axial Strain (%s)', eUnit));
ylabel(ax, sLabel);
title(ax, sprintf('%s - Stress vs. Strain', matName), 'Interpreter', 'none');
eSpan = max(e) - min(0, min(e));
sSpan = sU - min(0, min(s));
if eSpan > 0, xlim(ax, [min(0, min(e)), max(e) + 0.05*eSpan]); end
if sSpan > 0, ylim(ax, [min(0, min(s)), sU + 0.12*sSpan]); end

hLeg = [hCurve hErr hOff hY hU hR];
legTxt = {'Stress-strain curve', sprintf('Error (\\pm%g%% stress, \\pm%g strain)', stressErrPct, strainErrAbs)};
if ~isempty(hOff), legTxt{end+1} = sprintf('%g%% offset line', offset*100); end
if ~isempty(hY),   legTxt{end+1} = 'Yield (0.2% offset)'; end
legTxt = [legTxt {'Ultimate', 'Rupture'}];
legend(ax, hLeg, legTxt, 'Location', 'southeast');

% Results table
if isempty(specimenArea), areaTxt = 'not given'; else, areaTxt = fmt(specimenArea); end
if useDisp, strainTxt = sprintf('Displacement / %g in', gaugeLength);
else, strainTxt = 'Axial Strain column'; end
[~, fName, fExt] = fileparts(datFile);
rows = {
    'Material',                matName,          ''
    'DAT file',                [fName fExt],     ''
    'Data points',             fmt(iR),          ''
    'Cross-section area',      areaTxt,          'in^2'
    'Strain source',           strainTxt,        ''
    'Elastic modulus E',       fmt(E),           [sUnit '/(' eUnit ')']
    '0.2% yield stress',       fmt(sY),          sUnit
    'Strain at yield',         fmt(eY),          eUnit
    'Ultimate stress',         fmt(sU),          sUnit
    'Strain at ultimate',      fmt(eU),          eUnit
    'Rupture stress',          fmt(sR),          sUnit
    'Strain at rupture',       fmt(eR),          eUnit
    'Stress error',            ['+/- ' fmt(stressErrPct) '%'], 'of reading'
    'Strain error',            ['+/- ' fmt(strainErrAbs)],     eUnit
    };
uitable(fig, 'Data', rows, 'ColumnName', {'Property', 'Value', 'Units'}, ...
    'RowName', [], 'Units', 'normalized', 'Position', [0.65 0.11 0.33 0.80], ...
    'ColumnWidth', {150, 140, 110}, 'FontSize', 11);

disp(cell2table(rows, 'VariableNames', {'Property', 'Value', 'Units'}));

if saveFigure
    outBase = fullfile(matPath, [matName '_stress_strain']);
    saveas(fig, [outBase '.png']);
    savefig(fig, [outBase '.fig']);
    fprintf('Saved %s.png and .fig\n', outBase);
end

%% Local function: use baseFolder, or find "MAE Solids datasets" near here
function folder = resolveBaseFolder(folder)
    if isfolder(folder), return; end
    [~, name, ext] = fileparts(folder);
    name = [name ext];
    candidates = {fullfile(pwd, name), ...
                  fullfile(fileparts(mfilename('fullpath')), name), ...
                  pwd};
    for c = candidates
        if isfolder(c{1}) && endsWith(c{1}, name, 'IgnoreCase', true)
            folder = c{1};
            return;
        end
    end
    error('Base folder not found: %s\nSet baseFolder at the top of the script.', folder);
end

%% Local function: subfolder by name (exact match first, then partial match)
function folder = findSubfolder(parent, name)
    d = dir(parent);
    d = d([d.isdir] & ~startsWith({d.name}, '.'));
    names = {d.name};
    hit = strcmpi(names, name);
    if ~any(hit)
        hit = contains(names, name, 'IgnoreCase', true);
    end
    if ~any(hit)
        error('No folder matching "%s" in %s\nAvailable folders: %s', ...
            name, parent, strjoin(names, ', '));
    end
    if nnz(hit) > 1
        error('"%s" matches more than one folder in %s: %s\nUse the full folder name.', ...
            name, parent, strjoin(names(hit), ', '));
    end
    folder = fullfile(parent, names{hit});
end

%% Local function: .dat file anywhere inside the material folder
function file = findDatFile(folder, name)
    if isempty(name)
        f = dir(fullfile(folder, '**', '*'));
        f = f(~[f.isdir] & endsWith({f.name}, '.dat', 'IgnoreCase', true));
    else
        f = dir(fullfile(folder, '**', name));
        f = f(~[f.isdir]);
    end
    if isempty(f)
        error('No .dat file found in %s', folder);
    end
    pick = 1;
    if numel(f) > 1
        pick = find(strcmpi({f.name}, 'specimen.dat'));   % MTS default name
        if numel(pick) ~= 1
            [~, pick] = max([f.datenum]);                 % otherwise the newest
        end
        warning('Found %d .dat files in %s; using %s. Set datFileName to choose another.', ...
            numel(f), folder, f(pick).name);
    end
    file = fullfile(f(pick).folder, f(pick).name);
end

%% Local function: read an MTS .dat file (channel-name line, units line, data)
function [data, names, units] = readMtsDat(file)
    lines = regexp(fileread(file), '\r\n|\n|\r', 'split');
    hdr = find(contains(lines, 'Axial', 'IgnoreCase', true) & contains(lines, char(9)), 1);
    if isempty(hdr) || hdr == numel(lines)
        error('Could not find the channel-name line in %s', file);
    end
    names = strtrim(strsplit(lines{hdr},   char(9)));
    units = strtrim(strsplit(lines{hdr+1}, char(9)));
    nCol  = find(~cellfun('isempty', names), 1, 'last');
    names = names(1:nCol);
    units = [units repmat({''}, 1, max(0, nCol - numel(units)))];
    units = units(1:nCol);

    rows = lines(hdr+2:end);
    data = nan(numel(rows), nCol);
    keep = false(numel(rows), 1);
    for i = 1:numel(rows)
        v = sscanf(rows{i}, '%f');
        if numel(v) == nCol      % skips blank lines and repeated headers
            data(i, :) = v.';
            keep(i) = true;
        end
    end
    data = data(keep, :);
end

%% Local function: column index by channel name
function idx = findCol(names, key)
    idx = find(strcmpi(names, key), 1);
    if isempty(idx)
        idx = find(contains(names, key, 'IgnoreCase', true), 1);
    end
    if isempty(idx)
        error('Column "%s" not found. Columns in file: %s', key, strjoin(names, ', '));
    end
end

%% Local function: number to short text for the table
function str = fmt(x)
    if isnan(x)
        str = 'N/A';
    else
        str = sprintf('%.5g', x);
    end
end
