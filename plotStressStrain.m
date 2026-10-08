% Stress-strain curves from MTS .DAT files.
%
% Figure 1: one material (set "material" below) - stress-strain curve with a
%   0.2% offset line, uncertainty bars, yield, ultimate and rupture points,
%   and a table of the lab measurements and results with uncertainties.
% Figure 2: the materials in "compareMaterials" on one plot - every reading
%   (extensometer and MTS displacement where both exist) with its own 0.2%
%   offset line, uncertainty bars and yield point, plus tables comparing the
%   readings, the materials, and published values.
%
% Folder layout:
%   MAE Solids datasets\M003\<material folder>\...\<file>.dat
% The script finds each material folder by name, finds the .dat file inside
% it, reads it, and makes the figures. Enter each specimen's measurements
% once in the "specimens" table.
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
%   true rupture stress  sTR = F_R/Af     dsTR/sTR = sqrt((dF/F)^2 + (dAf/Af)^2)
%   true rupture strain  eTR = ln(Ai/Af)  deTR     = sqrt((dAi/Ai)^2 + (dAf/Af)^2)
%   percent difference   |measured - reference| / reference * 100
clear; clc; close all;

%% ===================== USER SETTINGS =====================
material = 'Steel';            % <-- material for figure 1 (folder inside M003; not case sensitive, partial name works)
compareMaterials = {'Steel', 'Aluminum'};   % <-- materials for figure 2 ({} = no figure 2)

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

