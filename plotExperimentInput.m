% Asks for an experiment number, then plots in one figure window:
%   Top:    Time vs. Voltage       (from 9_17_2026jamesXdat.txt)
%   Bottom: Frequency vs. Voltage  (from 9_17_2026jamesXfft.txt)
%   Right:  Nyquist (folding) diagram from the signal/sample frequencies
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

% ---- Nyquist diagram inputs (both in Hz) ----
signal = 750;                        % signal frequency [Hz]
source = 25000;                      % sample frequency [Hz]
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

%% Plot all three in the same figure window
% Time over frequency on the left, Nyquist diagram on the right
figure('Name', sprintf('Experiment %d', expNum), 'NumberTitle', 'off', ...
       'Position', [50 50 1400 700]);

subplot(2, 2, 1);
plot(t, vt, 'LineWidth', 1.2);
xlabel('Time (s)');
ylabel('Voltage (V)');
title(sprintf('Experiment %d: Time vs. Voltage', expNum));
grid on;
xlim(getLimits(t,  timeLim));
ylim(getLimits(vt, voltLim));

subplot(2, 2, 3);
plot(f, vf, 'LineWidth', 1.2);
xlabel('Frequency (Hz)');
ylabel('Voltage (V)');
title(sprintf('Experiment %d: Frequency vs. Voltage', expNum));
grid on;
xlim(getLimits(f,  []));
ylim(getLimits(vf, []));

ax = subplot(2, 2, [2 4]);
plotNyquist(ax, signal, source);

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

%% Local function: Nyquist folding diagram
% Zig-zag of the frequency axis folded at multiples of fN = fs/2:
%   level m (y = m) is a horizontal rung from 2m*fN (left) to (2m+1)*fN (right),
%   and a diagonal runs from (2m+1)*fN back up-left to 2(m+1)*fN on the next level.
% A frequency on any segment aliases to the frequency directly below it on
% the bottom rung (0 .. fN).
function plotNyquist(ax, fSig, fs)
    if fs <= 0,   error('Sample frequency (source) must be > 0 Hz.'); end
    if fSig < 0,  error('Signal frequency (signal) must be >= 0 Hz.'); end

    fN = fs/2;
    [uScale, uName] = pickUnits(fs);   % display units for labels / x axis

    % Which band (k) the signal is in, and where along it (r = 0..1)
    k = floor(fSig/fN);
    r = fSig/fN - k;
    if k > 0 && r == 0          % exactly on a fold: use end of previous band
        k = k - 1;
        r = 1;
    end
    m = floor(k/2);             % level the signal's band starts on
    if mod(k, 2) == 0           % horizontal rung, left -> right
        xSig = r*fN;
        ySig = m;
    else                        % diagonal, right -> up-left
        xSig = (1 - r)*fN;
        ySig = m + r;
    end
    fAlias = xSig;

    % Only the levels needed to reach the signal, plus a few extra
    nExtra  = 3;
    nLevels = m + 1 + nExtra;

    % Zig-zag path: (0,0) -> (fN,0) -> (0,1) -> (fN,1) -> ...
    xp = repmat([0 fN], 1, nLevels);
    yp = repelem(0:nLevels-1, 2);

    hold(ax, 'on');
    plot(ax, xp/uScale, yp, '-', 'LineWidth', 2, 'Color', [0 0.3 0.6]);

    % Level labels: left end = 2m*fN, right end = (2m+1)*fN
    % (the top rung's right end is left unlabelled, as in the sample diagram)
    dx = 0.08*fN/uScale;
    for lv = 0:nLevels-1
        text(ax, -dx, lv, fmtFreq(2*lv*fN, uScale, uName), ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
        if lv < nLevels-1
            text(ax, fN/uScale + dx, lv, fmtFreq((2*lv+1)*fN, uScale, uName), ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
        end
    end

    % Signal frequency marker
    plot(ax, xSig/uScale, ySig, '*', 'Color', 'b', 'MarkerSize', 12, 'LineWidth', 1.5);
    text(ax, xSig/uScale, ySig + 0.08, ['  ' fmtFreq(fSig, 1, 'Hz')], ...
        'Rotation', 45, 'Color', 'b', 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'bottom');

    % If the signal is above fN, project it down to the bottom rung (alias)
    if fSig > fN
        plot(ax, [xSig xSig]/uScale, [ySig 0], 'r--', 'LineWidth', 1.2);
        plot(ax, fAlias/uScale, 0, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 7);
        text(ax, fAlias/uScale, -0.08, ['  ' fmtFreq(fAlias, 1, 'Hz') ' (alias)'], ...
            'Rotation', -45, 'Color', 'r', 'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'top');
    end
    hold(ax, 'off');

    xlim(ax, [-0.25*fN 1.3*fN]/uScale);
    ylim(ax, [-1, nLevels - 0.5]);
    box(ax, 'on');
    title(ax, 'Nyquist Diagram');
end

function [scale, name] = pickUnits(f)
    if f >= 1e6
        scale = 1e6; name = 'MHz';
    elseif f >= 1e3
        scale = 1e3; name = 'kHz';
    else
        scale = 1;   name = 'Hz';
    end
end

function s = fmtFreq(f, scale, name)
    s = sprintf('%g %s', f/scale, name);
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
