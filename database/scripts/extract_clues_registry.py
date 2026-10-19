"""Extract a pinned local CLUES workbook; never ingest or infer current operation."""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path, PurePosixPath
import posixpath
import re
import stat
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[2]
ARTIFACTS = ROOT / "collectors" / "artifacts"
NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
REL = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
PKG_REL = "{http://schemas.openxmlformats.org/package/2006/relationships}"
CLUES = re.compile(r"[A-Z]{5}[0-9]{6}")
FIELDS = frozenset({
    "CLUES", "CLAVE DE LA INSTITUCION", "NOMBRE DE LA INSTITUCION",
    "CLAVE DE LA ENTIDAD", "ENTIDAD", "CLAVE DEL MUNICIPIO", "MUNICIPIO",
    "CLAVE DE LA LOCALIDAD", "LOCALIDAD", "NOMBRE DE LA UNIDAD",
    "NOMBRE COMERCIAL", "NOMBRE COMMERCIAL", "TIPO DE VIALIDAD", "VIALIDAD",
    "NUMERO EXTERIOR", "NUMERO INTERIOR", "TIPO DE ASENTAMIENTO",
    "ASENTAMIENTO", "CODIGO POSTAL", "CLAVE ESTATUS DE OPERACION",
    "ESTATUS DE OPERACION", "ULTIMO MOVIMIENTO", "FECHA ULTIMO MOVIMIENTO",
    "MOTIVO BAJA", "FECHA EFECTIVA DE BAJA",
})
REQUIRED = frozenset({"CLUES", "CLAVE DE LA ENTIDAD", "NOMBRE DE LA UNIDAD",
                      "CLAVE DE LA INSTITUCION", "NOMBRE DE LA INSTITUCION",
                      "ESTATUS DE OPERACION", "MUNICIPIO", "LOCALIDAD",
                      "VIALIDAD", "NUMERO EXTERIOR", "CODIGO POSTAL"})
COMMENT_FIELDS = frozenset({"OBSERVACIONES AL REGISTRO", "COMENTARIOS DE LA VALIDACION"})
MIB = 1024 * 1024


class SafeXML:
    """Stream XML without permitting a DTD or entity declarations."""

    def __init__(self, stream):
        self.stream = stream
        self.tail = b""

    def read(self, size=-1):
        data = self.stream.read(size)
        probe = (self.tail + data).upper()
        if b"<!DOCTYPE" in probe or b"<!ENTITY" in probe or b"\x00" in data:
            raise ValueError("Only UTF-8-compatible XML without DTD/entities is supported")
        self.tail = probe[-16:]
        return data


def digest(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(MIB), b""):
            result.update(chunk)
    return result.hexdigest()


def xml_root(archive, member, limit=2 * MIB):
    if archive.getinfo(member).file_size > limit:
        raise ValueError(f"XML metadata too large: {member}")
    with archive.open(member) as stream:
        return ET.parse(SafeXML(stream)).getroot()


def validate_archive(archive):
    members = archive.infolist()
    names = [entry.filename for entry in members]
    if len(names) != len(set(names)) or len(names) > 128:
        raise ValueError("Duplicate ZIP members or more than 128 members")
    if sum(entry.file_size for entry in members) > 320 * MIB:
        raise ValueError("ZIP expanded size exceeds 320 MiB")
    for entry in members:
        path = PurePosixPath(entry.filename)
        if (path.is_absolute() or ".." in path.parts or "\\" in entry.filename
                or ":" in entry.filename or stat.S_ISLNK(entry.external_attr >> 16)
                or entry.flag_bits & 1 or entry.file_size > 192 * MIB
                or entry.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)):
            raise ValueError(f"Unsafe or unsupported ZIP member: {entry.filename}")
    return members


def declared_sheet(archive):
    workbook = xml_root(archive, "xl/workbook.xml")
    sheets = workbook.findall(NS + "sheets/" + NS + "sheet")
    candidates = [sheet for sheet in sheets
                  if re.fullmatch(r"CLUES_[0-9]{6}", sheet.get("name", ""))]
    if len(candidates) != 1:
        raise ValueError("Expected exactly one declared CLUES_YYYYMM sheet")
    sheet = candidates[0]
    rels = xml_root(archive, "xl/_rels/workbook.xml.rels")
    matches = [item for item in rels.findall(PKG_REL + "Relationship")
               if item.get("Id") == sheet.get(REL + "id")]
    if len(matches) != 1:
        raise ValueError("Sheet relationship missing or duplicated")
    relation = matches[0]
    target = relation.get("Target", "")
    if (relation.get("TargetMode", "Internal") != "Internal"
            or relation.get("Type") != REL[1:-1] + "/worksheet"
            or "\\" in target or ":" in target or ".." in PurePosixPath(target).parts):
        raise ValueError("Unsafe worksheet relationship")
    member = posixpath.normpath(target.lstrip("/") if target.startswith("/")
                               else posixpath.join("xl", target))
    if not re.fullmatch(r"xl/worksheets/[^/]+\.xml", member):
        raise ValueError("Unsupported worksheet member")
    archive.getinfo(member)
    core = xml_root(archive, "docProps/core.xml")
    timestamps = {}
    for field in ("created", "modified"):
        value = core.findtext("{http://purl.org/dc/terms/}" + field)
        if value:
            datetime.fromisoformat(value.replace("Z", "+00:00"))
            timestamps[field] = value
    # Deliberately omit creator, lastModifiedBy and workbook local filesystem path.
    return sheet.get("name"), member, timestamps