% ---- Published values for the percent differences [psi] ----
% Same key matching as the specimens table. NaN = no published value (N/A).
% <-- replace with the alloys / values from your lab handout
published = {
%   keys       name                        yield    ultimate  rupture  Young's modulus
    'steel',   'AISI 1018 cold drawn',     53700,   63800,    NaN,     29.7e6
    'alum',    '6061-T6',                  40000,   45000,    NaN,     10.0e6
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

nErrorBars = 15;               % number of points along each curve that get uncertainty bars
saveFigure = false;            % true = save .png and .fig (figure 1 in the material folder,
                               % figure 2 in the M003 folder)
%% =========================================================

S = struct('baseFolder', baseFolder, 'testFolder', testFolder, 'datFileName', datFileName, ...
    'dimUnc', dimUnc, 'gaugeUnc', gaugeUnc, 'loadUncPct', loadUncPct, 'dispUnc', dispUnc, ...
    'extUnc', extUnc, 'strainSource', strainSource, 'toe', toeCompensation, ...
    'offset', offset, 'fitRange', fitRange, 'breakDrop', breakDrop);
S.specimens = specimens;

%% ================= FIGURE 1: one material =================
M = processMaterial(material, S);
r = M.r;
p = M.p;
e = r.e;  s = r.s;  eUnc = r.eUnc;  sUnc = r.sUnc;
E = r.E;  sY = r.sY;  eY = r.eY;
iU = p.iU;  iR = numel(s);
sU = p.sU;  eU = p.eU;  sR = p.sR;  eR = p.eR;

fig = figure('Name', sprintf('%s stress-strain', M.name), 'NumberTitle', 'off', ...
    'Color', 'w', 'Position', [60 60 1500 700]);
ax = axes(fig, 'Position', [0.05 0.10 0.50 0.82]);
hold(ax, 'on');

hCurve = plot(ax, e, s, '-', 'LineWidth', 1.5, 'Color', [0 0.3 0.6]);

% Uncertainty bars on evenly spaced points along the curve
hErr = drawUncertainty(ax, e, s, eUnc, sUnc, nErrorBars, [0.5 0.5 0.5]);

% 0.2% offset line, from zero stress up to a bit past yield
hOff = gobjects(0);
if isfinite(E) && E > 0
    [eLine, sLine] = offsetLine(r, offset, sU);
    hOff = plot(ax, eLine, sLine, '--', 'LineWidth', 1.2, 'Color', [0.85 0.33 0.1]);
end

% Key points
hY = gobjects(0);
if isfinite(sY)
    hY = plot(ax, eY, sY, 'o', 'MarkerSize', 9, 'LineWidth', 1.5, ...
        'MarkerFaceColor', [0.47 0.67 0.19], 'MarkerEdgeColor', 'k');
    text(ax, eY, sY, sprintf('  Yield (%.4g, %.5g)', eY, sY), ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'left');
end
hU = plot(ax, eU, sU, '^', 'MarkerSize', 9, 'LineWidth', 1.5, ...
    'MarkerFaceColor', [0.93 0.69 0.13], 'MarkerEdgeColor', 'k');
hR = plot(ax, eR, sR, 's', 'MarkerSize', 9, 'LineWidth', 1.5, ...
    'MarkerFaceColor', [0.64 0.08 0.18], 'MarkerEdgeColor', 'k');
if iU == iR                         % brittle: breaks at the ultimate
    text(ax, eU, sU, sprintf('Ultimate = Rupture (%.4g, %.5g)  ', eU, sU), ...
        'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right');
else
    text(ax, eU, sU, sprintf('Ultimate (%.4g, %.5g)', eU, sU), ...
        'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center');
    text(ax, eR, sR, sprintf('Rupture (%.4g, %.5g)  ', eR, sR), ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'right');
end
hold(ax, 'off');

grid(ax, 'on');
box(ax, 'on');
xlabel(ax, sprintf('Axial Strain (%s)', M.eUnit));
ylabel(ax, M.sLabel);
title(ax, sprintf('%s - Stress vs. Strain', M.name), 'Interpreter', 'none');
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

% Results table
if strcmpi(M.shape, 'round')
    dimRows = {'Initial diameter', pm(M.Wi, dimUnc), 'in'
               'Final diameter',   pm(M.Wf, dimUnc), 'in'};
else
    dimRows = {'Initial width',     pm(M.Wi, dimUnc), 'in'
               'Initial thickness', pm(M.ti, dimUnc), 'in'
               'Final width',       pm(M.Wf, dimUnc), 'in'
               'Final thickness',   pm(M.tf, dimUnc), 'in'};
end
rows = [
    {'LAB MEASUREMENTS', '', ''}
    {'Initial gauge length', pm(M.L0, gaugeUnc), 'in'}
    {'Final gauge length',   pm(M.Lf, gaugeUnc), 'in'}
    dimRows
    {'RESULTS', '', ''}
    {'Ultimate stress',          pm(p.sU, p.sUu),  M.sUnit}
    {'Strain at ultimate',       pm(p.eU, p.eUu),  M.eUnit}
    {'Rupture stress',           pm(p.sR, p.sRu),  M.sUnit}
    {'Strain at rupture',        pm(p.eR, p.eRu),  M.eUnit}
    {'Yield stress (0.2%)',      pm(r.sY, r.sYu),  M.sUnit}
    {'Strain at yield',          pm(r.eY, r.eYu),  M.eUnit}
    {'Young''s modulus E',       pm(r.E, r.EUnc),  M.sUnit}
    {'Modulus of toughness',     pm(p.UT, p.UTu),  M.uUnit}
    {'Modulus of resilience',    pm(r.Ur, r.Uru),  M.uUnit}
    ];
uitable(fig, 'Data', rows, 'ColumnName', {'Quantity', 'Value', 'Units'}, ...
    'RowName', [], 'Units', 'normalized', 'Position', [0.58 0.10 0.40 0.82], ...
    'ColumnWidth', {175, 260, 110}, 'FontSize', 11);
printTable(M.name, {'Quantity', 'Value', 'Units'}, rows);

%% ============ FIGURE 2: materials compared on one plot ============
fig2 = [];
if ~isempty(compareMaterials)
    Ms = cellfun(@(m) processMaterial(m, S), compareMaterials, 'UniformOutput', false);
    sUnit2 = Ms{1}.sUnit;
    uUnit2 = Ms{1}.uUnit;

    % every reading: extensometer (if the file has it) and MTS displacement
    R = cell(0, 3);                 % {analyzed curve, legend name, short label}
    for m = 1:numel(Ms)
        if ~isempty(Ms{m}.rX)
            R(end+1, :) = {Ms{m}.rX, [Ms{m}.name ' - extensometer'],     [Ms{m}.name ' ext.']};
        end
        R(end+1, :) = {Ms{m}.rD, [Ms{m}.name ' - MTS displacement'], [Ms{m}.name ' MTS']};
    end
    colors = [0 0.3 0.6; 0.85 0.33 0.1; 0.2 0.6 0.2; 0.5 0.2 0.6; 0.6 0.5 0.1; 0.3 0.3 0.3];

    fig2 = figure('Name', 'Stress-strain comparison', 'NumberTitle', 'off', ...
        'Color', 'w', 'Position', [40 40 1650 820]);
    ax2 = axes(fig2, 'Position', [0.04 0.08 0.43 0.85]);
    hold(ax2, 'on');
    sMax = max(cellfun(@(c) max(c.s), R(:, 1)));
    eMax = max(cellfun(@(c) max(c.e), R(:, 1)));
    h2 = gobjects(0);
    leg2 = {};
    labY = [];                      % heights of the yield labels placed so far
    for q = 1:size(R, 1)
        [rq, nameq, shortq] = R{q, :};
        cq = colors(mod(q - 1, size(colors, 1)) + 1, :);
        h2(end+1) = plot(ax2, rq.e, rq.s, '-', 'LineWidth', 1.5, 'Color', cq);
        leg2{end+1} = nameq;
        h2(end+1) = drawUncertainty(ax2, rq.e, rq.s, rq.eUnc, rq.sUnc, nErrorBars, 0.5*cq + 0.5);
        leg2{end+1} = sprintf('Uncertainty (%s)', shortq);
        if rq.E > 0
            [eLine, sLine] = offsetLine(rq, offset, max(rq.s));
            h2(end+1) = plot(ax2, eLine, sLine, '--', 'LineWidth', 1.2, 'Color', cq);
            leg2{end+1} = sprintf('%g%% offset line (%s)', offset*100, shortq);
        end
        if isfinite(rq.sY)
            h2(end+1) = plot(ax2, rq.eY, rq.sY, 'o', 'MarkerSize', 9, 'LineWidth', 1.5, ...
                'MarkerFaceColor', cq, 'MarkerEdgeColor', 'k');
            leg2{end+1} = sprintf('Yield (%s)', shortq);
            % label just below the yield point, stepped further down only
            % if it would overlap a label already placed
            yLab = rq.sY - 0.04*sMax;
            while any(abs(labY - yLab) < 0.06*sMax)
                yLab = yLab - 0.06*sMax;
            end
            labY(end+1) = yLab;
            text(ax2, rq.eY, yLab, sprintf('   Yield, %s (%.4g, %.5g)', shortq, rq.eY, rq.sY), ...
                'VerticalAlignment', 'top', 'HorizontalAlignment', 'left', 'Color', cq, ...
                'Interpreter', 'none', 'BackgroundColor', 'w', 'Margin', 1);
        end
    end
    hold(ax2, 'off');
    grid(ax2, 'on');
    box(ax2, 'on');
    xlabel(ax2, 'Axial Strain (in/in)');
    ylabel(ax2, Ms{1}.sLabel);
    title(ax2, ['Stress vs. Strain - ' strjoin(cellfun(@(c) c.name, Ms, 'UniformOutput', false), ' vs. ')], ...
        'Interpreter', 'none');
    xlim(ax2, [0, 1.05*eMax]);
    ylim(ax2, [0, 1.12*sMax]);
    legend(ax2, h2, leg2, 'Location', 'southeast', 'Interpreter', 'none');

    pdTxt = @(x, ref) pctDiff(x, ref);

    % ---- Table 1: each reading ----
    cols1 = {'Quantity'};
    T1 = {['Young''s modulus E (' sUnit2 ')']; ['Yield stress, 0.2% (' sUnit2 ')']; ...
          'Yield strain (in/in)'; ['Modulus of resilience (' uUnit2 ')']};
    for m = 1:numel(Ms)
        rD = Ms{m}.rD;
        colD = {pm(rD.E, rD.EUnc); pm(rD.sY, rD.sYu); pm(rD.eY, rD.eYu); pm(rD.Ur, rD.Uru)};
        if ~isempty(Ms{m}.rX)
            rX = Ms{m}.rX;
            colX = {pm(rX.E, rX.EUnc); pm(rX.sY, rX.sYu); pm(rX.eY, rX.eYu); pm(rX.Ur, rX.Uru)};
            colP = {pdTxt(rD.E, rX.E); pdTxt(rD.sY, rX.sY); pdTxt(rD.eY, rX.eY); ''};
            cols1 = [cols1, {[Ms{m}.name ' - extensometer'], [Ms{m}.name ' - MTS'], '% diff (MTS vs ext.)'}];
            T1 = [T1, colX, colD, colP];
        else
            cols1 = [cols1, {[Ms{m}.name ' - MTS']}];
            T1 = [T1, colD];
        end
    end

    % ---- Table 2: materials and published values ----
    % ultimate, rupture and toughness from the MTS displacement curve (the
    % extensometer comes off before the ultimate); yield and E from the
    % extensometer when the file has it, MTS displacement otherwise
    labels2 = {['Ultimate stress (' sUnit2 ')']; 'Strain at ultimate (in/in)'; ...
               ['Rupture stress (' sUnit2 ')']; 'Strain at rupture (in/in)'; ...
               ['True rupture stress (' sUnit2 ')']; 'True rupture strain (in/in)'; ...
               ['Yield stress, 0.2% (' sUnit2 ')']; ['Young''s modulus E (' sUnit2 ')']; ...
               ['Modulus of toughness (' uUnit2 ')']};
    pubCol = [2 0 3 0 0 0 1 4 0];   % column of "published" each row compares to (0 = none)
    cols2 = {'Quantity'};
    T2 = labels2;
    pubNames = {};
    for m = 1:numel(Ms)
        Mm = Ms{m};
        pD = Mm.pD;
        if ~isempty(Mm.rX), best = Mm.rX; else, best = Mm.rD; end
        vals = [pD.sU pD.sUu; pD.eU pD.eUu; pD.sR pD.sRu; pD.eR pD.eRu; ...
                Mm.sTR Mm.sTRu; Mm.eTR Mm.eTRu; best.sY best.sYu; best.E best.EUnc; pD.UT pD.UTu];
        [pub, pubName] = lookupPublished(published, Mm.name);
        if ~isempty(pubName), pubNames{end+1} = sprintf('%s = %s', Mm.name, pubName); end
        colV = cell(numel(labels2), 1);
        colPub = repmat({''}, numel(labels2), 1);
        colPd  = repmat({''}, numel(labels2), 1);
        for k = 1:numel(labels2)
            colV{k} = pm(vals(k, 1), vals(k, 2));
            if pubCol(k) > 0
                ref = pub(pubCol(k));
                if isfinite(ref)
                    colPub{k} = sprintf('%g', ref);
                    colPd{k}  = pdTxt(vals(k, 1), ref);
                else
                    colPub{k} = 'N/A';
                end
            end
        end
        cols2 = [cols2, {Mm.name, 'Published', '% diff'}];
        T2 = [T2, colV, colPub, colPd];
    end

    uicontrol(fig2, 'Style', 'text', 'Units', 'normalized', 'Position', [0.49 0.93 0.50 0.03], ...
        'String', 'Table 1 - Each reading', 'FontWeight', 'bold', 'FontSize', 11, ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
    uitable(fig2, 'Data', T1, 'ColumnName', cols1, 'RowName', [], 'Units', 'normalized', ...
        'Position', [0.49 0.70 0.50 0.23], 'FontSize', 10, ...
        'ColumnWidth', [{210}, repmat({150}, 1, numel(cols1) - 1)]);
    uicontrol(fig2, 'Style', 'text', 'Units', 'normalized', 'Position', [0.49 0.64 0.50 0.03], ...
        'String', 'Table 2 - Materials and published values', 'FontWeight', 'bold', 'FontSize', 11, ...
        'BackgroundColor', 'w', 'HorizontalAlignment', 'left');
    uitable(fig2, 'Data', T2, 'ColumnName', cols2, 'RowName', [], 'Units', 'normalized', ...
        'Position', [0.49 0.22 0.50 0.42], 'FontSize', 10, ...
        'ColumnWidth', [{210}, repmat({140, 80, 65}, 1, numel(Ms))]);
    note = {['Ultimate, rupture and toughness use the MTS displacement strain; yield and E use ' ...
             'the extensometer where the file has it.'], ...
            'True rupture: stress = rupture load / final area, strain = ln(initial area / final area).', ...
            'Percent difference = |measured - reference| / reference x 100 (reference: extensometer or published).', ...
            ['Published: ' strjoin(pubNames, '; ')]};
    uicontrol(fig2, 'Style', 'text', 'Units', 'normalized', 'Position', [0.49 0.06 0.50 0.14], ...
        'String', note, 'FontSize', 9, 'BackgroundColor', 'w', 'HorizontalAlignment', 'left');

    printTable('Table 1 - Each reading', cols1, T1);
    printTable('Table 2 - Materials and published values', cols2, T2);
end

if saveFigure
    outBase = fullfile(M.path, [M.name '_stress_strain']);
    saveas(fig, [outBase '.png']);
    savefig(fig, [outBase '.fig']);
    fprintf('Saved %s.png and .fig\n', outBase);
    if ~isempty(fig2)
        outBase2 = fullfile(fileparts(Ms{1}.path), 'comparison_stress_strain');
        saveas(fig2, [outBase2 '.png']);
        savefig(fig2, [outBase2 '.fig']);
        fprintf('Saved %s.png and .fig\n', outBase2);
    end
end

%% Local function: find, read and analyze one material
% Returns a struct with the specimen measurements, units, and three
% analyzed curves: r (best strain: extensometer, then displacement),
% rD (MTS displacement only) and rX (extensometer only, [] if none), plus
% ultimate/rupture/toughness (p for r, pD for rD) and the true rupture point.
function M = processMaterial(material, S)
    base     = resolveBaseFolder(S.baseFolder);
    testPath = findSubfolder(base, S.testFolder);
    M.path   = findSubfolder(testPath, material);
    [~, M.name] = fileparts(M.path);
    M.datFile = findDatFile(M.path, S.datFileName);
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

%% Local function: 0.2% offset line from zero stress to a bit past yield
function [eLine, sLine] = offsetLine(r, offset, sMax)
    if isfinite(r.sY), sTop = 1.15*r.sY; else, sTop = sMax; end
    sLine = [0 sTop];
    eLine = (sLine - r.b)/r.E + offset;
end

%% Local function: uncertainty bars on evenly spaced points along a curve
function h = drawUncertainty(ax, e, s, eUnc, sUnc, n, color)
    ib = unique(round(linspace(1, numel(e), min(n, numel(e)))));
    h  = errorbar(ax, e(ib), s(ib), sUnc(ib), sUnc(ib), eUnc(ib), eUnc(ib), 'LineStyle', 'none', ...
        'Color', color, 'CapSize', 4);
end

%% Local function: percent difference text, |x - ref| / ref * 100
function str = pctDiff(x, ref)
    if isfinite(x) && isfinite(ref) && ref ~= 0
        str = sprintf('%.1f%%', abs(x - ref)/abs(ref)*100);
    else
        str = 'N/A';
    end
end

%% Local function: row of a key table whose key appears in the folder name
% Case, spaces and punctuation are ignored; '|' separates alternative keys.
% Returns 0 if no key matches.
function best = matchKey(keys, folderName)
    norm = @(x) regexprep(lower(x), '[^a-z0-9|]', '');
    folder = norm(folderName);
    best = 0;
    bestLen = 0;
    for r = 1:numel(keys)
        for key = strsplit(norm(keys{r}), '|')
            if ~isempty(key{1}) && contains(folder, key{1}) && numel(key{1}) > bestLen
                best = r;
                bestLen = numel(key{1});
            end
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

%% Local function: published [yield ultimate rupture E] for a material folder
function [vals, name] = lookupPublished(published, matName)
    vals = nan(1, 4);
    name = '';
    best = matchKey(published(:, 1), matName);
    if best > 0
        name = published{best, 2};
        vals = [published{best, 3:6}];
    end
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
