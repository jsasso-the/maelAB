% Asks for an experiment number, then plots in one figure window:
%   Top:    Time vs. Voltage       (from 9_17_2026jamesXdat.txt)
%   Bottom: Frequency vs. Voltage  (from 9_17_2026jamesXfft.txt)
% Axes start autoscaled to the data; you can then type min/max values to
% change any axis (press Enter to keep the current value).
% Each file: tab-delimited, 1 header line, 2 columns.
clear; clc; close all;

%% ===================== USER SETTINGS =====================
% Folder containing the .txt files. If it doesn't exist, the script looks
% for a "MAE Matlab" folder next to this script / in the current folder.
dataFolder = 'C:\Users\jsasso\OneDrive - Syracuse University\MAE Matlab';
%% =========================================================

dataFolder = findDataFolder(dataFolder);

%% Ask which experiment to plot
expNum = [];
while isempty(expNum) || ~isscalar(expNum) || expNum < 0 || expNum ~= round(expNum)
    expNum = input('Enter the experiment number to plot: ');
end

prefix  = sprintf('9_17_2026james%d', expNum);
datFile = fullfile(dataFolder, [prefix 'dat.txt']);
fftFile = fullfile(dataFolder, [prefix 'fft.txt']);
if ~isfile(datFile), error('DAT file not found: %s', datFile); end
if ~isfile(fftFile), error('FFT file not found: %s', fftFile); end

%% Read data (1 header line, tab-delimited)
datData = readmatrix(datFile, 'NumHeaderLines', 1, 'Delimiter', '\t');
fftData = readmatrix(fftFile, 'NumHeaderLines', 1, 'Delimiter', '\t');
t  = datData(:,1);   % time [s]
vt = datData(:,2);   % voltage [V]
f  = fftData(:,1);   % frequency [Hz]
vf = fftData(:,2);   % voltage [V]

%% Plot both in the same figure window
fig = figure('Name', sprintf('Experiment %d', expNum), 'NumberTitle', 'off', ...
             'Position', [100 100 900 700]);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact');
title(tl, sprintf('Experiment %d', expNum));

axTime = nexttile(tl);
plot(axTime, t, vt, 'LineWidth', 1.2);
xlabel(axTime, 'Time (s)');
ylabel(axTime, 'Voltage (V)');
title(axTime, 'Time vs. Voltage');
grid(axTime, 'on');
xlim(axTime, dataLimits(t));
ylim(axTime, dataLimits(vt));

axFreq = nexttile(tl);
plot(axFreq, f, vf, 'LineWidth', 1.2);
xlabel(axFreq, 'Frequency (Hz)');
ylabel(axFreq, 'Voltage (V)');
title(axFreq, 'Frequency vs. Voltage');
grid(axFreq, 'on');
xlim(axFreq, dataLimits(f));
ylim(axFreq, dataLimits(vf));

drawnow;   % show the default-scaled plots before asking about limits

%% Let the user change the axis limits
fprintf('\nThe plots are shown with default (autoscaled) axes.\n');
while true
    choice = lower(strtrim(input('Edit axis limits? (y/n): ', 's')));
    if ~strcmp(choice, 'y'), break; end

    fprintf('\n--- Time vs. Voltage plot ---\n');
    editLimits(axTime, 'x', 'Time (s)');
    editLimits(axTime, 'y', 'Voltage (V)');

    fprintf('\n--- Frequency vs. Voltage plot ---\n');
    editLimits(axFreq, 'x', 'Frequency (Hz)');
    editLimits(axFreq, 'y', 'Voltage (V)');

    drawnow;
    fprintf('\n');
end
fprintf('Done.\n');

%% Local function: [min max] of the data (padded if the data is flat)
function lim = dataLimits(x)
    lim = [min(x) max(x)];
    if lim(1) == lim(2)
        lim = lim + [-1 1];
    end
end

%% Local function: prompt for new min/max on one axis (Enter keeps current)
function editLimits(ax, whichAxis, label)
    if whichAxis == 'x'
        cur = xlim(ax);
    else
        cur = ylim(ax);
    end

    newMin = askNumber(sprintf('  %s min [%g]: ', label, cur(1)), cur(1));
    newMax = askNumber(sprintf('  %s max [%g]: ', label, cur(2)), cur(2));
    if newMin >= newMax
        fprintf('  Min must be less than max -- keeping [%g %g].\n', cur(1), cur(2));
        return;
    end

    if whichAxis == 'x'
        xlim(ax, [newMin newMax]);
    else
        ylim(ax, [newMin newMax]);
    end
end

function val = askNumber(prompt, default)
    while true
        s = strtrim(input(prompt, 's'));
        if isempty(s)
            val = default;
            return;
        end
        val = str2double(s);
        if isfinite(val)
            return;
        end
        fprintf('  Please enter a number (or press Enter to keep %g).\n', default);
    end
end

%% Local function: locate the folder with the data files
function folder = findDataFolder(folder)
    if isfolder(folder), return; end
    candidates = {fullfile(fileparts(mfilename('fullpath')), 'MAE Matlab'), ...
                  fullfile(pwd, 'MAE Matlab'), pwd};
    for k = 1:numel(candidates)
        if isfolder(candidates{k}) && ~isempty(dir(fullfile(candidates{k}, '9_17_2026james*.txt')))
            folder = candidates{k};
            return;
        end
    end
    error(['Could not find the data folder. Set dataFolder at the top of ' ...
           'the script to the folder containing the 9_17_2026james*.txt files.']);
end
