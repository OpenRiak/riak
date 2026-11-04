%% -------------------------------------------------------------------
%%
%% Copyright (c) 2026 Workday, Inc.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------
%%
%% @doc Merge a key-value pair into a Riak advanced.config file.
%%
%% Usage:
%%   escript merge_advanced_config.escript ConfigFile App Key ValueTerm
%%
%% Example:
%%   escript merge_advanced_config.escript \
%%       /root/riak_node/etc/advanced.config \
%%       kernel inet_dist_use_interface "{10,0,0,1}"
%%

-spec main([string()]) -> ok.
main([ConfigFile, AppStr, KeyStr, ValueStr]) ->
    App = list_to_atom(AppStr),
    Key = list_to_atom(KeyStr),
    Value = parse_term(ValueStr),
    Base = read_config(ConfigFile),
    AppConfig = proplists:get_value(App, Base, []),
    UpdatedApp = lists:keystore(Key, 1, AppConfig, {Key, Value}),
    Final = lists:keystore(App, 1, Base, {App, UpdatedApp}),
    case file:write_file(ConfigFile, io_lib:format("~0p.~n", [Final])) of
        ok ->
            io:format("Merged ~s.~s into ~s~n", [AppStr, KeyStr, ConfigFile]);
        {error, WriteErr} ->
            io:format(standard_error,
                "ERROR: Cannot write ~s: ~s~n",
                [ConfigFile, file:format_error(WriteErr)]),
            halt(1)
    end;
main(_) ->
    io:format(standard_error,
        "Usage: merge_advanced_config.escript <config_file> <app> <key> <value>~n", []),
    halt(1).

-spec read_config(file:filename()) -> [{atom(), [{atom(), term()}]}].
read_config(ConfigFile) ->
    case file:consult(ConfigFile) of
        {ok, [Config]} when is_list(Config) ->
            Config;
        {ok, []} ->
            [];
        {error, enoent} ->
            [];
        {error, Reason} ->
            io:format(standard_error,
                "ERROR: Cannot read ~s: ~s~n",
                [ConfigFile, file:format_error(Reason)]),
            halt(1)
    end.

-spec parse_term(string()) -> term().
parse_term(Str) ->
    case erl_scan:string(Str ++ ".") of
        {ok, Tokens, _} ->
            case erl_parse:parse_term(Tokens) of
                {ok, Term} ->
                    Term;
                {error, {_, _, Desc}} ->
                    io:format(standard_error,
                        "ERROR: Bad value '~s': ~s~n",
                        [Str, erl_parse:format_error(Desc)]),
                    halt(1)
            end;
        {error, {_, _, Desc}, _} ->
            io:format(standard_error,
                "ERROR: Bad value '~s': ~s~n",
                [Str, erl_scan:format_error(Desc)]),
            halt(1)
    end.
