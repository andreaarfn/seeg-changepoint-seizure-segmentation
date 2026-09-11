"""MATLAB-friendly interface to src.detection.

This module keeps the lower-level detection functions available while adding
MATLAB-facing helpers for:

- phase-specific parameter overrides
- complete three-phase detection from precomputed feature matrices
- complete three-phase detection directly from a raw SEEG signal
- sample-to-second conversion

The scientific detection logic remains in src.detection and src.features.
"""

from __future__ import annotations

from typing import Any, Mapping

import numpy as np

from src.detection import (
    DEFAULT_PARAMS,
    detect_changepoints_pelt,
    detect_onset,
    detect_termination,
    detect_transition,
    get_default_params,
    merge_params,
    run_three_phase_detection,
)
from src.features import prepare_feature_matrix as _prepare_feature_matrix


PHASES = (
    "onset",
    "transition",
    "termination",
)


def get_defaults() -> dict[str, dict[str, Any]]:
    """Return an independent copy of the optimized detector defaults.

    This is useful for populating MATLAB GUI controls without exposing the
    module-level DEFAULT_PARAMS dictionary to accidental modification.
    """
    return get_default_params()


def detect_phase(
    feature_matrix: Any,
    phase: str,
    params: Mapping[str, Any] | None = None,
) -> int | None:
    """Run one selected phase detector on an already prepared feature matrix.

    Parameters
    ----------
    feature_matrix:
        One- or two-dimensional feature data. A one-dimensional input is
        treated as a single feature column.
    phase:
        "onset", "transition", or "termination".
    params:
        Partial settings for the selected phase. Omitted values retain the
        optimized defaults for that phase.
    """
    phase = _validate_phase(phase)
    matrix = _validate_feature_matrix(feature_matrix)

    phase_override = None
    if params is not None:
        phase_override = {phase: dict(params)}

    complete_params = merge_params(phase_override)
    phase_params = complete_params[phase]

    detector = {
        "onset": detect_onset,
        "transition": detect_transition,
        "termination": detect_termination,
    }[phase]

    result = detector(matrix, phase_params)

    return None if result is None else int(result)


def detect_all_phases(
    feature_matrices: Mapping[str, Any],
    time_indices: Mapping[str, Any] | None = None,
    params: Mapping[str, Any] | None = None,
) -> dict[str, int | None]:
    """Run all three detectors on precomputed feature matrices.

    This helper should be used when MATLAB or features_api.py has already
    prepared separate onset, transition, and termination feature matrices.

    `params` may contain only the settings the user changed. Missing phases
    and missing parameter fields retain their optimized defaults.
    """
    _validate_required_phases(
        data=feature_matrices,
        input_name="feature_matrices",
    )

    validated_matrices = {
        phase: _validate_feature_matrix(feature_matrices[phase])
        for phase in PHASES
    }

    validated_time_indices = None

    if time_indices is not None:
        _validate_required_phases(
            data=time_indices,
            input_name="time_indices",
        )

        validated_time_indices = {
            phase: _validate_time_indices(time_indices[phase])
            for phase in PHASES
        }

        for phase in PHASES:
            if len(validated_time_indices[phase]) < len(validated_matrices[phase]):
                raise ValueError(
                    f"time_indices for {phase} contains fewer entries than "
                    "the corresponding feature matrix contains rows."
                )

    complete_params = merge_params(
        dict(params) if params is not None else None
    )

    results = run_three_phase_detection(
        feature_matrices=validated_matrices,
        params=complete_params,
        time_indices=validated_time_indices,
    )

    return {
        phase: (
            None
            if results[phase] is None
            else int(results[phase])
        )
        for phase in PHASES
    }


def detect_from_signal(
    signal: Any,
    fs: float,
    params: Mapping[str, Any] | None = None,
    apply_highpass: bool = True,
    highpass_cutoff: float = 0.5,
    highpass_order: int = 3,
) -> dict[str, Any]:
    """Run the complete three-phase workflow directly from one SEEG signal.

    Each phase uses its own configured window size, step, selected features,
    smoothing alpha, feature weights, and PELT parameters.

    Parameters
    ----------
    signal:
        One-dimensional SEEG signal.
    fs:
        Sampling frequency in Hz.
    params:
        Partial or complete three-phase configuration.
    apply_highpass:
        Whether to apply the Butterworth high-pass filter before feature
        extraction.
    highpass_cutoff:
        High-pass cutoff in Hz.
    highpass_order:
        Butterworth filter order.

    Returns
    -------
    dict
        MATLAB-friendly result containing:
        - detected_samples
        - detected_seconds
        - time_indices for each phase
        - feature_matrices for each phase
        - parameters actually used
    """
    signal_array = _validate_signal(signal, fs)
    complete_params = merge_params(
        dict(params) if params is not None else None
    )

    if apply_highpass:
        from src.features import highpass_filter

        processed_signal = highpass_filter(
            signal_array,
            fs=float(fs),
            cutoff=float(highpass_cutoff),
            order=int(highpass_order),
        )
    else:
        processed_signal = signal_array.copy()

    feature_matrices: dict[str, np.ndarray] = {}
    time_indices: dict[str, np.ndarray] = {}

    for phase in PHASES:
        cfg = complete_params[phase]

        matrix, indices, _ = _prepare_feature_matrix(
            signal=processed_signal,
            fs=float(fs),
            window_size=int(cfg["window_size"]),
            step=int(cfg["step"]),
            feature_names=cfg["features"],
            weights=cfg.get("weights"),
            smoothing_alpha=float(cfg.get("smoothing_alpha", 0.1)),
        )

        if matrix.size == 0:
            raise ValueError(
                f"The signal is too short to prepare features for {phase} "
                f"using window_size={cfg['window_size']}."
            )

        feature_matrices[phase] = matrix
        time_indices[phase] = indices

    detected_samples = run_three_phase_detection(
        feature_matrices=feature_matrices,
        params=complete_params,
        time_indices=time_indices,
    )

    detected_seconds = samples_to_seconds(
        detected_samples=detected_samples,
        fs=float(fs),
    )

    return {
        "detected_samples": detected_samples,
        "detected_seconds": detected_seconds,
        "time_indices": time_indices,
        "feature_matrices": feature_matrices,
        "params": complete_params,
    }


