"""Run all tests to ensure this gui pipeline is working! :)."""

from pathlib import Path

import pytest


def main() -> int:
    tests_directory = Path(__file__).resolve().parent / "tests"

    print("=" * 70)
    print("SEEG GUI pipeline test suite")
    print(f"Test directory: {tests_directory}")
    print("=" * 70)

    return pytest.main([
        str(tests_directory),
        "-v",
        "--tb=short",
    ])


if __name__ == "__main__":
    raise SystemExit(main())