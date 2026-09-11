"""
Feature extraction functions for SEEG seizure segmentation.

Extracts seven multivariate envelope-based features from SEEG signals:
  - RMS envelope
  - Relative bandpower: theta (4-8 Hz), alpha (8-13 Hz),
    beta (13-30 Hz), gamma (30-80 Hz)
  - Line length
  - Spectral entropy

Reference:
    Kumar et al., "Three-Phase Seizure Segmentation in Stereotactic EEG
    Using Envelope-Based Multivariate Changepoint Analysis", Ann. Biomed. Eng.
"""

import numpy as np
from scipy.signal import welch, butter, filtfilt
from scipy.integrate import trapezoid
from scipy.stats import entropy


FEATURE_NAMES = ("rms", "theta", "alpha", "beta", "gamma", "ll", "se")

BANDS = {
    "theta": (4, 8),
    "alpha": (8, 13),
    "beta": (13, 30),
    "gamma": (30, 80),
}

TOTAL_BAND = (0.5, 150)

DEFAULT_PREPROCESSING = {
    "highpass_cutoff": 0.5,
    "highpass_order": 3,
}


# ---------------------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------------------

def _validate_window_settings(window_size, step):
    window_size = int(window_size)
    step = int(step)

    if window_size <= 0:
        raise ValueError("window_size must be > 0")
    if step <= 0:
        raise ValueError("step must be > 0")

    return window_size, step


def _validate_fs(fs):
    fs = float(fs)
    if fs <= 0:
        raise ValueError("fs must be > 0")
    return fs


# ---------------------------------------------------------------------------
# Preprocessing
# ---------------------------------------------------------------------------

def highpass_filter(signal, fs=1000, cutoff=0.5, order=3):
    """Apply a zero-phase Butterworth high-pass filter."""
    signal = np.asarray(signal, dtype=float)
    fs = _validate_fs(fs)
    cutoff = float(cutoff)
    order = int(order)

    if signal.ndim != 1:
        raise ValueError("signal must be one-dimensional")
    if cutoff <= 0:
        raise ValueError("cutoff must be > 0")
    if cutoff >= fs / 2:
        raise ValueError("cutoff must be below the Nyquist frequency")
    if order < 1:
        raise ValueError("order must be >= 1")

    nyq = 0.5 * fs
    b, a = butter(order, cutoff / nyq, btype="highpass")
    return filtfilt(b, a, signal)


# ---------------------------------------------------------------------------
# Feature extraction
# ---------------------------------------------------------------------------

def rms_envelope(signal, window_size, step):
    """Calculate root-mean-square amplitude in overlapping windows."""
    signal = np.asarray(signal, dtype=float)
    window_size, step = _validate_window_settings(window_size, step)

    if len(signal) < window_size:
        return np.array([]), np.array([], dtype=int)

    n_windows = (len(signal) - window_size) // step + 1

    envelope = np.array([
        np.sqrt(np.mean(np.square(signal[i * step:i * step + window_size])))
        for i in range(n_windows)
    ])

    time_indices = (
        np.arange(n_windows, dtype=int) * step + window_size // 2
    )

    return envelope, time_indices


def line_length(signal, window_size, step):
    """Sum absolute first differences within each signal window."""
    signal = np.asarray(signal, dtype=float)
    window_size, step = _validate_window_settings(window_size, step)

    if len(signal) < window_size:
        return np.array([])

    return np.array([
        np.sum(np.abs(np.diff(signal[s:s + window_size])))
        for s in range(0, len(signal) - window_size + 1, step)
    ])


def spectral_entropy(signal, fs, window_size, step):
    """Calculate Shannon entropy of the normalized Welch PSD."""
    signal = np.asarray(signal, dtype=float)
    fs = _validate_fs(fs)
    window_size, step = _validate_window_settings(window_size, step)

    if len(signal) < window_size:
        return np.array([])

    values = []

    for s in range(0, len(signal) - window_size + 1, step):
        seg = signal[s:s + window_size]
        _, pxx = welch(seg, fs=fs, nperseg=min(window_size, 256))
        pxx_norm = pxx / (pxx.sum() + 1e-12)
        values.append(entropy(pxx_norm))

    return np.asarray(values)


def relative_bandpower_envelope(
    signal,
    fs,
    band,
    total_band,
    window_size,
    step,
):
    """Calculate relative spectral power for a specified frequency band."""
    signal = np.asarray(signal, dtype=float)
    fs = _validate_fs(fs)
    window_size, step = _validate_window_settings(window_size, step)

    if len(signal) < window_size:
        return np.array([]), np.array([], dtype=int)

    n_windows = (len(signal) - window_size) // step + 1
    relative_power = np.zeros(n_windows)

    time_indices = (
        np.arange(n_windows, dtype=int) * step + window_size // 2
    )

    for i in range(n_windows):
        start = i * step
        seg = signal[start:start + window_size]
        f, pxx = welch(seg, fs=fs, nperseg=min(window_size, 256))

        total_mask = (f >= total_band[0]) & (f <= total_band[1])
        band_mask = (f >= band[0]) & (f <= band[1])

        total_power = trapezoid(pxx[total_mask], f[total_mask]) + 1e-12
        band_power = trapezoid(pxx[band_mask], f[band_mask])

        relative_power[i] = band_power / total_power

    return relative_power, time_indices


