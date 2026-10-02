% Asks for an experiment number, then plots in one figure window:
%   Top:    Time vs. Voltage       (from 9_17_2026jamesXdat.txt)
%   Bottom: Frequency vs. Voltage  (from 9_17_2026jamesXfft.txt)
% Each file: tab-delimited, 1 header line, 2 columns.
clear; clc; close all;

%% ===================== USER SETTINGS =====================
% Folder containing the .txt files. If it doesn't exist, the script looks
% for a "MAE Matlab" folder next to this script / in the current folder.
dataFolder = 'C:\Users\jsasso\OneDrive - Syracuse University\MAE Matlab';

% ---- DAT plot axis limits (Time vs. Voltage) ----
% Leave as [] to autoscale to the min/max of the data.
% Otherwise use [min max], e.g. timeLim = [0 0.005]; voltLim = [-5 2];
timeLim = [0 0.005];                 % X axis (time, s)
voltLim = [-5 2];                    % Y axis (voltage, V)

% ---- FFT plot axis limits (Frequency vs. Voltage) ----
freqLim    = [];                     % X axis (frequency, Hz)
fftVoltLim = [];                     % Y axis (voltage, V)
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
figure('Name', sprintf('Experiment %d', expNum), 'NumberTitle', 'off', ...
       'Position', [100 100 900 700]);

subplot(2, 1, 1);
plot(t, vt, 'LineWidth', 1.2);
xlabel('Time (s)');
ylabel('Voltage (V)');
title(sprintf('Experiment %d: Time vs. Voltage', expNum));
grid on;
xlim(getLimits(t,  timeLim));
ylim(getLimits(vt, voltLim));

subplot(2, 1, 2);
plot(f, vf, 'LineWidth', 1.2);
xlabel('Frequency (Hz)');
ylabel('Voltage (V)');
title(sprintf('Experiment %d: Frequency vs. Voltage', expNum));
grid on;
xlim(getLimits(f,  freqLim));
ylim(getLimits(vf, fftVoltLim));

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
