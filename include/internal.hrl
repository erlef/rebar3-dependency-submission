%% Returns the current stacktrace with the given arguments in the current frame.
-define(stacktrace(Arguments), [
    {?MODULE, ?FUNCTION_NAME, Arguments}
    | erlang:tl(
        erlang:element(
            2,
            {current_stacktrace, _} =
                erlang:process_info(erlang:self(), current_stacktrace)
        )
    )
]).

%% Returns the current stacktrace with the given arguments and cause in the current frame.
%%
%% The `error_info` module is hardcoded to `rds_common`.
-define(stacktrace(Arguments, Cause), [
    {?MODULE, ?FUNCTION_NAME, Arguments, [{error_info, #{module => rds_common, cause => Cause}}]}
    | erlang:tl(
        erlang:element(
            2,
            {current_stacktrace, _} =
                erlang:process_info(erlang:self(), current_stacktrace)
        )
    )
]).

%% Raises an `error` with the given reason.
%%
%% The given arguments and cause are added to the stacktrace, see `m:erl_error`.
%% In addition the error formatting module is set to `m:rds_common`.
-define(error(Reason, Arguments, Cause),
    erlang:error(Reason, Arguments, [
        {error_info, #{module => rds_common, cause => Cause}}
    ])
).

%% Returns true if the given term is an Erlang string, aka a list of codepoints.
%%
%% Can be used in both guards and normal expressions.
-define(is_string(Term), (Term =:= "" orelse (is_list(Term) and is_integer(hd(Term))))).

%% Debug macro that prints the given expression and its value, then returns the
%% value. It only evaluates the given expression once.
-define(inspect(Expression), begin
    (fun(Y__Value) ->
        io:format(standard_error, "~s = ~tp\n", [??Expression, Y__Value]),
        Y__Value
    end)(
        Expression
    )
end).

-define(log_debug(Format, Args),
    rds_github:debug(Format, Args)
).

-define(log_notice(Format, Args),
    rds_github:notice(Format, Args, #{
        file => ?FILE,
        line => ?LINE,
        endLine => ?LINE
    })
).

-define(log_notice(Format, Args, Parameters),
    rds_github:notice(
        Format,
        Args,
        maps:merge(
            #{
                file => ?FILE,
                line => ?LINE,
                endLine => ?LINE
            },
            Parameters
        )
    )
).

-define(log_warning(Format, Args),
    rds_github:warning(Format, Args, #{
        file => ?FILE,
        line => ?LINE,
        endLine => ?LINE
    })
).

-define(log_warning(Format, Args, Parameters),
    rds_github:warning(
        Format,
        Args,
        maps:merge(
            #{
                file => ?FILE,
                line => ?LINE,
                endLine => ?LINE
            },
            Parameters
        )
    )
).

-define(log_error(Format, Args),
    rds_github:error(Format, Args, #{
        file => ?FILE,
        line => ?LINE,
        endLine => ?LINE
    })
).

-define(log_error(Format, Args, Parameters),
    rds_github:error(
        Format,
        Args,
        maps:merge(
            #{
                file => ?FILE,
                line => ?LINE,
                endLine => ?LINE
            },
            Parameters
        )
    )
).
