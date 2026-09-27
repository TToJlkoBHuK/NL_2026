import std.stdio;
import std.file : exists, getSize, remove;
import std.conv : to;
import std.string : format, strip, split, startsWith;
import std.path : baseName;
import std.algorithm : min;

__gshared uint[256] crcTable;

static this() {
    foreach (i; 0 .. 256) {
        uint value = cast(uint) i;
        foreach (_; 0 .. 8) {
            value = (value & 1) ? (0xEDB88320u ^ (value >> 1)) : (value >> 1);
        }
        crcTable[i] = value;
    }
}

uint crc32(const(ubyte)[] data, uint crc = 0xFFFFFFFFu) {
    foreach (b; data) {
        crc = crcTable[(crc ^ b) & 0xFF] ^ (crc >> 8);
    }
    return crc;
}

void splitFile(string path, size_t chunkSize) {
    if (!exists(path)) {
        writeln("нет такого файла: ", path);
        return;
    }

    auto source = File(path, "rb");
    scope (exit) source.close();

    auto listPath = path ~ ".parts";
    auto list = File(listPath, "w");
    scope (exit) list.close();

    immutable total = getSize(path);
    list.writefln("file %s", baseName(path));
    list.writefln("size %d", total);

    auto buffer = new ubyte[chunkSize];
    size_t index = 0;
    ulong written = 0;

    while (true) {
        auto block = source.rawRead(buffer);
        if (block.length == 0) break;

        index++;
        auto partName = format("%s.part%03d", path, index);
        auto part = File(partName, "wb");
        part.rawWrite(block);
        part.close();

        immutable sum = crc32(block) ^ 0xFFFFFFFFu;
        list.writefln("part %s %d %08x", baseName(partName), block.length, sum);
        writefln("%s  %d байт  crc %08x", baseName(partName), block.length, sum);

        written += block.length;
        if (block.length < chunkSize) break;
    }

    writeln();
    writefln("Частей: %d, байт: %d, описание: %s", index, written, listPath);
}

void joinFile(string listPath, string outPath) {
    if (!exists(listPath)) {
        writeln("нет файла описания: ", listPath);
        return;
    }

    auto list = File(listPath, "r");
    scope (exit) list.close();

    auto output = File(outPath, "wb");
    scope (exit) output.close();

    ulong expected = 0;
    ulong actual = 0;
    size_t broken = 0;
    size_t parts = 0;

    foreach (raw; list.byLine()) {
        auto line = raw.idup.strip();
        if (line.length == 0) continue;

        auto fields = line.split();
        if (fields[0] == "size") {
            expected = to!ulong(fields[1]);
            continue;
        }
        if (fields[0] != "part") continue;

        parts++;
        auto partName = fields[1];
        if (!exists(partName)) {
            writefln("%s  ПОТЕРЯНА", partName);
            broken++;
            continue;
        }

        auto part = File(partName, "rb");
        auto data = new ubyte[cast(size_t) getSize(partName)];
        auto block = part.rawRead(data);
        part.close();

        immutable sum = crc32(block) ^ 0xFFFFFFFFu;
        immutable stored = to!uint(fields[3], 16);

        if (sum != stored) {
            writefln("%s  ПОВРЕЖДЕНА: ожидалось %08x, получено %08x", partName, stored, sum);
            broken++;
        } else {
            writefln("%s  %d байт  crc %08x  ок", partName, block.length, sum);
        }

        output.rawWrite(block);
        actual += block.length;
    }

    writeln();
    writefln("Частей обработано: %d, повреждено или потеряно: %d", parts, broken);
    writefln("Ожидалось байт: %d, собрано: %d", expected, actual);
    writefln("Результат: %s", outPath);
}

int main(string[] args) {
    if (args.length < 3) {
        writeln("Использование:");
        writeln("  split split <файл> [размер части в байтах]");
        writeln("  split join <файл описания> <результат>");
        return 1;
    }

    switch (args[1]) {
    case "split":
        size_t chunk = args.length > 3 ? to!size_t(args[3]) : 1048576;
        splitFile(args[2], chunk);
        break;
    case "join":
        if (args.length < 4) {
            writeln("для join нужны файл описания и имя результата");
            return 1;
        }
        joinFile(args[2], args[3]);
        break;
    default:
        writeln("неизвестный режим: ", args[1]);
        return 1;
    }
    return 0;
}
