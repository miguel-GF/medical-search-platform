"""Network defaults must not inherit proxy variables from the collector host."""

from pruevia_collectors.providers.chopo import ChopoClient
from pruevia_collectors.providers.ruiz import RuizClient
from pruevia_collectors.providers.salud_digna import SaludDignaClient


def test_official_clients_disable_environment_proxies():
    clients = [ChopoClient(), RuizClient(), SaludDignaClient()]
    try:
        assert all(client._client._trust_env is False for client in clients)
    finally:
        for client in clients:
            client.close()
