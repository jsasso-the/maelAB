% PLOTVIBRATIONDATA  Amplitude vs. frequency plot (with uncertainties and a
% scaled theoretical curve) for one file of the cantilever-beam vibration lab.
%
% HOW TO USE: paste this whole script into a new MATLAB script (any name that
% is not a MATLAB function name, e.g. plotVibrationData.m), set fileType,
% beamLength, experiment and normalizeFreq under "CHOOSE THE FILE" below,
% and press Run.
%   fileType = 'dat'    -> hammer test, frequency file   (..._16_adat.txt)
%   fileType = 'fft'    -> hammer test, time-series file (..._20_bfft.txt)
%   fileType = 'shaker' -> shaker test                   (Shaker24_inch_A.txt)
%
% The data are found automatically:
%   <mainFolder>\Vibrations datasets.zip  ->  Vibrations datasets\<groupFolder>\<file>.txt
% The zip file is extracted into mainFolder the first time; after that the
% extracted folder is used directly.
%
% File contents (from Instructions.txt):
%   hammer 'dat' : frequency data. col 1 = frequency [Hz], col 2 = beam output, col 3 = hammer input
%   hammer 'fft' : time series.    col 1 = time [s],       col 2 = beam output, col 3 = hammer input
%                  (an FFT of the beam output is taken to get amplitude vs. frequency)
%   shaker       : col 2 = frequency [Hz], col 3 = output amplitude, col 4 ignored
%
% Theory (equation numbers from the Vibrations Lab Procedure):
%   k   = 3*E*I/L^3,  I = b*h^3/12                      cantilever tip stiffness
%   meq = (33/140)*m_beam + m_end                        equivalent (Rayleigh) mass
%   wn  = sqrt(k/meq)  (eq 3),  fn = wn/(2*pi)  (eq 4)
%   zeta from the hammer time series, log decrement (eqs 5, 6)
%   R(w) = 1 / sqrt((1 - r^2)^2 + (2*zeta*r)^2),  r = w/wn
%   theo = R .* w.^2 .* (max measured response / max(R .* w.^2))
%   Normalized plot: x = f / fn,theory (theoretical undamped fn from eqs 3, 4),
%   u_x = sqrt((u_f/fn)^2 + (f*u_fn/fn^2)^2).
%   Measured fn: hammer peak is the damped frequency, wn = wd/sqrt(1-zeta^2) (eq 7);
%                shaker peak is the resonance,       wn = wr/sqrt(1-2*zeta^2) (eq 8).
%
% Sources for values not given in the procedure:
%   [1] MatWeb, AISI 1018 Steel, cold drawn: E = 200 GPa, density = 7.87 g/cc
%       https://matweb.com/search/datasheettext.aspx?matid=6817
%   [2] Total Materia, AISI 1018: E = 190-210 GPa, density = 7.67-7.86 g/cc (used for the uncertainties)
%       https://www.totalmateria.com/en-us/material/1250012
%   [3] NI-9234 Specifications: gain error 0.34 % max (calibrated, 1 year, 5 Vpk range)
%       https://ni.com/docs/en-US/bundle/ni-9234-specs
%   [4] Effective tip mass of a cantilever, Meff = 0.2357*M (= 33/140): US Patent 6,526,835
%       https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/6526835
%   [5] Second-order magnitude ratio: McGill ECSE 304 Lecture 30
%       https://cim.mcgill.ca/~boulet/304-303B/1999/L30.pdf

clear; clc; close all;

%% ===================== CHOOSE THE FILE =====================
fileType      = 'dat';         % 'dat', 'fft' or 'shaker'
beamLength    = 16;            % vibrating beam length [in]: 16, 20 or 24
experiment    = 'a';           % 'a' or 'b'
normalizeFreq = true;          % true:  x-axis = f / fn,theory (normalized frequency)
                               % false: x-axis = frequency in Hz

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

% ---- Theoretical curve ----
theoryFnSource = 'beam';       % 'beam' = fn from beam theory (eqs 3, 4)
                               % 'measured' = fn from the measured peak (eq 7 or 8)
theoryFn   = [];               % override fn [Hz]; [] = use theoryFnSource
theoryZeta = [];               % override zeta;    [] = log decrement of the hammer test
logDecCycles = 10;             % n in eq 6 (number of cycles between peaks)
logDecSkip   = 2;              % peaks skipped right after the hammer strike

% ---- Measurement uncertainties ----
daqGainPct    = 0.34;          % NI 9234 gain error [% of reading]  [3]
accelPct      = 0;             % accelerometer sensitivity uncertainty [%] (add if known)
shakerAmpRes  = 0.0005;        % shaker amplitude resolution (half of last digit, 0.001)
shakerFreqUnc = 0.5;           % shaker frequency [Hz] (frequency typed in 1 Hz steps)
% Hammer files: frequency uncertainty = half the FFT bin width (3 kHz, 8192 samples);
% the noise floor (median of the spectrum) is added in quadrature.
nErrorBars    = 40;            % hammer files: number of points that get error bars

