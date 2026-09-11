"""Negative and edge-case tests for src.detection."""

import numpy as np
import pytest

import src.detection as detection
from gui.mock_data_negative import (
    create_complete_phase_matrices,
    create_incomplete_phase_matrices,
    create_phase_params_missing_penalty,
    create_short_time_indices,
    create_valid_phase_params,
    expected_no_changepoint_result,
)
from src.detection import (
    detect_changepoints_pelt,
    detect_onset,
    detect_termination,
    detect_transition,
    run_three_phase_detection,
)


def test_pelt_raises_clear_error_when_ruptures_is_unavailable(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        detection,
        "_RUPTURES_AVAILABLE",
        False,
    )

    signal = np.ones((20, 2))

    with pytest.raises(
        ImportError,
        match="Install ruptures",
    ):
        detect_changepoints_pelt(
            signal,
            penalty=10,
        )


def test_detect_onset_returns_none_when_no_changepoints(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        detection,
        "detect_changepoints_pelt",
        lambda X, penalty: [],
    )

    result = detect_onset(
        np.ones((20, 2)),
        {"penalty": 10},
    )

    assert result is None


def test_detect_termination_returns_none_when_no_changepoints(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        detection,
        "detect_changepoints_pelt",
        lambda X, penalty: [],
    )

    result = detect_termination(
        np.ones((20, 2)),
        {"penalty": 10},
    )

    assert result is None


def test_detect_transition_returns_none_when_no_changepoints(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        detection,
        "detect_changepoints_pelt",
        lambda X, penalty: [],
    )

    result = detect_transition(
        np.ones((20, 2)),
        {"penalty": 10},
    )

    assert result is None


def test_detect_onset_requires_penalty_parameter() -> None:
    signal = np.ones((20, 2))
    params = create_phase_params_missing_penalty()

    with pytest.raises(KeyError):
        detect_onset(
            signal,
            params,
        )


def test_detect_termination_requires_penalty_parameter() -> None:
    signal = np.ones((20, 2))
    params = create_phase_params_missing_penalty()

    with pytest.raises(KeyError):
        detect_termination(
            signal,
            params,
        )


def test_detect_transition_requires_penalty_parameter() -> None:
    signal = np.ones((20, 2))
    params = create_phase_params_missing_penalty()

    with pytest.raises(KeyError):
        detect_transition(
            signal,
            params,
        )


def test_run_three_phase_detection_returns_none_when_no_points(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        detection,
        "detect_changepoints_pelt",
        lambda X, penalty: [],
    )

    feature_matrices = create_complete_phase_matrices(
        number_of_windows=20,
        number_of_features=2,
    )

    params = create_valid_phase_params()

    result = run_three_phase_detection(
        feature_dicts=feature_matrices,
        params=params,
    )

    assert result == expected_no_changepoint_result()


def test_run_three_phase_detection_handles_short_time_index_array(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        detection,
        "detect_onset",
        lambda X, params: 8,
    )

    monkeypatch.setattr(
        detection,
        "detect_transition",
        lambda X, params: 8,
    )

    monkeypatch.setattr(
        detection,
        "detect_termination",
        lambda X, params: 8,
    )

    feature_matrices = create_complete_phase_matrices(
        number_of_windows=20,
        number_of_features=2,
    )

    time_indices = create_short_time_indices()
    params = create_valid_phase_params()

    result = run_three_phase_detection(
        feature_dicts=feature_matrices,
        params=params,
        time_indices=time_indices,
    )

    assert result == expected_no_changepoint_result()


def test_run_three_phase_detection_requires_all_phase_inputs() -> None:
    feature_matrices = create_incomplete_phase_matrices()
    params = create_valid_phase_params()

    with pytest.raises(KeyError):
        run_three_phase_detection(
            feature_dicts=feature_matrices,
            params=params,
        )


def test_pelt_rejects_invalid_model_name() -> None:
    signal = np.ones((20, 2))

    with pytest.raises(Exception):
        detect_changepoints_pelt(
            signal,
            penalty=10,
            model="not-a-real-model",
        )