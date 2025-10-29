-module(rds_rebar).

-export([
    consult/1,
    from/1,
    new/0
]).

-export([
    app/2,
    app_load/1,
    app_src/2,
    config_if_exists/1,
    hex_metadata/2,
    lock/2
]).

-export_type([
    t/0
]).

-include("internal.hrl").
-include("records.hrl").

-type t() :: #{
    applications := #{
        app_name() => vsn()
    },
    hex_metadata := #{
        package_name() => map()
    },
    lock_version := binary(),
    packages := #{
        package_name() => {version(), pos_integer()}
    },
    pkg_hash := #{
        package_name() => binary()
    },
    pkg_hash_ext := #{
        package_name() => binary()
    }
}.

-type app_name() :: atom().

-type package_name() :: atom().

-type version() :: #pkg{} | #git{} | #git_subdir{}.

-type vsn() :: binary().

new() ->
    #{
        applications => #{},
        hex_metadata => #{},
        lock_version => ~"",
        packages => #{},
        pkg_hash => #{},
        pkg_hash_ext => #{}
    }.

from(RebarLock) ->
    State0 = new(),
    State1 = #{packages := Packages} = lock(State0, RebarLock),
    State2 = lists:foldl(
        fun(App, InnerState0) ->
            hex_metadata(app(InnerState0, App), App)
        end,
        State1,
        maps:keys(Packages)
    ),
    State2.

