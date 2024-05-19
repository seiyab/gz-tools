const std = @import("std");
const inflate = std.compress.flate.inflate;
const bytes = @import("./utils/bytes.zig");

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    try st(stdin, stdout);
}

const testdata = [_]u8{
    0x01,
    0x03,
    0x00,
    0xfc,
    0xff,
    0x00,
    0x01,
    0x02,
};

fn st(r: anytype, w: anytype) !void {
    const allocator = std.heap.page_allocator;
    const d: []u8 = try r.readAllAlloc(allocator, 1_000_000);
    try w.writeAll(d);
}

test "check testdata" {
    const allocator = std.testing.allocator;
    var w = bytes.BytesWriter.init(allocator);
    defer w.deinit();
    var r = bytes.BytesReader.init(&testdata);
    try inflate.decompress(.raw, r.reader(), w.writer());
    const out = w.data;
    try std.testing.expectEqualSlices(u8, testdata[5..], out.items);
}

test "st" {
    const allocator = std.testing.allocator;
    var w = bytes.BytesWriter.init(allocator);
    defer w.deinit();
    var r = bytes.BytesReader.init(&testdata);
    try st(r.reader(), w.writer());
    const out = w.data;
    try std.testing.expectEqualSlices(u8, &testdata, out.items);
}
