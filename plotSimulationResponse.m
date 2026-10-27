% PLOTSIMULATIONRESPONSE  Frequency response of the simulation runs (Lab Data V):
% one figure per parameter change, each with 2 subplots
%   top:    magnitude of response |H(f)| vs. frequency
%   bottom: phase lag vs. frequency
%
% HOW TO USE: paste this whole script into a new MATLAB script (any name that
% is not a MATLAB function name, e.g. plotSimulationResponse.m), choose the
% parameter under "CHOOSE THE PARAMETER" below, and press Run.
%
% Files: <mainFolder>\Lab Data V\10_8_2026jamesXvY.txt
%   X = run (experiment) number 1-14, Y = 'dat' or 'fft'
%   (small differences in the names, e.g. '20261james 3vdat', are accepted)
%   fft file: col 1 = frequency [Hz], col 2 = magnitude ratio |H(f)|
%   dat file: col 1 = frequency [Hz], col 2 = phase angle [deg] (0 to -180)
%   Phase lag = -(phase angle), so it runs from 0 to 180 deg.
%
% Runs (Vibrations Lab Procedure, section 3):
%   Length (3.1)          : runs 1-3   16, 20, 24 in
%   Damping (3.2)         : runs 4-8   c = 1, 3, 5, 7, 9 kg/s
%   End mass (3.3)        : runs 9-11  0.25, 0.40, 0.65 kg
%   Material (3.4)        : runs 12-14 carbon steel, stainless steel, aluminum

clear; clc; close all;

%% ===================== CHOOSE THE PARAMETER =====================
parameter = 'all';             % 'length', 'damping', 'endmass', 'material' or 'all'

% Or plot any runs you choose on one figure (leave [] to use 'parameter'):
customRuns = [];               % e.g. [4 6 8]

%% ===================== USER SETTINGS =====================

% ---- Folder structure ----
mainFolder = 'C:\Users\jsasso\OneDrive - Syracuse University\MAE Vibrations';
dataFolder = 'Lab Data V';                 % folder inside mainFolder
zipName    = 'Lab Data V.zip';             % used only if the folder is missing

% ---- Which file type (Y) holds which quantity ----
magType   = 'fft';             % file with the magnitude |H(f)|
phaseType = 'dat';             % file with the phase angle [deg]

% ---- Runs (X) in each parameter group, and their legend labels ----
groups = struct( ...
  'key',   {'length', 'damping', 'endmass', 'material'}, ...
  'title', {'Varying Beam Length', 'Varying Damping Coefficient', ...
            'Varying End Mass', 'Varying Material'}, ...
  'runs',  {[1 2 3], [4 5 6 7 8], [9 10 11], [12 13 14]}, ...
  'labels', {{'L = 16 in', 'L = 20 in', 'L = 24 in'}, ...
             {'c = 1 kg/s', 'c = 3 kg/s', 'c = 5 kg/s', 'c = 7 kg/s', 'c = 9 kg/s'}, ...
             {'m_{end} = 0.25 kg', 'm_{end} = 0.40 kg', 'm_{end} = 0.65 kg'}, ...
             {'Carbon steel', 'Stainless steel', 'Aluminum'}});

% ---- Plot options ----
logMagnitude = true;           % true: log scale for |H(f)| (runs differ a lot in size)
freqLim      = [];             % [fmin fmax] in Hz for every figure; [] = automatic
%% =========================================================

%% Locate the data folder
dataDir = findDataFolder(mainFolder, dataFolder, zipName);

%% Decide which figures to make
if ~isempty(customRuns)
    % Label each chosen run with its case name from the groups table
    allRuns   = [groups.runs];
    allLabels = [groups.labels];
    customLabels = cell(size(customRuns));
    for i = 1:numel(customRuns)
        j = find(allRuns == customRuns(i), 1);
        if isempty(j)
            customLabels{i} = sprintf('Run %d', customRuns(i));
        else
            customLabels{i} = allLabels{j};
        end
    end
    figs = struct('title', 'Selected Runs', 'runs', customRuns, 'labels', {customLabels});
else
    parameter = lower(char(parameter));
    if strcmp(parameter, 'all')
        figs = groups;
    else
        figs = groups(strcmp({groups.key}, parameter));
        if isempty(figs)
            error('parameter must be ''length'', ''damping'', ''endmass'', ''material'' or ''all''.');
        end
    end
end

