"""
Evaluation metrics for three-phase seizure segmentation.

Reference:
    Kumar et al., "Three-Phase Seizure Segmentation in Stereotactic EEG
    Using Envelope-Based Multivariate Changepoint Analysis", Ann. Biomed. Eng.
"""

import numpy as np


DEFAULT_TOLERANCE_SECONDS = 5.0


def _is_missing(value):
    """Return True for None or NaN-like scalar values."""
    if value is None:
        return True

    try:
        return bool(np.isnan(value))
    except (TypeError, ValueError):
        return False


def absolute_error(predicted, ground_truth):
    """Absolute error between predicted and ground-truth times in seconds."""
    if _is_missing(predicted) or _is_missing(ground_truth):
        return np.nan

    return abs(float(predicted) - float(ground_truth))


def accuracy_within_tolerance(
    errors,
    tolerance=DEFAULT_TOLERANCE_SECONDS,
):
    """Percentage of valid errors that fall within a tolerance in seconds."""
    tolerance = float(tolerance)

    if tolerance < 0:
        raise ValueError("tolerance must be >= 0")

    errors = np.asarray(errors, dtype=float)
    valid = errors[~np.isnan(errors)]

    if len(valid) == 0:
        return np.nan

    return float(np.mean(valid <= tolerance) * 100.0)


def mae(errors):
    """Mean absolute error, ignoring NaNs."""
    errors = np.asarray(errors, dtype=float)
    valid = errors[~np.isnan(errors)]

    return float(np.mean(valid)) if len(valid) > 0 else np.nan


def rmse(errors):
    """Root-mean-squared error, ignoring NaNs."""
    errors = np.asarray(errors, dtype=float)
    valid = errors[~np.isnan(errors)]

    return float(np.sqrt(np.mean(valid ** 2))) if len(valid) > 0 else np.nan


def summarise(
    errors,
    tolerance=DEFAULT_TOLERANCE_SECONDS,
    label="",
    print_summary=True,
):
    """Return summary statistics for a collection of absolute errors."""
    tolerance = float(tolerance)

    if tolerance < 0:
        raise ValueError("tolerance must be >= 0")

    errors = np.asarray(errors, dtype=float)
    valid = errors[~np.isnan(errors)]

    tolerance_key = f"acc_{tolerance:g}s"

    summary = {
        "label": str(label),
        "n": int(len(valid)),
        "mae": mae(errors),
        "rmse": rmse(errors),
        "median": (
            float(np.median(valid))
            if len(valid) > 0
            else np.nan
        ),
        "iqr": (
            float(np.percentile(valid, 75) - np.percentile(valid, 25))
            if len(valid) > 0
            else np.nan
        ),
        tolerance_key: accuracy_within_tolerance(errors, tolerance),
        "tolerance_seconds": tolerance,
    }

    if label and print_summary:
        print(
            f"{label}  |  "
            f"MAE={summary['mae']:.2f}s  "
            f"RMSE={summary['rmse']:.2f}s  "
            f"Acc(±{tolerance:g}s)="
            f"{summary[tolerance_key]:.1f}%  "
            f"N={summary['n']}"
        )

    return summary


def phase_errors(predicted, ground_truth):
    """Calculate onset, transition, and termination absolute errors.

    Parameters
    ----------
    predicted : dict
        Detection results with phase values in seconds.
    ground_truth : dict
        Ground-truth values with phase values in seconds.

    Returns
    -------
    dict
        Absolute error for each phase.
    """
    phases = ("onset", "transition", "termination")

    return {
        phase: absolute_error(
            predicted.get(phase),
            ground_truth.get(phase),
        )
        for phase in phases
    }
