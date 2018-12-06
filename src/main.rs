extern crate brite;
extern crate unicode_xid;

use brite::source::{parse, Document};
use std::env;
use std::io;
use std::path::PathBuf;

fn main() -> Result<(), io::Error> {
    let mut args = env::args();
    args.next();
    let path = args.next().expect("Expecting a file path.");
    let path = PathBuf::from(&path);
    let document = Document::read(path)?;
    let (diagnostics, _) = parse(&document);
    for diagnostic in diagnostics.iter() {
        println!("{}", diagnostic.to_simple_string(&document));
    }
    Ok(())
}
