function result = runIterativeStephenMethod( ...
    signal, time, fs, params, iterationWindowSeconds, iterationStepSeconds)

signal = double(signal(:));
time = double(time(:));
fs = double(fs);

if numel(signal) ~= numel(time)
    error("Signal and time must have the same number of samples.");
end

duration = time(end) - time(1);

if iterationWindowSeconds <= 0 || iterationStepSeconds <= 0
    error("Iteration window and step must be greater than zero.");
end

if iterationWindowSeconds > duration
    error("Iteration window cannot be longer than the selected analysis range.");
end

lastStart = time(end) - iterationWindowSeconds;
windowStarts = time(1):iterationStepSeconds:lastStart;

if isempty(windowStarts)
    windowStarts = time(1);
end

if abs(windowStarts(end) - lastStart) > max(1/fs, 1e-9)
    windowStarts(end+1) = lastStart;
end

windowStarts = unique(windowStarts);
nWindows = numel(windowStarts);

allTimes = [];
selectedPerWindow = nan(nWindows, 1);

windowResults = repmat(struct( ...
    'startTime', NaN, ...
    'endTime', NaN, ...
    'changeTimes', [], ...
    'changeCount', 0), nWindows, 1);

for w = 1:nWindows
    startTime = windowStarts(w);
    stopTime = startTime + iterationWindowSeconds;

    mask = time >= startTime & time <= stopTime;

    windowResults(w).startTime = startTime;
    windowResults(w).endTime = stopTime;

    if nnz(mask) < 3
        continue
    end

    windowResult = runStephenMethod( ...
        signal(mask), ...
        time(mask), ...
        fs, ...
        params);

    windowTimes = double(windowResult.changeTimes(:));
    windowResults(w).changeTimes = windowTimes;
    windowResults(w).changeCount = numel(windowTimes);
    selectedPerWindow(w) = numel(windowTimes);

    allTimes = [allTimes; windowTimes]; %#ok<AGROW>
end

% Preserve the current display behavior for the overlaid combined markers.
% This merge affects only the combined plot markers, not the per-window table.
mergeTolerance = max(iterationStepSeconds / 2, 1/fs);
changeTimes = localMergeTimes(allTimes, mergeTolerance);

result.changeTimes = changeTimes;
result.windowCount = nWindows;
result.selectedPerWindow = selectedPerWindow;
result.windowResults = windowResults;
result.iterationWindowSeconds = iterationWindowSeconds;
result.iterationStepSeconds = iterationStepSeconds;

end

function merged = localMergeTimes(values, tolerance)

values = sort(double(values(:)));

if isempty(values)
    merged = [];
    return
end

clusters = values(1);

for k = 2:numel(values)
    if abs(values(k) - clusters(end)) <= tolerance
        clusters(end) = mean([clusters(end), values(k)]);
    else
        clusters(end+1,1) = values(k); %#ok<AGROW>
    end
end

merged = clusters(:);

end
