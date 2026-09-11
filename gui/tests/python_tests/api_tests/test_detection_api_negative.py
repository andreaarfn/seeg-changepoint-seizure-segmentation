"""Negative tests for gui.api.detection_api."""

import numpy as np
import pytest

from gui.api.detection_api import (
    detect_all_phases,
    detect_phase,
    samples_to_seconds,
)
from gui.mock_data_negative import (
    create_complete_phase_matrices,
    create_incomplete_phase_matrices,
    create_valid_phase_params,
)


def test_detect_phase_rejects_unknown_phase() -> None:
    with pytest.raises(
        ValueError,
        match="onset, transition, or termination",
    ):
        detect_phase(
            feature_matrix=np.ones((20, 2)),
            phase="middle",
        )


def test_detect_phase_rejects_empty_matrix() -> None:
    with pytest.raises(
        ValueError,
        match="cannot be empty",
    ):
        detect_phase(
            feature_matrix=np.empty((0, 2)),
            phase="onset",
        )


def test_detect_phase_rejects_nan_matrix() -> None:
    matrix = np.ones((20, 2))
    matrix[0, 0] = np.nan

    with pytest.raises(
        ValueError,
        match="NaN or infinite",
    ):
        detect_phase(
            feature_matrix=matrix,
            phase="onset",
        )


def test_detect_phase_requires_penalty() -> None:
    with pytest.raises(
        ValueError,
        match="penalty",
    ):
        detect_phase(
            feature_matrix=np.ones((20, 2)),
            phase="onset",
            params={},
        )


def test_detect_all_phases_requires_every_matrix() -> None:
    with pytest.raises(
        ValueError,
        match="missing",
    ):
        detect_all_phases(
            feature_matrices=create_incomplete_phase_matrices(),
            params=create_valid_phase_params(),
        )


def test_detect_all_phases_requires_every_time_index_array() -> None:
    matrices = create_complete_phase_matrices()

    with pytest.raises(
        ValueError,
        match="time_indices is missing",
    ):
        detect_all_phases(
            feature_matrices=matrices,
            time_indices={
                "onset": np.arange(20),
            },
            params=create_valid_phase_params(),
        )


def test_samples_to_seconds_rejects_zero_sampling_frequency() -> None:
    with pytest.raises(
        ValueError,
        match="greater than zero",
    ):
        samples_to_seconds(
            detected_samples={
                "onset": 100,
            },
            fs=0,
        )


def test_samples_to_seconds_rejects_negative_sample() -> None:
    with pytest.raises(
        ValueError,
        match="cannot be negative",
    ):
        samples_to_seconds(
            detected_samples={
                "onset": -1,
            },
            fs=1000,
        )


def test_samples_to_seconds_rejects_nan_sample() -> None:
    with pytest.raises(
        ValueError,
        match="must be finite",
    ):
        samples_to_seconds(
            detected_samples={
                "onset": np.nan,
            },
            fs=1000,
        )