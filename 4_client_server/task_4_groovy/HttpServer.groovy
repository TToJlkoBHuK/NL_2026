int port = args.length > 0 ? args[0] as int : 8080
File root = new File(args.length > 1 ? args[1] : "www").canonicalFile

if (!root.isDirectory()) {
    println "нет каталога ${root}"
    System.exit(1)
}

def types = [
    html: "text/html; charset=utf-8",
    htm : "text/html; charset=utf-8",
    css : "text/css; charset=utf-8",
    js  : "application/javascript; charset=utf-8",
    json: "application/json; charset=utf-8",
    txt : "text/plain; charset=utf-8",
    png : "image/png",
    jpg : "image/jpeg",
    gif : "image/gif",
    ico : "image/x-icon",
]

def counters = [:]
def started = System.currentTimeMillis()

def bump = { String key ->
    synchronized (counters) {
        counters[key] = (counters[key] ?: 0) + 1
    }
}

def respond = { OutputStream out, int code, String status, String type, byte[] body ->
    def header = new StringBuilder()
    header << "HTTP/1.1 ${code} ${status}\r\n"
    header << "Content-Type: ${type}\r\n"
    header << "Content-Length: ${body.length}\r\n"
    header << "Connection: close\r\n\r\n"
    out.write(header.toString().getBytes("UTF-8"))
    out.write(body)
    out.flush()
}

def server = new ServerSocket(port)
println "сервер слушает порт ${port}, каталог ${root}"

while (true) {
    def socket = server.accept()

    Thread.start {
        def from = socket.inetAddress.hostAddress
        try {
            def reader = new BufferedReader(new InputStreamReader(socket.inputStream, "UTF-8"))
            def out = new BufferedOutputStream(socket.outputStream)

            def requestLine = reader.readLine()
            if (!requestLine) { socket.close(); return }

            def headers = [:]
            def line
            while ((line = reader.readLine()) != null && !line.isEmpty()) {
                int colon = line.indexOf(':')
                if (colon > 0) {
                    headers[line.substring(0, colon).trim().toLowerCase()] = line.substring(colon + 1).trim()
                }
            }

            def parts = requestLine.split(/\s+/)
            def method = parts.length > 0 ? parts[0] : ""
            def target = parts.length > 1 ? parts[1] : "/"
            def path = target.split(/\?/)[0]

            int code
            if (method != "GET" && method != "HEAD") {
                code = 405
                respond(out, 405, "Method Not Allowed", types.txt, "метод ${method} не поддерживается\n".getBytes("UTF-8"))
            } else if (path == "/stats") {
                code = 200
                def text = new StringBuilder()
                text << "<!doctype html><meta charset=utf-8><title>Статистика</title>"
                text << "<h1>Статистика сервера</h1>"
                text << "<p>Время работы: ${(int)((System.currentTimeMillis() - started) / 1000)} с</p><table border=1 cellpadding=4>"
                text << "<tr><th>Адрес</th><th>Запросов</th></tr>"
                synchronized (counters) {
                    counters.sort { -it.value }.each { key, value ->
                        text << "<tr><td>${key}</td><td>${value}</td></tr>"
                    }
                }
                text << "</table>"
                respond(out, 200, "OK", types.html, text.toString().getBytes("UTF-8"))
            } else {
                def name = path == "/" ? "index.html" : path.substring(1)
                def file = new File(root, name).canonicalFile

                if (!file.path.startsWith(root.path)) {
                    code = 403
                    respond(out, 403, "Forbidden", types.txt, "выход за пределы каталога\n".getBytes("UTF-8"))
                } else if (!file.isFile()) {
                    code = 404
                    respond(out, 404, "Not Found", types.html,
                            "<!doctype html><meta charset=utf-8><h1>404</h1><p>${path} не найден</p>".getBytes("UTF-8"))
                } else {
                    code = 200
                    def ext = file.name.contains('.') ? file.name.substring(file.name.lastIndexOf('.') + 1).toLowerCase() : ""
                    def type = types[ext] ?: "application/octet-stream"
                    def body = method == "HEAD" ? new byte[0] : file.bytes
                    respond(out, 200, "OK", type, body)
                }
            }

            bump(path)
            printf("%s %s %s -> %d%n", from, method, target, code)
        } catch (Exception e) {
            println "ошибка при обработке запроса: ${e.message}"
        } finally {
            try { socket.close() } catch (ignored) { }
        }
    }
}
