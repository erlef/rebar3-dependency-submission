-module(rebar3_dependency_submission_snapshot).

-define(API, [
    new/1
]).
-export(?API).
-ignore_xref(?API).

-export_type([
    t/0
]).

-include("rebar3_dependency_submission_internal.hrl").
-include("rebar3_dependency_submission_records.hrl").

-type t() :: #{
    version := pos_integer(),
    job := #{
        id := binary(),
        correlator := binary()
    },
    sha := binary(),
    ref := binary(),
    detector := #{
        name := binary(),
        version := binary(),
        url := binary()
    },
    scanned := string() | binary(),
    manifests := #{
        file:filename_all() => #{
            name := binary(),
            file := #{
                source_location := binary()
            },
            metadata := map(),
            resolved := #{
                dependency() => #{
                    package_url := binary(),
                    metadata := map(),
                    relationship := direct | indirect,
                    scope := runtime | development,
                    dependencies := [dependency()]
                }
            }
        }
    }
}.

-type dependency() :: binary().

-doc """
Creates a snapshot of the dependency information currently available.

For best result run `rebar3 compile` before this
""".
-spec new(rebar3_dependency_submission_options:t()) -> t().
new(#{
    correlator := Correlator,
    ref := Ref,
    run_id := RunId,
    sha := Sha
}) ->
    PluginVsn = rebar3_dependency_submission_common:version(),
    {App, AppManifest} = app_src("."),
    #{
        version => 1,
        job => #{
            id => RunId,
            correlator => Correlator
        },
        sha => Sha,
        ref => Ref,
        detector => #{
            name => ~"rebar3",
            version => rebar3_dependency_submission_common:to_binary(PluginVsn),
            url => ~"https://github.com/kivra/rebar3-dependency-submission"
        },
        scanned => calendar:system_time_to_rfc3339(
            erlang:system_time(millisecond), [
                {offset, "Z"}, {unit, millisecond}, {return, binary}
            ]
        ),
        manifests =>
            (#{
                RebarLock => manifest(App, AppManifest, RebarLock)
             || RebarLock <- lock_files(".")
            })
    }.

manifest(App, AppManifest, RebarLock) ->
    Info = rebar3_dependency_submission_rebar3:from(RebarLock),
    State = Info#{
        runtime_dependencies => runtime_dependencies(Info, App, AppManifest)
    },
    #{
        name => ~"rebar.lock",
        file => #{
            source_location => RebarLock
        },
        metadata => #{
            lock_version => rebar3_dependency_submission_common:to_binary(
                maps:get(lock_version, State)
            )
        },
        resolved =>
            maps:from_list([
                resolve_dependency(LocalName, Package, State)
             || LocalName := Package <- maps:get(packages, State)
            ])
    }.

