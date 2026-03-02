#!/usr/bin/env python3
import sys
import os
import json
import datetime as dt
import urllib.request

def main() -> None:
    # Read config
    agent_id = os.getenv("AGENT_ID")
    audit_url = os.getenv("AGENT_AUDIT_URL")

    # Build audit record
    event = json.load(sys.stdin)
    agent_id = os.getenv("AGENT_ID")
    now = dt.datetime.now(dt.timezone.utc)
    audit_record = {
        "agent_id": agent_id,
        "time": now.isoformat(),
        "type": "hook",
        "event": event,
    }
    
    # Publish
    data = json.dumps(audit_record).encode("utf-8")
    req = urllib.request.Request(
        audit_url,
        data=data,
        headers={"Content-Type": "application/json"})
    urllib.request.urlopen(req)

if __name__ == "__main__":
    main()
