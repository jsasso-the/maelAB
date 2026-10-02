% Asks for an experiment number, then plots in one figure window:
%   Top:    Time vs. Voltage       (from 9_17_2026jamesXdat.txt)
%   Bottom: Frequency vs. Voltage  (from 9_17_2026jamesXfft.txt)
% Each file: tab-delimited, 1 header line, 2 columns.
clear; clc; close all;

%% ===================== USER SETTINGS =====================
% Folder containing the .txt files. If it doesn't exist, the script looks
% for a "MAE Matlab" folder next to this script / in the current folder.
dataFolder = 'C:\Users\jsasso\OneDrive - Syracuse University\MAE Matlab';

% ---- Axis limits ----
% Leave as [] to autoscale to the data.
% Otherwise use [min max], e.g. timeLim = [0 0.01];
timeLim     = [];   % Time plot, x axis (s)
timeVoltLim = [];   % Time plot, y axis (V)
freqLim     = [];   % Frequency plot, x axis (Hz)
freqVoltLim = [];   % Frequency plot, y axis (V)
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
xlim(axTime, getLimits(t,  timeLim));
ylim(axTime, getLimits(vt, timeVoltLim));

axFreq = nexttile(tl);
plot(axFreq, f, vf, 'LineWidth', 1.2);
xlabel(axFreq, 'Frequency (Hz)');
ylabel(axFreq, 'Voltage (V)');
title(axFreq, 'Frequency vs. Voltage');
grid(axFreq, 'on');
xlim(axFreq, getLimits(f,  freqLim));
ylim(axFreq, getLimits(vf, freqVoltLim));

%% Local function: autoscale to data min/max unless limits are given
function lim = getLimits(x, userLim)
    if isempty(userLim)
        lim = [min(x) max(x)];
        if lim(1) == lim(2)
            lim = lim + [-1 1];
        end
    else
        lim = userLim;
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
