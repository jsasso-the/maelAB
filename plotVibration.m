function plotVibration(fileType, beamLength, experiment)
% PLOTVIBRATION  Amplitude vs. frequency plot (with uncertainties and a
% scaled theoretical curve) for one file of the cantilever-beam vibration lab.
%
%   plotVibration('dat',    16, 'a')   % hammer test, frequency file  (..._16_adat.txt)
%   plotVibration('fft',    20, 'b')   % hammer test, time-series file (..._20_bfft.txt)
%   plotVibration('shaker', 24, 'a')   % shaker test                  (Shaker24_inch_A.txt)
%   plotVibration                      % uses the defaults in USER SETTINGS below
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
% Theoretical curve:
%   R(w)  = 1 / sqrt((1 - r^2)^2 + (2*zeta*r)^2),   r = w/wn
%   theo  = R .* w.^2 .* (max measured response / max(R .* w.^2))

%% ===================== USER SETTINGS =====================
% ---- Defaults used when the function is called without inputs ----
defaultType       = 'dat';     % 'dat', 'fft' or 'shaker'
defaultLength     = 16;        % hammer/beam length [in]: 16, 20 or 24
defaultExperiment = 'a';       % 'a' or 'b'

% ---- Folder structure ----
mainFolder    = 'C:\Users\jsasso\OneDrive - Syracuse University\MAE Vibrations';
zipName       = 'Vibrations datasets.zip';   % zip file inside mainFolder
datasetFolder = 'Vibrations datasets';       % folder inside the zip
groupFolder   = 'M003';                      % group folder inside datasetFolder

% ---- Theoretical curve ----
% Leave as [] to estimate from the data:
%   hammer: fn = peak of the first mode, zeta = half-power bandwidth
%   shaker: fn and zeta = least-squares fit to the measured points
theoryFn   = [];               % natural frequency [Hz]
theoryZeta = [];               % damping ratio [-]
fnGuess16  = 27.5;             % expected 1st-mode fn of the 16 in beam [Hz]; scaled by (16/L)^2
                               % for other lengths. The peak is searched for in 0.5x-1.5x this.

% ---- Uncertainties ----
ampUncPct      = 5;            % amplitude uncertainty, % of reading (all files)
shakerAmpRes   = 0.0005;       % shaker amplitude resolution (half of last digit, 0.001)
shakerFreqUnc  = 0.5;          % shaker frequency uncertainty [Hz] (half of 1 Hz step)
% Hammer files: frequency uncertainty = half the FFT bin width; the noise floor
% (median of the spectrum) is added in quadrature to the % amplitude uncertainty.
nErrorBars     = 40;           % hammer files: number of points that get error bars

% ---- Plot options ----
freqLim        = [];           % [fmin fmax] in Hz; [] = automatic
showTimeSeries = true;         % 'fft' files: also plot the time series
%% =========================================================

if nargin < 1 || isempty(fileType),   fileType   = defaultType;       end
if nargin < 2 || isempty(beamLength), beamLength = defaultLength;     end
if nargin < 3 || isempty(experiment), experiment = defaultExperiment; end

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
fprintf('Using file: %s\n', filePath);

%% Read the data and build amplitude vs. frequency with uncertainties
fnExpected = fnGuess16 * (16/beamLength)^2;
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
        uA = sqrt(shakerAmpRes^2 + (ampUncPct/100 * A).^2);
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
        uA = sqrt(noiseFloor^2 + (ampUncPct/100 * A).^2);
        ampLabel = 'Amplitude (V\times10^2)';
end

%% Natural frequency, damping and the measured peak
isHammer = ~strcmp(fileType, 'shaker');
if isHammer
    win = find(f >= 0.5*fnExpected & f <= 1.5*fnExpected);
    [Apk, k] = max(A(win));
    iPk = win(k);
    fPk = f(iPk);
    fn   = pickValue(theoryFn,   fPk);
    zeta = pickValue(theoryZeta, halfPowerZeta(f, A, iPk));
    if isempty(freqLim), freqLim = [0 3*fn]; end
else
    [Apk, iPk] = max(A);
    fPk = f(iPk);
    fnFit = [];
    zetaFit = [];
    if isempty(theoryFn) || isempty(theoryZeta)
        [fnFit, zetaFit] = fitShaker(f, A, fPk);
    end
    fn   = pickValue(theoryFn,   fnFit);
    zeta = pickValue(theoryZeta, zetaFit);
    if isempty(freqLim)
        pad = max(2, 0.15*(max(f) - min(f)));
        freqLim = [max(0, min(f) - pad), max(f) + pad];
    end
