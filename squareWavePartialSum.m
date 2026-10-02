% Square wave partial sum reconstruction
% Uses b_n = (4.84/(2*pi*n))*(1 - (-1)^n), a_n = 0 (from hand calculations)

clear; clc; close all;

%% Parameters
f0  = 700;          % fundamental frequency [Hz] (from FFT peak)
T   = 1/f0;         % period [s]
w0  = 2*pi*f0;      % angular frequency [rad/s]
K   = 4.84;         % constant from hand calculation of b_n
numPeriods = 2;     % number of periods to plot

%% Choose the n values here (largest harmonic for each partial sum)
% Edit this vector to change which partial sums are plotted
Nlist = [1 3 7 15];

%% Time vector
t = linspace(0, numPeriods*T, 2000);

%% Ideal square wave (amplitude K/4, matches b_n above)
A = K/4;
ideal = A * sign(sin(w0*t));

%% Theoretical coefficients
bn = @(n) (K ./ (2*pi*n)) .* (1 - (-1).^n);   % zero for even n
an = @(n) zeros(size(n));                      % a_n = 0 for all n

%% Build partial sums
figure; hold on; grid on;
plot(t*1000, ideal, 'k--', 'LineWidth', 1.2, 'DisplayName', 'Ideal square wave');

colors = lines(numel(Nlist));
for k = 1:numel(Nlist)
    N = Nlist(k);
    f = zeros(size(t));                 % a_0/2 = 0
    for n = 1:N
        f = f + an(n)*cos(n*w0*t) + bn(n)*sin(n*w0*t);
    end
    plot(t*1000, f, 'Color', colors(k,:), 'LineWidth', 1.6, ...
         'DisplayName', sprintf('n up to %d', N));
end

xlabel('Time (ms)');
ylabel('Voltage (V)');
title('Partial sum reconstruction of the square wave');
legend('Location', 'best');
ylim([-1.9 1.9]);
hold off;

%% Optional: print the coefficients used
fprintf('\n n    b_n (V)\n');
for n = 1:max(Nlist)
    fprintf('%2d    %.4f\n', n, bn(n));
end