def shared_strings(archive):
    member = "xl/sharedStrings.xml"
    if member not in archive.namelist():
        return []
    if archive.getinfo(member).file_size > 32 * MIB:
        raise ValueError("Shared strings exceed 32 MiB")
    strings = []
    with archive.open(member) as stream:
        context = ET.iterparse(SafeXML(stream), events=("start", "end"))
        _, root = next(context)
        for event, element in context:
            if event == "end" and element.tag == NS + "si":
                value = "".join(node.text or "" for node in element.iter(NS + "t"))
                if len(value) > 32767 or len(strings) >= 1_000_000:
                    raise ValueError("Shared strings count/cell size exceeds limits")
                strings.append(value)
                element.clear()
                root.clear()
    return strings


def cell_text(cell, strings):
    if cell.find(NS + "f") is not None:
        raise ValueError("Formula cells are not supported")
    kind = cell.get("t")
    if kind == "inlineStr":
        value = "".join(node.text or "" for node in cell.iter(NS + "t"))
    else:
        value = cell.findtext(NS + "v", "")
        if kind == "s" and value:
            index = int(value)
            if index < 0 or index >= len(strings):
                raise ValueError("Invalid shared-string index")
            value = strings[index]
        elif kind not in (None, "n", "s", "str"):
            raise ValueError(f"Unsupported cell type: {kind}")
    if len(value) > 32767:
        raise ValueError("Cell exceeds Excel text limit")
    return value


def extract(archive, member, strings, entity, requested):
    records, headers, seen = [], {}, set()
    counts = Counter({key: 0 for key in (
        "rows_scanned", "excluded_other_entity", "entity_rows",
        "excluded_not_requested", "rows_emitted", "blank_rows")})
    previous_row = 0
    with archive.open(member) as stream:
        context = ET.iterparse(SafeXML(stream), events=("start", "end"))
        _, root = next(context)
        if root.tag != NS + "worksheet":
            raise ValueError("Declared member is not a worksheet")
        sheet_data = None
        for event, element in context:
            if event == "start" and element.tag == NS + "sheetData":
                if sheet_data is not None:
                    raise ValueError("Multiple worksheet data sections")
                sheet_data = element
            if event != "end" or element.tag != NS + "row":
                continue
            row_number = int(element.get("r", "0"))
            if row_number <= previous_row or row_number > 1_048_576:
                raise ValueError("Invalid worksheet row order/number")
            previous_row = row_number
            cells = {}
            for cell in element.findall(NS + "c"):
                coordinate = cell.get("r", "")
                match = re.fullmatch(r"([A-Z]{1,3})([1-9][0-9]*)", coordinate)
                if not match or int(match[2]) != row_number or match[1] in cells:
                    raise ValueError("Invalid or duplicate cell coordinate")
                cells[match[1]] = cell_text(cell, strings)
            if not headers:
                if row_number != 1:
                    raise ValueError("Headers must be in row 1")
                headers = {column: value for column, value in cells.items() if value}
                if len(set(headers.values())) != len(headers):
                    raise ValueError("Duplicate column headers")
                missing = REQUIRED - set(headers.values())
                if missing:
                    raise ValueError("Missing required headers: " + ", ".join(sorted(missing)))
            elif any(cells.values()):
                counts["rows_scanned"] += 1
                row = {headers[column]: value for column, value in cells.items()
                       if column in headers}
                clues = row.get("CLUES", "")
                if not CLUES.fullmatch(clues) or clues in seen:
                    raise ValueError(f"Missing/invalid/duplicate CLUES at row {row_number}")
                seen.add(clues)
                if row.get("CLAVE DE LA ENTIDAD") != entity:
                    counts["excluded_other_entity"] += 1
                else:
                    counts["entity_rows"] += 1
                    if requested is not None and clues not in requested:
                        counts["excluded_not_requested"] += 1
                    else:
                        record = {key: row.get(key, "") for key in sorted(FIELDS)
                                  if key in headers.values()}
                        record["_xlsx_row"] = row_number
                        references = []
                        for column, header in headers.items():
                            if header in COMMENT_FIELDS:
                                # Administrative text may attach the CLUES prefix
                                # directly to an ID. These are references only;
                                # their surrounding text never approves succession.
                                ids = sorted(set(re.findall(
                                    r"[A-Z]{5}[0-9]{6}", cells.get(column, "").upper())))
                                if ids:
                                    references.append({"source_cell": f"{column}{row_number}",
                                                       "mentioned_clues": ids})
                        if references:
                            record["_clues_references"] = references
                        records.append(record)
                        counts["rows_emitted"] += 1
            else:
                counts["blank_rows"] += 1
            element.clear()
            if sheet_data is not None:
                sheet_data.clear()
    if not headers:
        raise ValueError("Empty worksheet")
    return records, counts, headers


