"""Negative and edge-case tests for src.metrics."""

import numpy as np
import pytest

from src.metrics import (
    absolute_error,
    accuracy_within_tolerance,
    mae,
    rmse,
    summarise,
)


def test_absolute_error_returns_nan_when_prediction_is_none() -> None:
    result = absolute_error(
        predicted=None,
        ground_truth=10.0,
    )

    assert np.isnan(result)


def test_absolute_error_returns_nan_when_prediction_is_nan() -> None:
    result = absolute_error(
        predicted=np.nan,
        ground_truth=10.0,
    )

    assert np.isnan(result)


def test_absolute_error_returns_nan_when_ground_truth_is_nan() -> None:
    result = absolute_error(
        predicted=10.0,
        ground_truth=np.nan,
    )

    assert np.isnan(result)


def test_absolute_error_rejects_none_ground_truth() -> None:
    # The current implementation only checks whether predicted is None.
    # Calling np.isnan(None) for ground_truth raises TypeError.
    with pytest.raises(TypeError):
        absolute_error(
            predicted=10.0,
            ground_truth=None,
        )


def test_absolute_error_rejects_non_numeric_prediction() -> None:
    with pytest.raises(TypeError):
        absolute_error(
            predicted="ten",
            ground_truth=10.0,
        )


def test_accuracy_returns_nan_for_empty_input() -> None:
    result = accuracy_within_tolerance(
        [],
        tolerance=5.0,
    )

    assert np.isnan(result)


def test_accuracy_returns_nan_when_all_values_are_nan() -> None:
    errors = np.array([
        np.nan,
        np.nan,
    ])

    result = accuracy_within_tolerance(
        errors,
        tolerance=5.0,
    )

    assert np.isnan(result)


def test_accuracy_rejects_non_numeric_values() -> None:
    errors = [
        1.0,
        "invalid",
        3.0,
    ]

    with pytest.raises(ValueError):
        accuracy_within_tolerance(
            errors,
            tolerance=5.0,
        )


def test_accuracy_with_negative_tolerance_returns_zero_for_nonnegative_errors(
) -> None:
    errors = np.array([
        0.0,
        1.0,
        2.0,
    ])

    result = accuracy_within_tolerance(
        errors,
        tolerance=-1.0,
    )

    # The current implementation does not reject a negative tolerance.
    # No nonnegative error can be less than or equal to -1.
    assert result == pytest.approx(0.0)


def test_mae_returns_nan_for_empty_input() -> None:
    result = mae([])

    assert np.isnan(result)


def test_mae_returns_nan_when_all_values_are_nan() -> None:
    errors = np.array([
        np.nan,
        np.nan,
    ])

    result = mae(errors)

    assert np.isnan(result)


def test_mae_rejects_non_numeric_values() -> None:
    errors = [
        1.0,
        "invalid",
        3.0,
    ]

    with pytest.raises(ValueError):
        mae(errors)


def test_rmse_returns_nan_for_empty_input() -> None:
    result = rmse([])

    assert np.isnan(result)


def test_rmse_returns_nan_when_all_values_are_nan() -> None:
    errors = np.array([
        np.nan,
        np.nan,
    ])

    result = rmse(errors)

    assert np.isnan(result)


def test_rmse_rejects_non_numeric_values() -> None:
    errors = [
        1.0,
        "invalid",
        3.0,
    ]

    with pytest.raises(ValueError):
        rmse(errors)


def test_summarise_handles_empty_input() -> None:
    result = summarise(
        [],
        tolerance=5.0,
        label="",
    )

    assert result["label"] == ""
    assert result["n"] == 0
    assert np.isnan(result["mae"])
    assert np.isnan(result["rmse"])
    assert np.isnan(result["median"])
    assert np.isnan(result["iqr"])
    assert np.isnan(result["acc_5s"])


def test_summarise_handles_all_nan_input() -> None:
    errors = np.array([
        np.nan,
        np.nan,
    ])

    result = summarise(
        errors,
        tolerance=5.0,
        label="",
    )

    assert result["n"] == 0
    assert np.isnan(result["mae"])
    assert np.isnan(result["rmse"])
    assert np.isnan(result["median"])
    assert np.isnan(result["iqr"])
    assert np.isnan(result["acc_5s"])


def test_summarise_rejects_non_numeric_values() -> None:
    errors = [
        1.0,
        "invalid",
        3.0,
    ]

    with pytest.raises(ValueError):
        summarise(
            errors,
            tolerance=5.0,
            label="",
        )


def test_summarise_prints_nan_values_when_label_is_present(
    capsys: pytest.CaptureFixture[str],
) -> None:
    summarise(
        [],
        tolerance=5.0,
        label="Empty",
    )

    captured = capsys.readouterr()

    assert captured.out == (
        "Empty  |  MAE=nans  "
        "RMSE=nans  "
        "Acc(±5s)=nan%  "
        "N=0\n"
    )