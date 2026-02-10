-module(rebar3_dependency_submission_options).
-moduledoc """
This module parses command line options.

This uses `getopt:parse/2`, while falling back to various `GITHUB_*` environment
variables. If any required options are missing `parse/1` will write error
messages to standard error and exit with a non-zero status code.
""".

-define(API, [
    parse/1,
    usage/0
]).
-export(?API).
-ignore_xref(?API).

-export_type([
    t/0
]).

-define(OPTIONS, [
    {help, $h, "help", boolean, "Show this help message"},

    {api_url, $a, "api-url", utf8_binary,
        "The URL for GitHub's API. Defaults to `$GITHUB_API_URL`, then \"https://api.github.com\"."},
    {attempt, $e, "attempt", utf8_binary,
        "The attempt number of the job. Defaults to `$GITHUB_RUN_ATTEMPT`, then `0`."},
    {correlator, $c, "correlator", utf8_binary,
        "The key used to group snapshots submitted over time. Defaults to `${GITHUB_WORKFLOW}_${GITHUB_JOB}`."},
    {html_url, $u, "html-url", utf8_binary,
        "The URL for the job. Defaults to the workflow run."},
    {ref, $r, "ref", utf8_binary,
        "The repository branch that triggered this snapshot. Defaults to `$GITHUB_REF`."},
    {repo, $p, "repo", utf8_binary,
        "The owner and repository name. Defaults to `$GITHUB_REPOSITORY`."},
    {run_id, $i, "run-id", utf8_binary,
        "The external ID of the job. Defaults to `$GITHUB_RUN_ID`."},
    {server_url, $u, "server-url", utf8_binary,
        "The URL for the GitHub server. Defaults to `$GITHUB_SERVER_URL`, then `https://github.com`."},
    {sha, $s, "sha", utf8_binary,
        "The commit SHA associated with this dependency snapshot. Maximum length: 40 characters. Defaults to `$GITHUB_SHA`."},
    {token, $t, "token", utf8_binary,
        "The token used to authenticate with GitHub. Defaults to `$GITHUB_TOKEN`."}
]).

-doc """
Represents the parsed options.
""".
-type t() :: #{
    api_url => uri_string:uri_map(),
    attempt => binary(),
    correlator => binary(),
    html_url => binary(),
    ref => binary(),
    repo => binary(),
    run_id => binary(),
    sha => binary(),
    token => binary()
}.

-doc """
Represents the non-option arguments left after parsing.
""".
-type arguments() :: [string()].

-doc """
Print usage information on standard error.
""".
-spec usage() -> ok.
usage() ->
    ScriptPath = escript:script_name(),
    Usage = getopt:usage_cmd_line(filename:basename(ScriptPath), ?OPTIONS),
    Options = getopt:usage_options(?OPTIONS),
    Help = rebar3_dependency_submission_common:format_markdown(
        "~ts\n\n~ts\n", [
            Usage, Options
        ]
    ),
    io:put_chars(standard_error, Help).

-doc """
Parse command line arguments.

Automatically handles `--help` flag and prints usage information on standard
error if any required options are missing.
""".
-spec parse([string()]) ->
    {ok, help} | {ok, t(), arguments()} | {error, term()}.
