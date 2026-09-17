open System
open System.IO
open System.Text

type Json =
    | JNull
    | JBool of bool
    | JNumber of string
    | JString of string
    | JArray of Json list
    | JObject of (string * Json) list

exception JsonError of string * int

let parse (text: string) =
    let mutable pos = 0

    let fail message = raise (JsonError(message, pos))

    let peek () = if pos < text.Length then text.[pos] else '\000'

    let skipSpace () =
        while pos < text.Length && Char.IsWhiteSpace text.[pos] do
            pos <- pos + 1

    let expect (c: char) =
        skipSpace ()
        if peek () <> c then fail (sprintf "ожидался символ '%c'" c)
        pos <- pos + 1

    let parseString () =
        expect '"'
        let builder = StringBuilder()
        let mutable finished = false
        while not finished do
            if pos >= text.Length then fail "строка не закрыта"
            let c = text.[pos]
            pos <- pos + 1
            if c = '"' then finished <- true
            elif c = '\\' then
                if pos >= text.Length then fail "оборванная escape-последовательность"
                let e = text.[pos]
                pos <- pos + 1
                match e with
                | '"' -> builder.Append('"') |> ignore
                | '\\' -> builder.Append('\\') |> ignore
                | '/' -> builder.Append('/') |> ignore
                | 'n' -> builder.Append('\n') |> ignore
                | 'r' -> builder.Append('\r') |> ignore
                | 't' -> builder.Append('\t') |> ignore
                | 'b' -> builder.Append('\b') |> ignore
                | 'f' -> builder.Append('\f') |> ignore
                | 'u' ->
                    if pos + 4 > text.Length then fail "короткий \\u"
                    let code = Convert.ToInt32(text.Substring(pos, 4), 16)
                    builder.Append(char code) |> ignore
                    pos <- pos + 4
                | _ -> fail (sprintf "неизвестная escape-последовательность \\%c" e)
            else builder.Append(c) |> ignore
        builder.ToString()

    let parseLiteral (word: string) value =
        if pos + word.Length <= text.Length && text.Substring(pos, word.Length) = word then
            pos <- pos + word.Length
            value
        else
            fail (sprintf "ожидалось %s" word)

    let parseNumber () =
        let start = pos
        if peek () = '-' then pos <- pos + 1
        while pos < text.Length && (Char.IsDigit text.[pos] || "+-.eE".Contains(text.[pos])) do
            pos <- pos + 1
        if pos = start then fail "ожидалось число"
        text.Substring(start, pos - start)

    let rec parseValue () =
        skipSpace ()
        match peek () with
        | '{' -> parseObject ()
        | '[' -> parseArray ()
        | '"' -> JString(parseString ())
        | 't' -> parseLiteral "true" (JBool true)
        | 'f' -> parseLiteral "false" (JBool false)
        | 'n' -> parseLiteral "null" JNull
        | '\000' -> fail "неожиданный конец файла"
        | _ -> JNumber(parseNumber ())

    and parseObject () =
        expect '{'
        skipSpace ()
        if peek () = '}' then
            pos <- pos + 1
            JObject []
        else
            let items = ResizeArray()
            let mutable go = true
            while go do
                skipSpace ()
                let key = parseString ()
                expect ':'
                items.Add(key, parseValue ())
                skipSpace ()
                if peek () = ',' then pos <- pos + 1
                else
                    expect '}'
                    go <- false
            JObject(List.ofSeq items)

    and parseArray () =
        expect '['
        skipSpace ()
        if peek () = ']' then
            pos <- pos + 1
            JArray []
        else
            let items = ResizeArray()
            let mutable go = true
            while go do
                items.Add(parseValue ())
                skipSpace ()
                if peek () = ',' then pos <- pos + 1
                else
                    expect ']'
                    go <- false
            JArray(List.ofSeq items)

    let result = parseValue ()
    skipSpace ()
    if pos < text.Length then fail "лишние символы после значения"
    result

let escapeXml (s: string) =
    s.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;").Replace("\"", "&quot;")

let safeName (s: string) =
    let builder = StringBuilder()
    for c in s do
        if Char.IsLetterOrDigit c || c = '_' || c = '-' || c = '.' then builder.Append(c) |> ignore
        else builder.Append('_') |> ignore
    let name = builder.ToString()
    if name = "" || Char.IsDigit name.[0] then "_" + name else name

let mutable nodes = 0

let rec write (out: StringBuilder) (name: string) (value: Json) (depth: int) (attribute: string) =
    nodes <- nodes + 1
    let pad = String(' ', depth * 2)
    let tag = safeName name
    let attr = if attribute = "" then "" else " " + attribute

    match value with
    | JNull -> out.AppendLine(sprintf "%s<%s%s/>" pad tag attr) |> ignore
    | JBool b -> out.AppendLine(sprintf "%s<%s%s>%b</%s>" pad tag attr b tag) |> ignore
    | JNumber n -> out.AppendLine(sprintf "%s<%s%s>%s</%s>" pad tag attr n tag) |> ignore
    | JString s -> out.AppendLine(sprintf "%s<%s%s>%s</%s>" pad tag attr (escapeXml s) tag) |> ignore
    | JObject fields ->
        out.AppendLine(sprintf "%s<%s%s>" pad tag attr) |> ignore
        for (key, item) in fields do
            write out key item (depth + 1) ""
        out.AppendLine(sprintf "%s</%s>" pad tag) |> ignore
    | JArray items ->
        out.AppendLine(sprintf "%s<%s%s>" pad tag attr) |> ignore
        items |> List.iteri (fun i item -> write out "item" item (depth + 1) (sprintf "index=\"%d\"" i))
        out.AppendLine(sprintf "%s</%s>" pad tag) |> ignore

let run (argv: string[]) =
    if argv.Length < 2 then
        printfn "Использование: dotnet fsi json2xml.fsx <вход.json> <выход.xml>"
        1
    else
        try
            let text = File.ReadAllText(argv.[0])
            let tree = parse text
            let out = StringBuilder()
            out.AppendLine("<?xml version=\"1.0\" encoding=\"utf-8\"?>") |> ignore
            write out "root" tree 0 ""
            File.WriteAllText(argv.[1], out.ToString())
            printfn "Узлов обработано: %d" nodes
            printfn "Записано в %s" argv.[1]
            0
        with
        | JsonError(message, at) ->
            printfn "Ошибка разбора: %s (позиция %d)" message at
            1
        | :? FileNotFoundException ->
            printfn "не найден файл %s" argv.[0]
            1

run (fsi.CommandLineArgs |> Array.skip 1) |> ignore
