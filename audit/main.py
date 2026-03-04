import os
import logging
import json
import datetime as dt
import sqlite3
from contextlib import contextmanager, closing
from flask import Flask, jsonify, request


@contextmanager
def get_db_conn():
    """Return a database handle and initialize tables if necessary."""
    with closing(sqlite3.connect(os.getenv("AUDIT_DB"))) as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS audit (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                record TEXT NOT NULL
            );
        """)
        yield conn
        
log = logging.getLogger("main")
app = Flask(__name__)
counter = 0

@app.route("/audits", methods=["POST"])
def post_audits():
    """Insert an audit to the database."""
    req = request.json
    # Add server-side timestamp
    now = dt.datetime.now(dt.timezone.utc)
    req["time"] = now.isoformat()
    record = json.dumps(req)
    # Publish
    log.info("Recording %s", record)
    with get_db_conn() as conn:
        conn.execute("INSERT INTO audit (id, record) VALUES (NULL, ?)", (record,))
        conn.commit()
    return ('', 204)

@app.route("/audits", methods=["GET"])
def get_audits():
    """Fetch every audit from the database."""
    with get_db_conn() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM audit")
        all_records = cursor.fetchall()
        resp = []
        for audit_id, audit_jso_str in all_records:
            resp.append(
                (audit_id, json.loads(audit_jso_str))
            )
            
        return jsonify(resp)

@app.route("/api/healthz", methods=["GET"])
def get_healthz():
    """Healthcheck. Return empty body (204) for success."""
    return ('', 204)

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    host = os.getenv("AUDIT_BIND", "0.0.0.0")
    port = int(os.getenv("PORT"))
    app.run(
        host=host,
        port=port,
        debug=True,
    )
