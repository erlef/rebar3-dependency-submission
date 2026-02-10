# Try to keep consistent with .tool-versions
FROM erlang:28.3.1-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -qq git ca-certificates --no-install-recommends && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ARG workdir=/app
WORKDIR ${workdir}

# First copy only dependency descriptors to maximize Docker layer cache reuse
ENV NO_PLUGINS=1
COPY rebar.config rebar.lock ./

RUN git config --global --add safe.directory ${workdir} && \
    git config --global url."https://github.com/".insteadOf "git@github.com:"

RUN --mount=type=ssh \
    rebar3 compile --deps_only

COPY ./ .
RUN --mount=type=ssh \
    rebar3 escriptize && \
    cp _build/default/bin/rebar3_dependency_submission /usr/bin

ENTRYPOINT [ "/usr/bin/rebar3_dependency_submission" ]
