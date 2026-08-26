"""Source adapters for Pruevia."""

from .denue import DenueAdapter, DenueClient, DenueQuery, denue_row_to_record

__all__ = ["DenueAdapter", "DenueClient", "DenueQuery", "denue_row_to_record"]
from .ruiz import RuizAdapter, RuizClient, RuizDepartment

__all__ = ["RuizAdapter", "RuizClient", "RuizDepartment"]
