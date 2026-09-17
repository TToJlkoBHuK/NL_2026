using Sockets

const store = Dict{String,String}()
const store_lock = ReentrantLock()

function execute(line::AbstractString)
    parts = split(strip(line), ' '; limit = 3)
    cmd = uppercase(parts[1])

    if cmd == "SET"
        length(parts) < 3 && return "ERR формат: SET ключ значение"
        lock(store_lock) do
            store[parts[2]] = parts[3]
        end
        return "OK"

    elseif cmd == "GET"
        length(parts) < 2 && return "ERR формат: GET ключ"
        return lock(store_lock) do
            haskey(store, parts[2]) ? store[parts[2]] : "NOT FOUND"
        end

    elseif cmd == "DEL"
        length(parts) < 2 && return "ERR формат: DEL ключ"
        return lock(store_lock) do
            if haskey(store, parts[2])
                delete!(store, parts[2])
                "OK"
            else
                "NOT FOUND"
            end
        end

    elseif cmd == "KEYS"
        return lock(store_lock) do
            isempty(store) ? "(пусто)" : join(sort(collect(keys(store))), ", ")
        end

    elseif cmd == "QUIT"
        return "BYE"

    else
        return "ERR неизвестная команда: $(parts[1])"
    end
end

function serve(sock, id)
    println("клиент $id подключился")
    try
        while !eof(sock)
            line = readline(sock)
            isempty(strip(line)) && continue
            answer = execute(line)
            println("клиент $id: $(strip(line)) -> $answer")
            println(sock, answer)
            answer == "BYE" && break
        end
    catch err
        println("клиент $id: обрыв связи ($err)")
    finally
        close(sock)
        println("клиент $id отключился")
    end
end

function main()
    port = length(ARGS) > 0 ? parse(Int, ARGS[1]) : 9000
    server = listen(port)
    println("сервер слушает порт $port")
    println("команды: SET ключ значение, GET ключ, DEL ключ, KEYS, QUIT")

    id = 0
    while true
        sock = accept(server)
        id += 1
        current = id
        @async serve(sock, current)
    end
end

main()
