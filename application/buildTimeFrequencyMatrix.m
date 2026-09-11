function tf = buildTimeFrequencyMatrix(signal, time, fs, downsampleFactor, freqRange)

signal = double(signal(:));
time = double(time(:));
fs = double(fs);
downsampleFactor = max(1, round(downsampleFactor));

lowFreq = double(freqRange(1));
highFreq = double(freqRange(2));

if numel(signal) ~= numel(time)
    error("Signal and time must have the same number of samples.");
end

if ~isfinite(fs) || fs <= 0
    error("Sampling rate must be greater than zero.");
end

if lowFreq < 0 || highFreq <= lowFreq
    error("Frequency range must be [low high] with high > low.");
end

if exist('cwt', 'file') ~= 2
    error("Time-Frequency mode requires MATLAB's cwt function. The Wavelet Toolbox is not available in this MATLAB installation. Use Cleveland Clinic mode, install Wavelet Toolbox, or replace buildTimeFrequencyMatrix.m with a non-wavelet implementation.");
end

[cfs, frequencies] = cwt(signal, fs);

keep = frequencies >= lowFreq & frequencies <= highFreq;

if ~any(keep)
    error("No wavelet frequencies fall inside the selected frequency range.");
end

matrix = abs(cfs(keep, :));
frequencies = frequencies(keep);

sampleIndex = 1:downsampleFactor:size(matrix, 2);

tf.matrix = matrix(:, sampleIndex);
tf.time = time(sampleIndex);
tf.frequencies = frequencies;
tf.downsampleFactor = downsampleFactor;
tf.frequencyRange = [lowFreq highFreq];

end
