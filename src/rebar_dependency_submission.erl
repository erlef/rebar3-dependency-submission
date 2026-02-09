-module(rebar_dependency_submission).

%% API exports
-export([main/1]).

-include("internal.hrl").

%% escript Entry point
main(CommandLineArguments) ->
    maybe
        {ok, _} = application:ensure_all_started(rebar_dependency_submission),
        ?log_debug("Version: ~s\n", [rds_common:version()]),
        {ok, Options, Arguments} ?= rds_options:parse(CommandLineArguments),
        rds_github:group("Generating snapshot"),
        ?log_debug("Options (without token): ~p\n", [maps:without([token], Options)]),
        ?log_debug("Arguments: ~p\n", [Arguments]),
        ?log_debug("Current working directory: ~p\n", [element(2, file:get_cwd())]),
        Snapshot = rds_snapshot:new(Options),
        rds_github:end_group(),
        rds_github:group("Submitting snapshot"),
        ok ?= rds_github:start(),
        {ok, #{status := Status, ~"result" := Result, ~"message" := Message}} ?=
            rds_github:submit(Options, Snapshot),
        ?log_debug("Response ~s\n~s", [string:lowercase(Result), Message]),
        rds_github:end_group(),
        case Status of
            201 -> erlang:halt(0);
            _ -> erlang:halt(1)
        end
    else
        help ->
            rds_options:usage();
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
            rds_options:usage(),
            erlang:halt(1)
    end.
