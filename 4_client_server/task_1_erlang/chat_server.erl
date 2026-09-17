-module(chat_server).
-export([start/0, start/1]).

start() -> start(9000).

start(Port) when is_list(Port) ->
    start(list_to_integer(Port));
start(Port) ->
    Options = [binary, {packet, line}, {active, false}, {reuseaddr, true}],
    io:setopts(standard_io, [{encoding, unicode}]),
    {ok, Listen} = gen_tcp:listen(Port, Options),
    Registry = spawn(fun() -> registry([]) end),
    io:format("сервер слушает порт ~p~n", [Port]),
    accept_loop(Listen, Registry).

accept_loop(Listen, Registry) ->
    {ok, Socket} = gen_tcp:accept(Listen),
    Pid = spawn(fun() -> greet(Socket, Registry) end),
    gen_tcp:controlling_process(Socket, Pid),
    accept_loop(Listen, Registry).

greet(Socket, Registry) ->
    inet:setopts(Socket, [{active, true}]),
    send(Socket, "ник: "),
    receive
        {tcp, Socket, Data} ->
            case trim(Data) of
                "" ->
                    send(Socket, "пустой ник, до свидания~n"),
                    gen_tcp:close(Socket);
                Nick ->
                    Registry ! {join, self(), Nick},
                    client_loop(Socket, Registry, Nick)
            end;
        {tcp_closed, Socket} ->
            ok
    after 60000 ->
        gen_tcp:close(Socket)
    end.

client_loop(Socket, Registry, Nick) ->
    receive
        {tcp, Socket, Data} ->
            case trim(Data) of
                "" ->
                    client_loop(Socket, Registry, Nick);
                "/quit" ->
                    Registry ! {leave, self()},
                    gen_tcp:close(Socket);
                "/list" ->
                    Registry ! {who, self()},
                    client_loop(Socket, Registry, Nick);
                Text ->
                    Registry ! {say, self(), Text},
                    client_loop(Socket, Registry, Nick)
            end;
        {tcp_closed, Socket} ->
            Registry ! {leave, self()};
        {out, Text} ->
            send(Socket, Text),
            client_loop(Socket, Registry, Nick)
    end.

registry(Clients) ->
    receive
        {join, Pid, Nick} ->
            io:format("подключился ~ts (всего ~p)~n", [Nick, length(Clients) + 1]),
            broadcast(Clients, io_lib:format("* ~ts вошёл в чат~n", [Nick])),
            Pid ! {out, io_lib:format("* вы вошли как ~ts, участников: ~p~n",
                                      [Nick, length(Clients) + 1])},
            registry([{Pid, Nick} | Clients]);
        {leave, Pid} ->
            case lists:keyfind(Pid, 1, Clients) of
                {Pid, Nick} ->
                    Rest = lists:keydelete(Pid, 1, Clients),
                    io:format("отключился ~ts (осталось ~p)~n", [Nick, length(Rest)]),
                    broadcast(Rest, io_lib:format("* ~ts вышел из чата~n", [Nick])),
                    registry(Rest);
                false ->
                    registry(Clients)
            end;
        {say, Pid, Text} ->
            case lists:keyfind(Pid, 1, Clients) of
                {Pid, Nick} ->
                    Line = io_lib:format("[~ts] ~ts~n", [Nick, Text]),
                    broadcast(lists:keydelete(Pid, 1, Clients), Line),
                    registry(Clients);
                false ->
                    registry(Clients)
            end;
        {who, Pid} ->
            Names = [N || {_, N} <- Clients],
            Pid ! {out, io_lib:format("* в чате: ~ts~n", [string:join(Names, ", ")])},
            registry(Clients)
    end.

broadcast(Clients, Text) ->
    [Pid ! {out, Text} || {Pid, _} <- Clients].

send(Socket, Text) ->
    gen_tcp:send(Socket, unicode:characters_to_binary(Text)).

trim(Data) ->
    string:trim(unicode:characters_to_list(Data, utf8)).