hex_metadata(#{hex_metadata := Metadata} = State, App) when is_atom(App) ->
    Path = build_path(App, "hex_metadata.config"),
    case consult_if_exists(Path) of
        HexMetadata when is_list(HexMetadata) ->
            State#{hex_metadata := Metadata#{App => maps:from_list(HexMetadata)}};
        non_existing ->
            State
    end.

app(#{applications := Apps} = State0, App) ->
    maybe
        {app, non_existing} ?= {app, app_load(App)},
        AppSrcFile = extension(App, ".app.src"),
        false ?=
            lists:search(
                fun(Path) -> filename:basename(Path) =:= AppSrcFile end,
                rds_common:git_ls_files(".")
            ),
        AppSrcPattern = lists:concat(["_build/default/lib/", App, "/**/", AppSrcFile, "{,.script}"]),
        [PathAppSrc0 | _] ?= filelib:wildcard(AppSrcPattern),
        non_existing ?= app_src(State0, PathAppSrc0),
        ?error(enoent, [App, State0], #{reason => {file, format_error, [enoent]}})
    else
        {value, PathAppSrc1} ->
            app_src(State0, PathAppSrc1);
        [{application, _, AppManifest}] ->
            State0#{applications := Apps#{App => maps:from_list(AppManifest)}};
        PathApp when ?is_string(PathApp) ->
            [{application, _, AppManifest}] = consult(PathApp),
            State0#{applications := Apps#{App => maps:from_list(AppManifest)}};
        {app, AppManifest} when is_map(AppManifest) ->
            State0#{applications := Apps#{App => AppManifest}};
        State1 when is_map(State1) ->
            State1
    end.

app_load(App) ->
    _ = application:load(App),
    case application:get_all_key(App) of
        {ok, AppManifest} ->
            maps:from_list(AppManifest);
        undefined ->
            non_existing
    end.

app_src(#{applications := Apps} = State, Path) ->
    case filename:extension(Path) of
        ".src" ->
            maybe
                [{application, App, AppManifest0}] ?= consult_if_exists(Path),
                AppManifest1 = resolve_vsn(State, App, AppManifest0),
                {application, App, AppManifest2} = config_script(
                    Path, {application, App, AppManifest1}
                ),
                State#{applications := Apps#{App => maps:from_list(AppManifest2)}}
            end;
        ".script" ->
            maybe
                {application, App, AppManifest} ?= script_if_exists(Path, []),
                State#{applications := Apps#{App => maps:from_list(AppManifest)}}
            end
    end.

resolve_vsn(#{packages := Packages}, App, AppManifest0) ->
    Vsn = proplists:get_value(vsn, AppManifest0),
    AppName = atom_to_binary(App),
    case io_lib:char_list(Vsn) orelse Packages of
        #{AppName := {PackageVersion, _DepLevel}} ->
            Version = version(PackageVersion),
            lists:keystore(vsn, 1, AppManifest0, {vsn, Version});
        _ ->
            AppManifest0
    end.

-doc false.
version(#pkg{version = Version}) -> Version;
version(#git{ref = Ref}) -> ref_to_version(Ref);
version(#git_subdir{ref = Ref}) -> ref_to_version(Ref).

-doc false.
ref_to_version({tag, Tag}) -> Tag;
ref_to_version({branch, Branch}) -> Branch;
ref_to_version({ref, Commit}) -> Commit.

config_if_exists(App) when is_atom(App) ->
    config_if_exists_internal(build_path(App, "rebar.config"));
config_if_exists(PathRebarConfig) ->
    config_if_exists_internal(PathRebarConfig).

config_if_exists_internal(PathRebarConfig) ->
    case consult_if_exists(PathRebarConfig) of
        non_existing -> non_existing;
        CONFIG -> maps:from_list(config_script(PathRebarConfig, CONFIG))
    end.

-spec lock(t(), file:name_all()) -> t().
lock(State, PathRebarLock) ->
    [{LockVersion, Packages}, PackageHashes] = consult(PathRebarLock),
    PkgHash = proplists:get_value(pkg_hash, PackageHashes, []),
    PkgHashExt = proplists:get_value(pkg_hash_ext, PackageHashes, []),
    State#{
        lock_version := LockVersion,
        packages :=
            #{
                binary_to_atom(LocalName) => {Version, DepLevel}
             || {LocalName, Version, DepLevel} <- Packages
            },
        pkg_hash := maps:from_list(PkgHash),
        pkg_hash_ext := maps:from_list(PkgHashExt)
    }.

-doc """
A variant of `file:consult/1` that raises errors instead of returning them.

For interpretation errors it generates a synthetic frame for the file being
consulted. This should hopefully make it easier to track down any syntax errors
you may encounter.
""".
consult(File) ->
    case consult_if_exists(File) of
        non_existing ->
            ?error(enoent, [File], #{reason => {file, format_error, [enoent]}});
        Terms ->
            Terms
    end.

-doc """
Similar to `consult/1` except it returns `non_existing` instead of raising an error.
""".
-spec consult_if_exists(file:name_all()) -> [dynamic()] | non_existing.
consult_if_exists(File) ->
    case file:consult(File) of
        {ok, Terms} ->
            Terms;
        {error, enoent} ->
            non_existing;
        {error, enotdir} ->
            non_existing;
        {error, {Line, Module, Term}} when is_integer(Line) andalso is_atom(Module) ->
            erlang:raise(error, Term, [
                synthesize_frame(File, {Line, Module, Term}, [])
                | ?stacktrace([File])
            ]);
        {error, Reason} ->
            ?error(Reason, [File], #{reason => {file, format_error, [Reason]}})
    end.

config_script(Path, CONFIG0) ->
    SCRIPT = extension(Path, ".script"),
    Bindings = [{'CONFIG', CONFIG0}, {'SCRIPT', SCRIPT}],
    case script_if_exists(SCRIPT, Bindings) of
        non_existing -> CONFIG0;
        CONFIG1 -> CONFIG1
    end.

script_if_exists(Path, Bindings) ->
    case file:script(Path, Bindings) of
        {ok, Result} ->
            Result;
        {error, enoent} ->
            non_existing;
        {error, enotdir} ->
            non_existing;
        {error, {Line, Module, Term}} when is_integer(Line) andalso is_atom(Module) ->
            erlang:raise(error, Term, [
                synthesize_frame(Path, {Line, Module, Term}, Bindings)
                | ?stacktrace([Path, Bindings])
            ]);
        {error, Reason} ->
            ?error(Reason, [Path, Bindings], #{
                reason => {file, format_error, [Reason]}
            })
    end.

-doc """
Returns a synthetic stackframe for the given file and interpretation error.

See `file:consult/1` and `file:script/1` for more information.
""".
synthesize_frame(File, {Line, Module, Term}, Bindings) when
    is_integer(Line) andalso is_atom(Module)
->
    Basename = filename:basename(File),
    [FakeModule, FakeFunction] =
        case string:split(Basename, ".") of
            ["", Extension] -> [".", Extension];
            [Rootname, Extension] -> [Rootname, Extension]
        end,
    {list_to_atom(FakeModule), list_to_atom(FakeFunction), Bindings, [
        {line, Line},
        {file, File},
        #{
            cause => #{
                module => ?MODULE,
                reason => {Module, format_error, [Term]},
                general => "MFA is file:extension/bindings"
            }
        }
    ]}.

build_path(App, File) ->
    build_path(App, "", File).

build_path(App, Directory, File) ->
    filename:join(["_build", "default", "lib", App, Directory, File]).

extension(File, Extension) ->
    lists:concat([File, Extension]).
