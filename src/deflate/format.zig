const std = @import("std");

pub const Deflate = struct {
    blocks: std.ArrayList(Block),

    pub fn decode(alloc: std.mem.Allocator, data: []const u8) !@This() {
        var blocks = std.ArrayList(Block).init(alloc);

        var idx: usize = 0;
        while (idx < data.len) {
            const bfinal = data[idx] & 0x01 > 0;
            const btype: Btype = @enumFromInt((data[idx] >> 1) & 0x03);

            const b = switch (btype) {
                Btype.Literal => bok: {
                    idx += 1;
                    const len = (@as(usize, @intCast(data[idx + 1])) << 8) | data[idx];
                    // _ = (@as(usize, @intCast(data[idx + 3])) << 8) | data[idx + 2]; // nlen
                    idx += 4;
                    const bits = Bits{ .data = data[idx .. idx + len] };
                    break :bok Block{
                        .bfinal = bfinal,
                        .btype = btype,
                        .data = bits,
                    };
                },
                else => {
                    return error.UnsupportedBtype;
                },
            };
            try blocks.append(b);

            if (b.bfinal) {
                break;
            }
        }

        return .{
            .blocks = blocks,
        };
    }

    pub fn deinit(self: @This()) void {
        self.blocks.deinit();
    }

    const Reader = struct {
        blocks: []const Block,
        current: std.io.AnyReader,
        idx: usize,

        const GR = std.io.GenericReader(*Reader, anyerror, Reader.readFn);

        pub fn reader(self: *@This()) GR {
            return .{
                .context = self,
            };
        }

        fn readFn(self: *@This(), buffer: []u8) anyerror!usize {
            var current = self.current;
            var idx = self.idx;
            while (true) {
                const read = try current.read(buffer);
                if (read > 0) {
                    return read;
                }
                idx += 1;
                if (idx >= self.blocks.len) {
                    return read;
                }
                current = self.blocks[idx].reader().any();
            }
        }
    };

    pub fn reader(self: @This()) Reader {
        return .{
            .blocks = self.blocks.items,
            .current = self.blocks.items[0].reader(),
            .idx = 0,
        };
    }

    pub fn writeTo(self: @This(), writer: std.io.AnyWriter) !void {
        for (self.blocks) |block| {
            const data = block.decode(writer.allocator);
            try writer.write(data);
        }
    }
};

const Block = struct {
    bfinal: bool,
    btype: Btype,
    data: Bits,

    pub fn decode(self: Block, alloc: std.Allocator) ![]const u8 {
        const data = self.data.data;
        return switch (self.btype) {
            Btype.Literal => self.decodeLiteral(alloc, data),
            else => {
                return error.UnsupportedBtype;
            },
        };
    }

    const Reader = struct {
        block: Block,
        idx: usize,

        const GR = std.io.GenericReader(*Reader, anyerror, Reader.readFn);

        pub fn reader(self: *Reader) GR {
            return .{
                .context = self,
            };
        }

        fn readFn(self: *@This(), buffer: []u8) anyerror!usize {
            switch (self.btype) {
                Btype.Literal => {
                    const data = self.data;
                    const sizeToRead = @min(buffer.len, data.data.len - self.idx);
                    for (0..sizeToRead) |i| {
                        buffer[i] = data.data[self.idx + i];
                    }
                    self.idx += sizeToRead;
                    return sizeToRead;
                },
                else => {
                    return error.UnsupportedBtype;
                },
            }
        }
    };

    // pub fn reader(self: @This()) std.io.AnyReader {
    //     return std.io.AnyReader{
    //         .context = &Reader{ .block = self, .idx = 0 },
    //         .readFn = @This().readFn,
    //     };
    // }
    pub fn reader(self: @This()) Reader {
        return .{
            .block = self,
            .idx = 0,
        };
    }

    fn readFn(context: *const anyopaque, buffer: []u8) anyerror!usize {
        const ptr: *const Reader = @alignCast(@ptrCast(context));
        const block = ptr.block;
        switch (block.btype) {
            Btype.Literal => {
                const data = ptr.block.data;
                const sizeToRead = @min(buffer.len, data.data.len - ptr.idx);
                for (0..sizeToRead) |i| {
                    buffer[i] = data.data[ptr.idx + i];
                }
                ptr.idx += sizeToRead;
                return sizeToRead;
            },
            else => {
                return error.UnsupportedBtype;
            },
        }
    }
};

const Btype = enum(u8) {
    Literal = 0,
    Fixed = 1,
    Dynamic = 2,
};

const Symbol = struct {
    code: u32,
    extra: u32,
};

const Bits = struct {
    data: []const u8,
};

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

test "raw" {
    const allocator = std.testing.allocator;
    const deflate = try Deflate.decode(allocator, &testdata);
    defer deflate.deinit();
    const reader = try deflate.reader();
    const result = try reader.readAllAlloc(allocator, 1_000);
    try std.testing.expectEqualSlices(u8, testdata[5..], result);
}
