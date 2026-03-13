%% SPDX-License-Identifier: Apache-2.0
%% SPDX-FileCopyrightText: 2026 Kivra AB
-module(rebar3_dependency_submission_common_tests).

-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% to_binary
%%--------------------------------------------------------------------

to_binary_from_binary_test() ->
    ?assertEqual(
        ~"hello", rebar3_dependency_submission_common:to_binary(~"hello")
    ).

to_binary_from_list_test() ->
    ?assertEqual(
        ~"hello", rebar3_dependency_submission_common:to_binary("hello")
    ).

to_binary_from_iolist_test() ->
    ?assertEqual(
        ~"hello world",
        rebar3_dependency_submission_common:to_binary([~"hello", $\s, "world"])
    ).

to_binary_invalid_utf8_test() ->
    ?assertError(
        badarg, rebar3_dependency_submission_common:to_binary(<<255, 254>>)
    ).

%%--------------------------------------------------------------------
%% format_markdown
%%--------------------------------------------------------------------

format_markdown_no_backticks_test() ->
    Result = rebar3_dependency_submission_common:format_markdown("hello ~s", [
        "world"
    ]),
    ?assertEqual("hello world", lists:flatten(Result)).

format_markdown_with_backticks_test() ->
    Result = rebar3_dependency_submission_common:format_markdown(
        "`foo` bar", []
    ),
    Flat = unicode:characters_to_list(iolist_to_binary(Result)),
    ?assertNotEqual(nomatch, string:find(Flat, "foo")),
    %% Backticks should be replaced with ANSI bold
    ?assertEqual(nomatch, string:find(Flat, "`")).
