%% Copyright (c) 2017-2020 Guilherme Andrade
%%
%% Permission is hereby granted, free of charge, to any person obtaining a
%% copy  of this software and associated documentation files (the "Software"),
%% to deal in the Software without restriction, including without limitation
%% the rights to use, copy, modify, merge, publish, distribute, sublicense,
%% and/or sell copies of the Software, and to permit persons to whom the
%% Software is furnished to do so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
%% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
%% DEALINGS IN THE SOFTWARE.
%%
%% locus is an independent project and has not been authorized, sponsored,
%% or otherwise approved by MaxMind.

-module(locus).

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([start_loader/2]).                -ignore_xref({start_loader,2}).
-export([start_loader/3]).                -ignore_xref({start_loader,3}).
-export([stop_loader/1]).                 -ignore_xref({stop_loader,1}).
-export([loader_child_spec/2]).           -ignore_xref({loader_child_spec,2}).
-export([loader_child_spec/3]).           -ignore_xref({loader_child_spec,3}).
-export([loader_child_spec/4]).           -ignore_xref({loader_child_spec,4}).
-export([wait_for_loader/1]).             -ignore_xref({wait_for_loader,1}).
-export([wait_for_loader/2]).             -ignore_xref({wait_for_loader,2}).
-export([wait_for_loaders/2]).            -ignore_xref({wait_for_loaders,2}).
-export([lookup/2]).                      -ignore_xref({lookup,2}).
-export([get_version/1]).                 -ignore_xref({get_version,1}).
-export([get_info/1]).                    -ignore_xref({get_info,1}).
-export([get_info/2]).                    -ignore_xref({get_info,2}).
-export([analyze/1]).                     -ignore_xref({analyze,1}).

-deprecated([{get_version,1,eventually}]).

-ifdef(TEST).
-export([parse_database_edition/1]).
-endif.

%% ------------------------------------------------------------------
%% CLI-only Function Exports
%% ------------------------------------------------------------------

-ifdef(ESCRIPTIZING).
-export([main/1]).                        -ignore_xref({main,1}).
-endif.

%% ------------------------------------------------------------------
%% Type Definitions
%% ------------------------------------------------------------------

-define(might_be_chardata(V), (is_binary((V)) orelse ?is_proper_list((V)))).
-define(is_proper_list(V), (length((V)) >= 0)).

%% ------------------------------------------------------------------
%% Type Definitions
%% ------------------------------------------------------------------

-type database_edition() :: atom().
-export_type([database_edition/0]).

-type database_url() :: unicode:chardata().
-export_type([database_url/0]).

-type database_error() :: database_unknown | database_not_loaded.
-export_type([database_error/0]).

-type database_entry() :: locus_mmdb:lookup_success().
-export_type([database_entry/0]).

-type ip_address_prefix() :: locus_mmdb:ip_address_prefix().
-export_type([ip_address_prefix/0]).

-type database_info() ::
    #{ metadata := database_metadata(),
       source := database_source(),
       version := database_version()
     }.
-export_type([database_info/0]).

-type database_metadata() :: locus_mmdb:metadata().
-export_type([database_metadata/0]).

-type database_source() :: locus_loader:source().
-export_type([database_source/0]).

-type database_version() :: calendar:datetime().
-export_type([database_version/0]).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

%% @doc Like `:start_loader/3' but with default options
%%
%% <ul>
%% <li>`DatabaseId' must be an atom.</li>
%% <li>`DatabaseEdition' must be an atom; alternatively, `DatabaseURL'
%% must be a string or a binary representing a HTTP(s) URL or local path.</li>
%% </ul>
%%
%% Returns:
%% <ul>
%% <li>`ok' in case of success.</li>
%% <li>`{error, invalid_url}' if the source is invalid.</li>
%% <li>`{error, already_started}' if the loader under `DatabaseId' has already been started.</li>
%% </ul>
%% @see wait_for_loader/1
%% @see wait_for_loader/2
%% @see start_loader/1
%% @see start_loader/3
-spec start_loader(DatabaseId, DatabaseEdition | DatabaseURL) -> ok | {error, Error}
            when DatabaseId :: atom(),
                 DatabaseEdition :: database_edition(),
                 DatabaseURL :: database_url(),
                 Error :: invalid_url | already_started | application_not_running.
