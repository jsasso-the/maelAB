% Stress-strain curve from an MTS .DAT file, with a 0.2% offset line,
% uncertainty bars, and the yield, ultimate and rupture points, plus a table
% of the lab measurements and results (with uncertainties) in the same
% figure window.
%
% Folder layout:
%   MAE Solids datasets\M003\<material folder>\...\<file>.dat
% Set "material" below to the material folder name; the script finds the
% folder, finds the .dat file inside it, reads it, and makes the figure.
% Enter each specimen's measurements once in the "specimens" table.
%
% DAT file (MTS 793 export): a few header lines, then a tab-delimited line of
% channel names (Axial Force, Axial Displacement, Axial Strain), a line of
% units (lbf, in, in/in), then the data.
%
% Works for brittle (carbon fiber), ductile (aluminum, steel) and plastic
% samples:
%  - strain comes from the extensometer while it was on the specimen, and
%    from crosshead displacement after it was removed (or if it never was on)
%  - the slack "toe" at the start is removed so the curve starts at 0
%  - nothing after the rupture point is plotted
%
% Uncertainties (propagated as independent errors, root-sum-square):
%   area       A = w*t            dA/A  = sqrt((dw/w)^2 + (dt/t)^2)
%              A = pi*d^2/4       dA/A  = 2*dd/d
%   stress     s = F/A            ds/s  = sqrt((dF/F)^2 + (dA/A)^2)
%   strain     e = dL/L0          de    = sqrt((d(dL)/L0)^2 + (e*dL0/L0)^2)
%              (extensometer)     de    = extensometer accuracy
%   modulus    E = slope of fit   dE/E  = sqrt((SE/E)^2 + (ds/s)^2 + (de/e)^2)
%   toughness  UT = area under curve      dUT/UT = sqrt((ds/s)^2 + (deR/eR)^2)
%   resilience Ur = sY^2/(2E)             dUr/Ur = sqrt((2*dsY/sY)^2 + (dE/E)^2)
clear; clc; close all;

%% ===================== USER SETTINGS =====================
material = 'Aluminum';         % <-- material folder inside M003 (not case sensitive; a partial name works)

baseFolder  = 'C:\Users\jsasso\OneDrive - Syracuse University\MAE Solids datasets';
testFolder  = 'M003';
datFileName = '';              % '' = find the .dat file automatically, or e.g. 'specimen.dat'

% ---- Specimen measurements (one row per specimen) [in] ----
% keys:  matched against the material folder name, ignoring case, spaces
%        and punctuation; separate alternatives with '|'. The longest key
%        found in the folder name wins, so 'plastic2' beats 'plastic'.
% shape: 'rect' (width x thickness) or 'round' (diameter in the W columns,
%        NaN in the t columns)
% i = initial (before the test), f = final (after fracture)
% NaN = not measured -> initial width/thickness: the stress axis falls
%       back to axial force (lbf); final values: N/A in the table
specimens = {
%   keys                          shape   Li      Wi      ti      Lf      Wf      tf
    'steel',                      'rect', 2.7535, 0.5100, 0.0650, 3.0065, 0.4355, 0.0575
    'alum',                       'rect', 2.6430, 0.5160, 0.0615, 2.8455, 0.4650, 0.0550
    'cf90|carbonfiber90',         'rect', 2.5110, 0.5240, 0.0605, 2.5640, 0.5205, 0.0600
    'cf45|carbonfiber45|cf40|carbonfiber40', ...
                                  'rect', 2.8900, 0.5145, 0.0565, 2.9610, 0.4705, 0.0615
    'plastic',                    'rect', 2.0,    NaN,    NaN,    NaN,    NaN,    NaN      % <-- placeholder, enter measurements
    };

% ---- Measurement uncertainties ----
dimUnc     = 0.00025;          % +/- in, width/thickness/diameter (calipers)
gaugeUnc   = 0.00025;          % +/- in, gauge length (initial and final)
loadUncPct = 1.0;              % +/- percent of reading, load cell
dispUnc    = 0.001;            % +/- in, crosshead displacement
extUnc     = 5e-5;             % +/- in/in, extensometer

