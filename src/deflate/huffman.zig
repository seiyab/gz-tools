pub const Entry = struct {
    code: usize,
    size: usize,
};

const HuffmanCode = struct {
    entries: []const Entry,

    pub fn init(entries: []const Entry) HuffmanCode {
        return HuffmanCode{
            .entries = entries,
        };
    }

    pub fn encoder() Encoder {
        return Encoder{};
    }
};

const Encoder = struct {};
