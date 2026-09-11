"""Positive tests for gui.api.metrics_api."""

import numpy as np
import pytest

from gui.api.metrics_api import (
    absolute_error,
    calculate_phase_errors,
    evaluate_detections,
    summarize_errors,
)


def test_original_absolute_error_remains_available() -> None:
    result = absolute_error(
        predicted=12.5,
        ground_truth=10.0,
    )

    assert result == pytest.approx(2.5)


def test_calculate_phase_errors_returns_exact_values() -> None:
    result = calculate_phase_errors(
        detected_seconds={
            "onset": 8.0,
            "transition": 17.0,
            "termination": 25.0,
        },
        ground_truth_seconds={
            "onset": 10.0,
            "transition": 15.0,
            "termination": 24.0,
        },
    )

    assert result == {
        "onset": 2.0,
        "transition": 2.0,
        "termination": 1.0,
    }


def test_summarize_errors_returns_exact_summary() -> None:
    result = summarize_errors(
        errors=[
            1.0,
            2.0,
            3.0,
        ],
        tolerance=2.0,
    )

    assert result["n"] == 3
    assert result["mae"] == pytest.approx(2.0)
    assert result["rmse"] == pytest.approx(
        np.sqrt(14 / 3)
    )
    assert result["median"] == pytest.approx(2.0)
    assert result["iqr"] == pytest.approx(1.0)
    assert result["acc_2s"] == pytest.approx(
        (2 / 3) * 100
    )


def test_evaluate_detections_returns_errors_and_summary() -> None:
    result = evaluate_detections(
        detected_seconds={
            "onset": 8.0,
            "transition": 17.0,
            "termination": 25.0,
        },
        ground_truth_seconds={
            "onset": 10.0,
            "transition": 15.0,
            "termination": 24.0,
        },
        tolerance=2.0,
    )

    assert set(result) == {
        "errors",
        "summary",
    }

    assert result["errors"] == {
        "onset": 2.0,
        "transition": 2.0,
        "termination": 1.0,
    }

    assert result["summary"]["n"] == 3
    assert result["summary"]["acc_2s"] == 100.0