"""Positive tests for src.metrics."""

import numpy as np
import pytest

from src.metrics import (
    absolute_error,
    accuracy_within_tolerance,
    mae,
    rmse,
    summarise,
)


def test_absolute_error_returns_exact_difference() -> None:
    result = absolute_error(
        predicted=12.5,
        ground_truth=10.0,
    )

    assert result == pytest.approx(2.5)


def test_absolute_error_is_positive_when_prediction_is_earlier() -> None:
    result = absolute_error(
        predicted=7.0,
        ground_truth=10.0,
    )

    assert result == pytest.approx(3.0)


def test_absolute_error_returns_zero_for_exact_match() -> None:
    result = absolute_error(
        predicted=10.0,
        ground_truth=10.0,
    )

    assert result == pytest.approx(0.0)


def test_accuracy_within_tolerance_returns_exact_percentage() -> None:
    errors = np.array([
        1.0,
        4.0,
        6.0,
        8.0,
    ])

    result = accuracy_within_tolerance(
        errors,
        tolerance=5.0,
    )

    # Two of four errors are less than or equal to 5 seconds.
    assert result == pytest.approx(50.0)


def test_accuracy_includes_values_equal_to_tolerance() -> None:
    errors = np.array([
        5.0,
        5.0,
        6.0,
        7.0,
    ])

    result = accuracy_within_tolerance(
        errors,
        tolerance=5.0,
    )

    # The two errors equal to 5 seconds count as correct.
    assert result == pytest.approx(50.0)


def test_accuracy_ignores_nan_values() -> None:
    errors = np.array([
        1.0,
        4.0,
        6.0,
        np.nan,
    ])

    result = accuracy_within_tolerance(
        errors,
        tolerance=5.0,
    )

    # Two of the three valid errors are within tolerance.
    expected = (2 / 3) * 100.0

    assert result == pytest.approx(expected)


def test_mae_returns_exact_mean_absolute_error() -> None:
    errors = np.array([
        1.0,
        2.0,
        3.0,
        4.0,
        5.0,
    ])

    result = mae(errors)

    assert result == pytest.approx(3.0)


def test_mae_ignores_nan_values() -> None:
    errors = np.array([
        1.0,
        np.nan,
        3.0,
    ])

    result = mae(errors)

    assert result == pytest.approx(2.0)


def test_rmse_returns_exact_root_mean_squared_error() -> None:
    errors = np.array([
        1.0,
        2.0,
        3.0,
        4.0,
        5.0,
    ])

    result = rmse(errors)

    expected = np.sqrt(
        (1.0**2 + 2.0**2 + 3.0**2 + 4.0**2 + 5.0**2)
        / 5
    )

    assert result == pytest.approx(expected)
    assert result == pytest.approx(3.3166247903554)


def test_rmse_ignores_nan_values() -> None:
    errors = np.array([
        3.0,
        4.0,
        np.nan,
    ])

    result = rmse(errors)

    # sqrt((3² + 4²) / 2) = sqrt(12.5)
    assert result == pytest.approx(np.sqrt(12.5))


def test_summarise_returns_exact_summary_values() -> None:
    errors = np.array([
        1.0,
        2.0,
        3.0,
        4.0,
        5.0,
    ])

    result = summarise(
        errors,
        tolerance=5.0,
        label="",
    )

    assert result["label"] == ""
    assert result["n"] == 5
    assert result["mae"] == pytest.approx(3.0)
    assert result["rmse"] == pytest.approx(3.3166247903554)
    assert result["median"] == pytest.approx(3.0)
    assert result["iqr"] == pytest.approx(2.0)
    assert result["acc_5s"] == pytest.approx(100.0)


def test_summarise_ignores_nan_values() -> None:
    errors = np.array([
        1.0,
        2.0,
        np.nan,
        4.0,
        5.0,
    ])

    result = summarise(
        errors,
        tolerance=3.0,
        label="test",
    )

    valid_errors = np.array([
        1.0,
        2.0,
        4.0,
        5.0,
    ])

    assert result["label"] == "test"
    assert result["n"] == 4
    assert result["mae"] == pytest.approx(
        np.mean(valid_errors)
    )
    assert result["rmse"] == pytest.approx(
        np.sqrt(np.mean(valid_errors**2))
    )
    assert result["median"] == pytest.approx(3.0)
    assert result["iqr"] == pytest.approx(2.5)

    # Two of four valid errors are within 3 seconds.
    assert result["acc_3s"] == pytest.approx(50.0)


def test_summarise_prints_expected_message_when_label_is_present(
    capsys: pytest.CaptureFixture[str],
) -> None:
    errors = np.array([
        1.0,
        2.0,
        3.0,
    ])

    result = summarise(
        errors,
        tolerance=5.0,
        label="Onset",
    )

    captured = capsys.readouterr()

    assert result["label"] == "Onset"

    assert captured.out == (
        "Onset  |  MAE=2.00s  "
        "RMSE=2.16s  "
        "Acc(±5s)=100.0%  "
        "N=3\n"
    )


def test_summarise_does_not_print_without_label(
    capsys: pytest.CaptureFixture[str],
) -> None:
    summarise(
        [1.0, 2.0, 3.0],
        tolerance=5.0,
        label="",
    )

    captured = capsys.readouterr()

    assert captured.out == ""