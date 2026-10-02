% Asks for an experiment number, then plots in one figure window:
%   Top:    Time vs. Voltage       (from 9_17_2026jamesXdat.txt)
%   Bottom: Frequency vs. Voltage  (from 9_17_2026jamesXfft.txt)
% Axis limits start at the data min/max. Boxes to the right of each plot
% show the current limits: type a new value and press Enter to change it,
% or click "Reset to auto" to go back to the data min/max.
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
             'Position', [100 100 1150 750]);

axTime = axes(fig, 'Position', [0.07 0.57 0.62 0.35]);
plot(axTime, t, vt, 'LineWidth', 1.2);
xlabel(axTime, 'Time (s)');
ylabel(axTime, 'Voltage (V)');
title(axTime, sprintf('Experiment %d: Time vs. Voltage', expNum));
grid(axTime, 'on');

axFreq = axes(fig, 'Position', [0.07 0.08 0.62 0.35]);
plot(axFreq, f, vf, 'LineWidth', 1.2);
xlabel(axFreq, 'Frequency (Hz)');
ylabel(axFreq, 'Voltage (V)');
title(axFreq, sprintf('Experiment %d: Frequency vs. Voltage', expNum));
grid(axFreq, 'on');

% Editable limit boxes (pre-filled with the automatic limits)
addLimitControls(fig, axTime, [0.73 0.57 0.24 0.35], 'Time vs. Voltage', t, vt);
addLimitControls(fig, axFreq, [0.73 0.08 0.24 0.35], 'Frequency vs. Voltage', f, vf);

%% Local function: [min max] of the data (padded if the data is flat)
function lim = dataLimits(x)
    lim = [min(x) max(x)];
    if lim(1) == lim(2)
        lim = lim + [-1 1];
    end
end

%% Local function: panel of X/Y min/max boxes for one plot
function addLimitControls(fig, ax, pos, name, x, y)
    p = uipanel(fig, 'Title', [name ' limits'], 'Units', 'normalized', ...
                'Position', pos, 'FontSize', 10);
    labels = {'X min', 'X max', 'Y min', 'Y max'};
    rowY   = [0.78 0.60 0.42 0.24];
    eb = [];
    for k = 1:4
        uicontrol(p, 'Style', 'text', 'String', labels{k}, 'Units', 'normalized', ...
                  'Position', [0.05 rowY(k) 0.35 0.12], ...
                  'HorizontalAlignment', 'left', 'FontSize', 10);
        eb = [eb uicontrol(p, 'Style', 'edit', 'Units', 'normalized', ...
                          'Position', [0.42 rowY(k)+0.01 0.53 0.13], 'FontSize', 10)];
    end

    autoX = dataLimits(x);
    autoY = dataLimits(y);
    set(eb, 'Callback', @(~,~) applyLimits(ax, eb));
    uicontrol(p, 'Style', 'pushbutton', 'String', 'Reset to auto', ...
              'Units', 'normalized', 'Position', [0.2 0.04 0.6 0.14], 'FontSize', 10, ...
              'Callback', @(~,~) resetLimits(ax, eb, autoX, autoY));

    resetLimits(ax, eb, autoX, autoY);

end

function applyLimits(ax, eb)
    v = str2double(get(eb, 'String'));
    if any(~isfinite(v)) || v(1) >= v(2) || v(3) >= v(4)
        beep;
        fprintf('Invalid limits: values must be numbers and min must be less than max.\n');
        showLimits(ax, eb);   % put the current limits back in the boxes
        return;
    end
    xlim(ax, v(1:2));
    ylim(ax, v(3:4));
    showLimits(ax, eb);
end

function resetLimits(ax, eb, autoX, autoY)
    xlim(ax, autoX);
    ylim(ax, autoY);
    showLimits(ax, eb);
end

function showLimits(ax, eb)
    lims = [get(ax, 'XLim') get(ax, 'YLim')];
    for k = 1:4
        set(eb(k), 'String', sprintf('%.6g', lims(k)));
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