start_loader(DatabaseId, DatabaseEditionOrURL) ->
    start_loader(DatabaseId, DatabaseEditionOrURL, []).

%% @doc Starts a database loader under id `DatabaseId' with options `Opts'.
%%
%% <ul>
%% <li>`DatabaseId' must be an atom.</li>
%% <li>`DatabaseEdition' must be an atom; alternatively, `DatabaseURL'
%% must be a string or a binary representing a HTTP(s) URL or local path.</li>
%% <li>`Opts' must be a list of `locus_database:opt()' values</li>
%% </ul>
%%
%% Returns:
%% <ul>
%% <li>`ok' in case of success.</li>
%% <li>`{error, invalid_url}' if the source is invalid.</li>
%% <li>`{error, already_started}' if the loader under `DatabaseId' has already been started.</li>
%% </ul>
%% @see wait_for_loader/1
%% @see wait_for_loader/2
%% @see start_loader/1
%% @see start_loader/2
-spec start_loader(DatabaseId, DatabaseEdition | DatabaseURL, Opts) -> ok | {error, Error}
            when DatabaseId :: atom(),
                 DatabaseEdition :: database_edition(),
                 DatabaseURL :: database_url(),
                 Opts :: [locus_database:opt()],
                 Error :: (invalid_url | already_started |
                           {invalid_opt,term()} | application_not_running).
start_loader(DatabaseId, DatabaseEdition, Opts)
  when is_atom(DatabaseEdition) ->
    Origin = parse_database_edition(DatabaseEdition),
    OptsWithDefaults = opts_with_defaults(Opts),
    locus_database:start(DatabaseId, Origin, OptsWithDefaults);
start_loader(DatabaseId, DatabaseURL, Opts)
  when ?might_be_chardata(DatabaseURL) ->
    case parse_url(DatabaseURL) of
        false ->
            {error, invalid_url};
        Origin ->
            OptsWithDefaults = opts_with_defaults(Opts),
            locus_database:start(DatabaseId, Origin, OptsWithDefaults)
    end.

%% @doc Stops the database loader under id `DatabaseId'.
%%
%% <ul>
%% <li>`DatabaseId' must be an atom and refer to a database loader.</li>
%% </ul>
%%
%% Returns `ok' in case of success, `{error, not_found}' otherwise.
-spec stop_loader(DatabaseId) -> ok | {error, Error}
            when DatabaseId :: atom(),
                 Error :: not_found.
stop_loader(DatabaseId) ->
    locus_database:stop(DatabaseId).