% ---- Strain ----
% 'auto'         = extensometer (Axial Strain) while it was recording, then
%                  Axial Displacement / gauge length after it was removed;
%                  displacement only if the extensometer was never on
% 'strain'       = extensometer only
% 'displacement' = Axial Displacement / gauge length only
strainSource    = 'auto';
toeCompensation = true;        % remove the slack at the start so the elastic line starts at 0

% ---- 0.2% offset / elastic fit ----
offset    = 0.002;             % offset strain (0.002 = 0.2%)
fitRange  = [];                % [] = automatic (steepest straight part of the curve), or
                               % fractions of ultimate stress, e.g. [0.10 0.40]
breakDrop = 0.10;              % a sudden load drop bigger than this fraction of ultimate
                               % is the break; nothing after the rupture is plotted

nErrorBars = 15;               % number of points along the curve that get uncertainty bars
saveFigure = false;            % true = save .png and .fig into the material folder
%% =========================================================

%% Locate the folder and the .dat file
baseFolder = resolveBaseFolder(baseFolder);
testPath   = findSubfolder(baseFolder, testFolder);
matPath    = findSubfolder(testPath, material);
[~, matName] = fileparts(matPath);
datFile    = findDatFile(matPath, datFileName);
fprintf('Material folder: %s\nDAT file:        %s\n', matPath, datFile);

%% Specimen geometry
[shape, L0, Wi, ti, Lf, Wf, tf] = lookupSpecimen(specimens, matName);
[A, relA] = sectionArea(shape, Wi, ti, dimUnc);

haveArea = isfinite(A) && A > 0;
if ~haveArea
    relA = 0;
    fprintf('No specimen dimensions for "%s" - plotting axial force instead of stress.\n', matName);
end
if ~isfinite(L0) || L0 <= 0
    error('Enter the gauge length for "%s" in the specimens table.', matName);
end

%% Read the data
[data, names, units] = readMtsDat(datFile);
iF = findCol(names, 'Axial Force');
iD = findCol(names, 'Axial Displacement');
iE = find(contains(names, 'Strain', 'IgnoreCase', true), 1);   % extensometer, may be missing
fUnit = units{iF};

good = isfinite(data(:, iF)) & isfinite(data(:, iD));
if ~isempty(iE), good = good & isfinite(data(:, iE)); end
data = data(good, :);
if size(data, 1) < 10, error('Not enough data points in %s.', datFile); end

F  = data(:, iF);
eD = data(:, iD) / L0;
eD = eD - eD(1);

%% Strain
e = eD;
isExt = false(size(e));             % which points come from the extensometer
if ~strcmpi(strainSource, 'displacement') && ~isempty(iE)
    eX = data(:, iE);
    if contains(units{iE}, '%'), eX = eX/100; end    % percent -> in/in
    eX = eX - eX(1);
    [~, iRem] = max(eX);                             % last reading before the extensometer came off
    if strcmpi(strainSource, 'strain')
        e = eX;
        isExt(:) = true;
    elseif eX(iRem) - min(eX(1:iRem)) >= 1e-3        % a real test goes well past 0.1% strain
        % after removal, continue with displacement, scaled to match the
        % extensometer over the second half of the time it was on
        iA = max(1, round(iRem/2));
        k  = (eX(iRem) - eX(iA)) / (eD(iRem) - eD(iA));
        if ~isfinite(k) || k <= 0, k = 1; end
        e = eX;
        e(iRem+1:end) = eX(iRem) + k*(eD(iRem+1:end) - eD(iRem));
        isExt(1:iRem) = true;
        if iRem < numel(e) - 5
            fprintf('Extensometer removed at strain %.4g; continuing with displacement.\n', eX(iRem));
        end
    else
        fprintf(['Axial Strain column is flat - extensometer was not recording.\n' ...
            'Using Axial Displacement / gauge length (%g in) for strain.\n'], L0);
    end
end
eUnit = 'in/in';
eUnc = sqrt((dispUnc/L0)^2 + (e*gaugeUnc/L0).^2);
eUnc(isExt) = extUnc;

