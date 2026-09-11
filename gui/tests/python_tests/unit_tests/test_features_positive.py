"""Positive tests for src.features."""

import numpy as np
import pytest

from gui.mock_data_positive import (
    create_handcrafted_feature_inputs,
    create_single_frequency_signal,
)
from src.features import (
    BANDS,
    TOTAL_BAND,
    exponential_smooth,
    extract_all_features,
    highpass_filter,
    line_length,
    minmax_normalize,
    relative_bandpower_envelope,
    rms_envelope,
    spectral_entropy,
    stack_features,
)


FS = 1000
DURATION_SECONDS = 5.0
WINDOW_SIZE = 1000
STEP = 150

FEATURE_NAMES = [
    "rms",
    "theta",
    "alpha",
    "beta",
    "gamma",
    "ll",
    "se",
]


def test_highpass_filter_preserves_signal_shape() -> None:
    _, signal = create_single_frequency_signal(
        fs=FS,
        duration_seconds=DURATION_SECONDS,
        frequency_hz=10.0,
        amplitude=1.0,
    )

    filtered = highpass_filter(
        signal,
        fs=FS,
    )

    assert filtered.shape == signal.shape
    assert np.all(np.isfinite(filtered))


def test_rms_envelope_returns_exact_value_for_handcrafted_signal() -> None:
    inputs = create_handcrafted_feature_inputs()
    signal = inputs["rms_signal"]

    values, time_indices = rms_envelope(
        signal,
        window_size=2,
        step=1,
    )

    expected_values = np.array([
        3.5355339059327378,
    ])

    expected_time_indices = np.array([
        1,
    ])

    assert values == pytest.approx(expected_values)
    assert np.array_equal(
        time_indices,
        expected_time_indices,
    )


def test_rms_envelope_returns_expected_number_of_windows() -> None:
    _, signal = create_single_frequency_signal(
        fs=FS,
        duration_seconds=DURATION_SECONDS,
        frequency_hz=10.0,
        amplitude=1.0,
    )

    values, time_indices = rms_envelope(
        signal,
        window_size=WINDOW_SIZE,
        step=STEP,
    )

    expected_number_of_windows = 27

    assert len(values) == expected_number_of_windows
    assert len(time_indices) == expected_number_of_windows
    assert np.all(values >= 0)


def test_rms_time_indices_are_exact_window_centres() -> None:
    _, signal = create_single_frequency_signal(
        fs=FS,
        duration_seconds=DURATION_SECONDS,
        frequency_hz=10.0,
        amplitude=1.0,
    )

    _, time_indices = rms_envelope(
        signal,
        window_size=WINDOW_SIZE,
        step=STEP,
    )

    assert len(time_indices) == 27
    assert time_indices[0] == 500
    assert time_indices[-1] == 4400
    assert np.all(
        np.diff(time_indices) == STEP
    )


def test_line_length_returns_exact_value_for_handcrafted_signal() -> None:
    inputs = create_handcrafted_feature_inputs()
    signal = inputs["line_length_signal"]

    values = line_length(
        signal,
        window_size=4,
        step=1,
    )

    expected = np.array([
        4.0,
    ])

    assert np.array_equal(
        values,
        expected,
    )


def test_line_length_returns_nonnegative_values() -> None:
    _, signal = create_single_frequency_signal(
        fs=FS,
        duration_seconds=DURATION_SECONDS,
        frequency_hz=10.0,
        amplitude=1.0,
    )

    values = line_length(
        signal,
        window_size=WINDOW_SIZE,
        step=STEP,
    )

    assert values.shape == (27,)
    assert np.all(values >= 0)
    assert np.all(np.isfinite(values))


def test_spectral_entropy_returns_finite_values() -> None:
    _, signal = create_single_frequency_signal(
        fs=FS,
        duration_seconds=DURATION_SECONDS,
        frequency_hz=10.0,
        amplitude=1.0,
    )

    values = spectral_entropy(
        signal,
        fs=FS,
        window_size=WINDOW_SIZE,
        step=STEP,
    )

    assert values.shape == (27,)
    assert np.all(np.isfinite(values))
    assert np.all(values >= 0)