%% @doc Like `:loader_child_spec/2' but with default options
%%
%% <ul>
%% <li>`DatabaseId' must be an atom.</li>
%% <li>`DatabaseEdition' must be an atom; alternatively, `DatabaseURL'
%% must be a string or a binary representing a HTTP(s) URL or local path.</li>
%% </ul>
%%
%% Returns:
%% <ul>
%% <li>A `supervisor:child_spec()'.</li>
%% </ul>
%% @see loader_child_spec/1
%% @see loader_child_spec/3
%% @see wait_for_loader/1
%% @see wait_for_loader/2
%% @see start_loader/2
-spec loader_child_spec(DatabaseId, DatabaseEdition | DatabaseURL) -> ChildSpec | no_return()
            when DatabaseId :: atom(),
                 DatabaseEdition :: database_edition(),
                 DatabaseURL :: database_url(),
                 ChildSpec :: locus_database:static_child_spec().
loader_child_spec(DatabaseId, DatabaseEditionOrURL) ->
    loader_child_spec(DatabaseId, DatabaseEditionOrURL, []).

%% @doc Like `:loader_child_spec/3' but with default child id
%%
%% <ul>
%% <li>`DatabaseId' must be an atom.</li>
%% <li>`DatabaseEdition' must be an atom; alternatively, `DatabaseURL'
%% must be a string or a binary representing a HTTP(s) URL or local path.</li>
%% <li>`Opts' must be a list of `locus_database:opt()' values</li>
%% </ul>
%%
%% Returns:
%% <ul>
%% <li>A `supervisor:child_spec()'.</li>
%% </ul>
%% @see loader_child_spec/3
%% @see loader_child_spec/4
%% @see wait_for_loader/1
%% @see wait_for_loader/2
%% @see start_loader/3
-spec loader_child_spec(DatabaseId, DatabaseEdition | DatabaseURL, Opts) -> ChildSpec | no_return()
            when DatabaseId :: atom(),
                 DatabaseEdition :: database_edition(),
                 DatabaseURL :: database_url(),
                 Opts :: [locus_database:opt()],
                 ChildSpec :: locus_database:static_child_spec().
loader_child_spec(DatabaseId, DatabaseEditionOrURL, Opts) ->
    loader_child_spec({locus_database,DatabaseId}, DatabaseId, DatabaseEditionOrURL, Opts).

%% @doc Returns a supervisor child spec for a database loader under id `DatabaseId' with options `Opts'.
%%
%% <ul>
%% <li>`DatabaseId' must be an atom.</li>
%% <li>`DatabaseEdition' must be an atom; alternatively, `DatabaseURL'
%% must be a string or a binary representing a HTTP(s) URL or local path.</li>
%% <li>`Opts' must be a list of `locus_database:opt()' values</li>
%% </ul>
%%
%% Returns:
%% <ul>
%% <li>A `supervisor:child_spec()'.</li>
%% </ul>
%% @see loader_child_spec/3
%% @see wait_for_loader/1
%% @see wait_for_loader/2
%% @see start_loader/3
-spec loader_child_spec(ChildId, DatabaseId, DatabaseEdition | DatabaseURL, Opts)
        -> ChildSpec | no_return()
            when ChildId :: term(),
                 DatabaseId :: atom(),
                 DatabaseEdition :: database_edition(),
                 DatabaseURL :: database_url(),
                 Opts :: [locus_database:opt()],
                 ChildSpec :: locus_database:static_child_spec().
loader_child_spec(ChildId, DatabaseId, DatabaseEdition, Opts)
  when is_atom(DatabaseEdition) ->
    Origin = parse_database_edition(DatabaseEdition),
    OptsWithDefaults = opts_with_defaults(Opts),
    locus_database:static_child_spec(ChildId, DatabaseId, Origin, OptsWithDefaults);
loader_child_spec(ChildId, DatabaseId, DatabaseURL, Opts)
  when ?might_be_chardata(DatabaseURL) ->
    case parse_url(DatabaseURL) of
        false ->
            error(invalid_url);
        Origin ->
            OptsWithDefaults = opts_with_defaults(Opts),
            locus_database:static_child_spec(ChildId, DatabaseId, Origin, OptsWithDefaults)
    end.

%% @doc Blocks caller execution until either readiness is achieved or a database load attempt fails.
%%
%% <ul>
%% <li>`DatabaseId' must be an atom and refer to a database loader.</li>
%% </ul>
%%
%% Returns:
%% <ul>
%% <li>`{ok, LoadedVersion}' when the database is ready to use.</li>
%% <li>`{error, database_unknown}' if the database loader for `DatabaseId' hasn't been started.</li>
%% <li>`{error, {loading, term()}}' if loading the database failed for some reason.</li>
%% </ul>
%%
%% @see wait_for_loader/2
%% @see start_loader/2
-spec wait_for_loader(DatabaseId) -> {ok, LoadedVersion} | {error, Error}
            when DatabaseId :: atom(),
                 LoadedVersion :: database_version(),
                 Error :: database_unknown | {loading, LoadingError},
                 LoadingError :: term().
wait_for_loader(DatabaseId) ->
    wait_for_loader(DatabaseId, infinity).

%% @doc Like `wait_for_loader/1' but it can time-out.
%%
%% <ul>
%% <li>`DatabaseId' must be an atom and refer to a database loader.</li>
%% <li>`Timeout' must be either a non-negative integer (milliseconds) or `infinity'.</li>
%% </ul>
%%
%% Returns:
%% <ul>
%% <li>`{ok, LoadedVersion}' when the database is ready to use.</li>
%% <li>`{error, database_unknown}' if the database loader for `DatabaseId' hasn't been started.</li>
%% <li>`{error, {loading, term()}}' if loading the database failed for some reason.</li>
%% <li>`{error, timeout}' if we've given up on waiting.</li>
%% </ul>
%% @see wait_for_loader/1
%% @see start_loader/2
-spec wait_for_loader(DatabaseId, Timeout) -> {ok, LoadedVersion} | {error, Reason}
            when DatabaseId :: atom(),
                 Timeout :: timeout(),
                 LoadedVersion :: database_version(),
                 Reason :: database_unknown | {loading,term()} | timeout.
