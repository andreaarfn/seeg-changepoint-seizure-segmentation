"""MATLAB-friendly interface to src.metrics."""

from __future__ import annotations

from typing import Any, Mapping, Sequence

import numpy as np

from src.metrics import (
    DEFAULT_TOLERANCE_SECONDS,
    absolute_error,
    accuracy_within_tolerance,
    mae,
    phase_errors,
    rmse,
    summarise,
)


PHASES = (
    "onset",
    "transition",
    "termination",
)


def calculate_phase_errors(
    detected_seconds: Mapping[str, float | None],
    ground_truth_seconds: Mapping[str, float | None],
) -> dict[str, float]:
    """Calculate one absolute error for each seizure phase."""
    _validate_phase_mapping(
        detected_seconds,
        "detected_seconds",
    )
    _validate_phase_mapping(
        ground_truth_seconds,
        "ground_truth_seconds",
    )

    normalized_detected = {
        phase: _optional_finite_float(
            detected_seconds.get(phase),
            f"detected_seconds[{phase}]",
        )
        for phase in PHASES
    }

    normalized_ground_truth = {
        phase: _optional_finite_float(
            ground_truth_seconds.get(phase),
            f"ground_truth_seconds[{phase}]",
        )
        for phase in PHASES
    }

    return phase_errors(
        predicted=normalized_detected,
        ground_truth=normalized_ground_truth,
    )


def summarize_errors(
    errors: Sequence[float],
    tolerance: float = DEFAULT_TOLERANCE_SECONDS,
    label: str = "",
    print_summary: bool = False,
) -> dict[str, Any]:
    """Validate and summarize a collection of absolute errors."""
    tolerance = _validate_tolerance(tolerance)

    error_array = np.asarray(
        errors,
        dtype=float,
    ).reshape(-1)

    if np.any(np.isinf(error_array)):
        raise ValueError(
            "errors cannot contain positive or negative infinity."
        )

    return summarise(
        errors=error_array,
        tolerance=tolerance,
        label=str(label),
        print_summary=bool(print_summary),
    )


def evaluate_detections(
    detected_seconds: Mapping[str, float | None],
    ground_truth_seconds: Mapping[str, float | None],
    tolerance: float = DEFAULT_TOLERANCE_SECONDS,
    label: str = "",
    print_summary: bool = False,
) -> dict[str, Any]:
    """Compare three detected phase times with ground truth."""
    errors = calculate_phase_errors(
        detected_seconds=detected_seconds,
        ground_truth_seconds=ground_truth_seconds,
    )

    summary = summarize_errors(
        errors=list(errors.values()),
        tolerance=tolerance,
        label=label,
        print_summary=print_summary,
    )

    return {
        "errors": errors,
        "summary": summary,
    }


def _validate_phase_mapping(
    values: Mapping[str, Any],
    input_name: str,
) -> None:
    if not isinstance(values, Mapping):
        raise TypeError(
            f"{input_name} must be a mapping."
        )


def _optional_finite_float(
    value: float | None,
    input_name: str,
) -> float | None:
    if value is None:
        return None

    number = float(value)

    if np.isnan(number):
        return None

    if not np.isfinite(number):
        raise ValueError(
            f"{input_name} must be finite or missing."
        )

    return number


def _validate_tolerance(
    tolerance: float,
) -> float:
    tolerance = float(tolerance)

    if not np.isfinite(tolerance) or tolerance < 0:
        raise ValueError(
            "tolerance must be zero or greater."
        )

    return tolerance


__all__ = [
    "PHASES",
    "DEFAULT_TOLERANCE_SECONDS",
    "absolute_error",
    "accuracy_within_tolerance",
    "mae",
    "rmse",
    "summarise",
    "phase_errors",
    "calculate_phase_errors",
    "summarize_errors",
    "evaluate_detections",
]
