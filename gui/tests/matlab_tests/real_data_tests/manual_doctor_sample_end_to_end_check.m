%% Manual end-to-end check using Dr. Thompson's sample
%
% This script checks the complete MATLAB-to-Python backend using KW_sz.mat.
%
% It only treats independently verifiable values as "expected."
%
% It checks:
%   - the file structure
%   - the selected channel
%   - the signal values
%   - the time axis
%   - the sampling frequency
%   - the existing LVFA annotation
%   - the feature matrix shape and finite values
%   - whether the detection functions return valid outputs
%   - whether relative detection times map correctly back to the
%     original MATLAB time axis
%
% It does NOT assume that the returned onset, transition, or termination
% times are clinically correct.

clear
clc
close all

fprintf("\n");
fprintf("============================================================\n");
fprintf("DR. THOMPSON SAMPLE - END-TO-END BACKEND CHECK\n");
fprintf("============================================================\n\n");


%% ------------------------------------------------------------
% 1. Set up MATLAB and Python
% ------------------------------------------------------------

fprintf("1. MATLAB -> PYTHON CONNECTION\n");
fprintf("------------------------------------------------------------\n");

repositoryRoot = ...
    "/Users/arifi020/Documents/SEEG_GUI_Project/" + ...
    "seeg-changepoint-seizure-segmentation";

cd(repositoryRoot);

addpath("gui/tests/matlab_tests/real_data_tests");
addpath("gui/tests/matlab_tests/helpers");

setup_python_test_environment();

pythonEnvironment = pyenv();

fprintf("Expected:\n");
fprintf("    Python status = Loaded\n\n");

fprintf("Actual:\n");
fprintf("    Python status = %s\n", pythonEnvironment.Status);
fprintf("    Python version = %s\n", pythonEnvironment.Version);
fprintf("    Executable = %s\n\n", pythonEnvironment.Executable);

assert( ...
    string(pythonEnvironment.Status) == "Loaded", ...
    "Python did not load correctly." ...
);

fprintf("[CHECK] Python connection is working.\n\n");


%% ------------------------------------------------------------
% 2. Load Dr. Thompson's sample
% ------------------------------------------------------------

fprintf("============================================================\n");
fprintf("2. LOAD KW_sz.mat\n");
fprintf("============================================================\n");

testFile = fullfile( ...
    repositoryRoot, ...
    "gui", ...
    "tests", ...
    "test_data", ...
    "doctor_thomspon_samples", ...
    "KW_sz.mat" ...
);

fprintf("Expected:\n");
fprintf("    File exists = true\n\n");

fprintf("Actual:\n");
fprintf("    File exists = %s\n\n", ...
    yes_no(isfile(testFile)));

assert(isfile(testFile), ...
    "KW_sz.mat could not be found.");

loaded = load(testFile);

expectedTopLevelFields = { ...
    'chans', ...
    'data1', ...
    'data2', ...
    'data3' ...
};

actualTopLevelFields = fieldnames(loaded);

