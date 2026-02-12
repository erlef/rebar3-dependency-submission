%% SPDX-License-Identifier: Apache-2.0
%% SPDX-FileCopyrightText: 2026 Kivra AB
-module(rebar3_dependency_submission_common).

-define(API, [
    format_markdown/2,
    git_ls_files/1,
    to_binary/1,
    version/0,
    format_error/2
]).
-export(?API).
-ignore_xref(?API).

-include("rebar3_dependency_submission_internal.hrl").

-doc "`m:erl_error` callback.".
format_error(_, [{?MODULE, _Function, _Arguments, Info} | _StackTrace]) ->
    case proplists:get_value(error_info, Info, #{}) of
        #{cause := ErrorMap} when is_map(ErrorMap) ->
            maps:map(fun format_reason/2, ErrorMap);
        #{} ->
            #{}
    end.

-doc false.
format_reason(_Key, {Module, Function, Arguments}) when
    is_atom(Module) andalso is_atom(Function) andalso is_list(Arguments)
->
    to_list(apply(Module, Function, Arguments));
format_reason(_Key, Reason) ->
    Reason.

-doc """
Returns the given `t:unicode:chardata/0` as a UTF-8 encoded binary.

Unlike `unicode:characters_to_binary/1`, this function will raise an error if
the input is not valid or incomplete UTF-8.
""".
-spec to_binary(unicode:chardata()) -> binary().
to_binary(Chardata) ->
    case unicode:characters_to_binary(Chardata) of
        Binary when is_binary(Binary) ->
            Binary;
        {incomplete, _Encoded, _Rest} ->
            ?error(badarg, [Chardata], #{1 => "incomplete UTF-8"});
        {error, _Encoded, _Rest} ->
            ?error(badarg, [Chardata], #{1 => "invalid UTF-8"})
    end.

-doc """
Converts the given `t:unicode:chardata/0` to a list of characters.

Unlike `unicode:characters_to_list/1`, this function will raise an error if
the input is not valid or incomplete UTF-8.
""".
-spec to_list(unicode:chardata()) -> string().
to_list(Chardata) ->
    case unicode:characters_to_list(Chardata) of
        List when is_list(List) ->
            List;
        {incomplete, _Encoded, _Rest} ->
            ?error(badarg, [Chardata], #{1 => "incomplete UTF-8"});
        {error, _Encoded, _Rest} ->
            ?error(badarg, [Chardata], #{1 => "invalid UTF-8"})
    end.

version() ->
    {ok, PluginVsn} = application:get_key(rebar3_dependency_submission, vsn),
    PluginVsn.

-doc """
Executes `git ls-files` in the given `Directory` and returns the list of files.

This handles all filenames, including those with newlines.
""".
git_ls_files(Directory) ->
    Port = open_port({spawn_executable, os:find_executable("git")}, [
        stream,
        binary,
        hide,
        {args, ["ls-files", "--full-name", "-z"]},
        {cd, Directory}
    ]),
    MonitorRef = monitor(port, Port),
    GitFiles = read_nul_separated_files(Port, MonitorRef, <<>>, []),
    demonitor(MonitorRef),
    GitFiles.

-doc false.
read_nul_separated_files(Port, MonRef, LeftOver, Files) when is_port(Port) ->
    receive
        {Port, {data, Bytes}} ->
            case
                binary:split(<<LeftOver/binary, Bytes/binary>>, <<0>>, [global])
            of
                [File] ->
                    read_nul_separated_files(Port, MonRef, <<>>, [File | Files]);
                Files0 when is_list(Files0) ->
                    {Files1, [LeftOver]} = lists:split(
                        length(Files0) - 1, Files0
                    ),
                    read_nul_separated_files(Port, MonRef, LeftOver, [
                        Files1 | Files
                    ])
            end;
        {'DOWN', MonRef, _, _, _} ->
            lists:flatten(Files);
        Msg ->
            error({unknown, Msg})
    end.

-doc """
Markdown to ANSI escape sequences.

Currently only inline code gets converted to bold.
""".
format_markdown(Format, Args) ->
    Message0 = io_lib:format(Format, Args),
    Message1 = re:replace(Message0, "`([^`]+)`", "\e[1m\\1\e[0m", [global]),
    Message1.