def samples_to_seconds(
    detected_samples: Mapping[str, int | float | None],
    fs: float,
) -> dict[str, float | None]:
    """Convert detected sample positions into seconds."""
    fs = float(fs)

    if not np.isfinite(fs) or fs <= 0:
        raise ValueError(
            "The sampling frequency must be greater than zero."
        )

    results: dict[str, float | None] = {}

    for phase, sample in detected_samples.items():
        if sample is None:
            results[phase] = None
            continue

        sample_value = float(sample)

        if not np.isfinite(sample_value):
            raise ValueError(
                f"The detected sample for {phase} must be finite."
            )

        if sample_value < 0:
            raise ValueError(
                f"The detected sample for {phase} cannot be negative."
            )

        results[phase] = sample_value / fs

    return results


def _validate_phase(phase: str) -> str:
    phase = str(phase).lower().strip()

    if phase not in PHASES:
        raise ValueError(
            "phase must be onset, transition, or termination."
        )

    return phase


def _validate_signal(
    signal: Any,
    fs: float,
) -> np.ndarray:
    signal_array = np.asarray(
        signal,
        dtype=float,
    ).squeeze()

    if signal_array.ndim != 1:
        raise ValueError(
            "The signal must be one-dimensional."
        )

    if signal_array.size == 0:
        raise ValueError(
            "The signal cannot be empty."
        )

    if not np.all(np.isfinite(signal_array)):
        raise ValueError(
            "The signal contains NaN or infinite values."
        )

    fs_value = float(fs)

    if not np.isfinite(fs_value) or fs_value <= 0:
        raise ValueError(
            "The sampling frequency must be greater than zero."
        )

    return signal_array


def _validate_feature_matrix(
    feature_matrix: Any,
) -> np.ndarray:
    matrix = np.asarray(
        feature_matrix,
        dtype=float,
    )

    if matrix.ndim == 1:
        matrix = matrix.reshape(-1, 1)

    if matrix.ndim != 2:
        raise ValueError(
            "The feature matrix must be one- or two-dimensional."
        )

    if matrix.shape[0] == 0 or matrix.shape[1] == 0:
        raise ValueError(
            "The feature matrix cannot be empty."
        )

    if not np.all(np.isfinite(matrix)):
        raise ValueError(
            "The feature matrix contains NaN or infinite values."
        )

    return matrix


def _validate_time_indices(
    time_indices: Any,
) -> np.ndarray:
    raw_indices = np.asarray(
        time_indices,
        dtype=float,
    ).squeeze()

    if raw_indices.ndim != 1:
        raise ValueError(
            "Time indices must be one-dimensional."
        )

    if raw_indices.size == 0:
        raise ValueError(
            "Time indices cannot be empty."
        )

    if not np.all(np.isfinite(raw_indices)):
        raise ValueError(
            "Time indices cannot contain NaN or infinite values."
        )

    if np.any(raw_indices < 0):
        raise ValueError(
            "Time indices cannot contain negative values."
        )

    if not np.allclose(raw_indices, np.round(raw_indices)):
        raise ValueError(
            "Time indices must contain integer sample positions."
        )

    return np.round(raw_indices).astype(int)


def _validate_required_phases(
    data: Mapping[str, Any],
    input_name: str,
) -> None:
    if not isinstance(data, Mapping):
        raise TypeError(
            f"{input_name} must be a mapping."
        )

    missing = set(PHASES) - set(data)

    if missing:
        raise ValueError(
            f"{input_name} is missing: "
            + ", ".join(sorted(missing))
        )


__all__ = [
    "DEFAULT_PARAMS",
    "PHASES",
    "detect_changepoints_pelt",
    "detect_onset",
    "detect_transition",
    "detect_termination",
    "run_three_phase_detection",
    "get_defaults",
    "detect_phase",
    "detect_all_phases",
    "detect_from_signal",
    "samples_to_seconds",
]
