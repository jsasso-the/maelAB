% PLOTNATURALFREQUENCIES  Undamped natural frequency and resonance frequency
% vs. beam length (16, 20, 24 in), with error bars, for the cantilever-beam
% vibration lab.
%
% HOW TO USE: paste this whole script into a new MATLAB script (any name that
% is not a MATLAB function name, e.g. plotNaturalFrequencies.m), choose the
% experiment letter under "CHOOSE THE DATA" below, and press Run.
%
% What is plotted (equation numbers from the Vibrations Lab Procedure):
%   zeta      : experimental damping ratio from the hammer test, log decrement (eqs 5, 6)
%   Theory    : fn from the beam (k = 3EI/L^3, meq = 33/140 m, eqs 3, 4)
%               fr = fn*sqrt(1 - 2*zeta^2)                 (eq 8)
%   Hammer    : fd = first-mode peak of the hammer 'dat' spectrum
%               fn = fd/sqrt(1 - zeta^2)                   (eq 7)
%               fr = fn*sqrt(1 - 2*zeta^2)                 (eq 8)
%   Shaker    : fr = frequency of the largest shaker output
%               fn = fr/sqrt(1 - 2*zeta^2)                 (eq 8)
% The top panel shows fn and fr; because zeta is small they almost coincide,
% so the bottom panel shows the difference fn - fr.
% Uncertainties are propagated by root-sum-square of each input's
% uncertainty (fn, fd, fr, zeta, beam dimensions, E).
%
% Sources for values not given in the procedure:
%   [1] MatWeb, AISI 1018 Steel, cold drawn: E = 200 GPa, density = 7.87 g/cc
%       https://matweb.com/search/datasheettext.aspx?matid=6817
%   [2] Total Materia, AISI 1018: E = 190-210 GPa, density = 7.67-7.86 g/cc (used for the uncertainties)
%       https://www.totalmateria.com/en-us/material/1250012
%   [3] Effective tip mass of a cantilever, Meff = 0.2357*M (= 33/140): US Patent 6,526,835
%       https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/6526835

clear; clc; close all;

%% ===================== CHOOSE THE DATA =====================
experiment  = 'a';             % 'a' or 'b' (hammer and shaker runs to use)
beamLengths = [16 20 24];      % vibrating beam lengths [in]

%% ===================== USER SETTINGS =====================

% ---- Folder structure ----
mainFolder    = 'C:\Users\jsasso\OneDrive - Syracuse University\MAE Vibrations';
zipName       = 'Vibrations datasets.zip';   % zip file inside mainFolder
datasetFolder = 'Vibrations datasets';       % folder inside the zip
groupFolder   = 'M003';                      % group folder inside datasetFolder

% ---- Beam (measured, carbon steel) ----
lb2kg = 0.45359237;
beam.width       = 0.9985;     % b [in]
beam.thick       = 0.288;      % h [in]
beam.totalMass   = 2.07*lb2kg; % overall beam mass [kg] (2.07 lb)
beam.totalLength = 29.5;       % overall beam length [in]
% Vibrating mass (procedure): m_beam = (L / totalLength) * totalMass.
% Set totalMass = [] to use the density instead.
beam.E         = 200e9;        % Young's modulus [Pa]          [1]
beam.rho       = 7870;         % density [kg/m^3], only used if totalMass = []  [1]
beam.endMass   = 0;            % end mass [kg] (procedure: end-weight = 0)

% ---- Beam uncertainties ----
beam.uLength      = 1/32;      % [in] vibrating length, half of the 1/16 in tape division
beam.uTotalLength = 1/32;      % [in] overall length, same tape
beam.uWidth       = 0.0005;    % [in] half of the 0.001 in caliper division
beam.uThick       = 0.0005;    % [in] half of the 0.001 in caliper division
beam.uTotalMass   = 0.005*lb2kg; % [kg] half of the 0.01 lb scale division
beam.uE           = 10e9;      % [Pa]  half the 190-210 GPa spread  [2]
beam.uRho         = 100;       % [kg/m^3] ~ half the 7.67-7.87 g/cc spread [1,2]

% ---- Damping (hammer test, log decrement) ----
logDecCycles = 10;             % n in eq 6 (number of cycles between peaks)
logDecSkip   = 2;              % peaks skipped right after the hammer strike

% ---- Frequency uncertainties ----
shakerFreqUnc = 0.5;           % shaker frequency [Hz] (frequency typed in 1 Hz steps)
% Hammer: half the FFT bin width (3 kHz, 8192 samples) = 0.18 Hz, read from the file.
%% =========================================================