def main():
    parser = argparse.ArgumentParser(description=__doc__, epilog=(
        "--output is a NEW directory under collectors/artifacts. Writes identity-rows.json "
        "and manifest.json only after validation. --clues is a comma-separated list, not "
        "a file. All rows are scanned to reject duplicate CLUES; filters apply only to "
        "emission. Missing requested IDs are reported, not inferred. Source strings and "
        "Excel date serials remain literal. Comments yield CLUES IDs/cell references only. "
        "No network, contacts, person fields, source approval or current-operation inference."))
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--expected-sha256", required=True)
    parser.add_argument("--entity-code", required=True)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--clues", help="Comma-separated exact CLUES IDs; omission emits entity rows")
    args = parser.parse_args()
    try:
        source = args.input.resolve(strict=True)
        output = args.output.resolve()
        if not source.is_file() or not 0 < source.stat().st_size <= 40 * MIB:
            raise ValueError("Input must be a local file of at most 40 MiB")
        if not re.fullmatch(r"[0-9a-fA-F]{64}", args.expected_sha256):
            raise ValueError("Expected SHA-256 must contain exactly 64 hex digits")
        if not re.fullmatch(r"(?:0[1-9]|[12][0-9]|3[0-2])", args.entity_code):
            raise ValueError("Entity code must be two digits in 01..32")
        if not output.is_relative_to(ARTIFACTS.resolve()) or output == ARTIFACTS.resolve():
            raise ValueError("Output must be beneath collectors/artifacts")
        if output.exists() or output.is_symlink() or source.is_relative_to(output):
            raise ValueError("Output must be new and cannot contain the original input")
        requested = None
        if args.clues is not None:
            tokens = [value.strip() for value in args.clues.split(",")]
            if (not tokens or len(tokens) > 10000 or len(set(tokens)) != len(tokens)
                    or any(not CLUES.fullmatch(value) for value in tokens)):
                raise ValueError("--clues requires unique valid IDs (maximum 10,000)")
            requested = set(tokens)
        source_hash = digest(source)
        if source_hash != args.expected_sha256.lower():
            raise ValueError("Input SHA-256 differs from expected pin")
        with zipfile.ZipFile(source) as archive:
            members = validate_archive(archive)
            sheet, member, timestamps = declared_sheet(archive)
            records, counts, headers = extract(archive, member, shared_strings(archive),
                                               args.entity_code, requested)
        if digest(source) != source_hash:
            raise ValueError("Input changed during extraction")
        payload = (json.dumps(records, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
        emitted = {row["CLUES"] for row in records}
        manifest = {
            "schema": 1, "mode": "local_extraction_no_ingestion_no_status_inference",
            "observed_at_utc": datetime.now(timezone.utc).isoformat(),
            "input_name": source.name, "input_sha256": source_hash,
            "input_bytes": source.stat().st_size, "sheet_name": sheet,
            "sheet_member": member, "workbook_timestamps": timestamps,
            "zip_members": len(members), "zip_expanded_bytes": sum(x.file_size for x in members),
            "entity_code": args.entity_code, "counts": dict(counts),
            "clues_uniqueness": "validated across all nonblank sheet rows; duplicates refused",
            "requested_clues": sorted(requested) if requested is not None else None,
            "missing_requested_clues_in_entity": sorted(requested - emitted) if requested is not None else [],
            "status_counts_as_recorded": dict(Counter(row["ESTATUS DE OPERACION"] for row in records)),
            "emitted_fields": sorted(FIELDS & set(headers.values())),
            "clues_reference_policy": "IDs and cell coordinates only; no succession inferred",
            "output_file": "identity-rows.json",
            "output_sha256": hashlib.sha256(payload).hexdigest(), "output_bytes": len(payload),
            "limits": {"input_mib": 40, "zip_expanded_mib": 320,
                       "zip_member_mib": 192, "shared_strings_mib": 32, "zip_members": 128},
        }
        output.mkdir(parents=True, exist_ok=False)
        (output / "identity-rows.json").write_bytes(payload)
        (output / "manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"output": str(output), "counts": dict(counts),
                          "missing_requested": manifest["missing_requested_clues_in_entity"]}))
    except (ValueError, OSError, KeyError, ET.ParseError, zipfile.BadZipFile) as exc:
        parser.exit(1, f"Extraction refused: {exc}\n")


if __name__ == "__main__":
    main()
