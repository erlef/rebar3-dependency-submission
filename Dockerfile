# Try to keep consistent with .tool-versions
FROM erlang:28.3.1-slim

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -qq git ca-certificates --no-install-recommends && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ARG workdir=/app
WORKDIR ${workdir}

ARG NO_PLUGINS=1
COPY ./ .
RUN --mount=type=ssh git config --global url."https://github.com/".insteadOf "git@github.com:" && \
    rebar3 escriptize && \
    cp _build/default/bin/rebar3_dependency_submission /usr/bin

ENTRYPOINT [ "/usr/bin/rebar3_dependency_submission" ]
