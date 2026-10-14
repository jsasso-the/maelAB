% Ultimate stress of every plastic sample: a table of each sample's ultimate
% stress, and a summary table with the average, minimum and maximum.
%
% The script finds every folder inside M003 whose name contains
% "plasticKey" (case, spaces and punctuation are ignored), and every .dat
% file inside those folders (subfolders included) is one sample. So it works
% whether each sample has its own folder (Plastic 1, Plastic 2, ...) or
% several .dat files share one folder.
%   MAE Solids datasets\M003\<plastic folder>\...\<file>.dat
%
% DAT file (MTS 793 export): a few header lines, then a tab-delimited line of
% channel names (Axial Force, Axial Displacement, Axial Strain), a line of
% units (lbf, in, in/in), then the data.
%
% Ultimate stress = highest engineering stress before rupture (load / initial area).
%
% Uncertainties (propagated as independent errors, root-sum-square):
%   area       A = w*t            dA/A  = sqrt((dw/w)^2 + (dt/t)^2)
%   stress     s = F/A            ds/s  = sqrt((dF/F)^2 + (dA/A)^2)
%   average    sAvg = sum(sU)/n   dsAvg = sqrt(sum(dsU.^2)) / n   (measurement uncertainty)
%   spread     standard deviation of the n ultimate stresses (sample-to-sample scatter)
clear; clc; close all;

%% ===================== USER SETTINGS =====================
plasticKey = 'plastic';        % <-- every folder in M003 whose name contains this is used

baseFolder  = 'C:\Users\jsasso\OneDrive - Syracuse University\MAE Solids datasets';
testFolder  = 'M003';

% ---- Specimen measurements [in] ----
% keys:  matched against each sample's label (folder name, plus the file
%        name when a folder holds several .dat files), ignoring case, spaces
%        and punctuation; separate alternatives with '|'. The longest key
%        found wins, so add a 'plastic 7' row to give sample 7 its own
%        measurements; samples without their own row use the 'plastic' row.
% i = initial (before the test), f = final (after fracture); NaN = not measured
specimens = {
%   keys        shape   Li      Wi      ti      Lf      Wf      tf
    'plastic',  'rect', 3.0070, 0.5060, 0.1365, NaN,    NaN,    NaN
%   'plastic 2', 'rect', 3.0000, 0.5000, 0.1350, NaN,   NaN,    NaN   % <-- example of a per-sample row
    };

% ---- Measurement uncertainties ----
dimUnc     = 0.00025;          % +/- in, width/thickness (calipers)
gaugeUnc   = 0.00025;          % +/- in, gauge length
loadUncPct = 1.0;              % +/- percent of reading, load cell
dispUnc    = 0.001;            % +/- in, crosshead displacement
extUnc     = 5e-5;             % +/- in/in, extensometer

toeCompensation = true;        % remove the slack at the start of each curve
fitRange  = [];                % [] = automatic elastic fit (used for the toe removal), or
                               % fractions of ultimate stress, e.g. [0.10 0.40]
breakDrop = 0.10;              % a sudden load drop bigger than this fraction of ultimate
                               % is the break; data after the rupture is ignored

saveFigure = false;            % true = save the table figure (.png and .fig) in the M003 folder
%% =========================================================

S = struct('dimUnc', dimUnc, 'gaugeUnc', gaugeUnc, 'loadUncPct', loadUncPct, 'dispUnc', dispUnc, ...
    'extUnc', extUnc, 'strainSource', 'auto', 'toe', toeCompensation, ...
    'offset', 0.002, 'fitRange', fitRange, 'breakDrop', breakDrop);
S.specimens = specimens;

%% Find every plastic sample
testPath = fullfile(resolveBaseFolder(baseFolder), testFolder);
if ~isfolder(testPath), error('Folder not found: %s', testPath); end
norm = @(x) regexprep(lower(x), '[^a-z0-9]', '');
d = dir(testPath);
d = d([d.isdir] & ~startsWith({d.name}, '.'));
d = d(contains(cellfun(norm, {d.name}, 'UniformOutput', false), norm(plasticKey)));
if isempty(d), error('No folder in %s has "%s" in its name.', testPath, plasticKey); end
[~, order] = sort(naturalKey({d.name}));
d = d(order);

