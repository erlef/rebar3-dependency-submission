%% SPDX-License-Identifier: Apache-2.0
%% SPDX-FileCopyrightText: 2026 Kivra AB
-module(rebar3_dependency_submission_rebar3_tests).

-include_lib("eunit/include/eunit.hrl").
-include("rebar3_dependency_submission_records.hrl").

fixture(Name) ->
    filename:join([
        code:lib_dir(rebar3_dependency_submission),
        "test",
        "fixtures",
        Name
    ]).

%%--------------------------------------------------------------------
%% lock parsing
%%--------------------------------------------------------------------

from_hex_only_test() ->
    State = rebar3_dependency_submission_rebar3:from(fixture("hex_only.lock")),
    #{
        lock_version := LockVersion,
        packages := Packages,
        pkg_hash := PkgHash,
        pkg_hash_ext := PkgHashExt
    } = State,
    ?assertEqual("1.2.0", LockVersion),
    ?assertEqual(3, map_size(Packages)),
    ?assertMatch(
        {#pkg{name = ~"cowboy", version = ~"2.12.0"}, 0},
        maps:get(cowboy, Packages)
    ),
    ?assertMatch(
        {#pkg{name = ~"cowlib", version = ~"2.13.0"}, 1},
        maps:get(cowlib, Packages)
    ),
    ?assertMatch(
        {#pkg{name = ~"ranch", version = ~"1.8.0"}, 1},
        maps:get(ranch, Packages)
    ),
    ?assertEqual(3, map_size(PkgHash)),
    ?assertEqual(3, map_size(PkgHashExt)).

from_mixed_test() ->
    State = rebar3_dependency_submission_rebar3:from(fixture("mixed.lock")),
    #{packages := Packages} = State,
    ?assertEqual(5, map_size(Packages)),
    ?assertMatch(
        {#git{repo = "git@github.com:erlef/purl.git", ref = {ref, _}}, 0},
        maps:get(purl, Packages)
    ),
    ?assertMatch(
        {
            #git_subdir{
                repo = "git@github.com:erlang/rebar3.git",
                ref = {ref, _},
                subdir = "apps/rebar"
            },
            0
        },
        maps:get(rebar, Packages)
    ).

from_empty_lock_test() ->
    State = rebar3_dependency_submission_rebar3:from(fixture("empty.lock")),
    #{packages := Packages, lock_version := LockVersion} = State,
    ?assertEqual(0, map_size(Packages)),
    ?assertEqual(~"", LockVersion).

from_nonexistent_file_test() ->
    ?assertError(
        enoent,
        rebar3_dependency_submission_rebar3:from("/nonexistent/rebar.lock")
    ).

%%--------------------------------------------------------------------
%% version extraction
%%--------------------------------------------------------------------

version_pkg_test() ->
    ?assertEqual(
        ~"2.12.0",
        rebar3_dependency_submission_rebar3:version(
            #pkg{name = ~"cowboy", version = ~"2.12.0"}
        )
    ).

version_git_tag_test() ->
    ?assertEqual(
        ~"v1.0.0",
        rebar3_dependency_submission_rebar3:version(
            #git{repo = "repo", ref = {tag, ~"v1.0.0"}}
        )
    ).

version_git_branch_test() ->
    ?assertEqual(
        ~"main",
        rebar3_dependency_submission_rebar3:version(
            #git{repo = "repo", ref = {branch, ~"main"}}
        )
    ).

version_git_ref_test() ->
    ?assertEqual(
        ~"abc123",
        rebar3_dependency_submission_rebar3:version(
            #git{repo = "repo", ref = {ref, ~"abc123"}}
        )
    ).

version_git_subdir_test() ->
    ?assertEqual(
        ~"v2.0.0",
        rebar3_dependency_submission_rebar3:version(
            #git_subdir{
                repo = "repo", ref = {tag, ~"v2.0.0"}, subdir = "apps/foo"
            }
        )
    ).

%%--------------------------------------------------------------------
%% consult
%%--------------------------------------------------------------------

consult_nonexistent_test() ->
    ?assertError(
        enoent,
        rebar3_dependency_submission_rebar3:consult("/does/not/exist.config")
    ).

consult_valid_file_test() ->
    Result = rebar3_dependency_submission_rebar3:consult(
        fixture("hex_only.lock")
    ),
    ?assertMatch([{"1.2.0", _} | _], Result).
