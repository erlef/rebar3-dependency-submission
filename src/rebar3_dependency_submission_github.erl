%% SPDX-License-Identifier: Apache-2.0
%% SPDX-FileCopyrightText: 2026 Kivra AB
-module(rebar3_dependency_submission_github).
-compile({no_auto_import, [error/3]}).

-define(API, [
    notice/2,
    notice/3,
    warning/2,
    warning/3,
    start/0,
    submit/2,
    debug/2,
    end_group/0,
    error/2,
    error/3,
    group/1
]).
-export(?API).
-ignore_xref(?API).

-include("rebar3_dependency_submission_internal.hrl").

start() ->
    %% Use Mozilla CA store (Rebar3 does this too)
    ok = application:set_env(public_key, cacerts_path, certifi:cacertfile()),
    public_key:cacerts_clear(),
    public_key:cacerts_load().

-spec submit(
    rebar3_dependency_submission_options:t(),
    rebar3_dependency_submission_snapshot:t()
) -> {ok, Result} | {error, term()} when
    Result :: #{status := integer(), binary() => binary()}.
submit(#{token := Token} = Flags, Snapshot) ->
    URL = api_url(Flags),
    Headers = [
        {"Accept", ~"application/vnd.github+json"},
        {"Authorization", [~"Bearer ", Token]},
        {"User-Agent", [
            ~"rebar3-dependency-submission/",
            rebar3_dependency_submission_common:version()
        ]},
        {"X-GitHub-Api-Version", ~"2022-11-28"}
    ],
    Body = json:encode(Snapshot),
    Request = {URL, Headers, "application/json", Body},
    HttpOptions = [
        {timeout, timer:seconds(30)}
    ],
    Options = [
        {body_format, binary},
        {full_result, false}
    ],
    case httpc:request(post, Request, HttpOptions, Options) of
        {ok, {Status, Response}} when
            200 =< Status andalso Status < 300 andalso is_binary(Response)
        ->
            maybe
                {ok, JSON} ?= decode(Response),
                {ok, JSON#{status => Status}}
            end;
        {ok, {Status, Response}} when
            is_integer(Status) andalso is_binary(Response)
        ->
            maybe
                {ok, #{~"message" := Message}} ?= decode(Response),
                {error, <<
                    (integer_to_binary(Status))/binary, " ", Message/binary
                >>}
            else
                {ok, JSON} -> {error, {Status, JSON}};
                {error, _JSONDecodeError} -> {error, {Status, Response}}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

api_url(#{api_url := ApiUrl, repo := RepoOwner} = Flags) ->
    case
        uri_string:recompose(ApiUrl#{
            path := ["/repos/", RepoOwner, "/dependency-graph/snapshots"]
        })
    of
        {error, Reason, _} -> ?error(Reason, [Flags], #{});
        URL -> URL
    end.

decode(JSONString) ->
    try json:decode(JSONString) of
        JSON when is_map(JSON) -> {ok, JSON}
    catch
        error:Reason -> {error, Reason}
    end.

-doc """
Prints a debug message to standard_error.

See https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#setting-a-debug-message
""".
debug(Format, Args) ->
    case os:getenv("RUNNER_DEBUG") of
        false -> ok;
        _ -> log(debug, Format, Args, #{})
    end.

-doc #{equiv => notice(Format, Args, #{})}.
notice(Format, Args) ->
    notice(Format, Args, #{}).

-doc """
Prints a notice message to standard_error.

See https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#setting-a-notice-message
""".
notice(Format, Args, Location) ->
    log(notice, Format, Args, Location).

-doc #{equiv => notice(Format, Args, #{})}.
warning(Format, Args) ->
    warning(Format, Args, #{}).

-doc """
Prints a warning message to standard_error.

See https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#setting-a-warning-message
""".
warning(Format, Args, Location) ->
    log(warning, Format, Args, Location).

-doc #{equiv => warning(Format, Args, #{})}.
error(Format, Args) ->
    error(Format, Args, #{}).

-doc """
Prints an error message to standard_error.

See https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#setting-an-error-message
""".
error(Format, Args, Location) ->
    log(error, Format, Args, Location).

-doc """
Logs the given message to the standard out.

The message is formatted using the given format string and arguments, and then
highlighted using ANSI escape codes for bold text. The formatted message is
written to the standard out followed by a newline character.
""".
-spec log(Severity, io:format(), [term()], map()) -> ok when
    Severity :: error | warning | notice | debug.
log(Severity, Format, Args, Metadata) ->
    workflow_command(Severity, Metadata, Format, Args).

-doc """
Creates an expandable group of in the log on GitHub.

See https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#grouping-log-lines
""".
group(Title) ->
    workflow_command(group, #{}, "~ts", [Title]).

-doc """
Ends an expandable group of in the log on GitHub.

See https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#grouping-log-lines
""".
end_group() ->
    workflow_command(endgroup, #{}, "", []).

-doc false.
workflow_command(Type, Parameters, Format, Args) when
    is_atom(Type) andalso is_map(Parameters)
->
    Message =
        case os:getenv("GITHUB_ACTIONS") of
            false ->
                [
                    rebar3_dependency_submission_common:format_markdown(
                        Format, Args
                    ),
                    $\n
                ];
            _ ->
                format_command(Type, Parameters, Format, Args)
        end,
    io:put_chars(standard_io, Message).

-doc false.
format_command(Type, Parameters, Format, Args) when
    is_atom(Type) andalso map_size(Parameters) =:= 0
->
    io_lib:format("::~ts::~ts\n", [
        Type, rebar3_dependency_submission_common:format_markdown(Format, Args)
    ]);
format_command(Type, Parameters, Format, Args) when
    is_atom(Type) andalso is_map(Parameters)
->
    Extra = string:join(maps:fold(fun format_parameter/3, [], Parameters), ","),
    io_lib:format("::~ts ~ts::~ts\n", [
        Type,
        Extra,
        rebar3_dependency_submission_common:format_markdown(Format, Args)
    ]).

-doc false.
format_parameter(Parameter, Value, Extra) ->
    [io_lib:format("~ts=~tp", [Parameter, Value]) | Extra].