wait_for_loader(DatabaseId, Timeout) ->
    case wait_for_loaders([DatabaseId], Timeout) of
        {ok, #{DatabaseId := LoadedVersion}} ->
            {ok, LoadedVersion};
        {error, {DatabaseId, Reason}} ->
            {error, Reason};
        {error, timeout} ->
            {error, timeout}
    end.

%% @doc Like `wait_for_loader/2' but it can concurrently await status from more than one database.
%%
%% <ul>
%% <li>`DatabaseIds' must be a list of atoms that refer to database loaders.</li>
%% <li>`Timeout' must be either a non-negative integer (milliseconds) or `infinity'.</li>
%% </ul>
%%
%% Returns:
%% <ul>
%% <li>`{ok, #{DatabaseId => LoadedVersion}}' when all the databases are ready to use.</li>
%% <li>`{error, {DatabaseId, database_unknown}}' if the database loader for `DatabaseId' hasn't been started.</li>
%% <li>`{error, {DatabaseId, {loading, term()}}}' if loading `DatabaseId' failed for some reason.</li>
%% <li>`{error, timeout}' if we've given up on waiting.</li>
%% </ul>
%% @see wait_for_loader/1
%% @see start_loader/2
-spec wait_for_loaders(DatabaseIds, Timeout) -> {ok, LoadedVersionPerDatabase} | {error, Reason}
            when DatabaseIds :: [DatabaseId],
                 Timeout :: timeout(),
                 LoadedVersionPerDatabase :: #{DatabaseId => LoadedVersion},
                 LoadedVersion :: database_version(),
                 Reason ::{DatabaseId,LoaderFailure} | timeout,
                 LoaderFailure :: database_unknown | {loading,term()}.
wait_for_loaders(DatabaseIds, Timeout) ->
    {WaiterPid, WaiterMon} = locus_waiter:start(DatabaseIds, Timeout),
    case perform_wait(WaiterPid, WaiterMon) of
        {ok, LoadedVersionPerDatabase} ->
            {ok, LoadedVersionPerDatabase};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Looks-up info on IPv4 and IPv6 addresses.
%%
%% <ul>
%% <li>`DatabaseId' must be an atom and refer to a database loader.</li>
%% <li>`Address' must be either an `inet:ip_address()' tuple, or a string/binary
%%    containing a valid representation of the address.</li>
%% </ul>
%%
%% Returns:
%% <ul>
%% <li>`{ok, Entry}' in case of success</li>
%% <li>`{error, not_found}' if no data was found for this `Address'.</li>
%% <li>`{error, invalid_address}' if `Address' is not either a `inet:ip_address()'
%%    tuple or a valid textual representation of an IP address.</li>
%% <li>`{error, database_unknown}' if the database loader for `DatabaseId' hasn't been started.</li>
%% <li>`{error, database_not_loaded}' if the database hasn't yet been loaded.</li>
%% <li>`{error, ipv4_database}' if `Address' represents an IPv6 address and the database
%%      only supports IPv4 addresses.</li>
%% </ul>
-spec lookup(DatabaseId, Address) -> {ok, Entry} | {error, Error}
            when DatabaseId :: atom(),
                 Address :: inet:ip_address() | nonempty_string() | binary(),
                 Entry :: database_entry(),
                 Error :: (not_found | invalid_address |
                           database_unknown | database_not_loaded |
                           ipv4_database).
lookup(DatabaseId, Address) ->
    locus_mmdb:lookup(DatabaseId, Address).

%% @doc Returns the currently loaded database version.
%% @deprecated Please use {@link get_info/2} instead.
%%
%% <ul>
%% <li>`DatabaseId' must be an atom and refer to a database loader.</li>
%% </ul>
%%
%% Returns:
%% <ul>
%% <li>`{ok, LoadedVersion}' in case of success</li>
%% <li>`{error, database_unknown}' if the database loader for `DatabaseId' hasn't been started.</li>
%% <li>`{error, database_not_loaded}' if the database hasn't yet been loaded.</li>
%% </ul>
-spec get_version(DatabaseId) -> {ok, LoadedVersion} | {error, Error}
            when DatabaseId :: atom(),
                 LoadedVersion :: database_version(),
                 Error :: database_unknown | database_not_loaded.
get_version(DatabaseId) ->
    get_info(DatabaseId, version).

%% @doc Returns the properties of a currently loaded database.
%%
%% <ul>
%% <li>`DatabaseId' must be an atom and refer to a database loader.</li>
%% </ul>
%%
%% Returns:
%% <ul>
%% <li>`{ok, database_info()}' in case of success</li>
%% <li>`{error, database_unknown}' if the database loader for `DatabaseId' hasn't been started.</li>
%% <li>`{error, database_not_loaded}' if the database hasn't yet been loaded.</li>
%% </ul>
%% @see get_info/2
-spec get_info(DatabaseId) -> {ok, Info} | {error, Error}
            when DatabaseId :: atom(),
                 Info :: database_info(),
                 Error :: database_unknown | database_not_loaded.
get_info(DatabaseId) ->
    case locus_mmdb:get_parts(DatabaseId) of
        {ok, Parts} ->
            {ok, info_from_db_parts(Parts)};
        {error, Error} ->
            {error, Error}
    end.

%% @doc Returns a specific property of a currently loaded database.
%%
%% <ul>
%% <li>`DatabaseId' must be an atom and refer to a database loader.</li>
%% <li>`Property' must be either `metadata', `source' or `version'.</li>
%% </ul>
%%
%% Returns:
%% <ul>
%% <li>`{ok, Value}' in case of success</li>
%% <li>`{error, database_unknown}' if the database loader for `DatabaseId' hasn't been started.</li>
%% <li>`{error, database_not_loaded}' if the database hasn't yet been loaded.</li>
%% </ul>
%% @see get_info/1
-spec get_info(DatabaseId, Property) -> {ok, Value} | {error, Error}
            when DatabaseId :: atom(),
                 Property :: metadata | source | version,
                 Value :: database_metadata() | database_source() | database_version(),
                 Error :: database_unknown | database_not_loaded.
get_info(DatabaseId, Property) ->
    case get_info(DatabaseId) of
        {ok, Info} ->
            Value = maps:get(Property, Info),
            {ok, Value};
        {error, Error} ->
            {error, Error}
    end.

%% @doc Analyzes a loaded database for corruption or incompatibility.
%%
%% <ul>
%% <li>`DatabaseId' must be an atom and refer to a database loader.</li>
%% </ul>
%%
%% Returns:
%% <ul>
%% <li>`ok' if the database is wholesome</li>
%% <li>`{error, {flawed, [Flaw, ...]]}}' in case of corruption or incompatibility
%%    (see the definition of {@link locus_mmdb:analysis_flaw/0})
%% </li>
%% <li>`{error, database_unknown}' if the database loader for `DatabaseId' hasn't been started.</li>
%% <li>`{error, database_not_loaded}' if the database hasn't yet been loaded.</li>
%% </ul>
-spec analyze(DatabaseId) -> ok | {error, Error}
            when DatabaseId :: atom(),
                 Error :: ({flawed, [locus_mmdb:analysis_flaw(), ...]} |
                           database_unknown |
                           database_not_loaded).
analyze(DatabaseId) ->
    locus_mmdb:analyze(DatabaseId).

%% ------------------------------------------------------------------
%% CLI-only Function Definitions
%% ------------------------------------------------------------------

-ifdef(ESCRIPTIZING).
-spec main([string()]) -> no_return().
%% @private
main(Args) ->
    locus_cli:main(Args).
-endif.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

-spec parse_database_edition(database_edition()) -> {maxmind, atom()}.
%% @private
parse_database_edition(DatabaseEdition) ->
    {maxmind, DatabaseEdition}.

-spec parse_url(database_url()) -> locus_database:origin() | false.
parse_url(DatabaseURL) ->
    case parse_http_url(DatabaseURL) of
        Origin when is_tuple(Origin) ->
            Origin;
        false ->
            parse_filesystem_url(DatabaseURL)
    end.

parse_http_url(DatabaseURL) when is_list(DatabaseURL) ->
    try unicode:characters_to_binary(DatabaseURL) of
        <<BinaryChardata/bytes>> ->
            parse_http_url(BinaryChardata);
        _ ->
            false
    catch
        _:_ -> false
    end;
parse_http_url(DatabaseURL) ->
    ByteList = binary_to_list(DatabaseURL),
    try io_lib:printable_latin1_list(ByteList) andalso
        http_uri:parse(ByteList)
    of
        false ->
            false;
        {ok, {Scheme, "", "geolite.maxmind.com", Port, "/download/geoip/database/GeoLite2-" ++ Suffix, _}}
          when Scheme =:= http, Port =:= 80;
               Scheme =:= https, Port =:= 443 ->
            parse_discontinued_geolite2_http_url(DatabaseURL, Suffix, ByteList);
        {ok, {Scheme, "", "geolite.maxmind.com", Port, "/download/geoip/database/GeoLite2-" ++ Suffix, _, _}}
          when Scheme =:= http, Port =:= 80;
               Scheme =:= https, Port =:= 443 ->
            parse_discontinued_geolite2_http_url(DatabaseURL, Suffix, ByteList);
        {ok, _Result} ->
            {http, ByteList};
        {error, _Reason} ->
            false
    catch
        error:badarg -> false
    end.

parse_discontinued_geolite2_http_url(DatabaseURL, Suffix, ByteList) ->
    case Suffix of
        "Country.tar.gz" ->
            log_warning_on_use_of_discontinued_geolite2_http_url(DatabaseURL, 'GeoLite2-Country'),
            {maxmind, 'GeoLite2-Country'};
        "City.tar.gz" ->
            log_warning_on_use_of_discontinued_geolite2_http_url(DatabaseURL, 'GeoLite2-City'),
            {maxmind, 'GeoLite2-City'};
        "ASN.tar.gz" ->
            log_warning_on_use_of_discontinued_geolite2_http_url(DatabaseURL, 'GeoLite2-ASN'),
            {maxmind, 'GeoLite2-ASN'};
        _ ->
            {http, ByteList}
    end.

log_warning_on_use_of_discontinued_geolite2_http_url(LegacyURL, DatabaseEdition) ->
    locus_logger:log_warning(
      "Public access to GeoLite2 was discontinued on 2019-12-30; converting legacy URL for your convenience.~n"
      "Update your `:start_loader' and `:loader_child_spec' calls to silence this message.~n"
      "(Use the atom '~ts' instead of the legacy URL \"~ts\")",
      [DatabaseEdition, LegacyURL]).

