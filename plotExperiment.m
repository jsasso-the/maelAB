% Plots the DAT (time vs. voltage) and FFT (frequency vs. voltage) files
% for one experiment, plus an optional Nyquist (folding) diagram, all in
% the same figure window.
% Files: 9_17_2026jamesXY.txt, X = experiment number, Y = 'dat' or 'fft'.
% Each file: tab-delimited, 1 header line, 2 columns.
clear; clc; close all;

%% ===================== USER SETTINGS =====================
expNum     = 11;               % experiment number (integer)
dataFolder = 'C:\Users\jsasso\OneDrive - Syracuse University\MAE Matlab';    % folder containing the .txt files

% ---- OPTION B: specify file names manually instead ----
useManualNames = false;
FFT = "fft.txt";
DAT = "dat.txt";

% ---- Which plots to show (true/false) ----
showTimeDomain = true;         % Time vs. Voltage (DAT file)
showFreqDomain = true;         % Frequency vs. Voltage (FFT file)
showNyquist    = true;         % Nyquist (folding) diagram

% ---- Nyquist diagram inputs (both in Hz) ----
signal = 1200;                 % signal frequency [Hz]
source = 1000;                 % sample frequency [Hz]

% ---- DAT plot axis limits (override) ----
% Leave as [] to autoscale to the min/max of the data.
% Otherwise use [min max], e.g. timeLim = [0 0.005]; voltLim = [-3 3];
timeLim = [0 0.01];                 % X axis (time, s)
voltLim = [-5 5];                 % Y axis (voltage, V)
%% =========================================================

nPlots = showTimeDomain + showFreqDomain + showNyquist;
if nPlots == 0, error('No plots selected. Set at least one of the show* flags to true.'); end

%% Build file paths
if useManualNames
    datFile = fullfile(dataFolder, DAT);
    fftFile = fullfile(dataFolder, FFT);
else
    prefix  = sprintf('9_17_2026james%d', expNum);
    datFile = fullfile(dataFolder, [prefix 'dat.txt']);
    fftFile = fullfile(dataFolder, [prefix 'fft.txt']);
end

%% Read data (1 header line, tab-delimited) -- only the files that are needed
if showTimeDomain
    if ~isfile(datFile), error('DAT file not found: %s', datFile); end
    datData = readmatrix(datFile, 'NumHeaderLines', 1, 'Delimiter', '\t');
    t  = datData(:,1);   % time [s]
    vt = datData(:,2);   % voltage [V]
end
if showFreqDomain
    if ~isfile(fftFile), error('FFT file not found: %s', fftFile); end
    fftData = readmatrix(fftFile, 'NumHeaderLines', 1, 'Delimiter', '\t');
    f  = fftData(:,1);   % frequency [Hz]
    vf = fftData(:,2);   % voltage [V]
end

%% Figure and layout
% 1 plot  -> single tile
% 2 plots -> stacked vertically (order: time, frequency, nyquist)
% 3 plots -> time over frequency on the left, nyquist on the right spanning both rows
fig = figure('Name', sprintf('Experiment %d', expNum), 'NumberTitle', 'off');
if nPlots == 3
    fig.Position = [100 100 1400 700];
    tl = tiledlayout(2, 2, 'TileSpacing', 'compact');
    tiles = {1, 3, 2};          % tile index for time, freq, nyquist
    nyqSpan = [2 1];
else
    fig.Position = [100 100 800 350*nPlots];
    tl = tiledlayout(nPlots, 1, 'TileSpacing', 'compact');
    tiles = num2cell(cumsum([showTimeDomain showFreqDomain showNyquist]));
    nyqSpan = [1 1];
end
title(tl, sprintf('Experiment %d', expNum));

% --- Plot 1: Time vs. Voltage (DAT) ---
if showTimeDomain
    nexttile(tiles{1});
    plot(t, vt, 'LineWidth', 1.2);
    xlabel('Time (s)');
    ylabel('Voltage (V)');
    title('Time vs. Voltage');
    grid on;
    xlim(getLimits(t,  timeLim));
    ylim(getLimits(vt, voltLim));
end

