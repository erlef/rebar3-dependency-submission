%% SPDX-License-Identifier: Apache-2.0
%% SPDX-FileCopyrightText: 2026 Kivra AB
-module(rebar3_dependency_submission).

%% API exports
-define(API, [main/1]).
-export(?API).
-ignore_xref(?API).

-include("rebar3_dependency_submission_internal.hrl").

%% escript Entry point
main(CommandLineArguments) ->
    maybe
        {ok, _} = application:ensure_all_started(rebar3_dependency_submission),
        ?log_debug("Version: ~s\n", [
            rebar3_dependency_submission_common:version()
        ]),
        {ok, Options, Arguments} ?=
            rebar3_dependency_submission_options:parse(CommandLineArguments),
        rebar3_dependency_submission_github:group("Generating snapshot"),
        ?log_debug("Options (without token): ~p\n", [
            maps:without([token], Options)
        ]),
        ?log_debug("Arguments: ~p\n", [Arguments]),
        ?log_debug("Current working directory: ~p\n", [
            element(2, file:get_cwd())
        ]),
        Snapshot = rebar3_dependency_submission_snapshot:new(Options),
        rebar3_dependency_submission_github:end_group(),
        rebar3_dependency_submission_github:group("Submitting snapshot"),
        ok ?= rebar3_dependency_submission_github:start(),
        {ok, #{status := Status, ~"result" := Result, ~"message" := Message}} ?=
            rebar3_dependency_submission_github:submit(Options, Snapshot),
        ?log_debug("Response ~s\n~s", [string:lowercase(Result), Message]),
        rebar3_dependency_submission_github:end_group(),
        case Status of
            201 -> erlang:halt(0);
            _ -> erlang:halt(1)
        end
    else
        help ->
            rebar3_dependency_submission_options:usage();
        {error, missing} ->
            %% Already printed message to standard error
            erlang:halt(1);
        {error, Reason} ->
            case is_binary(Reason) orelse io_lib:deep_char_list(Reason) of
                true ->
                    ?log_error("~ts\n", [Reason], #{title => "Error"});
                false ->
                    ?log_error("~tp\n", [Reason], #{title => "Error"})
            end,
            rebar3_dependency_submission_options:usage(),
            erlang:halt(1)
    end.
