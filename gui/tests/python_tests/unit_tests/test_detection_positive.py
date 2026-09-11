"""Positive tests for src.detection."""

import numpy as np
import pytest

import src.detection as detection
from gui.mock_data_positive import (
    create_phase_feature_matrices,
    create_phase_time_indices,
    create_piecewise_feature_matrix,
)
from src.detection import (
    DEFAULT_PARAMS,
    detect_changepoints_pelt,
    detect_onset,
    detect_termination,
    detect_transition,
    run_three_phase_detection,
)


def test_pelt_accepts_one_dimensional_input() -> None:
    signal = np.concatenate([
        np.zeros(40),
        np.ones(40) * 3,
    ])

    changepoints = detect_changepoints_pelt(
        signal,
        penalty=5,
        model="l2",
    )

    assert isinstance(changepoints, list)
    assert len(changepoints) >= 1


def test_pelt_finds_changes_in_piecewise_matrix() -> None:
    matrix = create_piecewise_feature_matrix()

    changepoints = detect_changepoints_pelt(
        matrix,
        penalty=5,
        model="l2",
    )

    assert len(changepoints) >= 2
    assert any(abs(cp - 40) <= 5 for cp in changepoints)
    assert any(abs(cp - 80) <= 5 for cp in changepoints)


def test_onset_selects_first_changepoint(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        detection,
        "detect_changepoints_pelt",
        lambda X, penalty: [10, 25, 40],
    )

    result = detect_onset(
        np.ones((50, 3)),
        {"penalty": 10},
    )

    assert result == 10


def test_transition_selects_point_nearest_midpoint(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        detection,
        "detect_changepoints_pelt",
        lambda X, penalty: [10, 24, 40],
    )

    result = detect_transition(
        np.ones((50, 3)),
        {"penalty": 10},
    )

    assert result == 24


def test_termination_selects_last_changepoint(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        detection,
        "detect_changepoints_pelt",
        lambda X, penalty: [10, 25, 40],
    )

    result = detect_termination(
        np.ones((50, 3)),
        {"penalty": 10},
    )

    assert result == 40


def test_run_three_phase_detection_maps_indices_to_samples(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        detection,
        "detect_onset",
        lambda X, params: 1,
    )

    monkeypatch.setattr(
        detection,
        "detect_transition",
        lambda X, params: 2,
    )

    monkeypatch.setattr(
        detection,
        "detect_termination",
        lambda X, params: 3,
    )

    matrices = create_phase_feature_matrices(
        rows=5,
        cols=2,
    )

    time_indices = create_phase_time_indices()

    result = run_three_phase_detection(
        feature_dicts=matrices,
        params=DEFAULT_PARAMS,
        time_indices=time_indices,
    )

    assert result == {
        "onset": 200,
        "transition": 310,
        "termination": 420,
    }


def test_run_three_phase_detection_returns_feature_indices_without_time_indices(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        detection,
        "detect_onset",
        lambda X, params: 1,
    )

    monkeypatch.setattr(
        detection,
        "detect_transition",
        lambda X, params: 2,
    )

    monkeypatch.setattr(
        detection,
        "detect_termination",
        lambda X, params: 3,
    )

    matrices = create_phase_feature_matrices(
        rows=5,
        cols=2,
    )

    result = run_three_phase_detection(
        feature_dicts=matrices,
        params=DEFAULT_PARAMS,
        time_indices=None,
    )

    assert result == {
        "onset": 1,
        "transition": 2,
        "termination": 3,
    }