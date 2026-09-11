"""
Valid synthetic data for positive GUI and pipeline tests.

These helpers generate deterministic signals and feature matrices used by
the automated test suite. They are intended for software validation only
and are not physiological models of seizures.
"""

from __future__ import annotations

import numpy as np

# ---------------------------------------------------------------------
# Default constants
# ---------------------------------------------------------------------

DEFAULT_FS = 1000
DEFAULT_DURATION_SECONDS = 30.0
DEFAULT_SEED = 42


# ---------------------------------------------------------------------
# Mock SEEG signal
# ---------------------------------------------------------------------

def create_mock_seeg_signal(
    fs: int = DEFAULT_FS,
    duration_seconds: float = DEFAULT_DURATION_SECONDS,
    seed: int = DEFAULT_SEED,
) -> tuple[np.ndarray, np.ndarray]:
    """
    Create the default synthetic SEEG signal used throughout the tests.

    The signal contains four regions:

        0–8 s   : low-amplitude 6 Hz activity
        8–16 s  : larger 18 Hz activity
        16–24 s : larger 40 Hz activity
        24–30 s : return toward baseline

    With the current pipeline this signal produces approximately:

        onset       = 8750 samples (8.75 s)
        transition  = 16730 samples (16.73 s)
        termination = 25300 samples (25.30 s)
    """

    if fs <= 0:
        raise ValueError("fs must be positive.")

    if duration_seconds <= 0:
        raise ValueError("duration_seconds must be positive.")

    rng = np.random.default_rng(seed)

    n_samples = int(fs * duration_seconds)

    time = np.arange(n_samples) / fs

    signal = 0.15 * rng.standard_normal(n_samples)

    before = time < 8
    phase1 = (time >= 8) & (time < 16)
    phase2 = (time >= 16) & (time < 24)
    after = time >= 24

    signal[before] += (
        0.10 * np.sin(2 * np.pi * 6 * time[before])
    )

    signal[phase1] += (
        0.80 * np.sin(2 * np.pi * 18 * time[phase1])
    )

    signal[phase2] += (
        1.20 * np.sin(2 * np.pi * 40 * time[phase2])
    )

    signal[after] += (
        0.12 * np.sin(2 * np.pi * 7 * time[after])
    )

    return time, signal


# ---------------------------------------------------------------------
# Simple sinusoid
# ---------------------------------------------------------------------

def create_single_frequency_signal(
    fs: int = 1000,
    duration_seconds: float = 5.0,
    frequency_hz: float = 10.0,
    amplitude: float = 1.0,
) -> tuple[np.ndarray, np.ndarray]:
    """
    Create a pure sinusoid for feature tests.
    """

    if fs <= 0:
        raise ValueError("fs must be positive.")

    if duration_seconds <= 0:
        raise ValueError("duration_seconds must be positive.")

    time = np.arange(int(fs * duration_seconds)) / fs

    signal = amplitude * np.sin(
        2 * np.pi * frequency_hz * time
    )

    return time, signal


# ---------------------------------------------------------------------
# Detection test helpers
# ---------------------------------------------------------------------

def create_piecewise_feature_matrix() -> np.ndarray:
    """
    Create a feature matrix with two obvious changepoints.

    Rows:
        0-39
        40-79
        80-119
    """

    rng = np.random.default_rng(DEFAULT_SEED)

    first = rng.normal(
        loc=0.0,
        scale=0.05,
        size=(40, 3),
    )

    second = rng.normal(
        loc=2.0,
        scale=0.05,
        size=(40, 3),
    )

    third = rng.normal(
        loc=-1.5,
        scale=0.05,
        size=(40, 3),
    )

    return np.vstack([
        first,
        second,
        third,
    ])


def create_phase_feature_matrices(
    rows: int = 5,
    cols: int = 2,
) -> dict[str, np.ndarray]:
    """
    Create feature matrices for onset, transition,
    and termination tests.
    """

    matrix = np.ones(
        (rows, cols),
        dtype=float,
    )

    return {
        "onset": matrix.copy(),
        "transition": matrix.copy(),
        "termination": matrix.copy(),
    }


def create_phase_time_indices() -> dict[str, np.ndarray]:
    """
    Create sample-index arrays used when testing
    run_three_phase_detection().
    """

    return {
        "onset": np.array(
            [100, 200, 300, 400, 500],
            dtype=int,
        ),
        "transition": np.array(
            [110, 210, 310, 410, 510],
            dtype=int,
        ),
        "termination": np.array(
            [120, 220, 320, 420, 520],
            dtype=int,
        ),
    }


# ---------------------------------------------------------------------
# Feature unit-test inputs
# ---------------------------------------------------------------------

def create_handcrafted_feature_inputs() -> dict[str, np.ndarray]:
    """
    Small arrays whose outputs are known exactly.
    """

    return {

        "rms_signal": np.array(
            [3.0, 4.0],
            dtype=float,
        ),

        "line_length_signal": np.array(
            [0.0, 1.0, 3.0, 2.0],
            dtype=float,
        ),

        "normalization_feature": np.array(
            [2.0, 4.0, 6.0],
            dtype=float,
        ),

        "constant_feature": np.array(
            [7.5, 7.5, 7.5],
            dtype=float,
        ),

        "smoothing_feature": np.array(
            [0.0, 1.0, 0.0, 1.0],
            dtype=float,
        ),
    }


# ---------------------------------------------------------------------
# Expected regression outputs
# ---------------------------------------------------------------------

def expected_mock_detection_results() -> dict:
    """
    Exact regression output for the default mock signal.

    If this changes unexpectedly, either:

        1. the pipeline changed,
        2. a dependency changed, or
        3. the mock signal changed.
    """

    return {

        "samples": {

            "onset": 8750,
            "transition": 16730,
            "termination": 25300,
        },

        "seconds": {

            "onset": 8.75,
            "transition": 16.73,
            "termination": 25.30,
        },
    }


def expected_mock_feature_shapes() -> dict:
    """
    Expected feature dimensions for the default
    30-second mock signal.
    """

    return {

        "onset": {

            "windows": 194,
            "features": 7,
            "first_time_index": 500,
            "last_time_index": 29450,
        },

        "transition": {

            "windows": 226,
            "features": 7,
            "first_time_index": 350,
            "last_time_index": 29600,
        },

        "termination": {

            "windows": 146,
            "features": 7,
            "first_time_index": 500,
            "last_time_index": 29500,
        },
    }