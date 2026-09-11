"""
PELT-based changepoint detection for three-phase seizure segmentation.

Wraps the `ruptures` library's PELT algorithm and applies phase-specific
strategies for onset, intra-ictal transition, and termination detection.

Reference:
    Kumar et al., "Three-Phase Seizure Segmentation in Stereotactic EEG
    Using Envelope-Based Multivariate Changepoint Analysis", Ann. Biomed. Eng.
"""

from copy import deepcopy
import numpy as np

try:
    import ruptures as rpt
    _RUPTURES_AVAILABLE = True
except ImportError:
    _RUPTURES_AVAILABLE = False
    print(
        "Warning: `ruptures` not installed. PELT detection unavailable. "
        "Install with: pip install ruptures"
    )


# ---------------------------------------------------------------------------
# Default (optimised) phase parameters
# ---------------------------------------------------------------------------

DEFAULT_FEATURES = ["rms", "theta", "alpha", "beta", "gamma", "ll", "se"]

DEFAULT_PARAMS = {
    "onset": {
        "window_size": 1000,
        "step": 150,
        "penalty": 11,
        "features": DEFAULT_FEATURES.copy(),
        "model": "rbf",
        "min_size": 2,
        "jump": 1,
        "smoothing_alpha": 0.1,
        "weights": None,
    },
    "transition": {
        "window_size": 700,
        "step": 130,
        "penalty": 7,
        "features": DEFAULT_FEATURES.copy(),
        "model": "rbf",
        "min_size": 2,
        "jump": 1,
        "smoothing_alpha": 0.1,
        "weights": None,
    },
    "termination": {
        "window_size": 1000,
        "step": 200,
        "penalty": 10,
        "features": DEFAULT_FEATURES.copy(),
        "model": "rbf",
        "min_size": 2,
        "jump": 1,
        "smoothing_alpha": 0.1,
        "weights": None,
    },
}


def get_default_params():
    """Return an independent copy of the optimized detector parameters."""
    return deepcopy(DEFAULT_PARAMS)


def merge_params(params=None):
    """Merge user-supplied detector settings into the optimized defaults.

    Parameters
    ----------
    params : dict or None
        Partial or complete configuration. Any omitted setting retains its
        optimized default.

    Returns
    -------
    dict
        Complete configuration for onset, transition, and termination.
    """
    merged = get_default_params()

    if params is None:
        return merged

    if not isinstance(params, dict):
        raise TypeError("params must be a dictionary or None")

    for phase, overrides in params.items():
        if phase not in merged:
            raise ValueError(
                f"Unknown phase '{phase}'. Expected one of: "
                f"{', '.join(merged.keys())}"
            )
        if not isinstance(overrides, dict):
            raise TypeError(f"Parameters for phase '{phase}' must be a dictionary")
        merged[phase].update(overrides)

    validate_params(merged)
    return merged


def validate_params(params):
    """Validate a complete three-phase detector configuration."""
    valid_phases = ("onset", "transition", "termination")
    valid_features = set(DEFAULT_FEATURES)

    for phase in valid_phases:
        if phase not in params:
            raise ValueError(f"Missing detector parameters for phase '{phase}'")

        cfg = params[phase]

        for key in ("window_size", "step", "penalty", "features"):
            if key not in cfg:
                raise ValueError(f"Missing '{key}' for phase '{phase}'")

        if int(cfg["window_size"]) <= 0:
            raise ValueError(f"{phase}.window_size must be > 0")
        if int(cfg["step"]) <= 0:
            raise ValueError(f"{phase}.step must be > 0")
        if float(cfg["penalty"]) < 0:
            raise ValueError(f"{phase}.penalty must be >= 0")

        features = list(cfg["features"])
        if not features:
            raise ValueError(f"{phase}.features must contain at least one feature")

        unknown = set(features) - valid_features
        if unknown:
            raise ValueError(
                f"Unknown feature(s) for phase '{phase}': {sorted(unknown)}"
            )

        alpha = float(cfg.get("smoothing_alpha", 0.1))
        if not (0 < alpha <= 1):
            raise ValueError(f"{phase}.smoothing_alpha must be in (0, 1]")

        if int(cfg.get("min_size", 2)) < 1:
            raise ValueError(f"{phase}.min_size must be >= 1")

        if int(cfg.get("jump", 1)) < 1:
            raise ValueError(f"{phase}.jump must be >= 1")

        weights = cfg.get("weights")
        if weights is not None:
            if not isinstance(weights, dict):
                raise TypeError(f"{phase}.weights must be a dictionary or None")
            unknown_weight_features = set(weights) - valid_features
            if unknown_weight_features:
                raise ValueError(
                    f"Unknown weighted feature(s) for phase '{phase}': "
                    f"{sorted(unknown_weight_features)}"
                )


