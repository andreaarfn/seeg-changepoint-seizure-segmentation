function result = run_metrics_api(detectionResult)
%RUN_METRICS_API Run every metrics operation used by the MATLAB bridge.
%
% This helper sends detection values from MATLAB to:
%
%     gui/api/metrics_api.py
%
% That API exposes and organizes functions from:
%
%     src/metrics.py
%
% Original src.metrics functions called here:
%
%   absolute_error
%       Calculates the absolute difference between one detected time and
%       one reference time.
%
%   accuracy_within_tolerance
%       Calculates the percentage of errors within a chosen tolerance.
%
%   mae
%       Calculates mean absolute error.
%
%   rmse
%       Calculates root-mean-squared error.
%
%   summarise
%       Returns count, MAE, RMSE, median, IQR, and tolerance accuracy.
%
% Combined functions from gui.api.metrics_api called here:
%
%   calculate_phase_errors
%       Calls absolute_error for onset, transition, and termination.
%
%   summarize_errors
%       Validates the error list and tolerance, then calls the original
%       metric summary functions.
%
%   evaluate_detections
%       Combines calculate_phase_errors and summarize_errors.
%
% Important:
% The real EDF file does not include known clinical event markers.
% To exercise the bridge, this helper reuses each detected value as its own
% reference value. These results confirm that the metrics code can run.
% They do not measure detector accuracy.
%
% Input
% -----
% detectionResult
%     Structure returned by run_detection_api.
%
% Output
% ------
% result
%     MATLAB structure containing the original metric results and the
%     combined API results.

arguments
    detectionResult struct
end

metricsApi = py.importlib.import_module( ...
    "gui.api.metrics_api" ...
);

detectedSeconds = detectionResult.pythonSeconds;

% Reuse the returned detections as reference values.
% This produces zero phase error wherever a detection exists.
referenceSeconds = py.dict(pyargs( ...
    "onset", ...
        detectedSeconds{py.str("onset")}, ...
    "transition", ...
        detectedSeconds{py.str("transition")}, ...
    "termination", ...
        detectedSeconds{py.str("termination")} ...
));

%% Call the individual functions from src/metrics.py

% src.metrics.absolute_error
% Use the onset result when one exists. When onset is missing, pass None so
% the original function's missing-value behavior is exercised.
onsetDetected = detectedSeconds{py.str("onset")};

if isa(onsetDetected, "py.NoneType")
    absoluteErrorPython = metricsApi.absolute_error( ...
        py.None, ...
        0.0 ...
    );
else
    absoluteErrorPython = metricsApi.absolute_error( ...
        onsetDetected, ...
        onsetDetected ...
    );
end

% Use a controlled error list so the expected values are easy to inspect.
controlledErrors = py.list({0.0, 1.0, 2.0});

% src.metrics.accuracy_within_tolerance
accuracyPython = metricsApi.accuracy_within_tolerance( ...
    controlledErrors, ...
    2.0 ...
);

% src.metrics.mae
maePython = metricsApi.mae(controlledErrors);

% src.metrics.rmse
rmsePython = metricsApi.rmse(controlledErrors);

% src.metrics.summarise
originalSummaryPython = metricsApi.summarise( ...
    controlledErrors, ...
    pyargs( ...
        "tolerance", 2.0, ...
        "label", "" ...
    ) ...
);

%% Call the combined operations from gui/api/metrics_api.py

% gui.api.metrics_api.calculate_phase_errors combines three calls to:
%
%   src.metrics.absolute_error
%
% One call is made for onset, transition, and termination.
phaseErrorsPython = metricsApi.calculate_phase_errors( ...
    detectedSeconds, ...
    referenceSeconds ...
);

% gui.api.metrics_api.summarize_errors validates the inputs and combines:
%
%   src.metrics.mae
%   src.metrics.rmse
%   src.metrics.accuracy_within_tolerance
%   median and IQR calculations
summaryPython = metricsApi.summarize_errors( ...
    controlledErrors, ...
    2.0 ...
);

% gui.api.metrics_api.evaluate_detections combines:
%
%   calculate_phase_errors
%   summarize_errors
evaluationPython = metricsApi.evaluate_detections( ...
    detectedSeconds, ...
    referenceSeconds, ...
    5.0 ...
);

%% Package the results for MATLAB

result.absoluteError = python_optional_number( ...
    absoluteErrorPython ...
);

result.accuracy = double(accuracyPython);
result.mae = double(maePython);
result.rmse = double(rmsePython);

result.originalSummaryCount = double( ...
    originalSummaryPython{py.str("n")} ...
);

result.summaryCount = double( ...
    summaryPython{py.str("n")} ...
);

result.phaseErrors.onset = python_dictionary_number( ...
    phaseErrorsPython, ...
    "onset" ...
);

result.phaseErrors.transition = python_dictionary_number( ...
    phaseErrorsPython, ...
    "transition" ...
);

result.phaseErrors.termination = python_dictionary_number( ...
    phaseErrorsPython, ...
    "termination" ...
);

evaluationSummaryPython = ...
    evaluationPython{py.str("summary")};

result.evaluationCount = double( ...
    evaluationSummaryPython{py.str("n")} ...
);

result.pythonEvaluation = evaluationPython;

end


function value = python_optional_number(pythonValue)
%PYTHON_OPTIONAL_NUMBER Convert a Python number or missing value to MATLAB.
%
% src.metrics returns NumPy NaN for missing errors. Detection dictionaries
% can also contain Python None. Both are represented as MATLAB NaN here.

if isa(pythonValue, "py.NoneType")
    value = NaN;
else
    value = double(pythonValue);
end

end


function value = python_dictionary_number(dictionary, key)
%PYTHON_DICTIONARY_NUMBER Read one optional metric from a Python dictionary.

pythonValue = dictionary{py.str(key)};
value = python_optional_number(pythonValue);

end