def test_relative_bandpower_returns_valid_ratios() -> None:
    _, signal = create_single_frequency_signal(
        fs=FS,
        duration_seconds=DURATION_SECONDS,
        frequency_hz=10.0,
        amplitude=1.0,
    )

    values, time_indices = relative_bandpower_envelope(
        signal=signal,
        fs=FS,
        band=BANDS["alpha"],
        total_band=TOTAL_BAND,
        window_size=WINDOW_SIZE,
        step=STEP,
    )

    assert values.shape == (27,)
    assert time_indices.shape == (27,)
    assert np.all(np.isfinite(values))
    assert np.all(values >= 0)
    assert np.all(values <= 1)


def test_extract_all_features_returns_every_expected_feature() -> None:
    _, signal = create_single_frequency_signal(
        fs=FS,
        duration_seconds=DURATION_SECONDS,
        frequency_hz=10.0,
        amplitude=1.0,
    )

    features = extract_all_features(
        signal,
        fs=FS,
        window_size=WINDOW_SIZE,
        step=STEP,
    )

    expected_keys = {
        "rms",
        "theta",
        "alpha",
        "beta",
        "gamma",
        "ll",
        "se",
        "time_indices",
    }

    assert set(features) == expected_keys

    for name in FEATURE_NAMES:
        assert features[name].shape == (27,)
        assert np.all(
            np.isfinite(features[name])
        )

    assert features["time_indices"].shape == (27,)
    assert features["time_indices"][0] == 500
    assert features["time_indices"][-1] == 4400


def test_minmax_normalize_returns_exact_values() -> None:
    inputs = create_handcrafted_feature_inputs()
    feature = inputs["normalization_feature"]

    normalized = minmax_normalize(feature)

    expected = np.array([
        0.0,
        0.5,
        1.0,
    ])

    assert np.array_equal(
        normalized,
        expected,
    )


def test_exponential_smooth_returns_exact_values() -> None:
    inputs = create_handcrafted_feature_inputs()
    feature = inputs["smoothing_feature"]

    smoothed = exponential_smooth(
        feature,
        alpha=0.1,
    )

    expected = np.array([
        0.0,
        0.1,
        0.09,
        0.181,
    ])

    assert smoothed == pytest.approx(expected)


def test_stack_features_returns_expected_matrix_shape() -> None:
    _, signal = create_single_frequency_signal(
        fs=FS,
        duration_seconds=DURATION_SECONDS,
        frequency_hz=10.0,
        amplitude=1.0,
    )

    features = extract_all_features(
        signal,
        fs=FS,
        window_size=WINDOW_SIZE,
        step=STEP,
    )

    matrix = stack_features(
        feature_dict=features,
        feature_names=FEATURE_NAMES,
    )

    assert matrix.shape == (27, 7)
    assert np.all(np.isfinite(matrix))


def test_stack_features_returns_exact_weighted_values() -> None:
    feature_dict = {
        "rms": np.array([
            0.0,
            0.5,
            1.0,
        ]),
        "theta": np.array([
            0.0,
            0.5,
            1.0,
        ]),
    }

    matrix = stack_features(
        feature_dict=feature_dict,
        feature_names=[
            "rms",
            "theta",
        ],
        weights={
            "rms": 2.0,
            "theta": 0.5,
        },
        alpha=0.1,
    )

    expected = np.array([
        [0.0, 0.0],
        [0.1, 0.025],
        [0.29, 0.0725],
    ])

    assert matrix == pytest.approx(expected)


def test_rms_accepts_list_input() -> None:
    signal = [0.0] * 1000

    values, time_indices = rms_envelope(
        signal,
        window_size=100,
        step=50,
    )

    assert values.shape == (19,)
    assert time_indices.shape == (19,)
    assert np.all(values == 0.0)

    assert time_indices[0] == 50
    assert time_indices[-1] == 950


def test_stack_features_uses_shortest_feature_length() -> None:
    feature_dict = {
        "rms": np.array([
            1.0,
            2.0,
            3.0,
            4.0,
        ]),
        "theta": np.array([
            1.0,
            2.0,
        ]),
    }

    matrix = stack_features(
        feature_dict=feature_dict,
        feature_names=[
            "rms",
            "theta",
        ],
    )

    assert matrix.shape == (2, 2)

    expected = np.array([
        [0.0, 0.0],
        [0.03333333333333333, 0.1],
    ])

    assert matrix == pytest.approx(expected)