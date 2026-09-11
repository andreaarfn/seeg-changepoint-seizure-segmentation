function result = run_features_api(signal, fs)
%RUN_FEATURES_API Run every feature operation used by the MATLAB bridge.
%
% This helper does not calculate any SEEG features itself. It sends the
% MATLAB signal to Python and calls functions exposed by:
%
%     gui/api/features_api.py
%
% Those API functions either expose or organize functions from:
%
%     src/features.py
%
% Original src.features functions called here:
%
%   highpass_filter
%       Applies the repository's high-pass filter.
%
%   rms_envelope
%       Calculates RMS amplitude for each signal window.
%
%   line_length
%       Calculates line length for each signal window.
%
%   spectral_entropy
%       Calculates spectral entropy for each signal window.
%
%   relative_bandpower_envelope
%       Calculates relative power in a selected frequency band.
%       This helper uses the theta band as a direct function check.
%
%   extract_all_features
%       Calls the seven feature calculations and returns one dictionary.
%
%   minmax_normalize
%       Scales a feature between zero and one.
%
%   exponential_smooth
%       Smooths a normalized feature over time.
%
%   stack_features
%       Combines the seven processed features into one matrix.
%
% Combined functions from gui.api.features_api called here:
%
%   prepare_feature_matrix
%       Combines signal validation, optional high-pass filtering,
%       extract_all_features, and stack_features into one operation.
%
% Inputs
% ------
% signal
%     One MATLAB row vector containing a single recording channel.
%
% fs
%     Sampling frequency in hertz.
%
% Output
% ------
% result
%     A MATLAB structure containing the individual feature outputs,
%     the final feature matrix, time indices, and the Python objects needed
%     by the detection bridge.

arguments
    signal (1, :) double
    fs (1, 1) double {mustBePositive}
end

% Import the MATLAB-facing Python API and NumPy.
featuresApi = py.importlib.import_module( ...
    "gui.api.features_api" ...
);

numpy = py.importlib.import_module("numpy");

% Convert the MATLAB signal into a NumPy array before passing it to Python.
pythonSignal = numpy.array(signal);

% Use a window no larger than the available signal.
% The step is one quarter of that window.
windowSize = min(1000, numel(signal));
step = max(1, floor(windowSize / 4));

%% Call the individual functions from src/features.py

% src.features.highpass_filter
filteredSignalPython = featuresApi.highpass_filter( ...
    pythonSignal, ...
    fs ...
);

% src.features.rms_envelope
% Returns both RMS values and the center sample of each window.
rmsResult = featuresApi.rms_envelope( ...
    pythonSignal, ...
    int32(windowSize), ...
    int32(step) ...
);

rmsValues = numpy_to_matlab(rmsResult{1});
rmsTimeIndices = numpy_to_matlab(rmsResult{2});

% src.features.line_length
lineLengthPython = featuresApi.line_length( ...
    pythonSignal, ...
    int32(windowSize), ...
    int32(step) ...
);

lineLengthValues = numpy_to_matlab(lineLengthPython);

% src.features.spectral_entropy
spectralEntropyPython = featuresApi.spectral_entropy( ...
    pythonSignal, ...
    fs, ...
    int32(windowSize), ...
    int32(step) ...
);

spectralEntropyValues = numpy_to_matlab( ...
    spectralEntropyPython ...
);

% src.features.relative_bandpower_envelope
% The direct function check below uses:
%   theta band = 4 to 8 Hz
%   total band = 0.5 to 150 Hz
thetaResult = featuresApi.relative_bandpower_envelope( ...
    pythonSignal, ...
    fs, ...
    py.tuple({4.0, 8.0}), ...
    py.tuple({0.5, 150.0}), ...
    int32(windowSize), ...
    int32(step) ...
);

thetaValues = numpy_to_matlab(thetaResult{1});

