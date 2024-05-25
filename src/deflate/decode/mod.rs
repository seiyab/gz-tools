use std;
use std::iter;

struct Deflate {
    blocks: Vec<Block>,
}

impl Deflate {
    pub fn decode<I: iter::Iterator<Item = u8>>(deflate: &mut I) -> Result<Self> {
        let mut blocks = Vec::new();
        let b = Block::decode(deflate)?;
        blocks.push(b);
        return Ok(Self { blocks: blocks });
    }
}

enum Block {
    Raw(RawBlock),
}

impl Block {
    fn decode<I: iter::Iterator<Item = u8>>(it: &mut I) -> Result<Self> {
        let mut p = it.peekable();
        let head = p.next().ok_or(Error::new("Unexpected EOF"))?;
        let bfinal = head & 0x01;
        let btype = (head >> 1) & 0x03;

        if bfinal != 1 {
            return Err(Error::new("Unsupported bfinal"));
        }

        match btype {
            0 => {
                let raw = RawBlock::decode(&mut p)?;
                return Ok(Block::Raw(raw));
            }
            _ => {
                return Err(Error::new("Unsupported block type"));
            }
        }
    }
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
        if let Block::Raw(r) = &d.blocks[0] {
            assert_eq!(r.data.len(), 0);
        } else {
            panic!("Unexpected block type");
        }
    }
}