end

%% Theoretical curve: R*w^2, scaled to the measured maximum
% Extra points around fn so a sharp (lightly damped) peak is not missed
fTheo = linspace(max(freqLim(1), 1e-3), freqLim(2), 2000)';
fTheo = unique([fTheo; fn*(1 + (-5:0.01:5)'*zeta)]);
fTheo = fTheo(fTheo >= freqLim(1) & fTheo <= freqLim(2) & fTheo > 0);
[theo, scale] = theoryCurve(fTheo, fn, zeta, Apk);

fprintf('Natural frequency fn = %.3f Hz, damping ratio zeta = %.4f\n', fn, zeta);
fprintf('Measured peak = %.4g at %.3f Hz, scale factor = %.4g\n', Apk, fPk, scale);

%% Plot
if isHammer
    plotTitle = sprintf('Hammer %s: %d in, experiment %s', upper(fileType), beamLength, upper(experiment));
else
    plotTitle = sprintf('Shaker: %d in, experiment %s', beamLength, upper(experiment));
end

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

hold on;
if isHammer
    inRange = find(f >= freqLim(1) & f <= freqLim(2));
    % Shaded uncertainty band, the measured spectrum, and error bars on a subset
    fill([f(inRange); flipud(f(inRange))], ...
         [A(inRange) + uA(inRange); flipud(max(A(inRange) - uA(inRange), 0))], ...
         [0.6 0.75 0.95], 'EdgeColor', 'none', 'FaceAlpha', 0.5, ...
         'DisplayName', 'Uncertainty band');
    plot(f(inRange), A(inRange), '-', 'Color', [0 0.3 0.7], 'LineWidth', 1.2, ...
         'DisplayName', 'Measured');
    step = max(1, round(numel(inRange)/nErrorBars));
    eb = unique([inRange(1:step:end); iPk]);
    errorbar(f(eb), A(eb), uA(eb), uA(eb), uF(eb), uF(eb), 'o', ...
             'Color', [0 0.3 0.7], 'MarkerSize', 4, 'MarkerFaceColor', [0 0.3 0.7], ...
             'CapSize', 4, 'DisplayName', 'Error bars');
else
    errorbar(f, A, uA, uA, uF, uF, 'o', 'Color', [0 0.3 0.7], ...
             'MarkerSize', 6, 'MarkerFaceColor', [0 0.3 0.7], 'LineWidth', 1.2, ...
             'CapSize', 6, 'DisplayName', 'Measured');
end
plot(fTheo, theo, 'r--', 'LineWidth', 1.5, ...
     'DisplayName', sprintf('Theory (f_n = %.2f Hz, \\zeta = %.4f)', fn, zeta));
hold off;

xlabel('Frequency (Hz)');
ylabel(ampLabel);
if twoTiles
    title('Amplitude vs. Frequency');
else
    title({plotTitle, 'Amplitude vs. Frequency'});
end
subtitle([fName fExt], 'Interpreter', 'none');
xlim(freqLim);
ylim([0, 1.15*max([Apk + uA(iPk); theo])]);
grid on;
legend('Location', 'northeast');
end

%% ===================== Local functions =====================

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

function v = pickValue(userValue, autoValue)
    if isempty(userValue), v = autoValue; else, v = userValue; end
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

function [fn, zeta] = fitShaker(f, A, fPk)
% Least-squares fit of fn and zeta to the shaker points, using the same
% scaling as the plotted theoretical curve.
    fq = linspace(max(0.5*min(f), 1e-3), 1.5*max(f), 3000)';
    p = fminsearch(@cost, [fPk, log(0.03)], optimset('Display', 'off'));
    fn   = p(1);
    zeta = min(max(exp(p(2)), 1e-4), 0.5);

    function c = cost(q)
        if q(1) <= 0, c = Inf; return; end
        z = exp(q(2));
        % Scale over the measured points, a wide grid and points near fn,
        % then compare the model at the measured frequencies
        g = [f; fq; q(1)*(1 + (-5:0.01:5)'*z)];
        g = g(g > 0);
        t = theoryCurve(g, q(1), z, max(A));
        c = sum((A - t(1:numel(f))).^2);
    end
end
