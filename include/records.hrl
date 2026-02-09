-include_lib("purl/include/purl.hrl").

%% Copied from rebar.hrl to avoid circular dependencies
-record(resource, {
    type :: atom(),
    module :: module(),
    state :: term(),
    implementation :: rebar_resource | rebar_resource_v2
}).

-record(pkg, {
    name :: binary(),
    version :: binary()
}).

-record(git, {
    repo :: string(),
    ref :: {ref, string()} | {tag, string()} | {branch, string()}
}).

-record(git_subdir, {
    repo :: string(),
    ref :: {ref, string()} | {tag, string()} | {branch, string()},
    subdir :: file:filename()
}).
