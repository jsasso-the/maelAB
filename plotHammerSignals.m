% PLOTHAMMERSIGNALS  Four subplots of the hammer test for one beam length:
%   top row:    voltage vs. time       (hammer input, beam output)
%   bottom row: amplitude vs. frequency (hammer input, beam output)
%
% HOW TO USE: paste this whole script into a new MATLAB script (any name that
% is not a MATLAB function name, e.g. plotHammerSignals.m), type the beam
% length (16, 20 or 24) under "CHOOSE THE LENGTH" below, and press Run.
%
% Files used (found automatically in <mainFolder>\Vibrations datasets\<groupFolder>):
%   time series : ..._hammer_<L>_<exp>fft.txt   col 1 = time [s]
%   frequency   : ..._hammer_<L>_<exp>dat.txt   col 1 = frequency [Hz]
%   In both files col 2 = beam output (accelerometer at the free end) and
%   col 3 = hammer input (instrumented hammer).

clear; clc; close all;

%% ===================== CHOOSE THE LENGTH =====================
beamLength = 16;               % beam length [in]: 16, 20 or 24

%% ===================== USER SETTINGS =====================
experiment = 'a';              % hammer run to plot: 'a' or 'b'

% ---- Folder structure ----
mainFolder    = 'C:\Users\jsasso\OneDrive - Syracuse University\MAE Vibrations';
zipName       = 'Vibrations datasets.zip';   % zip file inside mainFolder
datasetFolder = 'Vibrations datasets';       % folder inside the zip
groupFolder   = 'M003';                      % group folder inside datasetFolder

% ---- Axis limits ([] = automatic) ----
timeLim = [];                  % [tmin tmax] in s; [] = whole record
freqLim = [0 250];             % [fmin fmax] in Hz; [] = up to the Nyquist frequency (1500 Hz)

% ---- Units shown on the y-axes (as written in the file headers) ----
voltUnit = 'V\times10^2';
%% =========================================================

if ~ismember(beamLength, [16 20 24])
    error('Length must be 16, 20 or 24 (inches).');
end
experiment = lower(char(experiment));

%% Locate the files
dataDir  = findDataFolder(mainFolder, zipName, datasetFolder, groupFolder);
timeFile = findDataFile(dataDir, 'fft', beamLength, experiment);
freqFile = findDataFile(dataDir, 'dat', beamLength, experiment);
fprintf('Time series: %s\nFrequency  : %s\n', timeFile, freqFile);

%% Read the data (1 header line, tab-delimited)
T = readmatrix(timeFile, 'FileType', 'text', 'NumHeaderLines', 1, 'Delimiter', '\t');
t      = T(:,1);
vOut_t = T(:,2);               % beam output
vIn_t  = T(:,3);               % hammer input

F = readmatrix(freqFile, 'FileType', 'text', 'NumHeaderLines', 1, 'Delimiter', '\t');
last   = find(any(F(:,2:3) ~= 0, 2), 1, 'last');   % drop zero padding above Nyquist
f      = F(1:last, 1);
aOut_f = F(1:last, 2);         % beam output
aIn_f  = F(1:last, 3);         % hammer input

if isempty(timeLim), timeLim = [t(1) t(end)]; end
if isempty(freqLim), freqLim = [0 f(end)]; end

%% Hammer strike and first-mode peak (for the labels)
[vHit, iHit] = max(vIn_t);
inBand = find(f >= max(freqLim(1), 2) & f <= freqLim(2));   % skip the DC drift below 2 Hz
[aPk, k] = max(aOut_f(inBand));
fPk = f(inBand(k));
fprintf('Hammer strike at t = %.4f s (peak %.3g %s)\n', t(iHit), vHit, strrep(voltUnit, '\times', 'x'));
fprintf('Largest output peak in the frequency window: %.3g at %.2f Hz\n', aPk, fPk);

%% Plot: 2 x 2 subplots
[~, tName, tExt] = fileparts(timeFile);
[~, fName, fExt] = fileparts(freqFile);
blue = [0 0.3 0.7];
red  = [0.85 0.1 0.1];

fig = figure('Name', sprintf('Hammer test, %d in', beamLength), 'NumberTitle', 'off');
fig.Position = [80 80 1300 800];
tl = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Hammer Test: %d in Beam, Experiment %s', beamLength, upper(experiment)));

% --- 1: input voltage vs. time ---
nexttile;
plot(t, vIn_t, 'Color', red, 'LineWidth', 1);
hold on;
plot(t(iHit), vHit, 'kv', 'MarkerFaceColor', 'k');
text(t(iHit), vHit, sprintf('  strike, t = %.3f s', t(iHit)), 'VerticalAlignment', 'top');
hold off;
xlabel('Time (s)');
ylabel(['Voltage (' voltUnit ')']);
title('Input (Hammer): Voltage vs. Time');
subtitle([tName tExt], 'Interpreter', 'none');
xlim(timeLim);
grid on;

% --- 2: output voltage vs. time ---
nexttile;
plot(t, vOut_t, 'Color', blue, 'LineWidth', 1);
xlabel('Time (s)');
ylabel(['Voltage (' voltUnit ')']);
title('Output (Beam): Voltage vs. Time');
subtitle([tName tExt], 'Interpreter', 'none');
xlim(timeLim);
grid on;

% --- 3: input amplitude vs. frequency ---
nexttile;
plot(f, aIn_f, 'Color', red, 'LineWidth', 1);
xlabel('Frequency (Hz)');
ylabel(['Amplitude (' voltUnit ')']);
title('Input (Hammer): Amplitude vs. Frequency');
subtitle([fName fExt], 'Interpreter', 'none');
xlim(freqLim);
grid on;

% --- 4: output amplitude vs. frequency ---
nexttile;
plot(f, aOut_f, 'Color', blue, 'LineWidth', 1);
hold on;
plot(fPk, aPk, 'kv', 'MarkerFaceColor', 'k');
text(fPk, aPk, sprintf('  %.2f Hz', fPk), 'VerticalAlignment', 'bottom');
hold off;
xlabel('Frequency (Hz)');
ylabel(['Amplitude (' voltUnit ')']);
title('Output (Beam): Amplitude vs. Frequency');
subtitle([fName fExt], 'Interpreter', 'none');
xlim(freqLim);
grid on;

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