experiment = lower(char(experiment));
if ~ismember(experiment, {'a', 'b'})
    error('Experiment must be ''a'' or ''b''.');
end
dataDir = findDataFolder(mainFolder, zipName, datasetFolder, groupFolder);

nL = numel(beamLengths);
[zeta, uZeta, fnT, uFnT, frT, uFrT, fnH, uFnH, frH, uFrH, fnS, uFnS, frS, uFrS] = ...
    deal(NaN(1, nL));

for j = 1:nL
    L = beamLengths(j);
    fprintf('\n===== %d in =====\n', L);

    % Theoretical undamped natural frequency (eqs 3, 4)
    [fnT(j), uFnT(j)] = beamNaturalFrequency(L, beam);

    % Experimental damping ratio from the hammer test (eqs 5, 6)
    [zeta(j), uZeta(j), zetaSrc] = dampingFromHammer(dataDir, L, experiment, ...
                                                     fnT(j), logDecCycles, logDecSkip);
    if isnan(zeta(j))
        warning('No usable hammer time series for %d in; skipping this length.', L);
        continue;
    end
    fprintf('zeta = %.4f +/- %.4f  (%s)\n', zeta(j), uZeta(j), zetaSrc);

    % Theory: fr from fn and zeta (eq 8)
    [frT(j), uFrT(j)] = propagate(@(x) x(1)*sqrt(1 - 2*x(2)^2), ...
                                  [fnT(j) zeta(j)], [uFnT(j) uZeta(j)]);

    % Hammer: damped peak -> fn (eq 7) -> fr (eq 8)
    try
        [fd, uFd, src] = hammerPeak(dataDir, L, experiment, fnT(j));
        [fnH(j), uFnH(j)] = propagate(@(x) x(1)/sqrt(1 - x(2)^2), ...
                                      [fd zeta(j)], [uFd uZeta(j)]);
        [frH(j), uFrH(j)] = propagate(@(x) x(1)*sqrt(1 - 2*x(2)^2)/sqrt(1 - x(2)^2), ...
                                      [fd zeta(j)], [uFd uZeta(j)]);
        fprintf('Hammer peak fd = %.3f +/- %.3f Hz  (%s)\n', fd, uFd, src);
    catch err
        warning('Hammer data for %d in skipped: %s', L, err.message);
    end

    % Shaker: resonance peak -> fn (eq 8)
    try
        [frS(j), src] = shakerPeak(dataDir, L, experiment);
        uFrS(j) = shakerFreqUnc;
        [fnS(j), uFnS(j)] = propagate(@(x) x(1)/sqrt(1 - 2*x(2)^2), ...
                                      [frS(j) zeta(j)], [uFrS(j) uZeta(j)]);
        fprintf('Shaker peak fr = %.3f +/- %.3f Hz  (%s)\n', frS(j), uFrS(j), src);
    catch err
        warning('Shaker data for %d in skipped: %s', L, err.message);
    end
end

%% Results table in the command window
fprintf('\n%-6s %-18s %-18s %-18s %-18s %-18s %-18s %-18s\n', 'L [in]', 'zeta', ...
        'fn theory [Hz]', 'fr theory [Hz]', 'fn hammer [Hz]', 'fr hammer [Hz]', ...
        'fn shaker [Hz]', 'fr shaker [Hz]');
for j = 1:nL
    fprintf('%-6d %-18s %-18s %-18s %-18s %-18s %-18s %-18s\n', beamLengths(j), ...
            pm(zeta(j), uZeta(j), 4), pm(fnT(j), uFnT(j), 3), pm(frT(j), uFrT(j), 3), ...
            pm(fnH(j), uFnH(j), 3), pm(frH(j), uFrH(j), 3), ...
            pm(fnS(j), uFnS(j), 3), pm(frS(j), uFrS(j), 3));
end

%% Plot
blue   = [0 0.3 0.7];
red    = [0.85 0.1 0.1];
green  = [0.1 0.55 0.2];
uL     = beam.uLength * ones(1, nL);
dx     = 0.25;                 % small horizontal offsets so the markers don't overlap

fig = figure('Name', 'Natural and resonance frequencies', 'NumberTitle', 'off');
fig.Position = [100 100 900 800];
tl = tiledlayout(2, 1, 'TileSpacing', 'compact');
title(tl, sprintf('Undamped Natural and Resonance Frequencies vs. Beam Length (experiment %s)', ...
                  upper(experiment)));

