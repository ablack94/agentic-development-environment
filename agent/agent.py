import os
import subprocess
import logging
import json
from uuid import uuid4
from typing import Protocol, NewType
from flask import Flask, jsonify, request


log = logging.getLogger("main")


class AgentExecutor(Protocol):

    def prompt(self, prompt: str) -> str:
        """Prompt request/response from an agent."""

class ClaudeSubprocess(AgentExecutor):

    def __init__(self, claude_code_path: str = None) -> None:
        self._claude = claude_code_path or "/usr/local/bin/claude"
    
    def prompt(self, prompt: str) -> str:
        cmd = [
            self._claude,
            "--dangerously-skip-permissions",
            "-p",
            prompt,
        ]
        result = subprocess.check_output(cmd, stderr=subprocess.STDOUT, text=True)
        return result


app = Flask(__name__)
agent_executor = ClaudeSubprocess(os.getenv("AGENT_CLAUDE_CODE_PATH"))

@app.route("/command", methods=["POST"])
def command():
    prompt = json.dumps(request.json)
    log.info("Received prompt: %s", prompt)
    result = jsonify(agent_executor.prompt(prompt))
    log.info("Sending response: %s", result)
    return result

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    host = os.getenv("AGENT_BIND", "0.0.0.0")
    port = int(os.getenv("PORT", "8080"))
    log.info("Starting agent server.")
    app.run(
        host=host,
        port=port,
        debug=True,
    )