%% One figure per parameter
colors = lines(7);
for g = 1:numel(figs)
    runs   = figs(g).runs;
    labels = figs(g).labels;

    fig = figure('Name', figs(g).title, 'NumberTitle', 'off');
    fig.Position = [60 + 40*g, 60 + 30*g, 1000, 800];
    tl = tiledlayout(2, 1, 'TileSpacing', 'compact');
    title(tl, ['Simulation Frequency Response: ' figs(g).title]);
    axMag = nexttile(1);  hold(axMag, 'on');
    axPh  = nexttile(2);  hold(axPh, 'on');

    fprintf('\n===== %s =====\n', figs(g).title);
    fprintf('%-4s %-20s %-14s %-12s %-16s\n', 'Run', 'Case', 'Peak f [Hz]', 'Peak |H|', 'f at 90 deg [Hz]');
    fMax = 0;
    for i = 1:numel(runs)
        X = runs(i);
        try
            [fM, mag] = readRun(dataDir, X, magType);
            [fP, ph]  = readRun(dataDir, X, phaseType);
        catch err
            warning('Run %d skipped: %s', X, err.message);
            continue;
        end
        lag = -ph;                                   % phase lag, 0 -> 180 deg
        [pk, k] = max(mag);
        f90 = interp1(lag + (1:numel(lag))'*1e-9, fP, 90);   % tiny ramp keeps x unique
        fMax = max(fMax, max([fM; fP]));
        col = colors(mod(i-1, size(colors,1)) + 1, :);
        name = labels{i};                            % e.g. 'L = 16 in', 'Aluminum'

        plot(axMag, fM, mag, '-', 'Color', col, 'LineWidth', 1.4, 'DisplayName', name);
        plot(axMag, fM(k), pk, 'v', 'Color', col, 'MarkerFaceColor', col, 'HandleVisibility', 'off');
        plot(axPh, fP, lag, '-', 'Color', col, 'LineWidth', 1.4, 'DisplayName', name);

        fprintf('%-4d %-20s %-14.2f %-12.4g %-16.2f\n', X, strrep(labels{i}, '_{end}', '_end'), ...
                fM(k), pk, f90);
    end
    hold(axMag, 'off');
    hold(axPh, 'off');

    if isempty(freqLim), xl = [0 fMax]; else, xl = freqLim; end

    xlabel(axMag, 'Frequency (Hz)');
    ylabel(axMag, '|H(f)|');
    title(axMag, 'Magnitude of Response');
    if logMagnitude, set(axMag, 'YScale', 'log'); end
    xlim(axMag, xl);
    grid(axMag, 'on');
    legend(axMag, 'Location', 'northeast');

    xlabel(axPh, 'Frequency (Hz)');
    ylabel(axPh, 'Phase lag (deg)');
    title(axPh, 'Phase Angle');
    yline(axPh, 90, ':', '90^\circ', 'HandleVisibility', 'off');
    xlim(axPh, xl);
    ylim(axPh, [0 180]);
    yticks(axPh, 0:30:180);
    grid(axPh, 'on');
    legend(axPh, 'Location', 'southeast');
end

%% ===================== Local functions =====================

function dataDir = findDataFolder(mainFolder, dataFolder, zipName)
% Returns <mainFolder>\<dataFolder>, extracting <zipName> into it if the
% folder does not exist yet.
    if ~isfolder(mainFolder)
        error('Main folder not found: %s', mainFolder);
    end
    dataDir = fullfile(mainFolder, dataFolder);
    if isfolder(dataDir), return; end

    zipPath = fullfile(mainFolder, zipName);
    if ~isfile(zipPath)
        % Accept other spellings, e.g. 'Lab_Data_V.zip'
        z = dir(fullfile(mainFolder, '*.zip'));
        z = z(contains(lower(regexprep({z.name}, '[_ ]', '')), 'labdatav'));
        if isempty(z)
            error('Neither the folder "%s" nor a Lab Data V zip file was found in %s.', ...
                  dataFolder, mainFolder);
        end
        zipPath = fullfile(mainFolder, z(1).name);
    end
    fprintf('Extracting %s ...\n', zipPath);
    unzip(zipPath, dataDir);
    % If the zip itself contains a folder, use the folder that holds the .txt files
    t = dir(fullfile(dataDir, '**', '*james*.txt'));
    if ~isempty(t)
        dataDir = t(1).folder;
    end
end

function [f, v] = readRun(dataDir, X, Y)
% Reads run X ('dat' or 'fft' file Y): col 1 = frequency, col 2 = value.
% Matches 10_8_2026jamesXvY.txt, also with a space before X or an extra digit
% in the date (e.g. '10_8_20261james 3vdat.txt').
    files = dir(fullfile(dataDir, '*.txt'));
    names = {files.name};
    pattern = sprintf('james\\s*%d\\s*v\\s*%s\\.txt$', X, Y);
    hit = ~cellfun(@isempty, regexpi(names, pattern, 'once'));
    match = names(hit);
    if isempty(match)
        error('No file for run %d, type ''%s'' in %s.', X, Y, dataDir);
    end
    if numel(match) > 1
        fprintf('Several files for run %d %s; using %s\n', X, Y, match{1});
    end
    M = readmatrix(fullfile(dataDir, match{1}), 'FileType', 'text', ...
                   'NumHeaderLines', 1, 'Delimiter', '\t');
    f = M(:,1);
    v = M(:,2);
end