% --- Top: fn and fr vs. length ---
nexttile;
hold on;
% Continuous beam-theory fn(L) with its uncertainty band
Lc = linspace(min(beamLengths) - 2, max(beamLengths) + 2, 200);
fnC = zeros(size(Lc));  uFnC = zeros(size(Lc));
for i = 1:numel(Lc)
    [fnC(i), uFnC(i)] = beamNaturalFrequency(Lc(i), beam);
end
fill([Lc fliplr(Lc)], [fnC + uFnC, fliplr(fnC - uFnC)], red, 'EdgeColor', 'none', ...
     'FaceAlpha', 0.12, 'DisplayName', 'Theory f_n(L) uncertainty');
plot(Lc, fnC, '-', 'Color', red, 'LineWidth', 1, 'DisplayName', 'Theory f_n(L)');

errorbar(beamLengths - dx, fnT, uFnT, uFnT, uL, uL, 's', 'Color', red, ...
         'MarkerFaceColor', red, 'MarkerSize', 7, 'LineWidth', 1.2, 'DisplayName', 'f_n theory');
errorbar(beamLengths - dx, frT, uFrT, uFrT, uL, uL, 's', 'Color', red, ...
         'MarkerSize', 11, 'LineWidth', 1.2, 'DisplayName', 'f_r theory');
errorbar(beamLengths, fnH, uFnH, uFnH, uL, uL, 'o', 'Color', blue, ...
         'MarkerFaceColor', blue, 'MarkerSize', 7, 'LineWidth', 1.2, 'DisplayName', 'f_n hammer');
errorbar(beamLengths, frH, uFrH, uFrH, uL, uL, 'o', 'Color', blue, ...
         'MarkerSize', 11, 'LineWidth', 1.2, 'DisplayName', 'f_r hammer');
errorbar(beamLengths + dx, fnS, uFnS, uFnS, uL, uL, '^', 'Color', green, ...
         'MarkerFaceColor', green, 'MarkerSize', 7, 'LineWidth', 1.2, 'DisplayName', 'f_n shaker');
errorbar(beamLengths + dx, frS, uFrS, uFrS, uL, uL, '^', 'Color', green, ...
         'MarkerSize', 11, 'LineWidth', 1.2, 'DisplayName', 'f_r shaker');
hold off;
xlabel('Beam Length (in)');
ylabel('Frequency (Hz)');
title('Natural (filled) and Resonance (open) Frequencies');
xticks(beamLengths);
xlim([min(Lc) max(Lc)]);
grid on;
legend('Location', 'northeast');

% --- Bottom: fn - fr, which is too small to see in the top panel ---
nexttile;
dfun = @(x) x(1)*(1 - sqrt(1 - 2*x(2)^2));     % fn - fr in terms of fn and zeta
[dT, uDT, dH, uDH, dS, uDS] = deal(NaN(1, nL));
for j = 1:nL
    if isnan(zeta(j)), continue; end
    [dT(j), uDT(j)] = propagate(dfun, [fnT(j) zeta(j)], [uFnT(j) uZeta(j)]);
    if ~isnan(fnH(j))
        [dH(j), uDH(j)] = propagate(dfun, [fnH(j) zeta(j)], [uFnH(j) uZeta(j)]);
    end
    if ~isnan(fnS(j))
        [dS(j), uDS(j)] = propagate(dfun, [fnS(j) zeta(j)], [uFnS(j) uZeta(j)]);
    end
end
hold on;
errorbar(beamLengths - dx, 1000*dT, 1000*uDT, 1000*uDT, uL, uL, 's', 'Color', red, ...
         'MarkerFaceColor', red, 'MarkerSize', 7, 'LineWidth', 1.2, 'DisplayName', 'Theory');
errorbar(beamLengths, 1000*dH, 1000*uDH, 1000*uDH, uL, uL, 'o', 'Color', blue, ...
         'MarkerFaceColor', blue, 'MarkerSize', 7, 'LineWidth', 1.2, 'DisplayName', 'Hammer');
errorbar(beamLengths + dx, 1000*dS, 1000*uDS, 1000*uDS, uL, uL, '^', 'Color', green, ...
         'MarkerFaceColor', green, 'MarkerSize', 7, 'LineWidth', 1.2, 'DisplayName', 'Shaker');
hold off;
xlabel('Beam Length (in)');
ylabel('f_n - f_r (mHz)');
title('Difference Between Natural and Resonance Frequency  (f_n - f_r = f_n[1 - \surd(1 - 2\zeta^2)])');
xticks(beamLengths);
xlim([min(Lc) max(Lc)]);
grid on;
legend('Location', 'northeast');