% src.features.extract_all_features
% Returns RMS, theta, alpha, beta, gamma, line length,
% spectral entropy, and time indices in one Python dictionary.
featureDictionary = featuresApi.extract_all_features( ...
    pythonSignal, ...
    fs, ...
    int32(windowSize), ...
    int32(step) ...
);

% src.features.minmax_normalize
normalizedRmsPython = featuresApi.minmax_normalize( ...
    numpy.array(rmsValues) ...
);

normalizedRms = numpy_to_matlab( ...
    normalizedRmsPython ...
);

% src.features.exponential_smooth
smoothedRmsPython = featuresApi.exponential_smooth( ...
    normalizedRmsPython, ...
    pyargs("alpha", 0.1) ...
);

smoothedRms = numpy_to_matlab( ...
    smoothedRmsPython ...
);

% src.features.stack_features
% Combines the seven selected features into one matrix.
featureNames = py.list({ ...
    "rms", ...
    "theta", ...
    "alpha", ...
    "beta", ...
    "gamma", ...
    "ll", ...
    "se" ...
});

stackedMatrixPython = featuresApi.stack_features( ...
    featureDictionary, ...
    featureNames ...
);

%% Call the combined operation from gui/api/features_api.py

% gui.api.features_api.prepare_feature_matrix combines:
%
%   validate_signal
%   preprocess_signal
%       -> src.features.highpass_filter when filtering is enabled
%   extract_features
%       -> src.features.extract_all_features
%   src.features.stack_features
%
% This is the operation a future MATLAB GUI would usually call.
prepared = featuresApi.prepare_feature_matrix( ...
    pythonSignal, ...
    fs, ...
    int32(windowSize), ...
    int32(step), ...
    pyargs("apply_highpass", true) ...
);

preparedMatrixPython = ...
    prepared{py.str("feature_matrix")};

preparedTimeIndicesPython = ...
    prepared{py.str("time_indices")};

%% Package the results for MATLAB

result.filteredSignal = numpy_to_matlab( ...
    filteredSignalPython ...
);

result.rmsValues = rmsValues;
result.rmsTimeIndices = rmsTimeIndices;
result.lineLengthValues = lineLengthValues;
result.spectralEntropyValues = spectralEntropyValues;
result.thetaValues = thetaValues;

result.normalizedRms = normalizedRms;
result.smoothedRms = smoothedRms;

result.stackedMatrix = numpy_to_matlab( ...
    stackedMatrixPython ...
);

result.featureMatrix = numpy_to_matlab( ...
    preparedMatrixPython ...
);

result.timeIndices = numpy_to_matlab( ...
    preparedTimeIndicesPython ...
);

% Keep these Python values because the detection API can use them directly.
% This avoids converting a matrix to MATLAB and then immediately converting
% it back into Python.
result.pythonFeatureMatrix = preparedMatrixPython;
result.pythonTimeIndices = preparedTimeIndicesPython;
result.pythonFeatureDictionary = featureDictionary;

result.windowSize = windowSize;
result.step = step;

end


function values = numpy_to_matlab(numpyArray)
%NUMPY_TO_MATLAB Convert a one- or two-dimensional NumPy array to MATLAB.
%
% MATLAB does not always convert NumPy arrays directly with double().
% This helper flattens the array in Python and rebuilds its original shape
% as a normal MATLAB numeric array.

shape = numpyArray.shape;
numberOfDimensions = int64(py.len(shape));

flatPythonValues = numpyArray.ravel().tolist();
flatCellValues = cell(flatPythonValues);

flatValues = cellfun( ...
    @double, ...
    flatCellValues ...
);

if numberOfDimensions == 1
    values = flatValues(:)';
    return
end

if numberOfDimensions == 2
    rows = double(shape{1});
    columns = double(shape{2});

    values = reshape( ...
        flatValues, ...
        columns, ...
        rows ...
    )';

    return
end

error( ...
    "SEEG:UnsupportedNumPyDimensions", ...
    "Only one- and two-dimensional NumPy arrays are supported." ...
);

end