% ---- Plot options ----
freqLim        = [];           % [fmin fmax] in Hz (also when normalized); [] = automatic
showTimeSeries = true;         % 'fft' files: also plot the time series
%% =========================================================

fileType   = lower(char(fileType));
experiment = lower(char(experiment));
if ~ismember(fileType, {'dat', 'fft', 'shaker'})
    error('fileType must be ''dat'', ''fft'' or ''shaker''.');
end
if ~ismember(beamLength, [16 20 24])
    error('Length must be 16, 20 or 24 (inches).');
end
if ~ismember(experiment, {'a', 'b'})
    error('Experiment must be ''a'' or ''b''.');
end

%% Locate the folder and the file
dataDir  = findDataFolder(mainFolder, zipName, datasetFolder, groupFolder);
filePath = findDataFile(dataDir, fileType, beamLength, experiment);
[~, fName, fExt] = fileparts(filePath);
fprintf('\nUsing file: %s\n', filePath);

%% Theoretical natural frequency from the beam properties
[fnBeam, uFnBeam] = beamNaturalFrequency(beamLength, beam);

%% Read the data and build amplitude vs. frequency with uncertainties
relPct = sqrt(daqGainPct^2 + accelPct^2);
isHammer = ~strcmp(fileType, 'shaker');
switch fileType
    case 'shaker'
        M = readmatrix(filePath, 'FileType', 'text', 'NumHeaderLines', 0, 'Delimiter', '\t');
        f = M(:,2);
        A = M(:,3);
        % The last rows can repeat a frequency (leftover data): keep only
        % the first reading at each frequency.
        [~, keep] = unique(f, 'first');
        keep = sort(keep);
        if numel(keep) < numel(f)
            fprintf('Removed %d repeated-frequency row(s).\n', numel(f) - numel(keep));
        end
        f = f(keep);
        A = A(keep);
        uF = shakerFreqUnc * ones(size(f));
        uA = sqrt(shakerAmpRes^2 + (relPct/100 * A).^2);
        ampLabel = 'Output Amplitude';

    otherwise   % hammer test, 'dat' or 'fft'
        M = readmatrix(filePath, 'FileType', 'text', 'NumHeaderLines', 1, 'Delimiter', '\t');
        x = M(:,1);
        y = M(:,2);              % beam output
        if isTimeFile(filePath)
            % Time series: single-sided amplitude spectrum of the beam output
            tSig = x;
            ySig = y;
            dt = mean(diff(x));
            N  = numel(y);
            Y  = fft(y - mean(y));
            P  = abs(Y(1:floor(N/2)+1)) / N;
            P(2:end-1) = 2*P(2:end-1);
            f = (0:floor(N/2))' / (N*dt);
            A = P;
        else
            % Frequency data: drop the zero-padded part above the Nyquist frequency
            last = find(y ~= 0, 1, 'last');
            f = x(1:last);
            A = y(1:last);
        end
        df = f(2) - f(1);
        noiseFloor = median(A(2:end));
        uF = df/2 * ones(size(f));
        uA = sqrt(noiseFloor^2 + (relPct/100 * A).^2);
        ampLabel = 'Amplitude (V\times10^2)';
end

%% Measured peak (first mode)
if isHammer
    % Search near the beam-theory fn so higher modes are not picked up
    win = find(f >= 0.5*fnBeam & f <= 1.5*fnBeam);
    [Apk, k] = max(A(win));
    iPk = win(k);
else
    [Apk, iPk] = max(A);
end
fPk = f(iPk);

%% Damping ratio: log decrement of the hammer time series (eqs 5, 6)
if isempty(theoryZeta)
    [zeta, uZeta, zetaSrc] = dampingFromHammer(dataDir, beamLength, experiment, ...
                                               fnBeam, logDecCycles, logDecSkip);
    if isnan(zeta)
        if isHammer
            zeta = halfPowerZeta(f, A, iPk);
            uZeta = 0;
            zetaSrc = 'half-power bandwidth of this file (log decrement failed)';
        else
            error(['Could not get zeta from the %d in hammer data by log decrement. ' ...
                   'Set theoryZeta in USER SETTINGS.'], beamLength);
        end
    end
else
    zeta = theoryZeta;
    uZeta = 0;
    zetaSrc = 'user setting';
end

%% Measured natural frequency (eq 7 for the hammer, eq 8 for the shaker)
if isHammer
    fnMeas = fPk / sqrt(1 - zeta^2);
