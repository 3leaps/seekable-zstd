from .seekable_zstd import Reader
from importlib.metadata import version, PackageNotFoundError

try:
    __version__ = version("seekable-zstd")
except PackageNotFoundError:
    __version__ = "unknown"

__all__ = ["Reader", "__version__"]
