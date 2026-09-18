"""Exception types for the world-model engine.

Every engine failure that a caller is expected to handle has a dedicated type so
the CLI can report it as a clear Chinese message instead of a traceback.
"""

from __future__ import annotations


class WorldModelError(Exception):
    """Base class for every world-model failure."""

    code = "world_model_error"

    def __init__(self, message: str, *, detail: str = ""):
        super().__init__(message)
        self.message = message
        self.detail = detail

    def as_dict(self) -> dict:
        return {"code": self.code, "message": self.message, "detail": self.detail}


class DataMissingError(WorldModelError):
    """A required world-model data file, table or key does not exist."""

    code = "data_missing"


class DataFormatError(WorldModelError):
    """A world-model data file exists but violates the schema or is unparseable."""

    code = "data_format"


class SaveCorruptError(WorldModelError):
    """A save file failed its checksum / version / structural validation."""

    code = "save_corrupt"


class ResourceExhausted(WorldModelError):
    """An action was refused because the resource it needs is exhausted."""

    code = "resource_exhausted"


class NumericOverflow(WorldModelError):
    """A projected value escaped its declared domain (out of band / negative)."""

    code = "numeric_overflow"


class GuBacklash(WorldModelError):
    """A gu turned on its cultivator: unpaid feeding, excessive hunger or an
    over-rank activation the cultivator was not eligible to attempt."""

    code = "gu_backlash"


class MetaProgressError(WorldModelError):
    """Hall/meta progress file missing or unusable."""

    code = "meta_progress"


class InputError(WorldModelError):
    """The player supplied a command the runner cannot parse or apply."""

    code = "input_error"
