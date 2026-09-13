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

from .semin import SeminAdapter, SeminClient

__all__ += ["SeminAdapter", "SeminClient"]
from .dr_simi import DrSimiAdapter, DrSimiClient, parse_branch, parse_campaign_branches

__all__ += ["DrSimiAdapter", "DrSimiClient", "parse_branch", "parse_campaign_branches"]
from .linfolab import LinfolabAdapter, LinfolabClient, branch_to_record, parse_branches

__all__ += ["LinfolabAdapter", "LinfolabClient", "branch_to_record", "parse_branches"]