%% ===================== Local functions =====================

function s = pm(v, u, nd)
% 'value +/- uncertainty' text for the results table.
    if isnan(v)
        s = '-';
    else
        s = sprintf(sprintf('%%.%df +/- %%.%df', nd, nd), v, u);
    end
end

function [y, uy] = propagate(fun, x, ux)
% y = fun(x) and its uncertainty: root-sum-square of the change in y when
% each input is moved by its own uncertainty.
    y = fun(x);
    dy = zeros(size(x));
    for i = 1:numel(x)
        xi = x;
        xi(i) = x(i) + ux(i);
        dy(i) = fun(xi) - y;
    end
    uy = sqrt(sum(dy.^2));
end

function [fd, uFd, src] = hammerPeak(dataDir, L, expLetter, fnBeam)
% First-mode peak of the hammer 'dat' spectrum (beam output, column 2),
% searched near the beam-theory fn. Uncertainty = half the bin width.
    file = findDataFile(dataDir, 'dat', L, expLetter);
    M = readmatrix(file, 'FileType', 'text', 'NumHeaderLines', 1, 'Delimiter', '\t');
    f = M(:,1);
    A = M(:,2);
    win = find(f >= 0.5*fnBeam & f <= 1.5*fnBeam);
    [~, k] = max(A(win));
    fd  = f(win(k));
    uFd = (f(2) - f(1)) / 2;
    [~, n, e] = fileparts(file);
    src = [n e];
end

function [fr, src] = shakerPeak(dataDir, L, expLetter)
% Frequency of the largest shaker output (column 3). Repeated-frequency rows
% at the end of the file are dropped (first reading kept).
    file = findDataFile(dataDir, 'shaker', L, expLetter);
    M = readmatrix(file, 'FileType', 'text', 'NumHeaderLines', 0, 'Delimiter', '\t');
    f = M(:,2);
    A = M(:,3);
    [~, keep] = unique(f, 'first');
    f = f(keep);
    A = A(keep);
    [~, k] = max(A);
    fr = f(k);
    [~, n, e] = fileparts(file);
    src = [n e];
end

function [fn, uFn] = beamNaturalFrequency(Lin, beam)
% Natural frequency of the cantilever (equivalent SDOF, eqs 3 and 4) and its
% uncertainty by propagating each input's uncertainty (root-sum-square).
    p  = [Lin, beam.width, beam.thick, beam.E, beam.rho];
    up = [beam.uLength, beam.uWidth, beam.uThick, beam.uE, beam.uRho];
    useMass = ~isempty(beam.totalMass);
    if useMass
        p  = [p,  beam.totalMass,  beam.totalLength];
        up = [up, beam.uTotalMass, beam.uTotalLength];
    end
    fn = fnOf(p);
    dfn = zeros(size(p));
    for i = 1:numel(p)
        q = p;
        q(i) = p(i) + up(i);
        dfn(i) = fnOf(q) - fn;
    end
    uFn = sqrt(sum(dfn.^2));

    function f = fnOf(v)
        in2m = 0.0254;
        L = v(1)*in2m;  b = v(2)*in2m;  h = v(3)*in2m;  E = v(4);  rho = v(5);
        I = b*h^3/12;
        k = 3*E*I/L^3;
        if useMass
            m = (v(1)/v(7)) * v(6);
        else
            m = rho*b*h*L;
        end
        meq = 33/140*m + beam.endMass;
        f = sqrt(k/meq) / (2*pi);
    end
end

function [zeta, uZeta, src] = dampingFromHammer(dataDir, L, expLetter, fnBeam, nCycles, nSkip)
% Damping ratio from the log decrement (eqs 5, 6) of the hammer time series.
% Uses the same length and experiment letter; falls back to the other letter.
    zeta = NaN;  uZeta = NaN;  src = '';
    letters = {expLetter, char('a' + 'b' - expLetter)};
    for li = 1:2
        try
            file = findDataFile(dataDir, 'fft', L, letters{li});
        catch
            continue;
        end
        M = readmatrix(file, 'FileType', 'text', 'NumHeaderLines', 1, 'Delimiter', '\t');
        t = M(:,1);
        y = M(:,2);          % beam output
        hm = M(:,3);         % hammer
        [z, uz] = logDecrement(t, y, hm, fnBeam, nCycles, nSkip);
        if ~isnan(z) && z > 0
            zeta = z;  uZeta = uz;
            [~, n, e] = fileparts(file);
            src = ['log decrement of ' n e];
            if li == 2
                fprintf('Note: log decrement of experiment %s was not usable; used %s.\n', ...
                        upper(expLetter), [n e]);
            end
            return;
        end
    end