else
    fnMeas = fPk / sqrt(1 - 2*zeta^2);
end
uFnMeas = uF(iPk);

%% Natural frequency used for the theoretical curve
if ~isempty(theoryFn)
    fn = theoryFn;  uFn = 0;  fnSrc = 'user setting';
elseif strcmpi(theoryFnSource, 'measured')
    fn = fnMeas;    uFn = uFnMeas;  fnSrc = 'measured peak';
else
    fn = fnBeam;    uFn = uFnBeam;  fnSrc = 'beam theory';
end

%% Frequency range
if isempty(freqLim)
    if isHammer
        freqLim = [0, 3*max(fn, fPk)];
    else
        lo = min([f; fn - uFn]);
        hi = max([f; fn + uFn]);
        pad = max(2, 0.15*(hi - lo));
        freqLim = [max(0, lo - pad), hi + pad];
    end
end

%% X axis: frequency in Hz, or normalized by the theoretical undamped fn
if normalizeFreq
    xScale = fnBeam;
    uX = sqrt((uF/fnBeam).^2 + (f*uFnBeam/fnBeam^2).^2);
    xLabelStr = 'Normalized Frequency  f / f_{n,theory}';
    % The fn,theory uncertainty is already in the horizontal error bars, so the
    % theory band only carries it when the theory curve uses another fn.
    if strcmp(fnSrc, 'beam theory'), uFnBand = 0; else, uFnBand = uFn; end
else
    xScale = 1;
    uX = uF;
    xLabelStr = 'Frequency (Hz)';
    uFnBand = uFn;
end

