% PLOTFREQUENCYRESPONSE  Frequency response H(f) = output/input of the hammer
% test for one beam length, in one figure with 2 subplots:
%   top:    magnitude |H(f)| vs. frequency
%   bottom: phase lag vs. frequency
%
% HOW TO USE: paste this whole script into a new MATLAB script (any name that
% is not a MATLAB function name, e.g. plotFrequencyResponse.m), type the beam
% length (16, 20 or 24) under "CHOOSE THE LENGTH" below, and press Run.
%
% How H(f) is found:
%   The hammer time-series file (..._hammer_<L>_<exp>fft.txt) has
%   col 1 = time [s], col 2 = beam output (accelerometer), col 3 = hammer input.
%   H(f) = FFT(output) / FFT(input)
%   |H(f)| = magnitude ratio (the same ratio as column 2 / column 3 of the 'dat' file)
%   phase lag = -angle(H) in degrees
%   The output accelerometer measures acceleration a = -w^2 x, which leads the
%   displacement x by 180 deg. With phaseRef = 'displacement' (default) 180 deg is
%   added so the phase lag is that of the beam displacement: 0 deg below
%   resonance, 90 deg at resonance, 180 deg above. With phaseRef = 'acceleration'
%   the raw accelerometer phase lag is shown (-180 deg -> -90 deg -> 0 deg).
%
% Theoretical curve (single degree of freedom, Vibrations Lab Procedure):
%   r = f/fn,  R = 1/sqrt((1 - r^2)^2 + (2*zeta*r)^2)
%   |H|theory = R*w^2 scaled so its maximum equals the measured maximum
%   phase lag theory = atan2(2*zeta*r, 1 - r^2) (displacement; minus 180 deg for acceleration)
%   zeta from the hammer time series, log decrement (eqs 5, 6)
%   fn from the measured peak, fn = fd/sqrt(1 - zeta^2) (eq 7), or from beam theory
%
% Sources for values not given in the procedure:
%   [1] MatWeb, AISI 1018 Steel, cold drawn: E = 200 GPa, density = 7.87 g/cc
%       https://matweb.com/search/datasheettext.aspx?matid=6817
%   [2] Effective tip mass of a cantilever, Meff = 0.2357*M (= 33/140): US Patent 6,526,835
%       https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/6526835

clear; clc; close all;

%% ===================== CHOOSE THE LENGTH =====================
beamLength = 16;               % beam length [in]: 16, 20 or 24

%% ===================== USER SETTINGS =====================
experiment = 'a';              % hammer run to use: 'a' or 'b'

% ---- Folder structure ----
mainFolder    = 'C:\Users\jsasso\OneDrive - Syracuse University\MAE Vibrations';
zipName       = 'Vibrations datasets.zip';   % zip file inside mainFolder
datasetFolder = 'Vibrations datasets';       % folder inside the zip
groupFolder   = 'M003';                      % group folder inside datasetFolder

% ---- Theoretical curve ----
showTheory     = true;         % overlay the single-degree-of-freedom theory
theoryFnSource = 'measured';   % 'measured' = fn from the measured peak (eq 7)
                               % 'beam'     = fn from beam theory (eqs 3, 4)
logDecCycles = 10;             % n in eq 6 (number of cycles between peaks)
logDecSkip   = 2;              % peaks skipped right after the hammer strike

% ---- Beam (measured, carbon steel); used for the beam-theory fn and to
%      locate the first mode ----
lb2kg = 0.45359237;
beam.width       = 0.9985;     % b [in]
beam.thick       = 0.288;      % h [in]
beam.totalMass   = 2.07*lb2kg; % overall beam mass [kg] (2.07 lb)
beam.totalLength = 29.5;       % overall beam length [in]
beam.E           = 200e9;      % Young's modulus [Pa]   [1]
beam.endMass     = 0;          % end mass [kg]

% ---- Phase reference ----
phaseRef = 'displacement';     % 'displacement' (textbook 0 -> 90 -> 180 deg) or 'acceleration'

% ---- Axis limits ([] = automatic: 0 to 3x the first-mode peak) ----
freqLim = [];                  % [fmin fmax] in Hz
%% =========================================================

if ~ismember(beamLength, [16 20 24])
    error('Length must be 16, 20 or 24 (inches).');
end
experiment = lower(char(experiment));

%% Locate and read the hammer time series
dataDir  = findDataFolder(mainFolder, zipName, datasetFolder, groupFolder);
timeFile = findDataFile(dataDir, 'fft', beamLength, experiment);
fprintf('Using file: %s\n', timeFile);
T = readmatrix(timeFile, 'FileType', 'text', 'NumHeaderLines', 1, 'Delimiter', '\t');
t    = T(:,1);
yOut = T(:,2);                 % beam output
xIn  = T(:,3);                 % hammer input

%% Frequency response H(f) = Y(f)/X(f)
N  = numel(t);
dt = mean(diff(t));
Y  = fft(yOut - mean(yOut));
X  = fft(xIn - median(xIn));   % median = baseline of the hammer signal
nH = floor(N/2) + 1;
f  = (0:nH-1)' / (N*dt);
H  = Y(1:nH) ./ X(1:nH);
magH = abs(H);
lag  = -angle(H) * 180/pi;               % lag of the accelerometer signal
if strcmpi(phaseRef, 'displacement')
    lag   = lag + 180;                     % a = -w^2 x: x lags a by 180 deg
    lagLo = -90;                           % plot range [-90, 270)
else
    lagLo = -270;                          % plot range [-270, 90)