parse_filesystem_url(DatabaseURL) ->
    try unicode:characters_to_list(DatabaseURL) of
        Path when is_list(Path) ->
            {filesystem, filename:absname(Path)};
        {error, _Parsed, _RestData} ->
            false;
        {incomplete, _Parsed, _RestData} ->
            false
    catch
        error:badarg -> false
    end.

info_from_db_parts(Parts) ->
    maps:with([metadata, source, version], Parts).

opts_with_defaults(Opts) ->
    [{event_subscriber, locus_logger} | Opts].

perform_wait(WaiterPid, WaiterMon) ->
    receive
        {WaiterPid, Result} ->
            demonitor(WaiterMon, [flush]),
            handle_waiter_result(Result);
        {'DOWN', WaiterMon, _, _, Reason} ->
            error({waiter_stopped, WaiterPid, Reason})
    end.

handle_waiter_result({ok, LoadedVersionPerDatabase}) ->
    {ok, LoadedVersionPerDatabase};
handle_waiter_result({error, {DatabaseId, Reason}}) ->
    {error, {DatabaseId, Reason}};
handle_waiter_result({error, {stopped, DatabaseId, Reason}}) ->
    case Reason of
        noproc ->
            {error, {DatabaseId, database_unknown}};
        normal ->
            {error, {DatabaseId, database_unknown}};
        shutdown ->
            {error, {DatabaseId, database_unknown}};
        {shutdown,_} ->
            {error, {DatabaseId, database_unknown}};
        _ ->
            exit(Reason)
    end;
handle_waiter_result({error, timeout}) ->
    {error, timeout}.
