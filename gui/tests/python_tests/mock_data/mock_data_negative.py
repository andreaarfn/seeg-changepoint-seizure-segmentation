"""Invalid and edge-case inputs for negative GUI and pipeline tests.

These helpers deliberately create inputs that should be rejected, return
empty outputs, or trigger controlled fallback behavior.
"""

from __future__ import annotations

from typing import Any

import numpy as np


def create_empty_signal() -> np.ndarray:
    """Return an empty one-dimensional signal.

    Expected GUI pipeline behavior:
        ValueError: signal cannot be empty.
    """
    return np.array([], dtype=float)


def create_short_signal(
    number_of_samples: int = 100,
) -> np.ndarray:
    """Return a signal shorter than the default feature windows.

    Expected direct feature behavior:

    - rms_envelope:
      empty values and empty time indices
    - line_length:
      empty values
    - spectral_entropy:
      empty values
    - relative_bandpower_envelope:
      empty values and empty time indices

    Expected GUI pipeline behavior:
        ValueError indicating that the signal is too short.
    """
    if number_of_samples < 0:
        raise ValueError(
            "number_of_samples cannot be negative."
        )

    return np.ones(number_of_samples, dtype=float)


def create_too_short_for_highpass_signal() -> np.ndarray:
    """Return a signal too short for scipy.signal.filtfilt.

    Expected behavior:
        ValueError from highpass_filter.
    """
    return np.ones(3, dtype=float)


def create_signal_with_nan(
    number_of_samples: int = 30000,
    nan_index: int = 10,
) -> np.ndarray:
    """Return a signal containing one NaN.

    Expected GUI pipeline behavior:
        ValueError indicating non-finite values.
    """
    signal = np.zeros(number_of_samples, dtype=float)

    if not 0 <= nan_index < number_of_samples:
        raise ValueError(
            "nan_index must identify an element in the signal."
        )

    signal[nan_index] = np.nan
    return signal


def create_signal_with_positive_infinity(
    number_of_samples: int = 30000,
    infinity_index: int = 10,
) -> np.ndarray:
    """Return a signal containing positive infinity.

    Expected GUI pipeline behavior:
        ValueError indicating non-finite values.
    """
    signal = np.zeros(number_of_samples, dtype=float)

    if not 0 <= infinity_index < number_of_samples:
        raise ValueError(
            "infinity_index must identify an element in the signal."
        )

    signal[infinity_index] = np.inf
    return signal


def create_signal_with_negative_infinity(
    number_of_samples: int = 30000,
    infinity_index: int = 10,
) -> np.ndarray:
    """Return a signal containing negative infinity."""
    signal = np.zeros(number_of_samples, dtype=float)

    if not 0 <= infinity_index < number_of_samples:
        raise ValueError(
            "infinity_index must identify an element in the signal."
        )

    signal[infinity_index] = -np.inf
    return signal


def create_two_dimensional_signal(
    channels: int = 2,
    number_of_samples: int = 30000,
) -> np.ndarray:
    """Return a 2-D array instead of one selected channel.

    Expected GUI pipeline behavior:
        ValueError indicating that the signal must be one-dimensional.
    """
    return np.zeros(
        (channels, number_of_samples),
        dtype=float,
    )


def create_constant_signal(
    number_of_samples: int = 30000,
    value: float = 1.0,
) -> np.ndarray:
    """Return a finite constant signal.

    This is an edge case rather than an invalid numerical array.

    Expected behavior:

    - feature extraction should produce finite arrays;
    - min-max normalization should produce zeros;
    - PELT may return no changepoints;
    - phase detections may therefore be None.
    """
    return np.full(
        number_of_samples,
        value,
        dtype=float,
    )


def create_empty_feature() -> np.ndarray:
    """Return an empty feature array.

    Expected behavior:

    - minmax_normalize:
      ValueError
    - exponential_smooth:
      IndexError with the current source implementation
    """
    return np.array([], dtype=float)


def create_constant_feature(
    length: int = 10,
    value: float = 7.5,
) -> np.ndarray:
    """Return a constant feature array.

    Expected minmax_normalize output:
        an array of zeros with the same shape.
    """
    return np.full(
        length,
        value,
        dtype=float,
    )


def create_feature_dict_missing_theta() -> dict[str, np.ndarray]:
    """Return a feature dictionary missing a requested feature.

    Expected stack_features behavior:
        KeyError when feature_names includes "theta".
    """
    return {
        "rms": np.array(
            [1.0, 2.0, 3.0],
            dtype=float,
        ),
    }


def create_feature_dict_with_empty_theta() -> dict[str, np.ndarray]:
    """Return a feature dictionary containing one empty feature.

    Expected stack_features behavior:
        ValueError from normalization of the empty feature.
    """
    return {
        "rms": np.array(
            [1.0, 2.0, 3.0],
            dtype=float,
        ),
        "theta": np.array([], dtype=float),
    }


def create_incomplete_phase_matrices() -> dict[str, np.ndarray]:
    """Return matrices missing transition and termination phases.

    Expected run_three_phase_detection behavior:
        KeyError.
    """
    return {
        "onset": np.ones(
            (20, 2),
            dtype=float,
        ),
    }


def create_complete_phase_matrices(
    number_of_windows: int = 20,
    number_of_features: int = 2,
) -> dict[str, np.ndarray]:
    """Return structurally valid matrices for controlled detection tests."""
    matrix = np.ones(
        (number_of_windows, number_of_features),
        dtype=float,
    )

    return {
        "onset": matrix.copy(),
        "transition": matrix.copy(),
        "termination": matrix.copy(),
    }


def create_phase_params_missing_penalty() -> dict[str, Any]:
    """Return a parameter dictionary without the required penalty key.

    Expected detect_onset, detect_transition, or detect_termination behavior:
        KeyError.
    """
    return {}


def create_valid_phase_params() -> dict[str, dict[str, int]]:
    """Return minimal valid parameters for controlled detection tests."""
    return {
        "onset": {
            "penalty": 11,
        },
        "transition": {
            "penalty": 7,
        },
        "termination": {
            "penalty": 10,
        },
    }


def create_short_time_indices() -> dict[str, np.ndarray]:
    """Return time arrays shorter than a controlled detected index.

    When a mocked detector returns index 8, expected output is None for
    each phase because index 8 cannot be mapped into a length-2 array.
    """
    return {
        "onset": np.array(
            [100, 200],
            dtype=int,
        ),
        "transition": np.array(
            [100, 200],
            dtype=int,
        ),
        "termination": np.array(
            [100, 200],
            dtype=int,
        ),
    }


def expected_no_changepoint_result() -> dict[str, None]:
    """Return the exact expected result when all phases detect nothing."""
    return {
        "onset": None,
        "transition": None,
        "termination": None,
    }


def invalid_sampling_frequencies() -> tuple[int, int]:
    """Return sampling rates that the GUI pipeline must reject."""
    return 0, -1000


def invalid_feature_steps() -> tuple[int, int]:
    """Return zero and negative sliding-window steps."""
    return 0, -1