labels = {};
files  = {};
for k = 1:numel(d)
    folder = fullfile(testPath, d(k).name);
    f = dir(fullfile(folder, '**', '*'));
    f = f(~[f.isdir] & endsWith({f.name}, '.dat', 'IgnoreCase', true));
    if isempty(f)
        warning('No .dat file in %s - skipped.', folder);
        continue;
    end
    [~, order] = sort(naturalKey(fullfile({f.folder}, {f.name})));
    f = f(order);
    for j = 1:numel(f)
        if numel(f) == 1
            labels{end+1} = d(k).name;
        else
            [~, fn] = fileparts(f(j).name);
            labels{end+1} = sprintf('%s - %s', d(k).name, fn);
        end
        files{end+1} = fullfile(f(j).folder, f(j).name);
    end
end
fprintf('Found %d plastic samples.\n', numel(files));

Ms = cellfun(@(n, f) processSample(n, f, S), labels, files, 'UniformOutput', false);

%% Ultimate stress of each sample
n   = numel(Ms);
sU  = cellfun(@(c) c.p.sU,  Ms);
sUu = cellfun(@(c) c.p.sUu, Ms);
sUnit = Ms{1}.sUnit;

[sMin, iMin] = min(sU);
[sMax, iMax] = max(sU);
sAvg  = mean(sU);
sAvgU = sqrt(sum(sUu.^2)) / n;              % measurement uncertainty of the average
if n > 1, sStd = std(sU); else, sStd = NaN; end

summary = {
    'Number of samples',            sprintf('%d', n),        '',     ''
    'Average ultimate stress',      pm(sAvg, sAvgU),         sUnit,  ''
    'Standard deviation',           pm(sStd, NaN),           sUnit,  'sample-to-sample scatter'
    'Minimum ultimate stress',      pm(sMin, sUu(iMin)),     sUnit,  Ms{iMin}.name
    'Maximum ultimate stress',      pm(sMax, sUu(iMax)),     sUnit,  Ms{iMax}.name
    };
