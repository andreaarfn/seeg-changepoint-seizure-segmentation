"""Positive tests for gui.api.features_api."""

import numpy as np
import pytest

from gui.api.features_api import (
    DEFAULT_FEATURE_NAMES,
    extract_features,
    prepare_feature_matrix,
    preprocess_signal,
    rms_envelope,
    validate_signal,
)
from gui.mock_data_positive import (
    create_handcrafted_feature_inputs,
    create_single_frequency_signal,
)


FS = 1000
WINDOW_SIZE = 1000
STEP = 150


def test_original_rms_function_remains_available() -> None:
    inputs = create_handcrafted_feature_inputs()

    values, time_indices = rms_envelope(
        inputs["rms_signal"],
        window_size=2,
        step=1,
    )

    assert values == pytest.approx([
        3.5355339059327378,
    ])

    assert np.array_equal(
        time_indices,
        np.array([1]),
    )


def test_validate_signal_converts_list_to_numpy_array() -> None:
    result = validate_signal(
        signal=[0.0, 1.0, 2.0],
        fs=FS,
    )

    assert isinstance(result, np.ndarray)
    assert result.dtype == float
    assert np.array_equal(
        result,
        np.array([0.0, 1.0, 2.0]),
    )


def test_preprocess_signal_can_skip_highpass_filter() -> None:
    signal = np.array([
        1.0,
        2.0,
        3.0,
    ])

    result = preprocess_signal(
        signal=signal,
        fs=FS,
        apply_highpass=False,
    )

    assert np.array_equal(
        result,
        signal,
    )

    assert result is not signal


def test_extract_features_returns_all_expected_features() -> None:
    _, signal = create_single_frequency_signal(
        fs=FS,
        duration_seconds=5.0,
        frequency_hz=10.0,
    )

    result = extract_features(
        signal=signal,
        fs=FS,
        window_size=WINDOW_SIZE,
        step=STEP,
        apply_highpass=False,
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

    assert set(result) == expected_keys
    assert result["time_indices"].shape == (27,)


def test_prepare_feature_matrix_returns_complete_result() -> None:
    _, signal = create_single_frequency_signal(
        fs=FS,
        duration_seconds=5.0,
        frequency_hz=10.0,
    )

    result = prepare_feature_matrix(
        signal=signal,
        fs=FS,
        window_size=WINDOW_SIZE,
        step=STEP,
        apply_highpass=False,
    )

    assert set(result) == {
        "processed_signal",
        "features",
        "feature_matrix",
        "time_indices",
        "feature_names",
    }

    assert result["processed_signal"].shape == signal.shape
    assert result["feature_matrix"].shape == (27, 7)
    assert result["time_indices"].shape == (27,)

    assert result["feature_names"] == list(
        DEFAULT_FEATURE_NAMES
    )


def test_prepare_feature_matrix_applies_selected_weights() -> None:
    _, signal = create_single_frequency_signal(
        fs=FS,
        duration_seconds=5.0,
        frequency_hz=10.0,
    )

    result = prepare_feature_matrix(
        signal=signal,
        fs=FS,
        window_size=WINDOW_SIZE,
        step=STEP,
        feature_names=[
            "rms",
            "theta",
        ],
        weights={
            "rms": 2.0,
            "theta": 0.5,
        },
        apply_highpass=False,
    )

    matrix = result["feature_matrix"]

    assert matrix.shape == (27, 2)
    assert np.all(np.isfinite(matrix))