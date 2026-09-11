"""Negative and edge-case tests for src.features."""

import numpy as np
import pytest

from gui.mock_data_negative import (
    create_constant_feature,
    create_empty_feature,
    create_feature_dict_missing_theta,
    create_feature_dict_with_empty_theta,
    create_short_signal,
    create_too_short_for_highpass_signal,
)
from src.features import (
    exponential_smooth,
    highpass_filter,
    line_length,
    minmax_normalize,
    relative_bandpower_envelope,
    rms_envelope,
    spectral_entropy,
    stack_features,
)


def test_rms_returns_empty_when_signal_is_shorter_than_window() -> None:
    signal = create_short_signal(
        number_of_samples=100,
    )

    values, time_indices = rms_envelope(
        signal,
        window_size=200,
        step=10,
    )

    assert np.array_equal(
        values,
        np.array([]),
    )

    assert np.array_equal(
        time_indices,
        np.array([]),
    )


def test_line_length_returns_empty_when_signal_is_shorter_than_window() -> None:
    signal = create_short_signal(
        number_of_samples=100,
    )

    values = line_length(
        signal,
        window_size=200,
        step=10,
    )

    assert np.array_equal(
        values,
        np.array([]),
    )


def test_spectral_entropy_returns_empty_when_signal_is_short() -> None:
    signal = create_short_signal(
        number_of_samples=100,
    )

    values = spectral_entropy(
        signal,
        fs=1000,
        window_size=200,
        step=10,
    )

    assert np.array_equal(
        values,
        np.array([]),
    )


def test_bandpower_returns_empty_when_signal_is_short() -> None:
    signal = create_short_signal(
        number_of_samples=100,
    )

    values, time_indices = relative_bandpower_envelope(
        signal=signal,
        fs=1000,
        band=(4, 8),
        total_band=(0.5, 150),
        window_size=200,
        step=10,
    )

    assert np.array_equal(
        values,
        np.array([]),
    )

    assert np.array_equal(
        time_indices,
        np.array([]),
    )


def test_highpass_filter_rejects_signal_that_is_too_short() -> None:
    signal = create_too_short_for_highpass_signal()

    with pytest.raises(ValueError):
        highpass_filter(
            signal,
            fs=1000,
        )


def test_minmax_normalize_handles_constant_feature() -> None:
    feature = create_constant_feature(
        length=10,
        value=7.5,
    )

    normalized = minmax_normalize(feature)

    expected = np.zeros(10)

    assert normalized.shape == feature.shape
    assert np.all(np.isfinite(normalized))
    assert np.array_equal(
        normalized,
        expected,
    )


def test_minmax_normalize_rejects_empty_feature() -> None:
    feature = create_empty_feature()

    with pytest.raises(ValueError):
        minmax_normalize(feature)


def test_exponential_smooth_rejects_empty_feature() -> None:
    feature = create_empty_feature()

    with pytest.raises(IndexError):
        exponential_smooth(feature)


def test_stack_features_rejects_missing_feature_name() -> None:
    feature_dict = create_feature_dict_missing_theta()

    with pytest.raises(KeyError):
        stack_features(
            feature_dict=feature_dict,
            feature_names=[
                "rms",
                "theta",
            ],
        )


def test_stack_features_rejects_empty_feature() -> None:
    feature_dict = create_feature_dict_with_empty_theta()

    with pytest.raises(ValueError):
        stack_features(
            feature_dict=feature_dict,
            feature_names=[
                "rms",
                "theta",
            ],
        )


def test_rms_rejects_zero_step() -> None:
    signal = create_short_signal(
        number_of_samples=1000,
    )

    with pytest.raises(ZeroDivisionError):
        rms_envelope(
            signal,
            window_size=100,
            step=0,
        )


def test_line_length_rejects_zero_step() -> None:
    signal = create_short_signal(
        number_of_samples=1000,
    )

    with pytest.raises(ValueError):
        line_length(
            signal,
            window_size=100,
            step=0,
        )