perSample = [cellfun(@(c) c.name, Ms(:), 'UniformOutput', false), ...
             arrayfun(@(k) pm(sU(k), sUu(k)), (1:n)', 'UniformOutput', false)];

%% Tables
fig = figure('Name', 'Plastic ultimate stress', 'NumberTitle', 'off', ...
    'Color', 'w', 'Position', [70 70 1100 650]);
uicontrol(fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.03 0.90 0.50 0.05], ...
    'String', 'Plastic samples - ultimate stress summary', 'FontWeight', 'bold', 'FontSize', 12, ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
uitable(fig, 'Data', summary, 'ColumnName', {'Quantity', 'Value', 'Units', 'Sample'}, ...
    'RowName', [], 'Units', 'normalized', 'Position', [0.03 0.55 0.55 0.35], 'FontSize', 11, ...
    'ColumnWidth', {190, 150, 60, 190});
uicontrol(fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.62 0.90 0.35 0.05], ...
    'String', 'Ultimate stress of each sample', 'FontWeight', 'bold', 'FontSize', 12, ...
    'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
uitable(fig, 'Data', perSample, 'ColumnName', {'Sample', ['Ultimate stress (' sUnit ')']}, ...
    'RowName', [], 'Units', 'normalized', 'Position', [0.62 0.05 0.35 0.85], 'FontSize', 11, ...
    'ColumnWidth', {170, 170});
uicontrol(fig, 'Style', 'text', 'Units', 'normalized', 'Position', [0.03 0.30 0.55 0.20], ...
    'String', {'Ultimate stress = highest engineering stress (load / initial area) before rupture.', ...
               'Average uncertainty = sqrt(sum of squared sample uncertainties) / n.', ...
               'Standard deviation = scatter between the samples.'}, ...
    'FontSize', 9, 'BackgroundColor', 'w', 'HorizontalAlignment', 'left');

printTable('Plastic samples - ultimate stress summary', {'Quantity', 'Value', 'Units', 'Sample'}, summary);
printTable('Ultimate stress of each sample', {'Sample', ['Ultimate stress (' sUnit ')']}, perSample);

if saveFigure
    outBase = fullfile(testPath, 'plastic_ultimate_stress');
    saveas(fig, [outBase '.png']);
    savefig(fig, [outBase '.fig']);
    fprintf('Saved %s.png and .fig\n', outBase);
end

%% Local function: sort key that puts "Plastic 2" before "Plastic 10"
function keys = naturalKey(names)
    keys = cell(size(names));
    for i = 1:numel(names)
        [num, txt] = regexp(lower(names{i}), '\d+', 'match', 'split');
        k = txt{1};
        for j = 1:numel(num)
            k = [k sprintf('%010d', str2double(num{j})) txt{j+1}];
        end
        keys{i} = k;
    end
end

%% Local function: read and analyze one sample (.dat file)
% name is the label for the sample (also used to find its row in the
% specimens table). Returns a struct with the specimen measurements, units,
% and the analyzed curves: r (best strain: extensometer, then displacement)
% and rD (MTS displacement only), plus ultimate/rupture/toughness.
function M = processSample(name, datFile, S)
    M.name = name;
    M.datFile = datFile;
    fprintf('\n%s\n  DAT file: %s\n', M.name, M.datFile);

    % specimen geometry
    [M.shape, M.L0, M.Wi, M.ti, M.Lf, M.Wf, M.tf] = lookupSpecimen(S.specimens, M.name);
    L0 = M.L0;
    [M.A,  M.relA ] = sectionArea(M.shape, M.Wi, M.ti, S.dimUnc);
    [M.Af, M.relAf] = sectionArea(M.shape, M.Wf, M.tf, S.dimUnc);
    haveArea = isfinite(M.A) && M.A > 0;
    relA = M.relA;
    if ~haveArea
        relA = 0;
        fprintf('  No specimen dimensions - plotting axial force instead of stress.\n');
    end
    if ~isfinite(L0) || L0 <= 0
        error('Enter the gauge length for "%s" in the specimens table.', M.name);
    end

    % read the data
    [data, names, units] = readMtsDat(M.datFile);
    iF = findCol(names, 'Axial Force');
    iD = findCol(names, 'Axial Displacement');
    iE = find(contains(names, 'Strain', 'IgnoreCase', true), 1);   % extensometer, may be missing
    fUnit = units{iF};
    good = isfinite(data(:, iF)) & isfinite(data(:, iD));
    if ~isempty(iE), good = good & isfinite(data(:, iE)); end
    data = data(good, :);
    if size(data, 1) < 10, error('Not enough data points in %s.', M.datFile); end
    F  = data(:, iF);
    eD = data(:, iD) / L0;
    eD = eD - eD(1);

    % strain
    e = eD;
    eExt = [];                      % extensometer strain, in/in (empty if none)
    isExt = false(size(e));         % which points come from the extensometer
    if ~strcmpi(S.strainSource, 'displacement') && ~isempty(iE)
        eX = data(:, iE);
        if contains(units{iE}, '%'), eX = eX/100; end    % percent -> in/in
        eX = eX - eX(1);
        [~, iRem] = max(eX);                             % last reading before the extensometer came off
        if strcmpi(S.strainSource, 'strain')
            e = eX;
            eExt = eX;
            isExt(:) = true;
        elseif eX(iRem) - min(eX(1:iRem)) >= 1e-3        % a real test goes well past 0.1% strain
            % after removal, continue with displacement, scaled to match the
            % extensometer over the second half of the time it was on
            iA = max(1, round(iRem/2));
            k  = (eX(iRem) - eX(iA)) / (eD(iRem) - eD(iA));
            if ~isfinite(k) || k <= 0, k = 1; end
            e = eX;
            e(iRem+1:end) = eX(iRem) + k*(eD(iRem+1:end) - eD(iRem));
            eExt = eX;
            isExt(1:iRem) = true;
            if iRem < numel(e) - 5
                fprintf('  Extensometer removed at strain %.4g; continuing with displacement.\n', eX(iRem));
            end
        else
            fprintf(['  Axial Strain column is flat - extensometer was not recording.\n' ...
                '  Using Axial Displacement / gauge length (%g in) for strain.\n'], L0);
        end
    end
    M.eUnit = 'in/in';
    eDu  = sqrt((S.dispUnc/L0)^2 + (eD*S.gaugeUnc/L0).^2);
    eUnc = eDu;
    eUnc(isExt) = S.extUnc;

    % stress
    if haveArea
        s = F / M.A;
        switch lower(fUnit)
            case 'lbf', M.sUnit = 'psi';   M.uUnit = 'in-lbf/in^3';
            case 'kip', M.sUnit = 'ksi';   M.uUnit = 'in-kip/in^3';
            case 'n',   M.sUnit = 'MPa';   M.uUnit = 'MJ/m^3';     % area in mm^2
            otherwise,  M.sUnit = [fUnit '/area']; M.uUnit = M.sUnit;
        end
        M.sLabel = sprintf('Engineering Stress (%s)', M.sUnit);
    else
        s = F;
        M.sUnit  = fUnit;
        M.uUnit  = [fUnit '*in/in'];
        M.sLabel = sprintf('Stress - Axial Force (%s)', M.sUnit);
    end
    relS = sqrt((S.loadUncPct/100)^2 + relA^2);   % relative stress uncertainty
    sUnc = abs(s) * relS;

    % break: biggest sudden load drop after the ultimate (one sample or a
    % few; the load cell may not read 0 afterwards, it can even go negative)
    [sU, iU] = max(s);
    iR = numel(s);
    d  = diff(s(iU:end));           % d(j) = s(iU+j) - s(iU+j-1)
    if ~isempty(d)
        [dMax, j] = min(d);
        if dMax < 0
            a = j;
            z = j;
            while a > 1 && d(a-1) < 0.3*dMax, a = a - 1; end
            while z < numel(d) && d(z+1) < 0.3*dMax, z = z + 1; end
            if -sum(d(a:z)) > S.breakDrop*sU
                iR = iU + a - 1;    % last point before the drop
            end
        end
    end
    if iR == numel(s)
        fprintf('  No break found in the data; rupture is the last data point.\n');
    end

    % rupture = start of the final load drop: ductile samples can tear for
    % a while before the last snap, so walk back from the snap while the
    % curve is still falling steeply (> 5% of E)
    E0 = fitElastic(e(1:iR), s(1:iR), S.fitRange);
    if E0 > 0
        w = max(2, round(0.01*numel(s)));
        j = iR;
        while j - w >= iU && e(j) > e(j-w) && (s(j-w) - s(j))/(e(j) - e(j-w)) > 0.05*E0
            j = j - 1;
        end
        if j < iR
            lo = max(iU, j - w);
            [~, k] = max(s(lo:j));
            iR = lo + k - 1;
        end
    end

    % analyzed curves
    P = struct('fitRange', S.fitRange, 'offset', S.offset, 'toe', S.toe, 'relS', relS, ...
        'extUnc', S.extUnc, 'dispUnc', S.dispUnc, 'gaugeUnc', S.gaugeUnc, 'L0', L0);
    M.r  = analyzeCurve(e(1:iR), s(1:iR), eUnc(1:iR), sUnc(1:iR), isExt(1:iR), P);
    M.p  = curveProps(M.r, relS);
    M.rD = analyzeCurve(eD(1:iR), s(1:iR), eDu(1:iR), sUnc(1:iR), false(iR, 1), P);
    M.pD = curveProps(M.rD, relS);
    M.rX = [];
    if ~isempty(eExt)
        nX = min(find(isExt, 1, 'last'), iR);
        M.rX = analyzeCurve(eExt(1:nX), s(1:nX), S.extUnc*ones(nX, 1), sUnc(1:nX), true(nX, 1), P);
    end
    if ~(M.r.E > 0)
        warning('Elastic slope is not positive (E = %.3g); 0.2%% offset yield cannot be found.', M.r.E);
    elseif isnan(M.r.sY)
        fprintf('  The curve never crosses the 0.2%% offset line (brittle sample); no yield point.\n');
    end

    % true rupture: rupture load over the final area, strain from the area change
    M.sTR  = F(iR) / M.Af;
    M.sTRu = abs(M.sTR) * sqrt((S.loadUncPct/100)^2 + M.relAf^2);
    M.eTR  = log(M.A / M.Af);
    M.eTRu = sqrt(M.relA^2 + M.relAf^2);
end

%% Local function: ultimate, rupture and modulus of toughness of a curve
function p = curveProps(r, relS)
    [p.sU, p.iU] = max(r.s);
    p.eU  = r.e(p.iU);    p.sUu = r.sUnc(p.iU);   p.eUu = r.eUnc(p.iU);
    p.sR  = r.s(end);     p.sRu = r.sUnc(end);
    p.eR  = r.e(end);     p.eRu = r.eUnc(end);
    p.UT  = trapz(r.e, r.s);
    p.UTu = abs(p.UT) * sqrt(relS^2 + (p.eRu/p.eR)^2);
end

%% Local function: elastic fit, toe compensation and 0.2% offset yield
% Returns a struct with the (toe-compensated) curve and its uncertainties,
% E +/- dE, the yield point +/- uncertainties and the modulus of resilience.
function r = analyzeCurve(e, s, eUnc, sUnc, isExt, P)
    [E, b, idx] = fitElastic(e, s, P.fitRange);
    ef  = e(idx);
    sf  = s(idx);
    res = sf - (E*ef + b);
    seE = sqrt(sum(res.^2)/max(1, numel(ef) - 2)) / sqrt(sum((ef - mean(ef)).^2));   % std. error of slope
    span = max(ef) - min(ef);
    if isExt(idx(1))
        relEfit = sqrt(2)*P.extUnc/span;
    else
        relEfit = sqrt((sqrt(2)*P.dispUnc/P.L0/span)^2 + (P.gaugeUnc/P.L0)^2);
    end
    r.E    = E;
    r.EUnc = abs(E) * sqrt((seE/E)^2 + P.relS^2 + relEfit^2);

    % toe compensation: shift so the elastic line passes through 0
    kStart = idx(1);
    if P.toe && E > 0
        e0   = -b/E;
        e    = [0; e(idx(1):end) - e0];
        s    = [0; s(idx(1):end)];
        sUnc = [0; sUnc(idx(1):end)];
        eUnc = [0; eUnc(idx(1):end)];
        b    = 0;
        kStart = 2;
    end
    r.e = e;  r.s = s;  r.eUnc = eUnc;  r.sUnc = sUnc;  r.b = b;

    % offset line: s = E*(e - offset) + b; yield is where the curve first
    % drops below it
    r.sY = NaN;  r.eY = NaN;  r.sYu = NaN;  r.eYu = NaN;
    if isfinite(E) && E > 0
        g = s - (E*(e - P.offset) + b);
        k = find(g(kStart:end) <= 0, 1) + kStart - 1;
        if ~isempty(k) && k > 1
            t     = g(k-1) / (g(k-1) - g(k));
            r.eY  = e(k-1) + t*(e(k) - e(k-1));
            r.sY  = s(k-1) + t*(s(k) - s(k-1));
            r.sYu = abs(r.sY) * P.relS;
            r.eYu = eUnc(k);
        end
    end

    % modulus of resilience: sY^2 / 2E
    r.Ur  = r.sY^2 / (2*E);
    r.Uru = abs(r.Ur) * sqrt((2*r.sYu/r.sY)^2 + (r.EUnc/E)^2);
end

%% Local function: row of a key table whose key appears in the folder name
% Case, spaces and punctuation are ignored; '|' separates alternative keys.
% A key ending in a number only matches that whole number ('plastic1' does
% not match 'plastic12'). Returns 0 if no key matches.
function best = matchKey(keys, folderName)
    norm = @(x) regexprep(lower(x), '[^a-z0-9|]', '');
    folder = norm(folderName);
    best = 0;
    bestLen = 0;
    for r = 1:numel(keys)
        for key = strsplit(norm(keys{r}), '|')
            if ~isempty(key{1}) && keyFound(folder, key{1}) && numel(key{1}) > bestLen
                best = r;
                bestLen = numel(key{1});
            end
        end
    end
end

%% Local function: key appears in text, not followed by a digit if it ends in one
function tf = keyFound(text, key)
    tf = false;
    for i = strfind(text, key)
        after = i + numel(key);
        if ~isstrprop(key(end), 'digit') || after > numel(text) || ~isstrprop(text(after), 'digit')
            tf = true;
            return;
        end
    end
end

%% Local function: specimen measurements for a material folder
function [shape, Li, Wi, ti, Lf, Wf, tf] = lookupSpecimen(specimens, matName)
    best = matchKey(specimens(:, 1), matName);
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

%% Local function: print a table to the Command Window
function printTable(titleStr, cols, T)
    fprintf('\n%s\n', titleStr);
    T = [cols; T];
    w = max(cellfun(@numel, T), [], 1);
    for i = 1:size(T, 1)
        for j = 1:size(T, 2)
            fprintf('  %-*s', w(j), T{i, j});
        end
        fprintf('\n');
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
