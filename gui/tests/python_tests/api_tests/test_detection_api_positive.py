"""Positive tests for gui.api.detection_api."""

import numpy as np
import pytest

import gui.api.detection_api as detection_api
from gui.api.detection_api import (
    detect_all_phases,
    detect_phase,
    samples_to_seconds,
)
from gui.mock_data_positive import (
    create_phase_feature_matrices,
    create_phase_time_indices,
)


def test_detect_phase_calls_onset_detector(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        detection_api,
        "detect_onset",
        lambda matrix, params: 4,
    )

    result = detect_phase(
        feature_matrix=np.ones((20, 2)),
        phase="onset",
        params={
            "penalty": 10,
        },
    )

    assert result == 4


def test_detect_phase_calls_transition_detector(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        detection_api,
        "detect_transition",
        lambda matrix, params: 9,
    )

    result = detect_phase(
        feature_matrix=np.ones((20, 2)),
        phase="transition",
        params={
            "penalty": 7,
        },
    )

    assert result == 9


def test_detect_phase_calls_termination_detector(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        detection_api,
        "detect_termination",
        lambda matrix, params: 15,
    )

    result = detect_phase(
        feature_matrix=np.ones((20, 2)),
        phase="termination",
        params={
            "penalty": 10,
        },
    )

    assert result == 15


def test_detect_all_phases_returns_mapped_samples(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    expected = {
        "onset": 200,
        "transition": 310,
        "termination": 420,
    }

    monkeypatch.setattr(
        detection_api,
        "run_three_phase_detection",
        lambda feature_dicts, params, time_indices: expected,
    )

    result = detect_all_phases(
        feature_matrices=create_phase_feature_matrices(),
        time_indices=create_phase_time_indices(),
    )

    assert result == expected


def test_samples_to_seconds_returns_exact_values() -> None:
    result = samples_to_seconds(
        detected_samples={
            "onset": 8750,
            "transition": 16730,
            "termination": 25300,
        },
        fs=1000,
    )

    assert result == {
        "onset": 8.75,
        "transition": 16.73,
        "termination": 25.3,
    }


def test_samples_to_seconds_preserves_none() -> None:
    result = samples_to_seconds(
        detected_samples={
            "onset": 1000,
            "transition": None,
            "termination": 3000,
        },
        fs=1000,
    )

    assert result == {
        "onset": 1.0,
        "transition": None,
        "termination": 3.0,
    }