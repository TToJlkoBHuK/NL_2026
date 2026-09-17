const std = @import("std");

const Op = struct {
    kind: u8,
    pos: usize,
    from: u8,
    to: u8,
};

fn min3(a: usize, b: usize, c: usize) usize {
    var m = a;
    if (b < m) m = b;
    if (c < m) m = c;
    return m;
}

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len < 3) {
        std.debug.print("Использование: levenshtein <строка1> <строка2>\n", .{});
        return;
    }

    const a = args[1];
    const b = args[2];
    const n = a.len;
    const m = b.len;
    const width = m + 1;

    const d = try alloc.alloc(usize, (n + 1) * width);
    defer alloc.free(d);

    var i: usize = 0;
    while (i <= n) : (i += 1) {
        d[i * width] = i;
    }
    var j: usize = 0;
    while (j <= m) : (j += 1) {
        d[j] = j;
    }

    i = 1;
    while (i <= n) : (i += 1) {
        j = 1;
        while (j <= m) : (j += 1) {
            var cost: usize = 1;
            if (a[i - 1] == b[j - 1]) cost = 0;
            d[i * width + j] = min3(
                d[(i - 1) * width + j] + 1,
                d[i * width + j - 1] + 1,
                d[(i - 1) * width + j - 1] + cost,
            );
        }
    }

    std.debug.print("Строка 1: {s}\n", .{a});
    std.debug.print("Строка 2: {s}\n", .{b});
    std.debug.print("Расстояние Левенштейна: {d}\n", .{d[n * width + m]});

    if (n <= 12 and m <= 12) {
        std.debug.print("\nМатрица:\n", .{});
        i = 0;
        while (i <= n) : (i += 1) {
            j = 0;
            while (j <= m) : (j += 1) {
                std.debug.print("{d:>3}", .{d[i * width + j]});
            }
            std.debug.print("\n", .{});
        }
    }

    // обратный проход: из правого нижнего угла к левому верхнему
    const ops = try alloc.alloc(Op, n + m);
    defer alloc.free(ops);

    var count: usize = 0;
    var ci = n;
    var cj = m;
    while (ci > 0 or cj > 0) {
        var diagonal = false;
        if (ci > 0 and cj > 0) {
            var cost: usize = 1;
            if (a[ci - 1] == b[cj - 1]) cost = 0;
            if (d[ci * width + cj] == d[(ci - 1) * width + (cj - 1)] + cost) diagonal = true;
        }

        if (diagonal) {
            if (a[ci - 1] != b[cj - 1]) {
                ops[count] = Op{ .kind = 'r', .pos = ci, .from = a[ci - 1], .to = b[cj - 1] };
                count += 1;
            }
            ci -= 1;
            cj -= 1;
        } else if (ci > 0 and d[ci * width + cj] == d[(ci - 1) * width + cj] + 1) {
            ops[count] = Op{ .kind = 'd', .pos = ci, .from = a[ci - 1], .to = 0 };
            count += 1;
            ci -= 1;
        } else {
            ops[count] = Op{ .kind = 'i', .pos = ci + 1, .from = 0, .to = b[cj - 1] };
            count += 1;
            cj -= 1;
        }
    }

    std.debug.print("\nПоследовательность правок ({d}):\n", .{count});
    var step: usize = 1;
    var k = count;
    while (k > 0) {
        k -= 1;
        const op = ops[k];
        switch (op.kind) {
            'r' => std.debug.print("{d}. замена: позиция {d}, {c} -> {c}\n", .{ step, op.pos, op.from, op.to }),
            'd' => std.debug.print("{d}. удаление: позиция {d}, символ {c}\n", .{ step, op.pos, op.from }),
            else => std.debug.print("{d}. вставка: позиция {d}, символ {c}\n", .{ step, op.pos, op.to }),
        }
        step += 1;
    }
}