runtime_dependencies(#{applications := Applications}, App, AppManifest) ->
    RuntimeDependencies = maps:fold(
        fun application_dependency_graph/3, digraph:new([private]), Applications
    ),
    _ = application_dependency_graph(App, AppManifest, RuntimeDependencies),
    ordsets:from_list(
        digraph_utils:reachable([App], RuntimeDependencies)
    ).

application_dependency_graph(App, AppManifest, Graph) ->
    AppVertex = digraph:add_vertex(Graph, App),
    AddDependencyEdge = fun(RuntimeDependency) ->
        DependencyVertex = digraph:add_vertex(Graph, RuntimeDependency),
        digraph:add_edge(Graph, AppVertex, DependencyVertex)
    end,
    lists:foreach(AddDependencyEdge, maps:get(applications, AppManifest)),
    lists:foreach(
        AddDependencyEdge, maps:get(included_applications, AppManifest, [])
    ),
    lists:foreach(
        AddDependencyEdge, maps:get(optional_applications, AppManifest, [])
    ),
    Graph.

resolve_dependency(LocalName, {Version, DepLevel}, #{
    runtime_dependencies := RuntimeDependencies,
    hex_metadata := HexMetadata,
    pkg_hash := PkgHash,
    pkg_hash_ext := PkgHashExt
}) ->
    Purl = to_purl(Version),
    PackageName = atom_to_binary(LocalName),
    ResolvedDependency0 = #{
        package_url => rebar3_dependency_submission_common:to_binary(
            purl:to_binary(Purl)
        ),
        metadata => #{
            local_name => LocalName,
            package_name => PackageName,
            pkg_hash => maps:get(PackageName, PkgHash, null),
            pkg_hash_ext => maps:get(PackageName, PkgHashExt, null)
        },
        relationship =>
            case DepLevel of
                0 -> direct;
                _ -> indirect
            end,
        scope =>
            case
                ordsets:is_element(
                    LocalName, RuntimeDependencies
                )
            of
                true -> runtime;
                false -> development
            end
    },
    ResolvedDependency1 =
        case HexMetadata of
            #{LocalName := #{~"requirements" := Requirements}} when
                is_list(Requirements)
            ->
                ResolvedDependency0#{
                    dependencies => proplists:get_keys(Requirements)
                };
            #{} ->
                case
                    rebar3_dependency_submission_rebar3:config_if_exists(
                        LocalName
                    )
                of
                    #{deps := Deps} ->
                        ResolvedDependency0#{
                            dependencies => proplists:get_keys(Deps)
                        };
                    _ ->
                        ResolvedDependency0
                end
        end,
    {Purl#purl.name, ResolvedDependency1}.

to_purl(Version) ->
    case to_purl_internal(Version) of
        {ok, #purl{} = Purl} -> Purl;
        error -> ?error(badarg, [Version], #{1 => "can't convert to PURL"})
    end.

to_purl_internal(#pkg{name = Name, version = Version}) ->
    purl:from_resource_uri(
        <<"https://hex.pm/packages/", Name/binary, "/", Version/binary>>
    );
to_purl_internal(#git{repo = Repo, ref = {ref, Ref}}) ->
    purl:from_resource_uri(
        Repo, rebar3_dependency_submission_common:to_binary(Ref)
    );
to_purl_internal(#git_subdir{repo = Repo, ref = {ref, Ref}, subdir = SubPath0}) ->
    maybe
        SubPath1 = binary:split(
            rebar3_dependency_submission_common:to_binary(SubPath0), ~"/", [
                trim_all, global
            ]
        ),
        {ok, Purl} ?=
            purl:from_resource_uri(
                Repo, rebar3_dependency_submission_common:to_binary(Ref)
            ),
        {ok, Purl#purl{subpath = SubPath1}}
    end.

app_src(Directory) ->
    PathAppSrc =
        maybe
            [] ?= filelib:wildcard("src/*.app.src", Directory),
            false ?=
                lists:search(
                    fun ends_in_app_src/1,
                    rebar3_dependency_submission_common:git_ls_files(Directory)
                ),
            ?error(enoent, [Directory], #{
                reason => {file, format_error, [enoent]}
            })
        else
            {value, Path} -> Path;
            [Path] when ?is_string(Path) -> Path
        end,
    case code:where_is_file(filename:basename(PathAppSrc, ".src")) of
        non_existing ->
            #{applications := Applications} = rebar3_dependency_submission_rebar3:app_src(
                rebar3_dependency_submission_rebar3:new(), PathAppSrc
            ),
            {App, AppSrc, _Iterator} = maps:next(maps:iterator(Applications)),
            {App, AppSrc};
        PathApp when ?is_string(PathApp) ->
            App = list_to_atom(filename:basename(PathApp, ".app")),
            {App, rebar3_dependency_submission_rebar3:app_load(App)}
    end.

ends_in_app_src(PathAppSrc) ->
    string:find(PathAppSrc, ".app.src", trailing) =/= nomatch.

lock_files(Directory) ->
    [
        RebarLock
     || RebarLock <- rebar3_dependency_submission_common:git_ls_files(
            Directory
        ),
        filename:basename(RebarLock) =:= ~"rebar.lock"
    ].
