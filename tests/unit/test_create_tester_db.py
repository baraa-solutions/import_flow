"""
Unit tests for scripts/create_tester_db.py (emptied tester copy of a database).
"""

import sqlite3

import pytest

from scripts import create_tester_db as tester


def _make_source(path):
    conn = sqlite3.connect(path)
    conn.executescript(
        """
        CREATE TABLE alembic_version (version_num TEXT PRIMARY KEY);
        INSERT INTO alembic_version VALUES ('d8e9f0a1b2c3');
        CREATE TABLE users (user_id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT);
        INSERT INTO users (username) VALUES ('admin'), ('clerk');
        CREATE TABLE import_companies (company_id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT);
        INSERT INTO import_companies (name) VALUES ('شركة سرور');
        CREATE TABLE suppliers (supplier_id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT);
        INSERT INTO suppliers (name) VALUES ('Ningbo Co');
        CREATE TABLE currencies (currency_id INTEGER PRIMARY KEY, code TEXT);
        INSERT INTO currencies VALUES (1, 'USD');
        CREATE TABLE exchange_rates (rate_id INTEGER PRIMARY KEY, currency_id INTEGER REFERENCES currencies(currency_id));
        INSERT INTO exchange_rates VALUES (1, 1);
        CREATE TABLE projects (project_id INTEGER PRIMARY KEY AUTOINCREMENT, company_id INTEGER REFERENCES import_companies(company_id));
        INSERT INTO projects (company_id) VALUES (1), (1);
        CREATE TABLE customs_tariffs (tariff_id INTEGER PRIMARY KEY AUTOINCREMENT, hs_code TEXT);
        INSERT INTO customs_tariffs (hs_code) VALUES ('8471.30.00');
        CREATE TABLE import_files (import_file_id INTEGER PRIMARY KEY AUTOINCREMENT, supplier_id INTEGER REFERENCES suppliers(supplier_id));
        INSERT INTO import_files (supplier_id) VALUES (1);
        CREATE TABLE brand_new_operational_table (id INTEGER PRIMARY KEY, note TEXT);
        INSERT INTO brand_new_operational_table VALUES (1, 'x');
        """
    )
    conn.commit()
    conn.close()


def _count(path, table):
    conn = sqlite3.connect(path)
    try:
        return conn.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0]
    finally:
        conn.close()


@pytest.fixture
def source_db(tmp_path):
    path = tmp_path / "source.db"
    _make_source(path)
    return path


def test_keeps_master_and_system_tables_and_empties_the_rest(source_db, tmp_path):
    out = tmp_path / "tester.db"
    result = tester.build_tester_db(source_db, out)

    for table, rows in {"import_companies": 1, "suppliers": 1, "currencies": 1, "exchange_rates": 1,
                        "users": 2, "alembic_version": 1}.items():
        assert _count(out, table) == rows, table
    for table in ("projects", "customs_tariffs", "import_files", "brand_new_operational_table"):
        assert _count(out, table) == 0, table

    assert result["deleted"]["projects"] == 2
    assert result["integrity"] == "ok"
    assert result["dangling"] == []


def test_source_database_is_never_modified(source_db, tmp_path):
    tester.build_tester_db(source_db, tmp_path / "tester.db")
    assert _count(source_db, "projects") == 2
    assert _count(source_db, "customs_tariffs") == 1
    assert _count(source_db, "import_files") == 1


def test_autoincrement_restarts_for_emptied_tables(source_db, tmp_path):
    out = tmp_path / "tester.db"
    tester.build_tester_db(source_db, out)
    conn = sqlite3.connect(out)
    try:
        conn.execute("INSERT INTO projects (company_id) VALUES (1)")
        assert conn.execute("SELECT MAX(project_id) FROM projects").fetchone()[0] == 1
    finally:
        conn.close()


def test_refuses_an_existing_output_file(source_db, tmp_path):
    out = tmp_path / "tester.db"
    out.write_bytes(b"keep me")
    with pytest.raises(FileExistsError):
        tester.build_tester_db(source_db, out)
    assert out.read_bytes() == b"keep me"


def test_refuses_a_missing_source(tmp_path):
    with pytest.raises(FileNotFoundError):
        tester.build_tester_db(tmp_path / "missing.db", tmp_path / "tester.db")


def test_requested_screens_are_kept_and_projects_and_tariff_are_not():
    for table in ("import_companies", "suppliers", "external_service_providers", "transport_locations",
                  "incoterms", "currencies", "exchange_rates"):
        assert table in tester.KEEP_TABLES
    for table in ("projects", "customs_tariffs", "fee_codes", "preferential_agreements"):
        assert table not in tester.KEEP_TABLES


def test_cli_reports_success(source_db, tmp_path, capsys):
    out = tmp_path / "tester.db"
    assert tester.main(["--source", str(source_db), "--out", str(out)]) == 0
    assert "[SUCCESS]" in capsys.readouterr().out
    assert tester.main(["--source", str(source_db), "--out", str(out)]) == 1