% --- Plot 2: Frequency vs. Voltage (FFT) ---
if showFreqDomain
    nexttile(tiles{2});
    plot(f, vf, 'LineWidth', 1.2);
    xlabel('Frequency (Hz)');
    ylabel('Voltage (V)');
    title('Frequency vs. Voltage');
    grid on;
    axis tight;
end

% --- Plot 3: Nyquist (folding) diagram ---
if showNyquist
    ax = nexttile(tiles{3}, nyqSpan);
    plotNyquist(ax, signal, source);
end

%% Local function: autoscale to data min/max unless user override is given
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
% The frequency axis is folded back and forth at multiples of the Nyquist
% frequency fN = fs/2. Rung k covers k*fN .. (k+1)*fN; even rungs run
% left->right, odd rungs run right->left. The signal frequency is marked on
% its rung and projected straight down to rung 0 to read the alias frequency.
function plotNyquist(ax, fSig, fs)
    if fs <= 0,   error('Sample frequency (source) must be > 0 Hz.'); end
    if fSig < 0,  error('Signal frequency (signal) must be >= 0 Hz.'); end

    fN = fs/2;

    % Which rung the signal sits on, and where along it (0..1)
    k = floor(fSig/fN);
    r = fSig/fN - k;
    if k > 0 && r == 0          % exactly on a fold: use end of previous rung
        k = k - 1;
        r = 1;
    end
    if mod(k, 2) == 0
        xSig = r*fN;            % even rung: left -> right
    else
        xSig = (1 - r)*fN;      % odd rung: right -> left
    end
    fAlias = xSig;

    nExtra = 2;                 % extra rungs for clarity
    nRungs = k + 1 + nExtra;
    dy     = 1;                 % vertical spacing between rungs
    fold   = 0.06*fN;           % how far the fold arcs stick out

    hold(ax, 'on');
    rungColor = [0.2 0.2 0.2];
    for n = 0:nRungs-1
        y = -n*dy;
        % rung line
        plot(ax, [0 fN], [y y], '-', 'Color', rungColor, 'LineWidth', 1.5);
        % minor ticks every 0.1*fN
        for xt = (0:0.1:1)*fN
            plot(ax, [xt xt], y + [-0.05 0.05], '-', 'Color', rungColor);
        end
        % end labels (frequency at each end of this rung)
        if mod(n, 2) == 0
            fLeft = n*fN;     fRight = (n+1)*fN;
        else
            fLeft = (n+1)*fN; fRight = n*fN;
        end
        text(ax, -fold*1.5, y, sprintf('%s', fmtHz(fLeft)), ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
        text(ax, fN + fold*1.5, y, sprintf('%s', fmtHz(fRight)), ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle');
        % fold arc to the next rung (right side after even, left after odd)
        if n < nRungs-1
            th = linspace(-pi/2, pi/2, 30);
            yc = y - dy/2;
            if mod(n, 2) == 0
                plot(ax, fN + fold*cos(th), yc + (dy/2)*sin(th), ':', 'Color', rungColor);
            else
                plot(ax, -fold*cos(th), yc + (dy/2)*sin(th), ':', 'Color', rungColor);
            end
        end
    end

    % Signal frequency marker and projection down to rung 0
    ySig = -k*dy;
    if k > 0
        plot(ax, [xSig xSig], [ySig 0], 'r--', 'LineWidth', 1.2);
    end
    plot(ax, xSig, ySig, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 8);
    text(ax, xSig, ySig - 0.25*dy, sprintf('f = %s', fmtHz(fSig)), ...
        'Color', 'r', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
    plot(ax, fAlias, 0, 'bs', 'MarkerFaceColor', 'b', 'MarkerSize', 8);
    text(ax, fAlias, 0.25*dy, sprintf('f_a = %s', fmtHz(fAlias)), ...
        'Color', 'b', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');

    hold(ax, 'off');
    xlim(ax, [-0.35*fN 1.35*fN]);
    ylim(ax, [-(nRungs-1)*dy - 0.75*dy, 0.75*dy]);
    axis(ax, 'off');
    title(ax, sprintf('Nyquist Diagram  (f_s = %s,  f_N = %s,  f_a = %s)', ...
        fmtHz(fs), fmtHz(fN), fmtHz(fAlias)));
end

function s = fmtHz(x)
    s = sprintf('%g Hz', x);
end