%% Stress
if haveArea
    s = F / A;
    switch lower(fUnit)
        case 'lbf', sUnit = 'psi';   uUnit = 'in-lbf/in^3';
        case 'kip', sUnit = 'ksi';   uUnit = 'in-kip/in^3';
        case 'n',   sUnit = 'MPa';   uUnit = 'MJ/m^3';     % area in mm^2
        otherwise,  sUnit = [fUnit '/area']; uUnit = sUnit;
    end
    sLabel = sprintf('Engineering Stress (%s)', sUnit);
else
    s = F;
    sUnit  = fUnit;
    uUnit  = [fUnit '*in/in'];
    sLabel = sprintf('Stress - Axial Force (%s)', sUnit);
end
relS = sqrt((loadUncPct/100)^2 + relA^2);   % relative stress uncertainty
sUnc = abs(s) * relS;

%% Break: biggest sudden load drop after the ultimate
% It can be one sample or spread over a few, and the load cell may not read
% 0 afterwards (it can even go negative).
[sU, iU] = max(s);
iR = numel(s);
d  = diff(s(iU:end));               % d(j) = s(iU+j) - s(iU+j-1)
if ~isempty(d)
    [dMax, j] = min(d);
    if dMax < 0
        a = j;
        z = j;
        while a > 1 && d(a-1) < 0.3*dMax, a = a - 1; end
        while z < numel(d) && d(z+1) < 0.3*dMax, z = z + 1; end
        if -sum(d(a:z)) > breakDrop*sU
            iR = iU + a - 1;        % last point before the drop
        end
    end
end
if iR == numel(s)
    fprintf('No break found in the data; rupture is the last data point.\n');
end

%% Young's modulus (linear fit) and its uncertainty
[E, b, idxFit] = fitElastic(e(1:iR), s(1:iR), fitRange);
ef = e(idxFit);
sf = s(idxFit);
res = sf - (E*ef + b);
seE = sqrt(sum(res.^2)/max(1, numel(ef) - 2)) / sqrt(sum((ef - mean(ef)).^2));   % std. error of slope
spanFit = max(ef) - min(ef);
if isExt(idxFit(1))
    relEfit = sqrt(2)*extUnc/spanFit;
else
    relEfit = sqrt((sqrt(2)*dispUnc/L0/spanFit)^2 + (gaugeUnc/L0)^2);
end
EUnc = abs(E) * sqrt((seE/E)^2 + relS^2 + relEfit^2);

%% Rupture = start of the final load drop
% Ductile samples can tear for a while before the last snap; walk back from
% the snap while the curve is still falling steeply (> 5% of E).
if E > 0
    w = max(2, round(0.01*numel(s)));
    j = iR;
    while j - w >= iU && e(j) > e(j-w) && (s(j-w) - s(j))/(e(j) - e(j-w)) > 0.05*E
        j = j - 1;
    end
    if j < iR
        lo = max(iU, j - w);
        [~, k] = max(s(lo:j));
        iR = lo + k - 1;
    end
end
s    = s(1:iR);
e    = e(1:iR);
sUnc = sUnc(1:iR);
eUnc = eUnc(1:iR);

%% Toe compensation: shift so the elastic line passes through 0
kStart = idxFit(1);
if toeCompensation && E > 0
    e0   = -b/E;
    e    = [0; e(idxFit(1):end) - e0];
    s    = [0; s(idxFit(1):end)];
    sUnc = [0; sUnc(idxFit(1):end)];
    eUnc = [0; eUnc(idxFit(1):end)];
    b    = 0;
    kStart = 2;
end

%% Ultimate, rupture and 0.2% offset yield
[sU, iU] = max(s);
eU  = e(iU);    sUu = sUnc(iU);    eUu = eUnc(iU);
iR  = numel(s);
sR  = s(iR);    sRu = sUnc(iR);    eR  = e(iR);    eRu = eUnc(iR);

sY = NaN;  eY = NaN;  sYu = NaN;  eYu = NaN;
if isfinite(E) && E > 0
    % offset line: s = E*(e - offset) + b; yield is where the curve first
    % drops below it
    g = s - (E*(e - offset) + b);
    k = find(g(kStart:end) <= 0, 1) + kStart - 1;
    if ~isempty(k) && k > 1
        t   = g(k-1) / (g(k-1) - g(k));
        eY  = e(k-1) + t*(e(k) - e(k-1));
        sY  = s(k-1) + t*(s(k) - s(k-1));
        sYu = abs(sY) * relS;
        eYu = eUnc(k);
    end
