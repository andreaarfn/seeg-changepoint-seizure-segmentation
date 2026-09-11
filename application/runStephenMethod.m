function result = runStephenMethod(signal, time, fs, params)

signal = double(signal(:));
time = double(time(:));
fs = double(fs);

if numel(signal) ~= numel(time)
    error("Signal and time must have the same number of samples.");
end

required = ["emdCutoff", "lowFreq", "highFreq", "voicesPerOctave", ...
    "minChanges", "maxChanges", "statistic", "minSpacing"];

for k = 1:numel(required)
    if ~isfield(params, required(k))
        error("Missing Stephen-method parameter: " + required(k));
    end
end

nSamples = numel(signal);

[baseline, fast] = emd_baseline(signal, fs, params.emdCutoff);

freqBand = [double(params.lowFreq), double(params.highFreq)];
voices = round(double(params.voicesPerOctave));

fb = cwtfilterbank( ...
    'SignalLength', nSamples, ...
    'Wavelet', 'Morse', ...
    'SamplingFrequency', fs, ...
    'FrequencyLimits', freqBand, ...
    'VoicesPerOctave', voices);

frequencies = centerFrequencies(fb);
coef = cwt(fast, 'Filterbank', fb);
powerMatrix = abs(coef).^2;

factor = localDownsampleFactor(fs);
powerDownsampled = downsample(powerMatrix', factor)';

candidateCounts = (round(params.minChanges):round(params.maxChanges))';
nCandidates = numel(candidateCounts);

if nCandidates < 3
    error("Stephen method needs at least three candidate fits for knee selection.");
end

indicesByCandidate = cell(nCandidates, 1);
residuals = nan(nCandidates, 1);

logPower = log(powerDownsampled);

for k = 1:nCandidates
    [indicesByCandidate{k}, residuals(k)] = findchangepts( ...
        logPower, ...
        'Statistic', char(string(params.statistic)), ...
        'MaxNumChanges', candidateCounts(k));
end

[~, uniqueIndex] = uniquetol(residuals);
uniqueIndex = flip(uniqueIndex);

if numel(uniqueIndex) < 3
    error("Fewer than three unique residual fits were available for knee selection.");
end

selectedArrayIndex = knee_pt( ...
    residuals(uniqueIndex), ...
    uniqueIndex);

selectedArrayIndex = round(selectedArrayIndex);

if selectedArrayIndex < 1 || selectedArrayIndex > nCandidates
    error("Knee selection returned an invalid candidate index.");
end

indicesDownsampled = double(indicesByCandidate{selectedArrayIndex}(:));
indices = round(indicesDownsampled .* factor);
indices = indices(indices >= 1 & indices <= nSamples);

minimumSamples = double(params.minSpacing) .* fs;

if numel(indices) > 1 && minimumSamples > 0
    closeIndex = find(diff(indices) < minimumSamples);
    drop = unique([closeIndex(:); closeIndex(:) + 1]);
    drop = drop(drop >= 1 & drop <= numel(indices));
    indices(drop) = [];
end

changeTimes = time(indices);

result.changeIndices = indices;
result.changeTimes = changeTimes(:);
result.baseline = baseline;
result.fast = fast;
result.frequencies = frequencies;
result.powerMatrix = powerMatrix;
result.downsampleFactor = factor;
result.candidateCounts = candidateCounts;
result.residuals = residuals;
result.selectedCandidateIndex = selectedArrayIndex;
result.selectedMaxChanges = candidateCounts(selectedArrayIndex);
result.params = params;

end

function factor = localDownsampleFactor(fs)

if abs(fs - 2024) < 1
    factor = 16;
elseif abs(fs - 1024) < 1
    factor = 8;
elseif abs(fs - 512) < 1
    factor = 4;
else
    factor = max(1, round(fs / 128));
end

end
