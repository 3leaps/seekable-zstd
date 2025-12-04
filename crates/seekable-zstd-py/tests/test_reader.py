import os

import pytest
from seekable_zstd import Reader


def test_reader_fixture(tmp_path):
    # This assumes the shared fixture exists from earlier phases.
    # In a real CI, we might need to point to it or regenerate it.
    # For now, let's create a fresh one or skip if not found.

    # Try to find the hello.szst fixture from the project root
    fixture_path = os.path.join(os.path.dirname(__file__), "../../../tests/fixtures/hello.szst")
    fixture_path = os.path.abspath(fixture_path)

    if not os.path.exists(fixture_path):
        pytest.skip(f"Fixture not found at {fixture_path}")

    reader = Reader(fixture_path)
    assert reader.size() == 11
    assert reader.frame_count() >= 1

    data = reader.read_range(0, 5)
    assert data == b"Hello"

    data = reader.read_range(6, 11)
    assert data == b"World"


def test_context_manager():
    """Test that Reader works as a context manager."""
    fixture_path = os.path.join(os.path.dirname(__file__), "../../../tests/fixtures/hello.szst")
    fixture_path = os.path.abspath(fixture_path)

    if not os.path.exists(fixture_path):
        pytest.skip(f"Fixture not found at {fixture_path}")

    with Reader(fixture_path) as reader:
        assert reader.size() == 11
        data = reader.read_range(0, 5)
        assert data == b"Hello"
