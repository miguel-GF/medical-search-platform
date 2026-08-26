from pathlib import Path

from pruevia_collectors.providers.chopo import ChopoPage, ChopoListingParser, parse_chopo_page, parse_price_text


def fixture_page() -> ChopoPage:
    path = Path(__file__).parent / "fixtures" / "chopo_puebla_page.html"
    return ChopoPage(1, "https://www.chopo.com.mx/puebla/estudios", path.read_text(encoding="utf-8"))


def test_chopo_parser_extracts_names_skus_urls_and_prices():
    records = parse_chopo_page(fixture_page())

    assert len(records) == 2
    assert records[0].external_record_id == "17002"
    assert records[0].payload["prices"] == {"regular": 28428, "online": 18479}
    assert records[0].source_url == "https://www.chopo.com.mx/puebla/biometria-hematica"
    assert records[1].payload["prices"] == {"regular": 80099}


def test_chopo_price_parser_keeps_minor_units():
    assert parse_price_text("Precio $1,500.00 $975.5") == {"regular": 150000, "online": 97550}
    assert parse_price_text("Sin precio") == {}


def test_chopo_parser_does_not_capture_search_autocomplete_items():
    parser = ChopoListingParser(page_url="https://www.chopo.com.mx/puebla/estudios")
    parser.feed('<dd><div class="product-name">AUTOCOMPLETE</div></dd>')
    assert parser.finish() == []
