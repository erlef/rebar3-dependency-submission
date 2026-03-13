%% SPDX-License-Identifier: Apache-2.0
%% SPDX-FileCopyrightText: 2026 Kivra AB
-module(rebar3_dependency_submission_snapshot_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("purl/include/purl.hrl").
-include("rebar3_dependency_submission_records.hrl").

%%--------------------------------------------------------------------
%% to_purl
%%--------------------------------------------------------------------

to_purl_hex_test() ->
    Purl = rebar3_dependency_submission_snapshot:to_purl(
        #pkg{name = ~"cowboy", version = ~"2.12.0"}
    ),
    ?assertEqual(~"hex", Purl#purl.type),
    ?assertEqual(~"cowboy", Purl#purl.name),
    ?assertEqual(~"2.12.0", Purl#purl.version).

to_purl_git_test() ->
    Ref = "d64773d59dfd1d6b8920209f219e3c796c974a3a",
    Purl = rebar3_dependency_submission_snapshot:to_purl(
        #git{repo = "git@github.com:erlef/purl.git", ref = {ref, Ref}}
    ),
    ?assertEqual(~"github", Purl#purl.type),
    ?assertEqual(~"purl", Purl#purl.name).

to_purl_git_subdir_test() ->
    Ref = "049f80c4fb5990b682b23b1fde643103ec1e6dea",
    Purl = rebar3_dependency_submission_snapshot:to_purl(
        #git_subdir{
            repo = "git@github.com:erlang/rebar3.git",
            ref = {ref, Ref},
            subdir = "apps/rebar"
        }
    ),
    ?assertEqual(~"github", Purl#purl.type),
    ?assertEqual([~"apps", ~"rebar"], Purl#purl.subpath).

to_purl_git_tag_test() ->
    Purl = rebar3_dependency_submission_snapshot:to_purl(
        #git{repo = "git@github.com:erlef/purl.git", ref = {tag, "v1.0.0"}}
    ),
    ?assertEqual(~"github", Purl#purl.type),
    ?assertEqual(~"purl", Purl#purl.name),
    ?assertEqual(~"v1.0.0", Purl#purl.version).

to_purl_git_branch_test() ->
    Purl = rebar3_dependency_submission_snapshot:to_purl(
        #git{repo = "git@github.com:erlef/purl.git", ref = {branch, "main"}}
    ),
    ?assertEqual(~"github", Purl#purl.type),
    ?assertEqual(~"purl", Purl#purl.name),
    ?assertEqual(~"main", Purl#purl.version).

to_purl_git_subdir_tag_test() ->
    Purl = rebar3_dependency_submission_snapshot:to_purl(
        #git_subdir{
            repo = "git@github.com:erlang/rebar3.git",
            ref = {tag, "3.24.0"},
            subdir = "apps/rebar"
        }
    ),
    ?assertEqual(~"github", Purl#purl.type),
    ?assertEqual([~"apps", ~"rebar"], Purl#purl.subpath),
    ?assertEqual(~"3.24.0", Purl#purl.version).

%%--------------------------------------------------------------------
%% resolve_dependency
%%--------------------------------------------------------------------

resolve_dependency_direct_hex_test() ->
    State = #{
        runtime_dependencies => ordsets:from_list([cowboy]),
        hex_metadata => #{},
        pkg_hash => #{~"cowboy" => ~"AABB"},
        pkg_hash_ext => #{~"cowboy" => ~"CCDD"}
    },
    {Name, Resolved} = rebar3_dependency_submission_snapshot:resolve_dependency(
        cowboy, {#pkg{name = ~"cowboy", version = ~"2.12.0"}, 0}, State
    ),
    ?assertEqual(~"cowboy", Name),
    ?assertEqual(direct, maps:get(relationship, Resolved)),
    ?assertEqual(runtime, maps:get(scope, Resolved)),
    ?assertEqual(~"AABB", maps:get(pkg_hash, maps:get(metadata, Resolved))),
    ?assert(is_binary(maps:get(package_url, Resolved))).

resolve_dependency_indirect_dev_test() ->
    State = #{
        runtime_dependencies => ordsets:from_list([]),
        hex_metadata => #{},
        pkg_hash => #{},
        pkg_hash_ext => #{}
    },
    {_Name, Resolved} = rebar3_dependency_submission_snapshot:resolve_dependency(
        some_dep, {#pkg{name = ~"some_dep", version = ~"1.0.0"}, 1}, State
    ),
    ?assertEqual(indirect, maps:get(relationship, Resolved)),
    ?assertEqual(development, maps:get(scope, Resolved)).

resolve_dependency_with_hex_metadata_test() ->
    State = #{
        runtime_dependencies => ordsets:from_list([cowboy]),
        hex_metadata => #{
            cowboy => #{
                ~"requirements" => [{~"cowlib", []}, {~"ranch", []}]
            }
        },
        pkg_hash => #{},
        pkg_hash_ext => #{}
    },
    {_Name, Resolved} = rebar3_dependency_submission_snapshot:resolve_dependency(
        cowboy, {#pkg{name = ~"cowboy", version = ~"2.12.0"}, 0}, State
    ),
    ?assertEqual(
        [~"cowlib", ~"ranch"], lists:sort(maps:get(dependencies, Resolved))
    ).

%%--------------------------------------------------------------------
%% resolve_dependency: git_subdir uses local name, not repo name
%%--------------------------------------------------------------------

resolve_dependency_git_subdir_uses_local_name_test() ->
    Ref = "049f80c4fb5990b682b23b1fde643103ec1e6dea",
    State = #{
        runtime_dependencies => ordsets:from_list([auth]),
        hex_metadata => #{},
        pkg_hash => #{},
        pkg_hash_ext => #{}
    },
    {Name, Resolved} = rebar3_dependency_submission_snapshot:resolve_dependency(
        auth,
        {
            #git_subdir{
                repo = "git@github.com:org/monorepo.git",
                ref = {ref, Ref},
                subdir = "erlang/auth"
            },
            0
        },
        State
    ),
    %% The key should be the local name "auth", not the repo name "monorepo"
    ?assertEqual(~"auth", Name),
    ?assertEqual(direct, maps:get(relationship, Resolved)),
    ?assertEqual(runtime, maps:get(scope, Resolved)),
    %% package_url should contain the subpath
    PackageUrl = maps:get(package_url, Resolved),
    ?assertNotEqual(nomatch, string:find(PackageUrl, "erlang/auth")).

resolve_dependency_hex_uses_purl_name_test() ->
    State = #{
        runtime_dependencies => ordsets:from_list([cowboy]),
        hex_metadata => #{},
        pkg_hash => #{},
        pkg_hash_ext => #{}
    },
    {Name, _Resolved} = rebar3_dependency_submission_snapshot:resolve_dependency(
        cowboy, {#pkg{name = ~"cowboy", version = ~"2.12.0"}, 0}, State
    ),
    ?assertEqual(~"cowboy", Name).

resolve_dependency_git_uses_purl_name_test() ->
    Ref = "d64773d59dfd1d6b8920209f219e3c796c974a3a",
    State = #{
        runtime_dependencies => ordsets:from_list([purl]),
        hex_metadata => #{},
        pkg_hash => #{},
        pkg_hash_ext => #{}
    },
    {Name, _Resolved} = rebar3_dependency_submission_snapshot:resolve_dependency(
        purl,
        {#git{repo = "git@github.com:erlef/purl.git", ref = {ref, Ref}}, 0},
        State
    ),
    ?assertEqual(~"purl", Name).
