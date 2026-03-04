FROM ubuntu:noble

RUN apt-get update -y \
 && apt-get install -y \
      build-essential \
      make \
      git \
      golang-go \
      python3 \
      python3-pip \
      python3-flask \
 && apt-get clean

# Fetch claude
COPY --from=ghcr.io/ablack94/docker-claude:stable /usr/local/bin/claude /usr/local/bin/claude
 
USER ubuntu

# Setup go
run mkdir /home/ubuntu/go
ENV GOPATH=/home/ubuntu/go
ENV PATH=${GOPATH}/bin:${PATH}

# Install rust
ENV CARGO_HOME=/home/${USER}/.cargo
ENV RUSTUP_HOME=/home/${USER}/.rustup
ENV PATH=${CARGO_HOME}/bin:${PATH}
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Build gitea
WORKDIR /build
RUN git clone https://gitea.com/gitea/gitea-mcp.git \
 && GOBIN="$PWD" make -C gitea-mcp install

# Agent application setup
WORKDIR /workarea

COPY agent.py /agent.py

RUN mkdir -p /home/ubuntu/.claude/hooks
COPY --chmod=0755 --chown=ubuntu:ubuntu audit.py /home/ubuntu/.claude/hooks/audit.py
COPY --chown=ubuntu:ubuntu settings.json /home/ubuntu/.claude/settings.json

COPY --chmod=0755 ./entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["python3", "/agent.py"]
