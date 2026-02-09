FROM erlang:28.2.0.0-slim

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -qq git
RUN git config --global url."https://github.com/".insteadOf 'git@github.com:'

ARG workdir=/app
WORKDIR ${workdir}

ARG NO_PLUGINS=1
COPY rebar.* .
RUN rebar3 get-deps
RUN rebar3 compile --deps_only

COPY ./ .
RUN rebar3 escriptize && cp _build/default/bin/rds /usr/bin

ENTRYPOINT [ "/usr/bin/rds" ]
