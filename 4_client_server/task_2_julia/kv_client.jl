using Sockets

host = length(ARGS) > 0 ? ARGS[1] : "127.0.0.1"
port = length(ARGS) > 1 ? parse(Int, ARGS[2]) : 9000

sock = connect(host, port)
println("подключено к $host:$port")
println("команды: SET ключ значение, GET ключ, DEL ключ, KEYS, QUIT")

while true
    print("> ")
    flush(stdout)
    eof(stdin) && break

    line = readline(stdin)
    isempty(strip(line)) && continue

    println(sock, line)
    answer = readline(sock)
    println(answer)
    answer == "BYE" && break
end

close(sock)
println("соединение закрыто")
