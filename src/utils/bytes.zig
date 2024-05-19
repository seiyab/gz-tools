const std = @import("std");

pub const BytesReader = struct {
    data: []const u8,
    cursor: usize,

    pub fn init(data: []const u8) BytesReader {
        return .{
            .data = data,
            .cursor = 0,
        };
    }

    const Reader = std.io.GenericReader(*BytesReader, anyerror, readFn);

    pub fn reader(self: *BytesReader) Reader {
        return .{
            .context = self,
        };
    }

    fn readFn(self: *BytesReader, buffer: []u8) !usize {
        const it: usize = @min(buffer.len, self.data.len - self.cursor);
        for (0..it) |i| {
            buffer[i] = self.data[self.cursor + i];
        }
        self.cursor += it;
        return it;
    }
};

test "BytesReader" {
    const allocator = std.testing.allocator;
    var br = BytesReader.init("hello");
    var r = br.reader().any();
    const x = try r.readAllAlloc(allocator, 1000);
    defer allocator.free(x);
    try std.testing.expectEqualSlices(u8, "hello", x);
}

const ReadError = error{};

pub const BytesWriter = struct {
    data: std.ArrayList(u8),

    const Writer = std.io.GenericWriter(*BytesWriter, anyerror, writeFn);

    pub fn init(allocator: std.mem.Allocator) BytesWriter {
        const data = std.ArrayList(u8).init(allocator);
        return .{ .data = data };
    }

    pub fn deinit(self: *BytesWriter) void {
        self.data.deinit();
    }

    pub fn writer(self: *@This()) Writer {
        return .{
            .context = self,
        };
    }

    fn writeFn(self: *BytesWriter, bytes: []const u8) anyerror!usize {
        try self.data.appendSlice(bytes);
        return bytes.len;
    }
};

test "BytesWriter" {
    const allocator = std.testing.allocator;
    var writer = BytesWriter.init(allocator);
    defer writer.deinit();
    const w = writer.writer();
    _ = try w.write("hello");
    _ = try w.write("world");
    const data = writer.data;
    try std.testing.expectEqualSlices(u8, "helloworld", data.items);
}
