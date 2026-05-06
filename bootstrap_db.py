"""
Database bootstrap for Railway / fresh deploys.

Runs once on container boot. If the VETERAN table already exists,
exits silently. Otherwise, executes the SQL files in order to set
up schema, sample data, triggers, stored procedures, and cursors.

Idempotent: safe to run on every deploy.
"""
import os
import re
import sys
from pathlib import Path

import mysql.connector

ROOT = Path(__file__).parent

DB_CONFIG = {
    "host":     os.environ.get("MYSQL_HOST", "localhost"),
    "port":     int(os.environ.get("MYSQL_PORT", "3306")),
    "user":     os.environ.get("MYSQL_USER", "root"),
    "password": os.environ.get("MYSQL_PASSWORD", ""),
    "database": os.environ.get("MYSQL_DATABASE", "ivrpms"),
}

# Order matters: schema → data → procedural objects
SQL_FILES = [
    ROOT / "01-schema" / "create_tables.sql",
    ROOT / "01-schema" / "sample_data.sql",
    ROOT / "02-plsql"  / "triggers.sql",
    ROOT / "02-plsql"  / "stored_procedures.sql",
    ROOT / "02-plsql"  / "cursors.sql",
]


def already_bootstrapped(conn) -> bool:
    """True if the VETERAN table exists and has rows."""
    cur = conn.cursor()
    try:
        cur.execute("""
            SELECT COUNT(*) FROM information_schema.TABLES
            WHERE TABLE_SCHEMA = %s AND TABLE_NAME = 'VETERAN'
        """, (DB_CONFIG["database"],))
        (table_count,) = cur.fetchone()
        if table_count == 0:
            return False
        cur.execute("SELECT COUNT(*) FROM VETERAN")
        (row_count,) = cur.fetchone()
        return row_count > 0
    finally:
        cur.close()


def split_statements(sql_text: str) -> list[str]:
    """
    Split a SQL script on `;` while honouring DELIMITER directives so
    multi-statement bodies inside CREATE PROCEDURE / TRIGGER blocks are
    kept intact. mysql-connector cannot run DELIMITER itself.
    """
    statements = []
    buf = []
    delimiter = ";"
    i = 0
    lines = sql_text.splitlines(keepends=True)
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Skip pure comment / blank lines outside a block
        if not buf and (not stripped or stripped.startswith("--")):
            i += 1
            continue

        m = re.match(r"^\s*DELIMITER\s+(\S+)\s*$", line, re.IGNORECASE)
        if m:
            # flush any pending buffer first
            if buf:
                stmt = "".join(buf).strip()
                if stmt.endswith(delimiter):
                    stmt = stmt[: -len(delimiter)].rstrip()
                if stmt:
                    statements.append(stmt)
                buf = []
            delimiter = m.group(1)
            i += 1
            continue

        buf.append(line)
        joined = "".join(buf).rstrip()
        if joined.endswith(delimiter):
            stmt = joined[: -len(delimiter)].rstrip()
            if stmt:
                statements.append(stmt)
            buf = []
        i += 1

    tail = "".join(buf).strip()
    if tail:
        statements.append(tail)
    return statements


def run_sql_file(conn, path: Path) -> None:
    print(f"  → {path.relative_to(ROOT)}", flush=True)
    sql_text = path.read_text(encoding="utf-8")
    # Strip `USE <db>;` lines — we connect to the right DB via env vars,
    # so the hardcoded `USE ivrpms;` would fail when the DB is named
    # differently (e.g. Railway provisions a DB called "railway").
    sql_text = re.sub(r"^\s*USE\s+\w+\s*;\s*$", "", sql_text,
                      flags=re.IGNORECASE | re.MULTILINE)
    statements = split_statements(sql_text)
    cur = conn.cursor()
    try:
        for stmt in statements:
            try:
                cur.execute(stmt)
                # Drain any result sets so the connection can take the next stmt
                while cur.nextset():
                    pass
            except mysql.connector.Error as e:
                preview = stmt[:120].replace("\n", " ")
                print(f"    ! error on: {preview}…", flush=True)
                print(f"    ! {e}", flush=True)
                raise
        conn.commit()
    finally:
        cur.close()


def main() -> int:
    print(f"[bootstrap] connecting to {DB_CONFIG['host']}:{DB_CONFIG['port']} "
          f"db={DB_CONFIG['database']}", flush=True)
    try:
        conn = mysql.connector.connect(**DB_CONFIG)
    except mysql.connector.Error as e:
        print(f"[bootstrap] connection failed: {e}", flush=True)
        # Don't crash the dyno — let Flask still start so /api/health
        # can report the connection error.
        return 0

    try:
        if already_bootstrapped(conn):
            print("[bootstrap] schema already present, skipping.", flush=True)
            return 0

        print("[bootstrap] empty database — loading SQL files…", flush=True)
        for f in SQL_FILES:
            if not f.exists():
                print(f"[bootstrap] missing file: {f}", flush=True)
                return 1
            run_sql_file(conn, f)
        print("[bootstrap] done.", flush=True)
        return 0
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())
