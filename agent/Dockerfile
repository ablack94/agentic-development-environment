FROM ubuntu:noble

RUN apt-get update -y \
 && apt-get install -y \
      make \
      git \
      golang-go \
      python3 \
      python3-pip \
      python3-flask \
 && apt-get clean

COPY --from=ghcr.io/ablack94/docker-claude:stable /usr/local/bin/claude /usr/local/bin/claude

WORKDIR /build

RUN git clone https://gitea.com/gitea/gitea-mcp.git \
 && make -C gitea-mcp install \
 && cp gitea-mcp/gitea-mcp /usr/local/bin/

USER ubuntu
WORKDIR /workarea

COPY agent.py /agent.py

RUN mkdir -p /home/ubuntu/.claude/hooks
COPY --chmod=0755 --chown=ubuntu:ubuntu audit.py /home/ubuntu/.claude/hooks/audit.py
COPY --chown=ubuntu:ubuntu settings.json /home/ubuntu/.claude/settings.json

COPY --chmod=0755 ./entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["python3", "/agent.py"]
