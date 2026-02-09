FROM erlang:28.2.0.0-slim

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -qq git --no-install-recommends && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    git config --global url."https://github.com/".insteadOf 'git@github.com:'

ARG workdir=/app
WORKDIR ${workdir}

ARG NO_PLUGINS=1
COPY ./ .
RUN rebar3 escriptize && \
    cp _build/default/bin/rebar_dependency_submission /usr/bin

ENTRYPOINT [ "/usr/bin/rebar_dependency_submission" ]
