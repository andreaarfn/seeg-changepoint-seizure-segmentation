function result = run_detection_api(featureResult, fs)
%RUN_DETECTION_API Run every detection operation used by the MATLAB bridge.
%
% This helper does not implement changepoint detection in MATLAB.
% It passes the feature matrix to:
%
%     gui/api/detection_api.py
%
% That API exposes and organizes functions from:
%
%     src/detection.py
%
% Original src.detection functions called here:
%
%   detect_changepoints_pelt
%       Runs PELT and returns all detected changepoint indices.
%
%   detect_onset
%       Returns the first detected changepoint.
%
%   detect_transition
%       Returns the changepoint nearest the middle of the matrix.
%
%   detect_termination
%       Returns the last detected changepoint.
%
%   run_three_phase_detection
%       Runs onset, transition, and termination detection together.
%
% Combined functions from gui.api.detection_api called here:
%
%   detect_phase
%       Validates the phase name and feature matrix, then calls one of:
%       detect_onset, detect_transition, or detect_termination.
%
%   detect_all_phases
%       Validates all three matrices and time-index arrays, then calls
%       src.detection.run_three_phase_detection.
%
%   samples_to_seconds
%       Converts returned sample positions into seconds.
%
% Inputs
% ------
% featureResult
%     Structure returned by run_features_api.
%
% fs
%     Sampling frequency in hertz.
%
% Output
% ------
% result
%     MATLAB structure containing changepoint indices, sample positions,
%     seconds, and Python dictionaries used by the metrics bridge.

arguments
    featureResult struct
    fs (1, 1) double {mustBePositive}
end

detectionApi = py.importlib.import_module( ...
    "gui.api.detection_api" ...
);

featureMatrix = featureResult.pythonFeatureMatrix;
timeIndices = featureResult.pythonTimeIndices;

% Phase-specific penalty values from src.detection.DEFAULT_PARAMS.
onsetParameters = py.dict(pyargs( ...
    "penalty", int64(11) ...
));

transitionParameters = py.dict(pyargs( ...
    "penalty", int64(7) ...
));

terminationParameters = py.dict(pyargs( ...
    "penalty", int64(10) ...
));

%% Call the individual functions from src/detection.py

% src.detection.detect_changepoints_pelt
% This direct check requests the l2 cost model and returns every
% changepoint found in the feature matrix.
changepointsPython = detectionApi.detect_changepoints_pelt( ...
    featureMatrix, ...
    5.0, ...
    pyargs("model", "l2") ...
);

% src.detection.detect_onset
onsetIndexPython = detectionApi.detect_onset( ...
    featureMatrix, ...
    onsetParameters ...
);

% src.detection.detect_transition
transitionIndexPython = detectionApi.detect_transition( ...
    featureMatrix, ...
    transitionParameters ...
);

% src.detection.detect_termination
terminationIndexPython = detectionApi.detect_termination( ...
    featureMatrix, ...
    terminationParameters ...
);

% Prepare the three dictionaries expected by run_three_phase_detection.
% This bridge check uses the same real feature matrix for all three phases.
phaseMatrices = py.dict(pyargs( ...
    "onset", featureMatrix, ...
    "transition", featureMatrix, ...
    "termination", featureMatrix ...
));

phaseTimeIndices = py.dict(pyargs( ...
    "onset", timeIndices, ...
    "transition", timeIndices, ...
    "termination", timeIndices ...
));

% src.detection.run_three_phase_detection
threePhaseSamplesPython = ...
    detectionApi.run_three_phase_detection( ...
        phaseMatrices, ...
        pyargs("time_indices", phaseTimeIndices) ...
    );

%% Call the combined operations from gui/api/detection_api.py

% gui.api.detection_api.detect_phase combines:
%
%   feature-matrix validation
%   phase-name validation
%   parameter validation
%   one phase-specific detector from src.detection
selectedOnsetPython = detectionApi.detect_phase( ...
    featureMatrix, ...
    "onset", ...
    onsetParameters ...
);

% gui.api.detection_api.detect_all_phases combines:
%
%   validation of all three feature matrices
%   validation of all three time-index arrays
%   src.detection.run_three_phase_detection
allPhaseSamplesPython = detectionApi.detect_all_phases( ...
    phaseMatrices, ...
    phaseTimeIndices ...
);

% gui.api.detection_api.samples_to_seconds converts the sample positions
% returned above into seconds using the recording's sampling frequency.
allPhaseSecondsPython = detectionApi.samples_to_seconds( ...
    allPhaseSamplesPython, ...
    fs ...
);

%% Package the results for MATLAB

result.changepoints = python_sequence_to_double( ...
    changepointsPython ...
);

result.onsetIndex = python_optional_number( ...
    onsetIndexPython ...
);

result.transitionIndex = python_optional_number( ...
    transitionIndexPython ...
);

result.terminationIndex = python_optional_number( ...
    terminationIndexPython ...
);

result.selectedOnset = python_optional_number( ...
    selectedOnsetPython ...
);

result.samples.onset = python_dictionary_number( ...
    allPhaseSamplesPython, ...
    "onset" ...
);

result.samples.transition = python_dictionary_number( ...
    allPhaseSamplesPython, ...
    "transition" ...
);

result.samples.termination = python_dictionary_number( ...
    allPhaseSamplesPython, ...
    "termination" ...
);

result.seconds.onset = python_dictionary_number( ...
    allPhaseSecondsPython, ...
    "onset" ...
);

result.seconds.transition = python_dictionary_number( ...
    allPhaseSecondsPython, ...
    "transition" ...
);

result.seconds.termination = python_dictionary_number( ...
    allPhaseSecondsPython, ...
    "termination" ...
);

% Preserve the Python dictionaries for the metrics API.
result.pythonSamples = allPhaseSamplesPython;
result.pythonSeconds = allPhaseSecondsPython;
result.pythonThreePhaseSamples = threePhaseSamplesPython;

end


function value = python_optional_number(pythonValue)
%PYTHON_OPTIONAL_NUMBER Convert a Python number or None into MATLAB.
%
% A missing detection is returned by Python as None. MATLAB represents that
% missing detector result as NaN in the manual walkthrough.

if isa(pythonValue, "py.NoneType")
    value = NaN;
else
    value = double(pythonValue);
end

end


function value = python_dictionary_number(dictionary, key)
%PYTHON_DICTIONARY_NUMBER Read one optional number from a Python dictionary.

pythonValue = dictionary{py.str(key)};
value = python_optional_number(pythonValue);

end


function values = python_sequence_to_double(sequence)
%PYTHON_SEQUENCE_TO_DOUBLE Convert a Python numeric sequence to MATLAB.

if int64(py.len(sequence)) == 0
    values = [];
    return
end

values = double(py.array.array("d", sequence));

end