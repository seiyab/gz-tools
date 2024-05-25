use std;
use std::iter;

struct Deflate {
    blocks: Vec<Block>,
}

impl Deflate {
    pub fn decode<I: iter::Iterator<Item = u8>>(deflate: &mut I) -> Result<Self> {
        let mut blocks = Vec::new();
        loop {
            let b = Block::decode(deflate)?;
            let bfinal = b.bfinal;
            blocks.push(b);
            if bfinal {
                break;
            }
        }
        return Ok(Self { blocks: blocks });
    }
}

struct Block {
    bfinal: bool,
    body: BlockBody,
}

impl Block {
    fn decode<I: iter::Iterator<Item = u8>>(it: &mut I) -> Result<Self> {
        let mut p = it.peekable();
        let head = p.peek().ok_or(Error::new("Unexpected EOF"))?;
        let bfinal = head & 0x01;
        let btype = (head >> 1) & 0x03;

        match btype {
            0 => {
                _ = p.next();
                let raw = RawBlock::decode(&mut p)?;
                let body = BlockBody::Raw(raw);
                return Ok(Self {
                    bfinal: bfinal == 1,
                    body: body,
                });
            }
            _ => {
                return Err(Error::new("Unsupported block type"));
            }
        }
    }
}

enum BlockBody {
    Raw(RawBlock),
}

struct RawBlock {
    data: Vec<u8>,
}

impl RawBlock {
    fn decode<I: iter::Iterator<Item = u8>>(p: &mut I) -> Result<Self> {
        let len0 = p.next().unwrap() as usize;
        let len1 = p.next().unwrap() as usize;
        let len = len0 | (len1 << 8);
        let nlen0 = p.next().unwrap() as usize;
        let nlen1 = p.next().unwrap() as usize;
        let nlen = nlen0 | (nlen1 << 8);
        if (len ^ nlen) != 0xFFFF {
            return Err(Error::new("Invalid length"));
        }
        let mut data = Vec::new();
        for _ in 0..len {
            data.push(p.next().unwrap());
        }
        return Ok(Self { data: data });
    }
}

type Result<T> = std::result::Result<T, Error>;

#[derive(Debug)]
struct Error {
    message: String,
}

impl Error {
    fn new(message: &str) -> Self {
        return Self {
            message: message.to_string(),
        };
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_decode() {
        let deflate: Vec<u8> = vec![0x01, 0x00, 0x00, 0xff, 0xff];
        let d = Deflate::decode(&mut deflate.iter().copied()).unwrap();
        assert_eq!(d.blocks.len(), 1);
        if let BlockBody::Raw(r) = &d.blocks[0].body {
            assert_eq!(r.data.len(), 0);
        } else {
            panic!("Unexpected block type");
        }
    }
}