else
    warning('Elastic slope is not positive (E = %.3g); 0.2%% offset yield cannot be found.', E);
end
if isnan(sY)
    fprintf('The curve never crosses the 0.2%% offset line (brittle sample); no yield point.\n');
end

%% Modulus of toughness (area under the curve) and resilience (sY^2 / 2E)
UT  = trapz(e, s);
UTu = abs(UT) * sqrt(relS^2 + (eRu/eR)^2);
Ur  = sY^2 / (2*E);
Uru = abs(Ur) * sqrt((2*sYu/sY)^2 + (EUnc/E)^2);

%% Figure: plot on the left, table on the right
fig = figure('Name', sprintf('%s stress-strain', matName), 'NumberTitle', 'off', ...
    'Color', 'w', 'Position', [60 60 1500 700]);
ax = axes(fig, 'Position', [0.05 0.10 0.50 0.82]);
hold(ax, 'on');

hCurve = plot(ax, e, s, '-', 'LineWidth', 1.5, 'Color', [0 0.3 0.6]);

% Uncertainty bars on evenly spaced points along the curve
ib   = unique(round(linspace(1, iR, min(nErrorBars, iR))));
hErr = errorbar(ax, e(ib), s(ib), sUnc(ib), sUnc(ib), eUnc(ib), eUnc(ib), 'LineStyle', 'none', ...
    'Color', [0.5 0.5 0.5], 'CapSize', 4);

% 0.2% offset line, from zero stress up to a bit past yield
hOff = gobjects(0);
if isfinite(E) && E > 0
    if isfinite(sY), sTop = 1.15*sY; else, sTop = sU; end
    sLine = [0 sTop];
    eLine = (sLine - b)/E + offset;
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
hR = plot(ax, eR, sR, 's', 'MarkerSize', 9, 'LineWidth', 1.5, ...
    'MarkerFaceColor', [0.64 0.08 0.18], 'MarkerEdgeColor', 'k');
if iU == iR                         % brittle: breaks at the ultimate
    text(ax, eU, sU, sprintf('Ultimate = Rupture (%.4g, %.4g)  ', eU, sU), ...
        'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right');
else
    text(ax, eU, sU, sprintf('Ultimate (%.4g, %.4g)', eU, sU), ...
        'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center');
    text(ax, eR, sR, sprintf('Rupture (%.4g, %.4g)  ', eR, sR), ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'right');
end
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
legTxt = {'Stress-strain curve', 'Uncertainty'};
if ~isempty(hOff), legTxt{end+1} = sprintf('%g%% offset line', offset*100); end
if ~isempty(hY),   legTxt{end+1} = 'Yield (0.2% offset)'; end
legTxt = [legTxt {'Ultimate', 'Rupture'}];
legend(ax, hLeg, legTxt, 'Location', 'best');

%% Results table
if strcmpi(shape, 'round')
    dimRows = {'Initial diameter', pm(Wi, dimUnc), 'in'
               'Final diameter',   pm(Wf, dimUnc), 'in'};
else
    dimRows = {'Initial width',     pm(Wi, dimUnc), 'in'
               'Initial thickness', pm(ti, dimUnc), 'in'
               'Final width',       pm(Wf, dimUnc), 'in'
               'Final thickness',   pm(tf, dimUnc), 'in'};
end

rows = [
    {'LAB MEASUREMENTS', '', ''}
    {'Initial gauge length', pm(L0, gaugeUnc), 'in'}
    {'Final gauge length',   pm(Lf, gaugeUnc), 'in'}
    dimRows
    {'RESULTS', '', ''}
    {'Ultimate stress',          pm(sU, sUu),   sUnit}
    {'Strain at ultimate',       pm(eU, eUu),   eUnit}
    {'Rupture stress',           pm(sR, sRu),   sUnit}
    {'Strain at rupture',        pm(eR, eRu),   eUnit}
    {'Yield stress (0.2%)',      pm(sY, sYu),   sUnit}
    {'Strain at yield',          pm(eY, eYu),   eUnit}
    {'Young''s modulus E',       pm(E, EUnc),   sUnit}
    {'Modulus of toughness',     pm(UT, UTu),   uUnit}
    {'Modulus of resilience',    pm(Ur, Uru),   uUnit}
    ];