end

function [zeta, uZeta] = logDecrement(t, y, hammer, fnBeam, nCycles, nSkip)
% Keeps only the first mode (FFT band-pass 0.5-1.5 x fnBeam), finds the
% positive peaks after the hammer strike and applies eqs 5 and 6.
% u_zeta comes from the scatter of the single-cycle decrements.
    zeta = NaN;  uZeta = NaN;
    N  = numel(y);
    dt = mean(diff(t));
    Y  = fft(y - mean(y));
    k  = (0:N-1)';
    fr = min(k, N - k) / (N*dt);
    Y(fr < 0.5*fnBeam | fr > 1.5*fnBeam) = 0;
    yf = real(ifft(Y));

    [~, iHit] = max(hammer);
    pk = find(yf(2:end-1) > yf(1:end-2) & yf(2:end-1) >= yf(3:end) & yf(2:end-1) > 0) + 1;
    pk = pk(pk > iHit);
    pk = pk(nSkip+1:end);
    n = min(nCycles, numel(pk) - 1);
    if n < 2, return; end

    x = yf(pk(1:n+1));
    Delta = log(x(1)/x(n+1)) / n;                          % eq 6
    zeta  = Delta / sqrt((2*pi)^2 + Delta^2);              % eq 5
    perCycle = log(x(1:n) ./ x(2:n+1));
    uDelta = std(perCycle) / sqrt(n);
    uZeta  = uDelta * (2*pi)^2 / ((2*pi)^2 + Delta^2)^1.5; % d(zeta)/d(Delta)
end

function dataDir = findDataFolder(mainFolder, zipName, datasetFolder, groupFolder)
% Returns <mainFolder>\<datasetFolder>\<groupFolder>, extracting the zip first if needed.
    if ~isfolder(mainFolder)
        error('Main folder not found: %s', mainFolder);
    end
    dataDir = fullfile(mainFolder, datasetFolder, groupFolder);
    if isfolder(dataDir), return; end

    zipPath = fullfile(mainFolder, zipName);
    if ~isfile(zipPath)
        % Accept other spellings, e.g. 'Vibrations_datasets.zip'
        z = dir(fullfile(mainFolder, '*.zip'));
        z = z(contains(lower({z.name}), 'vibration'));
        if isempty(z)
            error('Neither the folder %s nor a vibrations zip file was found in %s.', ...
                  fullfile(datasetFolder, groupFolder), mainFolder);
        end
        zipPath = fullfile(mainFolder, z(1).name);
    end
    fprintf('Extracting %s ...\n', zipPath);
    unzip(zipPath, mainFolder);
    if isfolder(dataDir), return; end

    % The zip may contain differently named folders: search for the group folder
    d = dir(fullfile(mainFolder, '**'));
    d = d([d.isdir] & strcmpi({d.name}, groupFolder));
    if isempty(d)
        error('Folder %s not found inside %s.', groupFolder, zipPath);
    end
    dataDir = fullfile(d(1).folder, d(1).name);
end

function filePath = findDataFile(dataDir, fileType, L, expLetter)
% Finds the .txt file for the given type, length and experiment letter.
% M003 names: 10_8_2026m003_hammer_16_adat.txt / _afft.txt, Shaker16_inch_A.txt.
% Other groups' spellings (hammer16inadat, shaker16inchA, ...) are also accepted.
    files = dir(fullfile(dataDir, '*.txt'));
    names = {files.name};
    if strcmp(fileType, 'shaker')
        pattern = sprintf('^shaker?_?%d\\D*%s\\.txt$', L, expLetter);
    else
        pattern = sprintf('hammer\\D*%d\\D.*%s%s\\.txt$', L, expLetter, fileType);
    end
    hit = ~cellfun(@isempty, regexpi(names, pattern, 'once'));
    match = names(hit);
    if isempty(match)
        error('No %s file for %d in, experiment %s, found in %s.', fileType, L, upper(expLetter), dataDir);
    end
    if numel(match) > 1
        % Prefer the shortest name (e.g. Shaker16_inch_A over Shaker16NEW_inch_A)
        [~, order] = sort(cellfun(@numel, match));
        match = match(order);
        fprintf('Several files match; using the first:\n');
        fprintf('  %s\n', match{:});
    end
    filePath = fullfile(dataDir, match{1});
end
