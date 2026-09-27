import Foundation

struct ParseError: Error {
    let message: String
}

func parseCSV(_ text: String, separator: Character) throws -> [[String]] {
    var rows: [[String]] = []
    var row: [String] = []
    var field = ""
    var quoted = false
    var line = 1

    var i = text.startIndex
    while i < text.endIndex {
        let ch = text[i]

        if quoted {
            if ch == "\"" {
                let next = text.index(after: i)
                if next < text.endIndex && text[next] == "\"" {
                    field.append("\"")
                    i = next
                } else {
                    quoted = false
                }
            } else {
                if ch == "\n" { line += 1 }
                field.append(ch)
            }
        } else {
            switch ch {
            case "\"":
                quoted = true
            case separator:
                row.append(field)
                field = ""
            case "\r":
                break
            case "\n":
                row.append(field)
                field = ""
                rows.append(row)
                row = []
                line += 1
            default:
                field.append(ch)
            }
        }

        i = text.index(after: i)
    }

    if quoted {
        throw ParseError(message: "не закрыта кавычка, строка \(line)")
    }
    if !field.isEmpty || !row.isEmpty {
        row.append(field)
        rows.append(row)
    }

    return rows.filter { $0.count > 1 || ($0.count == 1 && !$0[0].isEmpty) }
}

func escaped(_ value: String) -> String {
    var result = ""
    for ch in value.unicodeScalars {
        switch ch {
        case "\"": result += "\\\""
        case "\\": result += "\\\\"
        case "\n": result += "\\n"
        case "\r": result += "\\r"
        case "\t": result += "\\t"
        default:
            if ch.value < 0x20 {
                result += String(format: "\\u%04x", ch.value)
            } else {
                result.unicodeScalars.append(ch)
            }
        }
    }
    return "\"" + result + "\""
}

func looksNumeric(_ value: String) -> Bool {
    if value.isEmpty { return false }
    var seenDigit = false
    var seenDot = false
    var index = value.startIndex
    if value[index] == "-" || value[index] == "+" {
        index = value.index(after: index)
    }
    while index < value.endIndex {
        let ch = value[index]
        if ch.isNumber {
            seenDigit = true
        } else if ch == "." && !seenDot {
            seenDot = true
        } else {
            return false
        }
        index = value.index(after: index)
    }
    return seenDigit
}

func jsonValue(_ raw: String) -> String {
    let value = raw.trimmingCharacters(in: .whitespaces)
    if value.isEmpty { return "null" }
    let lower = value.lowercased()
    if lower == "true" || lower == "false" || lower == "null" { return lower }
    if looksNumeric(value) { return value }
    return escaped(raw)
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    print("Использование: csv2json <вход.csv> <выход.json> [разделитель]")
    exit(1)
}

let separator: Character = arguments.count > 3 && !arguments[3].isEmpty
    ? arguments[3].first!
    : ","

guard let data = FileManager.default.contents(atPath: arguments[1]),
      let text = String(data: data, encoding: .utf8) else {
    print("не читается файл \(arguments[1])")
    exit(1)
}

do {
    let rows = try parseCSV(text, separator: separator)
    guard let header = rows.first else {
        print("файл пуст")
        exit(1)
    }

    var output = "[\n"
    var written = 0

    for row in rows.dropFirst() {
        if written > 0 { output += ",\n" }
        output += "  {\n"
        for (index, name) in header.enumerated() {
            let raw = index < row.count ? row[index] : ""
            output += "    \(escaped(name)): \(jsonValue(raw))"
            output += index == header.count - 1 ? "\n" : ",\n"
        }
        output += "  }"
        written += 1
    }

    output += "\n]\n"

    try output.write(toFile: arguments[2], atomically: true, encoding: .utf8)

    print("Столбцов: \(header.count) (\(header.joined(separator: ", ")))")
    print("Записей:  \(written)")
    print("Записано в \(arguments[2])")
} catch let error as ParseError {
    print("Ошибка разбора CSV: \(error.message)")
    exit(1)
}
