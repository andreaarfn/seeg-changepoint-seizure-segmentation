"""Negative tests for gui.api.features_api."""

import numpy as np
import pytest

from gui.api.features_api import (
    extract_features,
    prepare_feature_matrix,
    preprocess_signal,
    validate_signal,
)
from gui.mock_data_negative import (
    create_empty_signal,
    create_short_signal,
    create_signal_with_nan,
    create_two_dimensional_signal,
)


def test_validate_signal_rejects_empty_signal() -> None:
    with pytest.raises(
        ValueError,
        match="cannot be empty",
    ):
        validate_signal(
            create_empty_signal(),
            fs=1000,
        )


def test_validate_signal_rejects_two_dimensional_signal() -> None:
    with pytest.raises(
        ValueError,
        match="one-dimensional",
    ):
        validate_signal(
            create_two_dimensional_signal(),
            fs=1000,
        )


def test_validate_signal_rejects_nan() -> None:
    with pytest.raises(
        ValueError,
        match="NaN or infinite",
    ):
        validate_signal(
            create_signal_with_nan(),
            fs=1000,
        )


@pytest.mark.parametrize(
    "fs",
    [0, -1000, np.nan, np.inf],
)
def test_validate_signal_rejects_invalid_sampling_frequency(
    fs: float,
) -> None:
    with pytest.raises(
        ValueError,
        match="greater than zero",
    ):
        validate_signal(
            np.ones(1000),
            fs=fs,
        )


def test_extract_features_rejects_zero_window_size() -> None:
    with pytest.raises(
        ValueError,
        match="window_size",
    ):
        extract_features(
            signal=np.ones(1000),
            fs=1000,
            window_size=0,
            step=10,
        )


def test_extract_features_rejects_zero_step() -> None:
    with pytest.raises(
        ValueError,
        match="step",
    ):
        extract_features(
            signal=np.ones(1000),
            fs=1000,
            window_size=100,
            step=0,
        )


def test_extract_features_rejects_short_signal() -> None:
    with pytest.raises(
        ValueError,
        match="too short",
    ):
        extract_features(
            signal=create_short_signal(100),
            fs=1000,
            window_size=200,
            step=10,
        )


def test_prepare_feature_matrix_rejects_empty_feature_names() -> None:
    with pytest.raises(
        ValueError,
        match="At least one",
    ):
        prepare_feature_matrix(
            signal=np.ones(1000),
            fs=1000,
            window_size=100,
            step=10,
            feature_names=[],
            apply_highpass=False,
        )


def test_prepare_feature_matrix_rejects_unknown_feature() -> None:
    with pytest.raises(
        ValueError,
        match="Unknown feature",
    ):
        prepare_feature_matrix(
            signal=np.ones(1000),
            fs=1000,
            window_size=100,
            step=10,
            feature_names=[
                "rms",
                "not-a-feature",
            ],
            apply_highpass=False,
        )


def test_prepare_feature_matrix_rejects_invalid_alpha() -> None:
    with pytest.raises(
        ValueError,
        match="between zero and one",
    ):
        prepare_feature_matrix(
            signal=np.ones(1000),
            fs=1000,
            window_size=100,
            step=10,
            alpha=1.5,
            apply_highpass=False,
        )


def test_prepare_feature_matrix_rejects_weight_for_unselected_feature() -> None:
    with pytest.raises(
        ValueError,
        match="not selected",
    ):
        prepare_feature_matrix(
            signal=np.ones(1000),
            fs=1000,
            window_size=100,
            step=10,
            feature_names=["rms"],
            weights={
                "theta": 1.0,
            },
            apply_highpass=False,
        )