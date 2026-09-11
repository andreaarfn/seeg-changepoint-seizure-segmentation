function result = runIterativeChangePoints( ...
    signal, time, fs, maxChanges, downsampleFactor, freqRange, ...
    statistic, minDistance, scanWindowSeconds, scanStepSeconds)

signal = double(signal(:));
time = double(time(:));
fs = double(fs);

maxChanges = max(1, round(maxChanges));
downsampleFactor = max(1, round(downsampleFactor));
minDistance = max(1, round(minDistance));
statistic = char(string(statistic));

allowedStatistics = ["mean", "rms", "std", "linear"];
if ~any(string(statistic) == allowedStatistics)
    error("Statistic must be mean, rms, std, or linear.");
end

if numel(signal) ~= numel(time)
    error("Signal and time must have the same number of samples.");
end

if scanWindowSeconds <= 0 || scanStepSeconds <= 0
    error("Scan window and scan step must be greater than zero.");
end

recordingStart = time(1);
recordingEnd = time(end);
duration = recordingEnd - recordingStart;

if scanWindowSeconds > duration
    error("Scan window cannot be longer than the selected analysis range.");
end

lastStart = recordingEnd - scanWindowSeconds;
windowStarts = recordingStart:scanStepSeconds:lastStart;

if isempty(windowStarts)
    windowStarts = recordingStart;
end

if abs(windowStarts(end) - lastStart) > max(1/fs, 1e-9)
    windowStarts(end+1) = lastStart;
end

windowStarts = unique(windowStarts);
windowCount = numel(windowStarts);

changeCounts = (1:maxChanges)';
residualMatrix = nan(windowCount, maxChanges);
selectedCounts = nan(windowCount, 1);
allSelectedTimes = [];

windowResults = repmat(struct( ...
    'startTime', NaN, ...
    'endTime', NaN, ...
    'selectedCount', NaN, ...
    'selectedTimes', [], ...
    'residuals', []), windowCount, 1);

for w = 1:windowCount
    startTime = windowStarts(w);
    endTime = startTime + scanWindowSeconds;

    mask = time >= startTime & time <= endTime;

    if nnz(mask) < 3
        continue
    end

    windowSignal = signal(mask);
    windowTime = time(mask);

    tf = buildTimeFrequencyMatrix( ...
        windowSignal, ...
        windowTime, ...
        fs, ...
        downsampleFactor, ...
        freqRange);

    profile = mean(tf.matrix, 1);
    profile = double(profile(:)');

    residuals = nan(maxChanges, 1);
    allChangeIndices = cell(maxChanges, 1);

    for n = 1:maxChanges
        try
            [idx, residual] = findchangepts( ...
                profile, ...
                'MaxNumChanges', n, ...
                'Statistic', statistic, ...
                'MinDistance', minDistance);

            idx = double(idx(:));
            idx = idx(idx >= 1 & idx <= numel(tf.time));

            residual = double(residual);

            if isempty(residual)
                residualValue = NaN;
            else
                residualValue = sum(residual(:), 'omitnan');
            end

            allChangeIndices{n} = idx;
            residuals(n) = residualValue;
        catch
            allChangeIndices{n} = [];
            residuals(n) = NaN;
        end
    end

    valid = isfinite(residuals);

    if ~any(valid)
        continue
    end

    validCounts = changeCounts(valid);
    validResiduals = residuals(valid);

    selectedCount = selectKneePoint(validCounts, validResiduals);
    selectedCount = max(1, min(maxChanges, round(selectedCount)));

    selectedIndices = allChangeIndices{selectedCount};

    if isempty(selectedIndices)
        [~, nearest] = min(abs(validCounts - selectedCount));
        selectedCount = validCounts(nearest);
        selectedIndices = allChangeIndices{selectedCount};
    end

    selectedTimes = tf.time(selectedIndices);
    selectedTimes = double(selectedTimes(:));

    residualMatrix(w, :) = residuals(:)';
    selectedCounts(w) = selectedCount;
    allSelectedTimes = [allSelectedTimes; selectedTimes]; %#ok<AGROW>

    windowResults(w).startTime = startTime;
    windowResults(w).endTime = endTime;
    windowResults(w).selectedCount = selectedCount;
    windowResults(w).selectedTimes = selectedTimes;
    windowResults(w).residuals = residuals;
end

meanResiduals = mean(residualMatrix, 1, 'omitnan')';

validSelectedCounts = selectedCounts(isfinite(selectedCounts));

if isempty(validSelectedCounts)
    medianSelectedPerWindow = NaN;
else
    medianSelectedPerWindow = round(median(validSelectedCounts));
end

if isempty(allSelectedTimes)
    mergedTimes = [];
else
    allSelectedTimes = sort(allSelectedTimes(:));

    timeResolution = max(downsampleFactor / fs, 1 / fs);
    mergedTimes = allSelectedTimes(1);

    for k = 2:numel(allSelectedTimes)
        if abs(allSelectedTimes(k) - mergedTimes(end)) <= timeResolution
            mergedTimes(end) = mean([mergedTimes(end), allSelectedTimes(k)]);
        else
            mergedTimes(end+1, 1) = allSelectedTimes(k); %#ok<AGROW>
        end
    end
end

result.changeCounts = changeCounts;
result.meanResiduals = meanResiduals;
result.residualMatrix = residualMatrix;
result.selectedCountsPerWindow = selectedCounts;
result.medianSelectedPerWindow = medianSelectedPerWindow;
result.selectedTimes = mergedTimes;
result.windowCount = windowCount;
result.windowResults = windowResults;
result.scanWindowSeconds = scanWindowSeconds;
result.scanStepSeconds = scanStepSeconds;
result.statistic = string(statistic);
result.minDistance = minDistance;

end
