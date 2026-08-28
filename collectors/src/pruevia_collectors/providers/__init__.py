"""Source adapters for Pruevia."""

from .denue import DenueAdapter, DenueClient, DenueQuery, denue_row_to_record

__all__ = ["DenueAdapter", "DenueClient", "DenueQuery", "denue_row_to_record"]
from .ruiz import RuizAdapter, RuizClient, RuizDepartment

__all__ = ["RuizAdapter", "RuizClient", "RuizDepartment"]
from .salud_digna import SaludDignaAdapter, SaludDignaClient, SaludDignaLocationPage

__all__ += ["SaludDignaAdapter", "SaludDignaClient", "SaludDignaLocationPage"]
from .generic import (
    GenericCrawlConfig,
    GenericPage,
    GenericPageParser,
    GenericProviderAdapter,
    GenericWebClient,
    parse_price_minor,
)

__all__ += [
    "GenericCrawlConfig",
    "GenericPage",
    "GenericPageParser",
    "GenericProviderAdapter",
    "GenericWebClient",
    "parse_price_minor",
]