uitable(fig, 'Data', rows, 'ColumnName', {'Quantity', 'Value', 'Units'}, ...
    'RowName', [], 'Units', 'normalized', 'Position', [0.58 0.10 0.40 0.82], ...
    'ColumnWidth', {175, 260, 110}, 'FontSize', 11);

disp(cell2table(rows, 'VariableNames', {'Quantity', 'Value', 'Units'}));

if saveFigure
    outBase = fullfile(matPath, [matName '_stress_strain']);
    saveas(fig, [outBase '.png']);
    savefig(fig, [outBase '.fig']);
    fprintf('Saved %s.png and .fig\n', outBase);
end

%% Local function: specimen row whose key appears in the folder name
% Case, spaces and punctuation are ignored; '|' separates alternative keys.
function [shape, Li, Wi, ti, Lf, Wf, tf] = lookupSpecimen(specimens, matName)
    norm = @(x) regexprep(lower(x), '[^a-z0-9|]', '');
    folder = norm(matName);
    best = 0;
    bestLen = 0;
    for r = 1:size(specimens, 1)
        for key = strsplit(norm(specimens{r, 1}), '|')
            if ~isempty(key{1}) && contains(folder, key{1}) && numel(key{1}) > bestLen
                best = r;
                bestLen = numel(key{1});
            end
        end
    end
    if best == 0
        error(['No row in the specimens table matches the folder "%s".\n' ...
            'Add a row whose key is part of that folder name.'], matName);
    end
    row = specimens(best, :);
    [shape, Li, Wi, ti, Lf, Wf, tf] = row{2:8};
end

%% Local function: cross-section area and its relative uncertainty
function [A, relA] = sectionArea(shape, w, t, dimUnc)
    if strcmpi(shape, 'round')
        A    = pi*w^2/4;
        relA = 2*dimUnc/w;
    else
        A    = w*t;
        relA = sqrt((dimUnc/w)^2 + (dimUnc/t)^2);
    end
end

%% Local function: elastic slope from a straight-line fit
% fitRange = [] tries 25%-wide stress windows starting at 5%..50% of the
% ultimate and keeps the steepest one (skips the slack toe at the start and
% the curved part after yield).
function [E, b, idx] = fitElastic(e, s, fitRange)
    [sU, iU] = max(s);
    if isempty(fitRange)
        starts = 0.05:0.05:0.50;
        width  = 0.25;
    else
        starts = fitRange(1);
        width  = fitRange(2) - fitRange(1);
    end
    E = NaN;
    b = NaN;
    idx = [];
    for a = starts
        m = find(s(1:iU) >= a*sU & s(1:iU) <= (a + width)*sU);
        if numel(m) < 3, continue; end
        p = polyfit(e(m), s(m), 1);
        if isempty(idx) || p(1) > E
            E = p(1);
            b = p(2);
            idx = m;
        end
    end
    if isempty(idx)
        error('Not enough points to fit the elastic slope. Set fitRange, e.g. [0.10 0.40].');
    end
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

%% Local function: "value +/- uncertainty" text for the table
% Uncertainty to 2 significant figures, value to the same decimal place;
% very large or small numbers as (m +/- dm)e+XX.
function str = pm(x, dx)
    if isnan(x)
        str = 'N/A';
        return;
    elseif isnan(dx) || dx <= 0
        str = sprintf('%.5g', x);
        return;
    end
    p = floor(log10(dx)) - 1;               % place of the 2nd significant figure
    if abs(x) >= 1e5 || (abs(x) < 1e-3 && x ~= 0)
        ex  = floor(log10(abs(x)));
        dec = max(0, ex - p);
        str = sprintf('(%.*f %s %.*f)e%+03d', dec, x/10^ex, char(177), dec, dx/10^ex, ex);
    else
        dec = max(0, -p);
        str = sprintf('%.*f %s %.*f', dec, x, char(177), dec, dx);
    end
end
