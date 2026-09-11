function result = runIterativeDefaultDetection( ...
    signal, time, fs, params, scanWindowSeconds, scanStepSeconds)

signal = double(signal(:));
time = double(time(:));
fs = double(fs);

if numel(signal) ~= numel(time)
    error("Signal and time must have the same number of samples.");
end

if scanWindowSeconds <= 0 || scanStepSeconds <= 0
    error("Scan window and scan step must be greater than zero.");
end

duration = time(end) - time(1);

if scanWindowSeconds > duration
    error("Scan window cannot be longer than the selected analysis range.");
end

api = py.importlib.import_module('gui.api.detection_api');
py.importlib.reload(api);

lastStart = time(end) - scanWindowSeconds;
windowStarts = time(1):scanStepSeconds:lastStart;

if isempty(windowStarts)
    windowStarts = time(1);
end

if abs(windowStarts(end) - lastStart) > max(1/fs, 1e-9)
    windowStarts(end+1) = lastStart;
end

windowStarts = unique(windowStarts);

onsets = [];
transitions = [];
ends = [];

windowResults = repmat(struct( ...
    'startTime', NaN, ...
    'endTime', NaN, ...
    'onset', NaN, ...
    'transition', NaN, ...
    'endTimeDetected', NaN), numel(windowStarts), 1);

for w = 1:numel(windowStarts)
    startTime = windowStarts(w);
    stopTime = startTime + scanWindowSeconds;

    mask = time >= startTime & time <= stopTime;

    if nnz(mask) < 3
        continue
    end

    windowSignal = signal(mask);
    windowTime = time(mask);

    pyResult = api.detect_from_signal( ...
        py.numpy.array(windowSignal), ...
        fs, ...
        params, ...
        true);

    seconds = pyResult{'detected_seconds'};

    onset = localAbsoluteTime(localPyValue(seconds{'onset'}), windowTime);
    transition = localAbsoluteTime(localPyValue(seconds{'transition'}), windowTime);
    ending = localAbsoluteTime(localPyValue(seconds{'termination'}), windowTime);

    if isfinite(onset), onsets(end+1,1) = onset; end %#ok<AGROW>
    if isfinite(transition), transitions(end+1,1) = transition; end %#ok<AGROW>
    if isfinite(ending), ends(end+1,1) = ending; end %#ok<AGROW>

    windowResults(w).startTime = startTime;
    windowResults(w).endTime = stopTime;
    windowResults(w).onset = onset;
    windowResults(w).transition = transition;
    windowResults(w).endTimeDetected = ending;
end

mergeTolerance = max(scanStepSeconds / 2, 1 / fs);

result.onsets = localMergeTimes(onsets, mergeTolerance);
result.transitions = localMergeTimes(transitions, mergeTolerance);
result.ends = localMergeTimes(ends, mergeTolerance);
result.windowCount = numel(windowStarts);
result.windowResults = windowResults;
result.scanWindowSeconds = scanWindowSeconds;
result.scanStepSeconds = scanStepSeconds;

end

function value = localPyValue(pyObj)
if isequal(class(pyObj), 'py.NoneType')
    value = NaN;
else
    value = double(pyObj);
end
end

function value = localAbsoluteTime(relativeSeconds, windowTime)
if ~isfinite(relativeSeconds)
    value = NaN;
else
    value = windowTime(1) + relativeSeconds;
end
end

function merged = localMergeTimes(values, tolerance)
values = sort(double(values(:)));

if isempty(values)
    merged = [];
    return
end

groups = values(1);

for k = 2:numel(values)
    if abs(values(k) - groups(end)) <= tolerance
        groups(end) = mean([groups(end), values(k)]);
    else
        groups(end+1,1) = values(k); %#ok<AGROW>
    end
end

merged = groups(:);
end