# ---------------------------------------------------------------------------
# Convenience wrappers
# ---------------------------------------------------------------------------

def extract_all_features(signal, fs, window_size, step):
    """Extract all seven supported features using common window settings."""
    rms, t = rms_envelope(signal, window_size, step)
    ll = line_length(signal, window_size, step)
    se = spectral_entropy(signal, fs, window_size, step)

    theta, _ = relative_bandpower_envelope(
        signal, fs, BANDS["theta"], TOTAL_BAND, window_size, step
    )
    alpha, _ = relative_bandpower_envelope(
        signal, fs, BANDS["alpha"], TOTAL_BAND, window_size, step
    )
    beta, _ = relative_bandpower_envelope(
        signal, fs, BANDS["beta"], TOTAL_BAND, window_size, step
    )
    gamma, _ = relative_bandpower_envelope(
        signal, fs, BANDS["gamma"], TOTAL_BAND, window_size, step
    )

    return {
        "rms": rms,
        "theta": theta,
        "alpha": alpha,
        "beta": beta,
        "gamma": gamma,
        "ll": ll,
        "se": se,
        "time_indices": t,
    }


def extract_selected_features(
    signal,
    fs,
    window_size,
    step,
    feature_names=None,
):
    """Extract the requested feature subset.

    This currently calculates all seven features first, then returns only the
    requested subset. This keeps the numerical behavior centralized and
    consistent with extract_all_features().
    """
    if feature_names is None:
        feature_names = list(FEATURE_NAMES)

    feature_names = list(feature_names)

    if not feature_names:
        raise ValueError("feature_names must contain at least one feature")

    unknown = set(feature_names) - set(FEATURE_NAMES)
    if unknown:
        raise ValueError(f"Unknown feature(s): {sorted(unknown)}")

    all_features = extract_all_features(signal, fs, window_size, step)

    result = {name: all_features[name] for name in feature_names}
    result["time_indices"] = all_features["time_indices"]

    return result


def minmax_normalize(feat):
    """Min-max normalize a feature vector to [0, 1]."""
    feat = np.asarray(feat, dtype=float)

    if feat.size == 0:
        return feat.copy()

    f_min = feat.min()
    f_max = feat.max()
    denom = f_max - f_min

    return (feat - f_min) / (denom if denom > 1e-12 else 1.0)


def exponential_smooth(feat, alpha=0.1):
    """Apply exponential weighted averaging to a feature vector."""
    feat = np.asarray(feat, dtype=float)
    alpha = float(alpha)

    if not (0 < alpha <= 1):
        raise ValueError("alpha must be in (0, 1]")

    if feat.size == 0:
        return feat.copy()

    smoothed = np.zeros_like(feat, dtype=float)
    smoothed[0] = feat[0]

    for t in range(1, len(feat)):
        smoothed[t] = alpha * feat[t] + (1 - alpha) * smoothed[t - 1]

    return smoothed


def stack_features(
    feature_dict,
    feature_names,
    weights=None,
    alpha=0.1,
):
    """Normalize, smooth, optionally weight, and stack selected features."""
    feature_names = list(feature_names)

    if not feature_names:
        raise ValueError("feature_names must contain at least one feature")

    unknown = set(feature_names) - set(FEATURE_NAMES)
    if unknown:
        raise ValueError(f"Unknown feature(s): {sorted(unknown)}")

    if weights is None:
        weights = {name: 1.0 for name in feature_names}

    columns = []

    for name in feature_names:
        if name not in feature_dict:
            raise KeyError(f"Feature dictionary does not contain '{name}'")

        feat = np.asarray(feature_dict[name], dtype=float)
        feat_norm = minmax_normalize(feat)
        feat_smooth = exponential_smooth(feat_norm, alpha=alpha)
        columns.append(feat_smooth * float(weights.get(name, 1.0)))

    if any(len(column) == 0 for column in columns):
        return np.empty((0, len(columns)))

    n = min(len(column) for column in columns)

    return np.column_stack([column[:n] for column in columns])


def prepare_feature_matrix(
    signal,
    fs,
    window_size,
    step,
    feature_names,
    weights=None,
    smoothing_alpha=0.1,
):
    """Extract and stack one phase's features for changepoint detection.

    Returns
    -------
    X : ndarray
        Feature matrix passed to PELT.
    time_indices : ndarray
        Sample indices corresponding to rows of X.
    raw_features : dict
        Extracted features before normalization/smoothing.
    """
    raw_features = extract_selected_features(
        signal=signal,
        fs=fs,
        window_size=window_size,
        step=step,
        feature_names=feature_names,
    )

    X = stack_features(
        raw_features,
        feature_names=feature_names,
        weights=weights,
        alpha=smoothing_alpha,
    )

    time_indices = np.asarray(raw_features["time_indices"], dtype=int)

    if len(time_indices) > len(X):
        time_indices = time_indices[:len(X)]

    return X, time_indices, raw_features
