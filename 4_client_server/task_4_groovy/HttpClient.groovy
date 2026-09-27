String host = args.length > 0 ? args[0] : "127.0.0.1"
int port = args.length > 1 ? args[1] as int : 8080
String path = args.length > 2 ? args[2] : "/"

def socket = new Socket(host, port)
socket.soTimeout = 5000

def out = new PrintWriter(new OutputStreamWriter(socket.outputStream, "UTF-8"), false)
out.print("GET ${path} HTTP/1.1\r\n")
out.print("Host: ${host}:${port}\r\n")
out.print("User-Agent: groovy-client\r\n")
out.print("Connection: close\r\n\r\n")
out.flush()

def reader = new BufferedReader(new InputStreamReader(socket.inputStream, "UTF-8"))

println "--- ответ сервера ---"
def line
boolean body = false
while ((line = reader.readLine()) != null) {
    if (!body && line.isEmpty()) {
        body = true
        println "--- тело ---"
        continue
    }
    println line
}

socket.close()