parse(CommandLineArguments) ->
    maybe
        {ok, {Options, Arguments}} ?=
            getopt:parse(?OPTIONS, CommandLineArguments),
        %% Return early on `help` to avoid printing "missing option"
        no_help ?= help(Options),
        %% We fetch first and then match to print all missing options and not
        %% just the first one
        MaybeApiUrl = api_url(Options),
        MaybeAttempt = attempt(Options),
        MaybeCorrelator = correlator(Options),
        MaybeRef = option(Options, ref, "GITHUB_REF"),
        MaybeRepo = option(Options, repo, "GITHUB_REPOSITORY"),
        MaybeRunId = option(Options, run_id, "GITHUB_RUN_ID"),
        MaybeSha = option(Options, sha, "GITHUB_SHA"),
        MaybeToken = option(Options, token, "GITHUB_TOKEN"),
        MaybeServerURL = server_url(Options),
        {ok, ApiUrl} ?= MaybeApiUrl,
        {ok, Correlator} ?= MaybeCorrelator,
        {ok, Ref} ?= MaybeRef,
        {ok, Repo} ?= MaybeRepo,
        {ok, RunId} ?= MaybeRunId,
        {ok, Sha} ?= MaybeSha,
        {ok, Token} ?= MaybeToken,
        {ok, Attempt} ?= MaybeAttempt,
        {ok, ServerURL} ?= MaybeServerURL,
        ParsedOptions = #{
            api_url => ApiUrl,
            attempt => Attempt,
            correlator => Correlator,
            html_url => html_url(Options, ServerURL, Repo),
            ref => Ref,
            repo => Repo,
            run_id => RunId,
            sha => Sha,
            token => Token
        },
        {ok, ParsedOptions, Arguments}
    else
        {error, {Reason, _} = Error} when is_atom(Reason) ->
            {error, getopt:format_error(?OPTIONS, Error)};
        Term ->
            Term
    end.

help(Options) ->
    case proplists:get_bool(help, Options) of
        true -> help;
        false -> no_help
    end.

attempt(Options) ->
    maybe
        {ok, undefined} ?= {ok, proplists:get_value(attempt, Options)},
        false ?= env("GITHUB_RUN_ATTEMPT"),
        {ok, 0}
    end.

server_url(Options) ->
    maybe
        {ok, undefined} ?= {ok, proplists:get_value(server_url, Options)},
        false ?= env("GITHUB_SERVER_URL"),
        {ok, ~"https://github.com"}
    end.

api_url(Options) ->
    maybe
        {ok, ApiUrl} ?=
            maybe
                {ok, undefined} ?= {ok, proplists:get_value(api_url, Options)},
                false ?= env("GITHUB_API_URL"),
                {ok, ~"https://api.github.com"}
            end,
        case uri_string:parse(ApiUrl) of
            ApiUrlMap when is_map(ApiUrlMap) ->
                {ok, ApiUrlMap};
            {error, Type, Reason} ->
                {error, {Type, Reason}}
        end
    end.

correlator(Options) ->
    maybe
        %% This may look a bit odd, but we use `maybe` in reverse so to speak.
        %% If it's none, then try the environment variables
        none ?= proplists:lookup(correlator, Options),
        {ok, Workflow} ?= env("GITHUB_WORKFLOW"),
        {ok, Job} ?= env("GITHUB_JOB"),
        {ok, <<Workflow/binary, "_", Job/binary>>}
    else
        {correlator, Value} ->
            {ok, rebar3_dependency_submission_common:to_binary(Value)};
        false ->
            rebar3_dependency_submission_github:error(
                "`--correlator`, `$GITHUB_WORKFLOW`, and/or `$GITHUB_JOB` are missing",
                []
            ),
            {error, missing}
    end.

html_url(Options, ServerURL, Repo) ->
    maybe
        undefined ?= proplists:get_value(html_url, Options),
        {ok, RunId} ?= env("GITHUB_RUN_ID"),
        <<ServerURL/binary, "/", Repo/binary, "/actions/runs/", RunId/binary>>
    else
        {html_url, Value} ->
            rebar3_dependency_submission_common:to_binary(Value);
        false ->
            null
    end.

option(Options, Flag, EnvironmentalVariable) ->
    maybe
        %% This may look a bit odd, but we use `maybe` in reverse so to speak.
        %% If it's none, then try the environment variable
        none ?= proplists:lookup(Flag, Options),
        {ok, _} ?= env(EnvironmentalVariable)
    else
        {Flag, Value} ->
            {ok, rebar3_dependency_submission_common:to_binary(Value)};
        false ->
            rebar3_dependency_submission_github:error(
                "`--~ts` and `$~ts` are missing", [
                    string:replace(atom_to_binary(Flag), "_", "-", all),
                    EnvironmentalVariable
                ]
            ),
            {error, missing}
    end.

env(EnvironmentalVariable) ->
    case os:getenv(EnvironmentalVariable) of
        false ->
            false;
        Value ->
            {ok, rebar3_dependency_submission_common:to_binary(Value)}
    end.
