"""MATLAB-friendly interface to src.features.

The scientific feature calculations remain in src.features. This module
provides validation and higher-level wrappers that are convenient for MATLAB
to call.
"""

from __future__ import annotations

from typing import Any, Mapping, Sequence

import numpy as np

from src.features import (
    BANDS,
    FEATURE_NAMES,
    TOTAL_BAND,
    exponential_smooth,
    extract_all_features,
    extract_selected_features,
    highpass_filter,
    line_length,
    minmax_normalize,
    prepare_feature_matrix as _prepare_feature_matrix,
    relative_bandpower_envelope,
    rms_envelope,
    spectral_entropy,
    stack_features,
)


DEFAULT_FEATURE_NAMES = tuple(FEATURE_NAMES)


def validate_signal(
    signal: Any,
    fs: float,
) -> np.ndarray:
    """Convert and validate one signal for MATLAB-facing workflows."""
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


def preprocess_signal(
    signal: Any,
    fs: float = 1000.0,
    apply_highpass: bool = True,
    cutoff: float = 0.5,
    order: int = 3,
) -> np.ndarray:
    """Validate and optionally high-pass filter one signal."""
    signal_array = validate_signal(
        signal=signal,
        fs=fs,
    )

    if not apply_highpass:
        return signal_array.copy()

    return highpass_filter(
        signal_array,
        fs=float(fs),
        cutoff=float(cutoff),
        order=int(order),
    )


def extract_features(
    signal: Any,
    fs: float,
    window_size: int,
    step: int,
    feature_names: Sequence[str] | None = None,
    apply_highpass: bool = True,
    highpass_cutoff: float = 0.5,
    highpass_order: int = 3,
) -> dict[str, np.ndarray]:
    """Preprocess a signal and extract requested repository features."""
    window_size, step = _validate_window_parameters(
        window_size=window_size,
        step=step,
    )

    names = (
        DEFAULT_FEATURE_NAMES
        if feature_names is None
        else _validate_feature_names(feature_names)
    )

    processed_signal = preprocess_signal(
        signal=signal,
        fs=fs,
        apply_highpass=apply_highpass,
        cutoff=highpass_cutoff,
        order=highpass_order,
    )

    features = extract_selected_features(
        signal=processed_signal,
        fs=float(fs),
        window_size=window_size,
        step=step,
        feature_names=names,
    )

    if features["time_indices"].size == 0:
        raise ValueError(
            "The signal is too short for feature extraction "
            "with the requested window size."
        )

    return features


def prepare_features(
    signal: Any,
    fs: float,
    window_size: int,
    step: int,
    feature_names: Sequence[str] = DEFAULT_FEATURE_NAMES,
    weights: Mapping[str, float] | None = None,
    alpha: float = 0.1,
    apply_highpass: bool = True,
    highpass_cutoff: float = 0.5,
    highpass_order: int = 3,
) -> dict[str, Any]:
    """Create one complete feature-analysis result for MATLAB.

    Returns the processed signal, raw selected features, stacked feature
    matrix, sample indices, and selected feature names.
    """
    window_size, step = _validate_window_parameters(
        window_size=window_size,
        step=step,
    )
    names = _validate_feature_names(feature_names)
    alpha = _validate_alpha(alpha)
    validated_weights = _validate_weights(
        weights=weights,
        feature_names=names,
    )

    processed_signal = preprocess_signal(
        signal=signal,
        fs=fs,
        apply_highpass=apply_highpass,
        cutoff=highpass_cutoff,
        order=highpass_order,
    )

    feature_matrix, time_indices, raw_features = _prepare_feature_matrix(
        signal=processed_signal,
        fs=float(fs),
        window_size=window_size,
        step=step,
        feature_names=names,
        weights=validated_weights,
        smoothing_alpha=alpha,
    )

    if feature_matrix.size == 0:
        raise ValueError(
            "The signal is too short for feature preparation "
            "with the requested window size."
        )

    return {
        "processed_signal": processed_signal,
        "features": raw_features,
        "feature_matrix": feature_matrix,
        "time_indices": time_indices,
        "feature_names": list(names),
        "window_size": int(window_size),
        "step": int(step),
        "alpha": float(alpha),
        "weights": validated_weights,
    }


# Backwards-compatible name used by the current MATLAB bridge.
prepare_feature_matrix = prepare_features


def _validate_window_parameters(
    window_size: int,
    step: int,
) -> tuple[int, int]:
    if isinstance(window_size, bool) or not isinstance(
        window_size,
        (int, np.integer),
    ):
        raise TypeError(
            "window_size must be an integer."
        )

    if isinstance(step, bool) or not isinstance(
        step,
        (int, np.integer),
    ):
        raise TypeError(
            "step must be an integer."
        )

    window_size = int(window_size)
    step = int(step)

    if window_size <= 0:
        raise ValueError(
            "window_size must be greater than zero."
        )

    if step <= 0:
        raise ValueError(
            "step must be greater than zero."
        )

    return window_size, step


def _validate_feature_names(
    feature_names: Sequence[str],
) -> tuple[str, ...]:
    names = tuple(str(name) for name in feature_names)

    if not names:
        raise ValueError(
            "At least one feature name is required."
        )

    if len(set(names)) != len(names):
        raise ValueError(
            "Feature names cannot contain duplicates."
        )

    unknown = set(names) - set(DEFAULT_FEATURE_NAMES)

    if unknown:
        raise ValueError(
            "Unknown feature names: "
            + ", ".join(sorted(unknown))
        )

    return names


def _validate_alpha(alpha: float) -> float:
    alpha = float(alpha)

    if not np.isfinite(alpha) or not 0 < alpha <= 1:
        raise ValueError(
            "alpha must be greater than zero and at most one."
        )

    return alpha


def _validate_weights(
    weights: Mapping[str, float] | None,
    feature_names: Sequence[str],
) -> dict[str, float] | None:
    if weights is None:
        return None

    weights_dict = {
        str(name): float(value)
        for name, value in weights.items()
    }

    unknown = set(weights_dict) - set(feature_names)

    if unknown:
        raise ValueError(
            "Weights were supplied for features that are not selected: "
            + ", ".join(sorted(unknown))
        )

    for feature_name, weight in weights_dict.items():
        if not np.isfinite(weight):
            raise ValueError(
                f"The weight for {feature_name} must be finite."
            )

    return weights_dict


__all__ = [
    "BANDS",
    "TOTAL_BAND",
    "DEFAULT_FEATURE_NAMES",
    "highpass_filter",
    "rms_envelope",
    "line_length",
    "spectral_entropy",
    "relative_bandpower_envelope",
    "extract_all_features",
    "extract_selected_features",
    "minmax_normalize",
    "exponential_smooth",
    "stack_features",
    "validate_signal",
    "preprocess_signal",
    "extract_features",
    "prepare_features",
    "prepare_feature_matrix",
]
