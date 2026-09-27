import os, strutils

const BytesPerLine = 16

proc printable(b: byte): char =
  if b >= 32'u8 and b < 127'u8: char(b) else: '.'

proc dump(inPath, outPath: string) =
  var input = open(inPath, fmRead)
  defer: input.close()
  var output = open(outPath, fmWrite)
  defer: output.close()

  var buffer: array[BytesPerLine, byte]
  var offset = 0

  while true:
    let read = input.readBuffer(addr buffer[0], BytesPerLine)
    if read == 0: break

    var hex = ""
    var text = ""
    for i in 0 ..< BytesPerLine:
      if i < read:
        hex.add(toHex(buffer[i].int, 2).toLowerAscii)
        text.add(printable(buffer[i]))
      else:
        hex.add("  ")
      hex.add(' ')

    let line = toHex(offset, 8).toLowerAscii & "  " & hex & " |" & text & "|"
    echo line
    output.writeLine(line)

    offset += read
    if read < BytesPerLine: break

  echo ""
  echo "Обработано байт: ", offset
  echo "Дамп записан в ", outPath

proc restore(dumpPath, outPath: string) =
  var output = open(outPath, fmWrite)
  defer: output.close()

  var total = 0
  for line in lines(dumpPath):
    if line.len == 0: continue
    let barPos = line.find('|')
    let hexPart = if barPos > 0: line[0 ..< barPos] else: line
    let fields = hexPart.splitWhitespace()
    for i in 1 ..< fields.len:
      let value = byte(parseHexInt(fields[i]))
      output.write(char(value))
      total += 1

  echo "Восстановлено байт: ", total
  echo "Файл записан в ", outPath

proc compare(first, second: string) =
  let a = readFile(first)
  let b = readFile(second)
  if a == b:
    echo "Сверка с оригиналом: файлы совпадают побайтово"
  else:
    echo "Сверка с оригиналом: РАСХОЖДЕНИЕ (", a.len, " и ", b.len, " байт)"

when isMainModule:
  let args = commandLineParams()
  if args.len < 3:
    echo "Использование:"
    echo "  hexdump dump <файл> <дамп>"
    echo "  hexdump restore <дамп> <файл> [оригинал для сверки]"
    quit(1)

  case args[0]
  of "dump":
    dump(args[1], args[2])
  of "restore":
    restore(args[1], args[2])
    if args.len > 3:
      compare(args[3], args[2])
  else:
    echo "неизвестный режим: ", args[0]
    quit(1)
