from importlib.metadata import PackageNotFoundError, version

from .seekable_zstd import Reader

try:
    __version__ = version("seekable-zstd")
except PackageNotFoundError:
    __version__ = "unknown"

__all__ = ["Reader", "__version__"]
