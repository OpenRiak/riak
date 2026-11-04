#!/usr/bin/env escript
%%! -name client_test@127.0.0.1 -pa _build/default/lib/riak_pb/ebin -pa _build/default/lib/riakc/ebin
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

main(Args) ->
    ssl:start(),
    %%
    %% Use the following options and 'case' statement
    %% to connect to a Riak cluster with SSL enabled.
    %% 
    % SO = [
    %     {credentials, "riakwriteclient", ""},
    %     {cacertfile, "PATH_TO_CA/riakca.ca.crt.pem"},
    %     {certfile, "PATH_TO_CERT/riakwriteclient.crt.pem"},
    %     {keyfile, "PATH_TO_KEY/riakwriteclient.key.pem"}
    % ],
    %case riakc_pb_socket:start("127.0.0.1", 10017, SO) of
    %%
    %% Use the following 'case' statement
    %% to connect to a Riak cluster with SSL disabled.
    %% 
    case riakc_pb_socket:start("127.0.0.1", 10017, []) of
        {ok, P} ->
            case Args of
                [ "ping" ] ->
                    StartTime = erlang:monotonic_time(millisecond),
                    case riakc_pb_socket:ping(P) of
                        pong -> io:format("PONG~n");
                        {error, Err} -> io:format("~p~n", [Err])
                    end,
                    EndTime = erlang:monotonic_time(millisecond),
                    io:format("Ping time: ~p ms~n", [EndTime - StartTime]);
                [ "put", Bucket, Key | ValOrFile ] ->
                    % if ValOrFile is a file, read the value from the file, 
                    % otherwise use the provided value
                    Value = case file:read_file(ValOrFile) of
                        {ok, FileValue} -> FileValue;
                        {error, _} -> list_to_binary(ValOrFile)
                    end,
                    RObj = riakc_obj:new(list_to_binary(Bucket),
                        list_to_binary(Key), Value),
                    StartTime = erlang:monotonic_time(millisecond),
                    do_put(P, RObj),
                    EndTime = erlang:monotonic_time(millisecond),
                    io:format("Put time: ~p ms~n", [EndTime - StartTime]);
                [ "get", Bucket, Key | OutFile ] ->
                    StartTime = erlang:monotonic_time(millisecond),
                    Value = do_get(P, Bucket, Key),
                    EndTime = erlang:monotonic_time(millisecond),
                    case Value of
                        undefined -> io:format("NOT FOUND~n");
                        _ ->
                            case OutFile of
                                [] -> io:format("Value: ~p~n", [Value]);
                                _ ->
                                    case file:write_file(OutFile, Value) of
                                        ok -> io:format("Value written to ~p~n", [OutFile]);
                                        {error, Err} -> io:format("~p~n", [Err])
                                    end
                            end
                    end,
                    io:format("Get time: ~p ms~n", [EndTime - StartTime]);
                [ Del, Bucket, Key ] when Del =:= "delete"; Del =:= "del" ->
                    StartTime = erlang:monotonic_time(millisecond),
                    case riakc_pb_socket:delete(P, list_to_binary(Bucket),
                            list_to_binary(Key)) of
                        ok -> io:format("Deleted!~n");
                        {error, Err} -> io:format("~p~n", [Err])
                    end,
                    EndTime = erlang:monotonic_time(millisecond),
                    io:format("Delete time: ~p ms~n", [EndTime - StartTime]);
                %% The following commands are used in a cluster which supports
                %% large object streaming.  If your cluster does not support this, you can
                %% remove these commands from the case statement, or ignore them.
                [ "get_stream", Bucket, Key, OutFile ] ->
                    StartTime = erlang:monotonic_time(millisecond),
                    Res = do_get_stream(P, Bucket, Key, OutFile),
                    EndTime = erlang:monotonic_time(millisecond),
                    case Res of
                        ok          -> io:format("Streamed to ~s~n", [OutFile]);
                        notfound    -> io:format("NOT FOUND~n");
                        unchanged   -> io:format("UNCHANGED~n");
                        {error, E}  -> io:format("~p~n", [E])
                    end,
                    io:format("Get stream time: ~p ms~n", [EndTime - StartTime]);
                [ "put_stream_file", Bucket, Key, FilePath ] ->
                    StartTime = erlang:monotonic_time(millisecond),
                    Res = riakc_pb_socket:put_stream_file(P,
                                                          list_to_binary(Bucket),
                                                          list_to_binary(Key),
                                                          FilePath),
                    EndTime = erlang:monotonic_time(millisecond),
                    case Res of
                        ok          -> io:format("Ok~n");
                        {ok, _}     -> io:format("Ok~n");
                        {error, E}  -> io:format("~p~n", [E])
                    end,
                    io:format("Put stream file time: ~p ms~n", [EndTime - StartTime]);
                [ "put_stream_with_opts", Bucket, Key, FilePath, OptsStr ] ->
                    Opts = parse_term(OptsStr),
                    Res = (catch riakc_pb_socket:put_stream_file(P,
                                                                 list_to_binary(Bucket),
                                                                 list_to_binary(Key),
                                                                 FilePath,
                                                                 Opts)),
                    io:format("~p~n", [Res]);
                _ ->
                    io:format("Usage:~n"),
                    io:format("      put BUCKET KEY VALUE~n"),
                    io:format("      put BUCKET KEY <VALUE_FILE>~n"),
                    io:format("      get BUCKET KEY [OUTFILE]~n"),
                    io:format("      del BUCKET KEY~n"),
                    io:format("      get_stream BUCKET KEY OUTFILE~n"),
                    io:format("      put_stream_file BUCKET KEY FILEPATH~n"),
                    io:format("      put_stream_with_opts BUCKET KEY FILEPATH OPTSTERM~n"),
                    io:format("      ping~n")
            end;
        {error, Reason} ->
            io:format("Error: ~p~n", [Reason])
    end,
    ok.

do_get(P, Bucket, Key) ->
    case riakc_pb_socket:get(P, list_to_binary(Bucket),
            list_to_binary(Key)) of
        {ok, Obj} -> riakc_obj:get_value(Obj);
        _ -> io:format("NOT FOUND~n"), undefined
    end.

do_put(P, RObj) ->
    case riakc_pb_socket:put(P, RObj) of
        {error, Err} -> io:format("~p~n", [ Err ]);
        _ -> io:format("Ok~n")
    end.

do_get_stream(P, Bucket, Key, OutFile) ->
    case riakc_pb_socket:get_stream(P,
                                    list_to_binary(Bucket),
                                    list_to_binary(Key)) of
        {ok, ReqId} ->
            case file:open(OutFile, [write, binary, raw]) of
                {ok, Fd} ->
                    try recv_stream(ReqId, Fd)
                    after _ = file:close(Fd) end;
                {error, E} -> {error, {file_open, E}}
            end;
        {error, E} -> {error, E}
    end.

recv_stream(ReqId, Fd) ->
    receive
        {ReqId, {meta, _Obj}}      -> recv_stream(ReqId, Fd);
        {ReqId, {chunk, Bin}}      -> ok = file:write(Fd, Bin),
                                      recv_stream(ReqId, Fd);
        {ReqId, done}              -> ok;
        {ReqId, {error, notfound}} -> notfound;
        {ReqId, unchanged}         -> unchanged;
        {ReqId, {error, E}}        -> {error, E}
    after 600000 ->
        {error, timeout}
    end.

parse_term(Str) ->
    {ok, Tokens, _} = erl_scan:string(Str ++ "."),
    {ok, Term} = erl_parse:parse_term(Tokens),
    Term.