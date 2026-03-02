import os
import logging
import json
from flask import Flask, jsonify, request
import sqlite3
from contextlib import contextmanager, closing


@contextmanager
def get_db_conn():
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
    record = json.dumps(request.json)
    log.info("Recording %s", record)
    with get_db_conn() as conn:
        conn.execute("INSERT INTO audit (id, record) VALUES (NULL, ?)", (record,))
        conn.commit()
    return {}

@app.route("/audits", methods=["GET"])
def get_audits():
    with get_db_conn() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM audit")
        all_records = cursor.fetchall()
        return jsonify(all_records)

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    host = os.getenv("AUDIT_BIND", "0.0.0.0")
    port = int(os.getenv("PORT"))
    app.run(
        host=host,
        port=port,
        debug=True,
    )
