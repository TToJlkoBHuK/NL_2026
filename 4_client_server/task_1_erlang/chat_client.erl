-module(chat_client).
-export([start/0, start/2]).

start() -> start("127.0.0.1", 9000).

start(Host, Port) when is_list(Port) ->
    start(Host, list_to_integer(Port));
start(Host, Port) ->
    io:setopts(standard_io, [{encoding, unicode}]),
    Options = [binary, {packet, line}, {active, true}],
    case gen_tcp:connect(Host, Port, Options) of
        {ok, Socket} ->
            io:format("подключено к ~ts:~p, /list - участники, /quit - выход~n", [Host, Port]),
            spawn_link(fun() -> input_loop(Socket) end),
            recv_loop(Socket);
        {error, Reason} ->
            io:format("не удалось подключиться: ~p~n", [Reason])
    end.

input_loop(Socket) ->
    case io:get_line("") of
        eof ->
            gen_tcp:send(Socket, <<"/quit\n">>);
        {error, _} ->
            gen_tcp:send(Socket, <<"/quit\n">>);
        Line ->
            gen_tcp:send(Socket, unicode:characters_to_binary(Line)),
            input_loop(Socket)
    end.

recv_loop(Socket) ->
    receive
        {tcp, Socket, Data} ->
            io:format("~ts", [unicode:characters_to_list(Data, utf8)]),
            recv_loop(Socket);
        {tcp_closed, Socket} ->
            io:format("соединение закрыто~n"),
            halt(0)
    end.