# ---------------------------------------------------------------------------
# Core detection
# ---------------------------------------------------------------------------

def detect_changepoints_pelt(
    X,
    penalty,
    model="rbf",
    min_size=2,
    jump=1,
):
    """Run PELT on a feature matrix and return changepoint indices."""
    if not _RUPTURES_AVAILABLE:
        raise ImportError("Install ruptures: pip install ruptures")

    X = np.asarray(X, dtype=float)

    if X.ndim == 1:
        X = X.reshape(-1, 1)

    if X.ndim != 2:
        raise ValueError("X must be a 1-D or 2-D numeric array")

    if len(X) == 0:
        return []

    algo = rpt.Pelt(
        model=str(model),
        min_size=int(min_size),
        jump=int(jump),
    ).fit(X)

    result = algo.predict(pen=float(penalty))

    # ruptures includes len(X) as the final segment boundary.
    return result[:-1]


# ---------------------------------------------------------------------------
# Phase-specific strategies
# ---------------------------------------------------------------------------

def _phase_changepoints(X, params):
    return detect_changepoints_pelt(
        X,
        penalty=params["penalty"],
        model=params.get("model", "rbf"),
        min_size=params.get("min_size", 2),
        jump=params.get("jump", 1),
    )


def detect_onset(X, params):
    """Return the first changepoint (earliest transition)."""
    cps = _phase_changepoints(X, params)
    return cps[0] if cps else None


def detect_termination(X, params):
    """Return the last changepoint (latest transition)."""
    cps = _phase_changepoints(X, params)
    return cps[-1] if cps else None


def detect_transition(X, params):
    """Return the changepoint closest to the midpoint of the feature window."""
    cps = _phase_changepoints(X, params)

    if not cps:
        return None

    mid = len(X) / 2.0
    return min(cps, key=lambda cp: abs(cp - mid))


# ---------------------------------------------------------------------------
# Convenience: run all three phases from already-stacked feature matrices
# ---------------------------------------------------------------------------

def run_three_phase_detection(feature_matrices, params=None, time_indices=None):
    """Detect onset, transition, and termination from stacked feature matrices.

    Parameters
    ----------
    feature_matrices : dict
        Keys 'onset', 'transition', and 'termination'. Each value must be the
        2-D feature matrix that should be passed to PELT.
    params : dict or None
        Partial or complete detector configuration.
    time_indices : dict or None
        Optional sample-index array corresponding to the rows of each phase's
        feature matrix.

    Returns
    -------
    dict
        Detected changepoints. If time_indices is supplied, values are sample
        indices; otherwise values are feature-matrix row indices.
    """
    cfg = merge_params(params)

    phase_functions = {
        "onset": detect_onset,
        "transition": detect_transition,
        "termination": detect_termination,
    }

    results = {}

    for phase, fn in phase_functions.items():
        if phase not in feature_matrices:
            raise ValueError(f"Missing feature matrix for phase '{phase}'")

        X = feature_matrices[phase]
        cp_idx = fn(X, cfg[phase])

        if cp_idx is None:
            results[phase] = None
            continue

        if time_indices is None:
            results[phase] = int(cp_idx)
            continue

        if phase not in time_indices:
            raise ValueError(f"Missing time indices for phase '{phase}'")

        t = np.asarray(time_indices[phase])

        if cp_idx >= len(t):
            results[phase] = None
        else:
            results[phase] = int(t[cp_idx])

    return results