end
wrapLag = @(v) mod(v - lagLo, 360) + lagLo;
lag = wrapLag(lag);

%% First-mode peak (searched near the beam-theory fn so higher modes are skipped)
fnBeam = beamNaturalFrequency(beamLength, beam);
win = find(f >= 0.5*fnBeam & f <= 1.5*fnBeam);
[Hpk, k] = max(magH(win));
iPk = win(k);
fPk = f(iPk);
if isempty(freqLim), freqLim = [0, 3*fPk]; end

%% Damping ratio (log decrement) and fn for the theory
zeta = logDecrement(t, yOut, xIn, fnBeam, logDecCycles, logDecSkip);
if isnan(zeta) || zeta <= 0
    warning('Log decrement failed for this run; the theoretical curve is not drawn.');
    showTheory = false;
end
if showTheory
    if strcmpi(theoryFnSource, 'beam')
        fn = fnBeam;
    else
        fn = fPk / sqrt(1 - zeta^2);                     % eq 7
    end
    fT = linspace(max(freqLim(1), 1e-3), freqLim(2), 4000)';
    fT = unique([fT; fn*(1 + (-5:0.01:5)'*zeta)]);      % resolve the sharp peak
    fT = fT(fT >= freqLim(1) & fT <= freqLim(2) & fT > 0);
    r  = fT / fn;
    Rw = (2*pi*fT).^2 ./ sqrt((1 - r.^2).^2 + (2*zeta*r).^2);
    magT = Rw * (Hpk / max(Rw));
    lagT = atan2(2*zeta*r, 1 - r.^2) * 180/pi;          % displacement, 0 -> 180 deg
    if ~strcmpi(phaseRef, 'displacement')
        lagT = lagT - 180;                               % acceleration
    end
    lagT = wrapLag(lagT);
end

fprintf('Peak |H| = %.3f at %.2f Hz, phase lag there = %.1f deg\n', Hpk, fPk, lag(iPk));
if showTheory
    fprintf('Theory: fn = %.2f Hz (%s), zeta = %.4f\n', fn, theoryFnSource, zeta);
end

%% Plot: 2 subplots
[~, fName, fExt] = fileparts(timeFile);
blue = [0 0.3 0.7];
red  = [0.85 0.1 0.1];
inR  = f >= freqLim(1) & f <= freqLim(2);

fig = figure('Name', sprintf('Frequency response, %d in', beamLength), 'NumberTitle', 'off');
fig.Position = [100 80 1000 800];
tl = tiledlayout(2, 1, 'TileSpacing', 'compact');
title(tl, sprintf('Frequency Response H(f) = Output / Input: %d in Beam, Experiment %s', ...
                  beamLength, upper(experiment)));
subtitle(tl, [fName fExt], 'Interpreter', 'none');

% --- Magnitude ---
nexttile;
hold on;
plot(f(inR), magH(inR), '-', 'Color', blue, 'LineWidth', 1.2, 'DisplayName', 'Measured');
plot(fPk, Hpk, 'kv', 'MarkerFaceColor', 'k', 'HandleVisibility', 'off');
text(fPk, Hpk, sprintf('  %.2f Hz', fPk), 'VerticalAlignment', 'bottom');
if showTheory
    plot(fT, magT, '--', 'Color', red, 'LineWidth', 1.5, ...
         'DisplayName', sprintf('Theory (f_n = %.2f Hz, \\zeta = %.4f)', fn, zeta));
end
hold off;
xlabel('Frequency (Hz)');
ylabel('|H(f)|');
title('Magnitude of Frequency Response');
xlim(freqLim);
grid on;
legend('Location', 'northeast');

% --- Phase lag ---
nexttile;
hold on;
plot(f(inR), lag(inR), '.-', 'Color', blue, 'LineWidth', 1, 'MarkerSize', 8, ...
     'DisplayName', 'Measured');
if showTheory
    plot(fT, lagT, '--', 'Color', red, 'LineWidth', 1.5, 'DisplayName', 'Theory');
end
yline(lagLo + 180, ':', sprintf('%d^\\circ', lagLo + 180), 'HandleVisibility', 'off');
xline(fPk, ':', sprintf('%.2f Hz', fPk), 'HandleVisibility', 'off');
hold off;
xlabel('Frequency (Hz)');
ylabel('Phase lag (deg)');
title(sprintf('Phase Lag of Output (%s) Relative to Input', lower(phaseRef)));
xlim(freqLim);
ylim([lagLo, lagLo + 360]);
yticks(lagLo:45:lagLo + 360);
grid on;
legend('Location', 'northeast');

%% ===================== Local functions =====================

function fn = beamNaturalFrequency(Lin, beam)
% Natural frequency of the cantilever (equivalent SDOF, eqs 3 and 4):
% k = 3EI/L^3, meq = 33/140 * (L/totalLength)*totalMass + endMass.
    in2m = 0.0254;
    L = Lin*in2m;  b = beam.width*in2m;  h = beam.thick*in2m;
    I = b*h^3/12;
    k = 3*beam.E*I/L^3;
    m = (Lin/beam.totalLength) * beam.totalMass;
    meq = 33/140*m + beam.endMass;
    fn = sqrt(k/meq) / (2*pi);
end

function zeta = logDecrement(t, y, hammer, fnBeam, nCycles, nSkip)
% Keeps only the first mode (FFT band-pass 0.5-1.5 x fnBeam), finds the
% positive peaks after the hammer strike and applies eqs 5 and 6.
    zeta = NaN;
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
