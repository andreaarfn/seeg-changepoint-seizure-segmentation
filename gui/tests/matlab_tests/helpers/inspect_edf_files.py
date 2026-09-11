"""Find and summarize EDF files that may be useful for bridge testing."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys

try:
    import pyedflib
except ImportError:
    print(
        "pyedflib is not installed.\n"
        "Install it with:\n"
        "  python -m pip install pyedflib"
    )
    raise SystemExit(1)


SCALP_LABELS = {
    "fp1", "fp2", "f3", "f4", "f7", "f8",
    "c3", "c4", "cz", "p3", "p4", "pz",
    "o1", "o2", "fz", "t3", "t4", "t5", "t6",
}

ECOG_TERMS = {
    "grid",
    "strip",
    "ecog",
}

SEEG_TERMS = {
    "seeg",
    "depth",
    "amyg",
    "amygdala",
    "hip",
    "hipp",
    "hippocampus",
    "insula",
}


def normalize_label(label: str) -> str:
    """Return a lowercase label without spaces or punctuation."""
    return re.sub(r"[^a-z0-9]", "", label.lower())


def looks_like_depth_contact(label: str) -> bool:
    """Check for labels such as LA1, RA2, LHH3, or RPH10."""
    normalized = normalize_label(label)

    return bool(
        re.fullmatch(
            r"[lr]?[a-z]{1,5}\d{1,3}",
            normalized,
        )
    )


def guess_recording_type(labels: list[str]) -> str:
    """Make a rough guess using channel labels only."""
    normalized = [normalize_label(label) for label in labels]

    if any(
        any(term in label for term in ECOG_TERMS)
        for label in normalized
    ):
        return "Likely ECoG"

    if any(
        any(term in label for term in SEEG_TERMS)
        for label in normalized
    ):
        return "Likely SEEG"

    depth_contact_count = sum(
        looks_like_depth_contact(label)
        for label in labels
    )

    if depth_contact_count >= 8:
        return "Possibly SEEG"

    scalp_count = sum(
        label in SCALP_LABELS
        for label in normalized
    )

    if scalp_count >= 4:
        return "Likely scalp EEG"

    return "Unknown from channel labels"


def inspect_edf_file(file_path: Path) -> None:
    """Print useful metadata for one EDF file."""
    print("=" * 68)
    print(f"Folder : {file_path.parent.name}")
    print(f"File   : {file_path.name}")
    print(f"Path   : {file_path.parent}")

    try:
        with pyedflib.EdfReader(str(file_path)) as reader:
            number_of_signals = reader.signals_in_file
            labels = [
                label.strip()
                for label in reader.getSignalLabels()
            ]

            sample_frequencies = [
                float(value)
                for value in reader.getSampleFrequencies()
            ]

            sample_counts = [
                int(value)
                for value in reader.getNSamples()
            ]

            durations = [
                samples / frequency
                for samples, frequency in zip(
                    sample_counts,
                    sample_frequencies,
                )
                if frequency > 0
            ]

            print(f"Signals: {number_of_signals}")

            if durations:
                print(
                    "Length : "
                    f"{min(durations):.2f} to "
                    f"{max(durations):.2f} seconds"
                )

            unique_frequencies = sorted(
                set(sample_frequencies)
            )

            formatted_frequencies = ", ".join(
                f"{frequency:g}"
                for frequency in unique_frequencies[:10]
            )

            if len(unique_frequencies) > 10:
                formatted_frequencies += ", ..."

            print(
                "Sample frequencies: "
                f"{formatted_frequencies} Hz"
            )

            print("\nFirst channel labels:")

            number_to_show = min(15, len(labels))

            for channel_index in range(number_to_show):
                label = labels[channel_index]
                frequency = sample_frequencies[channel_index]
                samples = sample_counts[channel_index]

                print(
                    f"  {channel_index + 1:>3}: "
                    f"{label:<20} "
                    f"{frequency:g} Hz, "
                    f"{samples} samples"
                )

            remaining = len(labels) - number_to_show

            if remaining > 0:
                print(f"  ... {remaining} more channel(s)")

            recording_type = guess_recording_type(labels)

            usable_channels = sum(
                frequency > 0 and samples >= frequency
                for frequency, samples in zip(
                    sample_frequencies,
                    sample_counts,
                )
            )

            print(
                "\nPossible recording type: "
                f"{recording_type}"
            )

            if usable_channels > 0:
                print(
                    "Bridge candidate: yes "
                    f"({usable_channels} usable channel(s))"
                )
            else:
                print(
                    "Bridge candidate: no usable "
                    "signal channels found"
                )

    except Exception as error:
        print("\nCould not read this EDF file.")
        print(f"{type(error).__name__}: {error}")

    print()


def inspect_edf_files(root_folder: Path) -> None:
    """Recursively inspect every EDF file below a folder."""
    if not root_folder.is_dir():
        raise NotADirectoryError(
            f"Folder does not exist: {root_folder}"
        )

    edf_files = sorted(
        path
        for path in root_folder.rglob("*")
        if path.is_file()
        and path.suffix.lower() in {".edf", ".bdf"}
    )

    if not edf_files:
        print(
            "No EDF or BDF files were found under:\n"
            f"{root_folder}"
        )
        return

    print(f"\nFound {len(edf_files)} EDF/BDF file(s).\n")

    for file_path in edf_files:
        inspect_edf_file(file_path)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Recursively inspect EDF files and print "
            "channel and sampling information."
        )
    )

    parser.add_argument(
        "root_folder",
        type=Path,
        help="Folder containing EDF files or subfolders.",
    )

    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()

    try:
        inspect_edf_files(
            arguments.root_folder.expanduser().resolve()
        )
    except Exception as error:
        print(
            f"Error: {error}",
            file=sys.stderr,
        )
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())