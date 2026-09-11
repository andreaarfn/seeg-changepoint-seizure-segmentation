# MATLAB Integration Layer for SEEG Three-Phase Seizure Segmentation

## Purpose

The original repository was designed as a Python research codebase. Its core algorithms are implemented as independent functions in the `src/` directory, while the `scripts/` directory contains research workflows used to reproduce the analyses in the published paper.

The goal of this `gui/` package is **not to modify or replace the original algorithms**. Instead, it provides a clean interface that allows MATLAB (or another application) to call the existing Python code without needing to reconstruct the processing pipeline manually.


- Preserve the original repository structure.
- Do not duplicate scientific algorithms.
- Keep every original function individually accessible.
- Provide higher-level helper functions for common workflows.
- Validate inputs before calling the scientific code.
- Make future MATLAB integration straightforward.

---

# Directory Structure

```
gui/
│
├── api/
│   ├── features_api.py
│   ├── detection_api.py
│   ├── metrics_api.py
│   └── __init__.py
│
├── tests/
│   ├── python_unit_tests/
│   └── api_tests/
│
├── mock_data_positive.py
├── mock_data_negative.py
│
└── test_gui_pipeline.py
```

---

# Relationship to the Original Repository

The original repository separates its code into two categories:

```
src/
    Scientific algorithms

scripts/
    Research workflows and analysis scripts
```

The GUI follows the same philosophy.

The `src` folder remains unchanged and continues to contain the scientific implementation.

The `gui/api` folder simply provides a MATLAB-friendly interface to those functions.

No scientific calculations have been rewritten.

---

# API Modules

## features_api.py

Wraps the functions from:

```
src/features.py
```

### Original functions still available

- highpass_filter()
- rms_envelope()
- line_length()
- spectral_entropy()
- relative_bandpower_envelope()
- extract_all_features()
- minmax_normalize()
- exponential_smooth()
- stack_features()

### Added helper functions

#### validate_signal()

Checks that

- the signal is one-dimensional
- the signal is not empty
- there are no NaN or infinite values
- the sampling frequency is valid

This allows MATLAB to receive clear errors before the scientific functions are executed.

---

#### preprocess_signal()

Combines

```
validate_signal()

↓

highpass_filter()
```

The high-pass filter can optionally be skipped.

---

#### extract_features()

Combines

```
validate_signal()

↓

preprocess_signal()

↓

extract_all_features()
```

Returns the complete feature dictionary produced by the original repository.

---

#### prepare_feature_matrix()

Combines

```
validate_signal()

↓

preprocess_signal()

↓

extract_all_features()

↓

stack_features()
```

Returns

- processed signal
- extracted features
- stacked feature matrix
- feature names
- time indices

This produces the feature matrix required by the changepoint detector in one function call.

---

## detection_api.py

Wraps

```
src/detection.py
```

### Original functions still available

- detect_changepoints_pelt()
- detect_onset()
- detect_transition()
- detect_termination()
- run_three_phase_detection()

### Added helper functions

#### detect_phase()

Allows MATLAB to detect only one seizure phase.

Internally calls one of

```
detect_onset()

or

detect_transition()

or

detect_termination()
```

depending on the selected phase.

---

#### detect_all_phases()

Validates the inputs before calling

```
run_three_phase_detection()
```

Returns

```
{
    onset,
    transition,
    termination
}
```

---

#### samples_to_seconds()

Converts detected sample indices into seconds.

Example

```
8750 samples

↓

8.75 seconds
```

---

## metrics_api.py

Wraps

```
src/metrics.py
```

### Original functions still available

- absolute_error()
- accuracy_within_tolerance()
- mae()
- rmse()
- summarise()

### Added helper functions

#### calculate_phase_errors()

Calls

```
absolute_error()
```

for

- onset
- transition
- termination

and returns one dictionary containing all phase errors.

---

#### summarize_errors()

Validates the tolerance before calling

```
summarise()
```

---

#### evaluate_detections()

Combines

```
calculate_phase_errors()

↓

summarize_errors()
```

Returns

```
{
    errors,
    summary
}
```

---

# Testing

Testing is divided into two layers.

## 1. Python Unit Tests

Location

```
gui/tests/python_unit_tests/
```

Purpose

Verify that every individual function in

```
src/
```

behaves correctly.

These tests cover

- expected inputs
- edge cases
- invalid inputs
- failure conditions

The scientific algorithms themselves are tested here.

---

## 2. API Tests

Location

```
gui/tests/api_tests/
```

Purpose

Verify that the MATLAB-facing API correctly wraps the original functions.

These tests confirm that the API

- validates inputs
- calls the correct underlying functions
- returns the expected outputs
- preserves the original functionality

No scientific calculations are duplicated.

---

# Current Test Coverage

The following components have been tested.

## src/features.py

✓ Positive cases

✓ Negative cases

---

## src/detection.py

✓ Positive cases

✓ Negative cases

---

## src/metrics.py

✓ Positive cases

✓ Negative cases

---

## gui/api/features_api.py

✓ Positive cases

✓ Negative cases

---

## gui/api/detection_api.py

✓ Positive cases

✓ Negative cases

---

## gui/api/metrics_api.py

✓ Positive cases

✓ Negative cases

---

# Current Status

At this stage

✓ Every scientific function has been unit tested.

✓ Every MATLAB-facing API wrapper has been tested.

✓ The original repository remains unchanged.

✓ The API layer provides a clean interface for future MATLAB integration.

---

# Next Step

The next stage is MATLAB integration.

MATLAB will call the functions in

```
gui/api/
```

instead of directly calling the functions in

```
src/
```

This keeps the scientific implementation unchanged while providing MATLAB with a stable, validated interface.

Once MATLAB integration is complete, the final GUI can call these API functions to

- load SEEG recordings
- extract features
- detect seizure onset
- detect intra-ictal transition
- detect seizure termination
- visualize results
- export annotations back to MATLAB