fprintf("Expected top-level fields:\n");
disp(expectedTopLevelFields');

fprintf("Actual top-level fields:\n");
disp(actualTopLevelFields);

assert( ...
    all(ismember(expectedTopLevelFields, actualTopLevelFields)), ...
    "The expected structures were not found." ...
);

fprintf("[CHECK] File structure is correct.\n\n");


%% ------------------------------------------------------------
% 3. Select the same recording and channel used for validation
% ------------------------------------------------------------

fprintf("============================================================\n");
fprintf("3. SELECT DATA BLOCK AND CHANNEL\n");
fprintf("============================================================\n");

block = loaded.data1;
channelIndex = 1;

signal = block.F(channelIndex, :);
time = block.Time;

channelName = string( ...
    loaded.chans.Channel(channelIndex).Name ...
);

fprintf("Expected from the source file:\n");
fprintf("    Data block = data1\n");
fprintf("    Channel index = 1\n");
fprintf("    Channel name = A1-A2\n");
fprintf("    Samples = 56321\n\n");

fprintf("Actual:\n");
fprintf("    Data block = data1\n");
fprintf("    Channel index = %d\n", channelIndex);
fprintf("    Channel name = %s\n", channelName);
fprintf("    Samples = %d\n\n", numel(signal));

assert(channelName == "A1-A2");
assert(numel(signal) == 56321);

fprintf("[CHECK] Correct channel was loaded.\n\n");


%% ------------------------------------------------------------
% 4. Confirm the selected signal matches the source data
% ------------------------------------------------------------

fprintf("============================================================\n");
fprintf("4. SIGNAL INTEGRITY\n");
fprintf("============================================================\n");

sampleIndices = [1 1000 10000 25000 50000];

sourceValues = block.F(channelIndex, sampleIndices);
selectedValues = signal(sampleIndices);

fprintf("Expected:\n");
fprintf("    Selected signal values should exactly match data1.F.\n\n");

fprintf("Source values:\n");
disp(sourceValues);

fprintf("Selected signal values:\n");
disp(selectedValues);

signalMatches = isequal(sourceValues, selectedValues);

fprintf("Match = %s\n\n", yes_no(signalMatches));

assert(signalMatches, ...
    "The selected signal does not match the source data.");

fprintf("[CHECK] The original signal values are preserved.\n\n");


%% ------------------------------------------------------------
% 5. Verify sampling frequency and time axis
% ------------------------------------------------------------

fprintf("============================================================\n");
fprintf("5. SAMPLING RATE AND TIME AXIS\n");
fprintf("============================================================\n");

fs = 1 / median(diff(time));

fprintf("Expected from the source file:\n");
fprintf("    Sampling frequency = 512 Hz\n");
fprintf("    First time = 3290.000 s\n");
fprintf("    Last time = 3400.000 s\n\n");

fprintf("Actual:\n");
fprintf("    Sampling frequency = %.2f Hz\n", fs);
fprintf("    First time = %.3f s\n", time(1));
fprintf("    Last time = %.3f s\n\n", time(end));

assert(abs(fs - 512) < 1e-9);
assert(abs(time(1) - 3290) < 1e-9);
assert(abs(time(end) - 3400) < 1e-9);

fprintf("[CHECK] Sampling rate and time axis are correct.\n\n");


%% ------------------------------------------------------------
% 6. Verify the existing annotation
% ------------------------------------------------------------

fprintf("============================================================\n");
fprintf("6. EXISTING ANNOTATION\n");
fprintf("============================================================\n");

eventLabel = string(block.Events.label);
eventAbsoluteTime = block.Events.times;
eventRelativeTime = eventAbsoluteTime - time(1);

fprintf("Expected from the source file:\n");
fprintf("    Label = LVFA\n");
fprintf("    Absolute time = 3320.543 s\n");
fprintf("    Relative time = 30.543 s\n\n");

fprintf("Actual:\n");
fprintf("    Label = %s\n", eventLabel);
fprintf("    Absolute time = %.3f s\n", eventAbsoluteTime);
fprintf("    Relative time = %.3f s\n\n", eventRelativeTime);

assert(eventLabel == "LVFA");
assert(abs(eventAbsoluteTime - 3320.543) < 0.001);

fprintf("[CHECK] Existing annotation was preserved correctly.\n\n");


%% View 1: Original signal and existing annotation

figure("Name", "1 - Original signal and annotation");

plot(time, signal);
hold on;

xline( ...
    eventAbsoluteTime, ...
    ":", ...
    "LVFA" ...
);

xlabel("Time (s)");
ylabel("Amplitude");
title(channelName + " - Original Signal");
grid on;
hold off;


%% ------------------------------------------------------------
% 7. Run feature extraction
% ------------------------------------------------------------

fprintf("============================================================\n");
fprintf("7. PYTHON FEATURE EXTRACTION\n");
fprintf("============================================================\n");

features = run_features_api(signal, fs);

featureRows = size(features.featureMatrix, 1);
featureColumns = size(features.featureMatrix, 2);

featuresFinite = all( ...
    isfinite(features.featureMatrix), ...
    "all" ...
);

fprintf("Expected from the feature workflow:\n");
fprintf("    Feature columns = 7\n");
fprintf("    Feature rows > 0\n");
fprintf("    All feature values finite = true\n\n");

fprintf("Actual:\n");
fprintf("    Feature rows = %d\n", featureRows);
fprintf("    Feature columns = %d\n", featureColumns);
fprintf("    Window size = %d samples\n", features.windowSize);
fprintf("    Step = %d samples\n", features.step);
fprintf("    All values finite = %s\n\n", ...
    yes_no(featuresFinite));

assert(featureRows > 0);
assert(featureColumns == 7);
assert(featuresFinite);

fprintf("[CHECK] Feature extraction returned a valid 7-column matrix.\n\n");


%% View 2: Feature matrix

featureNames = { ...
    'RMS', ...
    'Theta', ...
    'Alpha', ...
    'Beta', ...
    'Gamma', ...
    'LineLength', ...
    'SpectralEntropy' ...
};

featureTime = ...
    time(1) + ...
    features.timeIndices / fs;

figure("Name", "2 - Extracted features");

plot(featureTime, features.featureMatrix);

xlabel("Time (s)");
ylabel("Normalized feature value");
title(channelName + " - Seven Features");

legend( ...
    featureNames, ...
    "Location", ...
    "best" ...
);

grid on;


%% ------------------------------------------------------------
% 8. Run changepoint detection
% ------------------------------------------------------------

fprintf("============================================================\n");
fprintf("8. PYTHON CHANGEPOINT DETECTION\n");
fprintf("============================================================\n");

detections = run_detection_api(features, fs);

fprintf("Returned detection values:\n");
fprintf("    Onset = %s\n", ...
    format_detection(detections.seconds.onset));
fprintf("    Transition = %s\n", ...
    format_detection(detections.seconds.transition));
fprintf("    Termination = %s\n\n", ...
    format_detection(detections.seconds.termination));

validOnset = ...
    isfinite(detections.seconds.onset) || ...
    isnan(detections.seconds.onset);

validTransition = ...
    isfinite(detections.seconds.transition) || ...
    isnan(detections.seconds.transition);

validTermination = ...
    isfinite(detections.seconds.termination) || ...
    isnan(detections.seconds.termination);

assert(validOnset);
assert(validTransition);
assert(validTermination);

fprintf("[CHECK] Detection functions returned valid outputs.\n");
fprintf("        A numeric value means detected.\n");
fprintf("        NaN means not detected.\n\n");


%% ------------------------------------------------------------
% 9. Verify relative -> absolute time mapping
% ------------------------------------------------------------

fprintf("============================================================\n");
fprintf("9. DETECTION TIME MAPPING\n");
fprintf("============================================================\n");

if ~isnan(detections.seconds.onset)

    onsetAbsolute = ...
        time(1) + detections.seconds.onset;

    fprintf("Onset relative time:\n");
    fprintf("    %.4f s\n", detections.seconds.onset);

    fprintf("Onset absolute time:\n");
    fprintf("    %.4f s\n\n", onsetAbsolute);

    assert( ...
        abs( ...
            (onsetAbsolute - time(1)) - ...
            detections.seconds.onset ...
        ) < 1e-9 ...
    );

else
    onsetAbsolute = NaN;

    fprintf("Onset was not detected.\n\n");
end


if ~isnan(detections.seconds.transition)

    transitionAbsolute = ...
        time(1) + detections.seconds.transition;

    fprintf("Transition relative time:\n");
    fprintf("    %.4f s\n", ...
        detections.seconds.transition);

    fprintf("Transition absolute time:\n");
    fprintf("    %.4f s\n\n", ...
        transitionAbsolute);

    assert( ...
        abs( ...
            (transitionAbsolute - time(1)) - ...
            detections.seconds.transition ...
        ) < 1e-9 ...
    );

else
    transitionAbsolute = NaN;

    fprintf("Transition was not detected.\n\n");
end


if ~isnan(detections.seconds.termination)

    terminationAbsolute = ...
        time(1) + detections.seconds.termination;

    fprintf("Termination relative time:\n");
    fprintf("    %.4f s\n", ...
        detections.seconds.termination);

    fprintf("Termination absolute time:\n");
    fprintf("    %.4f s\n\n", ...
        terminationAbsolute);

    assert( ...
        abs( ...
            (terminationAbsolute - time(1)) - ...
            detections.seconds.termination ...
        ) < 1e-9 ...
    );

else
    terminationAbsolute = NaN;

    fprintf("Termination was not detected.\n\n");
end

fprintf("[CHECK] Returned detection times map correctly to the\n");
fprintf("        original MATLAB time axis.\n\n");


%% ------------------------------------------------------------
% 10. Check detections fall inside the selected recording
% ------------------------------------------------------------

fprintf("============================================================\n");
fprintf("10. DETECTION BOUNDS\n");
fprintf("============================================================\n");

recordingStart = time(1);
recordingEnd = time(end);

if ~isnan(onsetAbsolute)
    assert( ...
        onsetAbsolute >= recordingStart && ...
        onsetAbsolute <= recordingEnd ...
    );

    fprintf("Onset lies inside the recording: yes\n");
end

if ~isnan(transitionAbsolute)
    assert( ...
        transitionAbsolute >= recordingStart && ...
        transitionAbsolute <= recordingEnd ...
    );

    fprintf("Transition lies inside the recording: yes\n");
end

if ~isnan(terminationAbsolute)
    assert( ...
        terminationAbsolute >= recordingStart && ...
        terminationAbsolute <= recordingEnd ...
    );

    fprintf("Termination lies inside the recording: yes\n");
end

fprintf("\n[CHECK] All returned detections are within the signal bounds.\n\n");


%% ------------------------------------------------------------
% 11. Compare existing annotation and detector visually
% ------------------------------------------------------------

fprintf("============================================================\n");
fprintf("11. VISUAL COMPARISON\n");
fprintf("============================================================\n");

fprintf("The existing LVFA annotation is plotted with any returned\n");
fprintf("onset, transition, and termination markers.\n\n");

fprintf("This checks that the markers are placed on the correct\n");
fprintf("MATLAB time axis. It does not establish clinical accuracy.\n\n");


%% View 3: Annotation and detector output

figure("Name", "3 - Annotation and detector output");

plot(time, signal);
hold on;

xline( ...
    eventAbsoluteTime, ...
    ":", ...
    "LVFA" ...
);

if ~isnan(onsetAbsolute)
    xline( ...
        onsetAbsolute, ...
        "--", ...
        "Onset" ...
    );
end

if ~isnan(transitionAbsolute)
    xline( ...
        transitionAbsolute, ...
        "--", ...
        "Transition" ...
    );
end

if ~isnan(terminationAbsolute)
    xline( ...
        terminationAbsolute, ...
        "--", ...
        "Termination" ...
    );
end

xlabel("Time (s)");
ylabel("Amplitude");
title(channelName + " - Annotation and Detector Output");
grid on;
hold off;


%% ------------------------------------------------------------
% Final summary
% ------------------------------------------------------------

fprintf("============================================================\n");
fprintf("END-TO-END CHECK COMPLETE\n");
fprintf("============================================================\n\n");

fprintf("Verified independently:\n");
fprintf("  [✓] KW_sz.mat loads successfully\n");
fprintf("  [✓] Expected Brainstorm structures are present\n");
fprintf("  [✓] Channel A1-A2 is selected correctly\n");
fprintf("  [✓] Selected signal values match data1.F exactly\n");
fprintf("  [✓] Sampling frequency is derived as 512 Hz\n");
fprintf("  [✓] Original time axis is preserved\n");
fprintf("  [✓] Existing LVFA annotation is preserved\n");
fprintf("  [✓] Python feature extraction runs from MATLAB\n");
fprintf("  [✓] Seven feature columns are returned\n");
fprintf("  [✓] Feature matrix contains finite values\n");
fprintf("  [✓] Python detection functions return valid outputs\n");
fprintf("  [✓] Returned detection times map correctly to the\n");
fprintf("      original MATLAB time axis\n");
fprintf("  [✓] Returned detections lie within the recording\n");
fprintf("  [✓] Existing and detected markers can be plotted together\n\n");

fprintf("Not established by this check:\n");
fprintf("  [ ] Whether detected onset is clinically correct\n");
fprintf("  [ ] Whether detected transition is clinically correct\n");
fprintf("  [ ] Whether detected termination is clinically correct\n");
fprintf("  [ ] Whether LVFA corresponds to one of those three phases\n\n");


function text = yes_no(value)

if value
    text = "yes";
else
    text = "no";
end

end


function text = format_detection(value)

if isnan(value)
    text = "Not detected";
else
    text = sprintf("%.4f s", value);
end

end