%% Theoretical curve: R*w^2 scaled to the measured maximum, plus an
%% uncertainty band from fn +/- u_fn and zeta +/- u_zeta
fnSet   = fn + uFnBand*[0 -1 1 -1 1];
zetaSet = max(zeta + uZeta*[0 -1 -1 1 1], 1e-4);
fTheo = linspace(max(freqLim(1), 1e-3), freqLim(2), 2000)';
for i = 1:numel(fnSet)
    % Extra points around each fn so a sharp (lightly damped) peak is not missed
    fTheo = [fTheo; fnSet(i)*(1 + (-5:0.01:5)'*zetaSet(i))]; %#ok<AGROW>
end
fTheo = unique(fTheo(fTheo >= freqLim(1) & fTheo <= freqLim(2) & fTheo > 0));
theoAll = zeros(numel(fTheo), numel(fnSet));
for i = 1:numel(fnSet)
    theoAll(:,i) = theoryCurve(fTheo, fnSet(i), zetaSet(i), Apk);
end
[theo, scale] = theoryCurve(fTheo, fn, zeta, Apk);
theoLo = min(theoAll, [], 2);
theoHi = max(theoAll, [], 2);

%% Results in the command window
pctDiff = 100*(fnMeas - fnBeam)/fnBeam;
fprintf('Theoretical fn (beam)   = %.2f +/- %.2f Hz\n', fnBeam, uFnBeam);
fprintf('Measured peak           = %.4g at %.2f Hz\n', Apk, fPk);
fprintf('Measured fn (eq %d)      = %.2f +/- %.2f Hz  (%+.1f %% vs. theory)\n', ...
        7 + ~isHammer, fnMeas, uFnMeas, pctDiff);
fprintf('Damping ratio zeta      = %.4f +/- %.4f  (%s)\n', zeta, uZeta, zetaSrc);
fprintf('Theory curve: fn = %.2f Hz (%s), scale factor = %.4g\n', fn, fnSrc, scale);
if normalizeFreq
    fprintf('Measured fn / fn,theory = %.3f +/- %.3f\n', fnMeas/fnBeam, ...
            sqrt((uFnMeas/fnBeam)^2 + (fnMeas*uFnBeam/fnBeam^2)^2));
end

%% Plot
if isHammer
    plotTitle = sprintf('Hammer %s: %d in, experiment %s', upper(fileType), beamLength, upper(experiment));
else
    plotTitle = sprintf('Shaker: %d in, experiment %s', beamLength, upper(experiment));
end

if normalizeFreq, plotType = 'Normalized Frequency'; else, plotType = 'Frequency'; end
fig = figure('Name', plotTitle, 'NumberTitle', 'off');
twoTiles = strcmp(fileType, 'fft') && showTimeSeries;
if twoTiles
    fig.Position = [100 100 900 750];
    tl = tiledlayout(2, 1, 'TileSpacing', 'compact');
    title(tl, plotTitle, 'Interpreter', 'none');
    nexttile;
    plot(tSig, ySig, 'LineWidth', 1);
    xlabel('Time (s)');
    ylabel('Beam output (V\times10^2)');
    title('Time Series');
    grid on;
    axis tight;
    nexttile;
else
    fig.Position = [100 100 900 500];
end

blue = [0 0.3 0.7];
red  = [0.85 0.1 0.1];
hold on;
fill([fTheo; flipud(fTheo)]/xScale, [theoHi; flipud(theoLo)], red, 'EdgeColor', 'none', ...
     'FaceAlpha', 0.15, 'DisplayName', 'Theory uncertainty (f_n, \zeta)');
if isHammer
    inRange = find(f >= freqLim(1) & f <= freqLim(2));
    % Shaded uncertainty band, the measured spectrum, and error bars on a subset
    fill([f(inRange); flipud(f(inRange))]/xScale, ...
         [A(inRange) + uA(inRange); flipud(max(A(inRange) - uA(inRange), 0))], ...
         blue, 'EdgeColor', 'none', 'FaceAlpha', 0.25, ...
         'DisplayName', 'Measurement uncertainty');
    plot(f(inRange)/xScale, A(inRange), '-', 'Color', blue, 'LineWidth', 1.2, ...
         'DisplayName', 'Measured');
    step = max(1, round(numel(inRange)/nErrorBars));
    eb = unique([inRange(1:step:end); iPk]);
    errorbar(f(eb)/xScale, A(eb), uA(eb), uA(eb), uX(eb), uX(eb), 'o', ...
             'Color', blue, 'MarkerSize', 4, 'MarkerFaceColor', blue, ...
             'CapSize', 4, 'DisplayName', 'Error bars');
else
    errorbar(f/xScale, A, uA, uA, uX, uX, 'o', 'Color', blue, ...
             'MarkerSize', 6, 'MarkerFaceColor', blue, 'LineWidth', 1.2, ...
             'CapSize', 6, 'DisplayName', 'Measured');
end
plot(fTheo/xScale, theo, '--', 'Color', red, 'LineWidth', 1.5, ...
     'DisplayName', sprintf('Theory (f_n = %.2f Hz, \\zeta = %.4f)', fn, zeta));
hold off;

xlabel(xLabelStr);
ylabel(ampLabel);
if twoTiles
    title(['Amplitude vs. ' plotType]);
else
    title({plotTitle, ['Amplitude vs. ' plotType]});
end
subtitle([fName fExt], 'Interpreter', 'none');
xlim(freqLim/xScale);
ylim([0, 1.15*max([Apk + uA(iPk); theoHi])]);
grid on;
legend('Location', 'northeast');

% Summary box
summary = {sprintf('f_{n,theory} = %.2f \\pm %.2f Hz', fnBeam, uFnBeam), ...
           sprintf('f_{n,measured} = %.2f \\pm %.2f Hz (%+.1f%%)', fnMeas, uFnMeas, pctDiff), ...
           sprintf('\\zeta = %.4f \\pm %.4f', zeta, uZeta)};
if normalizeFreq
    summary{end+1} = sprintf('x-axis divided by f_{n,theory} = %.2f Hz', fnBeam);
end
text(0.02, 0.97, summary, 'Units', 'normalized', 'VerticalAlignment', 'top', ...
     'BackgroundColor', 'w', 'EdgeColor', [0.7 0.7 0.7], 'FontSize', 9);

%% ===================== Local functions =====================

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

function tf = isTimeFile(filePath)
% True if the header line says the first column is time.
    fid = fopen(filePath, 'r');
    header = fgetl(fid);
    fclose(fid);
    tf = startsWith(strtrim(lower(header)), 'time');
end

function zeta = halfPowerZeta(f, A, iPk)
% Damping ratio from the half-power (-3 dB) bandwidth around the peak at iPk.
    h = A(iPk) / sqrt(2);
    i = iPk;
    while i > 1 && A(i) > h, i = i - 1; end
    j = iPk;
    while j < numel(A) && A(j) > h, j = j + 1; end
    % Linear interpolation to where the curve crosses h on each side
    fLo = f(i)   + (h - A(i))   * (f(i+1) - f(i))   / (A(i+1) - A(i));
    fHi = f(j-1) + (h - A(j-1)) * (f(j) - f(j-1))   / (A(j) - A(j-1));
    zeta = (fHi - fLo) / (2 * f(iPk));
end

function [theo, scale] = theoryCurve(fq, fn, zeta, Amax)
% R*w^2 scaled so that its maximum equals the measured maximum Amax.
    w  = 2*pi*fq;
    r  = fq / fn;
    R  = 1 ./ sqrt((1 - r.^2).^2 + (2*zeta*r).^2);
    Rw = R .* w.^2;
    scale = Amax / max(Rw);
    theo  = scale * Rw;
end
