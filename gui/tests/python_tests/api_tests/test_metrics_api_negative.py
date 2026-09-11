"""Negative and edge-case tests for gui.api.metrics_api."""

import numpy as np
import pytest

from gui.api.metrics_api import (
    calculate_phase_errors,
    evaluate_detections,
    summarize_errors,
)


def test_calculate_phase_errors_handles_missing_detection() -> None:
    result = calculate_phase_errors(
        detected_seconds={
            "onset": 8.0,
            "transition": None,
            "termination": 25.0,
        },
        ground_truth_seconds={
            "onset": 10.0,
            "transition": 15.0,
            "termination": 24.0,
        },
    )

    assert result["onset"] == 2.0
    assert np.isnan(result["transition"])
    assert result["termination"] == 1.0


def test_calculate_phase_errors_handles_missing_ground_truth() -> None:
    result = calculate_phase_errors(
        detected_seconds={
            "onset": 8.0,
            "transition": 17.0,
            "termination": 25.0,
        },
        ground_truth_seconds={
            "onset": 10.0,
            "transition": None,
            "termination": 24.0,
        },
    )

    assert np.isnan(
        result["transition"]
    )


def test_summarize_errors_rejects_negative_tolerance() -> None:
    with pytest.raises(
        ValueError,
        match="zero or greater",
    ):
        summarize_errors(
            errors=[
                1.0,
                2.0,
            ],
            tolerance=-1.0,
        )


def test_summarize_errors_handles_empty_errors() -> None:
    result = summarize_errors(
        errors=[],
        tolerance=5.0,
    )

    assert result["n"] == 0
    assert np.isnan(result["mae"])
    assert np.isnan(result["rmse"])
    assert np.isnan(result["median"])
    assert np.isnan(result["iqr"])
    assert np.isnan(result["acc_5s"])


def test_evaluate_detections_handles_all_missing_values() -> None:
    result = evaluate_detections(
        detected_seconds={},
        ground_truth_seconds={},
        tolerance=5.0,
    )

    assert all(
        np.isnan(error)
        for error in result["errors"].values()
    )

    assert result["summary"]["n"] == 0