%% SPDX-License-Identifier: Apache-2.0
%% SPDX-FileCopyrightText: 2026 Kivra AB
-module(rebar3_dependency_submission_options_tests).

-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% parse
%%--------------------------------------------------------------------

parse_help_test() ->
    ?assertEqual(help, rebar3_dependency_submission_options:parse(["--help"])).

parse_all_flags_test() ->
    Args = [
        "--token",
        "ghp_test123",
        "--sha",
        "abc123def456",
        "--ref",
        "refs/heads/main",
        "--repo",
        "erlef/rebar3-dependency-submission",
        "--run-id",
        "12345",
        "--correlator",
        "my_workflow_my_job",
        "--api-url",
        "https://api.github.com",
        "--attempt",
        "1"
    ],
    {ok, Options, []} = rebar3_dependency_submission_options:parse(Args),
    ?assertEqual(~"ghp_test123", maps:get(token, Options)),
    ?assertEqual(~"abc123def456", maps:get(sha, Options)),
    ?assertEqual(~"refs/heads/main", maps:get(ref, Options)),
    ?assertEqual(
        ~"erlef/rebar3-dependency-submission", maps:get(repo, Options)
    ),
    ?assertEqual(~"12345", maps:get(run_id, Options)),
    ?assertEqual(~"my_workflow_my_job", maps:get(correlator, Options)).

parse_missing_required_test() ->
    {error, missing} = rebar3_dependency_submission_options:parse([]).

parse_env_fallback_test() ->
    Envs = [
        {"GITHUB_TOKEN", "env_token"},
        {"GITHUB_SHA", "env_sha"},
        {"GITHUB_REF", "refs/heads/main"},
        {"GITHUB_REPOSITORY", "owner/repo"},
        {"GITHUB_RUN_ID", "999"},
        {"GITHUB_WORKFLOW", "ci"},
        {"GITHUB_JOB", "test"},
        {"GITHUB_RUN_ATTEMPT", "1"}
    ],
    try
        [os:putenv(K, V) || {K, V} <- Envs],
        {ok, Options, []} = rebar3_dependency_submission_options:parse([]),
        ?assertEqual(~"env_token", maps:get(token, Options)),
        ?assertEqual(~"env_sha", maps:get(sha, Options)),
        ?assertEqual(~"ci_test", maps:get(correlator, Options))
    after
        [os:unsetenv(K) || {K, _} <- Envs]
    end.

parse_cli_overrides_env_test() ->
    os:putenv("GITHUB_TOKEN", "env_token"),
    try
        Envs = [
            {"GITHUB_SHA", "env_sha"},
            {"GITHUB_REF", "refs/heads/main"},
            {"GITHUB_REPOSITORY", "owner/repo"},
            {"GITHUB_RUN_ID", "999"},
            {"GITHUB_WORKFLOW", "ci"},
            {"GITHUB_JOB", "test"},
            {"GITHUB_RUN_ATTEMPT", "1"}
        ],
        [os:putenv(K, V) || {K, V} <- Envs],
        {ok, Options, []} = rebar3_dependency_submission_options:parse([
            "--token", "cli_token"
        ]),
        ?assertEqual(~"cli_token", maps:get(token, Options))
    after
        os:unsetenv("GITHUB_TOKEN"),
        [
            os:unsetenv(K)
         || {K, _} <- [
                {"GITHUB_SHA", ""},
                {"GITHUB_REF", ""},
                {"GITHUB_REPOSITORY", ""},
                {"GITHUB_RUN_ID", ""},
                {"GITHUB_WORKFLOW", ""},
                {"GITHUB_JOB", ""},
                {"GITHUB_RUN_ATTEMPT", ""}
            ]
        ]
    end.
