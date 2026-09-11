function result = runStephenMethod(signal, time, fs, params)
%RUNSTEPHENMETHOD Run Stephen's single-channel time-frequency workflow.
%
% This is a GUI-facing wrapper around the workflow in:
%   pipeline_single.m
%   emd_baseline.m
%   ds_changepts.m
%   knee_pt.m
%
% The original files remain unchanged. This wrapper returns the same
% changepoint result plus the candidate-fit residual curve needed by the GUI.

signal = double(signal(:));
time = double(time(:));
fs = double(fs);

if numel(signal) ~= numel(time)
    error("Signal and time must have the same number of samples.");
end

if numel(signal) < 3
    error("The selected signal range is too short.");
end

nSamples = numel(signal);

% Stephen's EMD baseline separation.
[~, fast] = emd_baseline(signal, fs, params.emdCutoff);

% Stephen's Morse wavelet power representation.
freqBand = [params.lowFreq, params.highFreq];

fb = cwtfilterbank( ...
    'SignalLength', nSamples, ...
    'Wavelet', 'Morse', ...
    'SamplingFrequency', fs, ...
    'FrequencyLimits', freqBand, ...
    'VoicesPerOctave', params.voicesPerOctave);

coef = cwt(fast, 'Filterbank', fb);
TF = abs(coef).^2;

% Match Stephen's downsampling choices where explicitly defined.
if fs == 2024
    factor = 16;
elseif fs == 1024
    factor = 8;
elseif fs == 512
    factor = 4;
else
    % Keep approximately the same ~128 Hz time resolution for other Fs.
    factor = max(1, round(fs / 128));
end

TF_ds = downsample(TF', factor)';

candidateCounts = params.minChanges:params.maxChanges;
nCandidates = numel(candidateCounts);

if nCandidates < 3
    error("Stephen's knee selection requires at least three candidate fits.");
end

candidatePoints = cell(1, nCandidates);
residuals = nan(1, nCandidates);

% Stephen's supplied ds_changepts.m hard-codes Statistic='mean'.
for i = 1:nCandidates
    [candidatePoints{i}, residuals(i)] = findchangepts( ...
        log(TF_ds), ...
        'Statistic', 'mean', ...
        'MaxNumChanges', candidateCounts(i));
end

% Preserve Stephen's residual-knee selection logic.
[~, res_cut] = uniquetol(residuals);
res_cut = flip(res_cut);

if numel(res_cut) < 3
    error("Too few unique residual values were returned to determine a knee.");
end

selectedIndex = knee_pt(residuals(res_cut), res_cut);
selectedIndex = round(double(selectedIndex));

if ~isfinite(selectedIndex) || selectedIndex < 1 || selectedIndex > nCandidates
    error("Stephen's knee selection did not return a valid candidate fit.");
end

ipts_ds = candidatePoints{selectedIndex};
ipts = ipts_ds .* factor;

% Stephen's minimum-spacing rule.
if ~isempty(ipts)
    min_change_idx = find(diff(ipts) < params.minSpacing .* fs);
    drop = unique([min_change_idx, min_change_idx + 1]);
    drop = drop(drop >= 1 & drop <= numel(ipts));
    ipts(drop) = [];
end

% Keep indices inside the selected signal.
ipts = round(ipts(:));
ipts = ipts(ipts >= 1 & ipts <= nSamples);

result = struct();
result.changeIndices = ipts;
result.changeTimes = time(ipts);
result.candidateCounts = candidateCounts(:);
result.residuals = residuals(:);
result.selectedIndex = selectedIndex;
result.selectedMaxChanges = candidateCounts(selectedIndex);
result.downsampleFactor = factor;
end
