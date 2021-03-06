use std::fmt;
use std::fs;
use std::io;
use std::path::{Path, PathBuf};
use std::str::Chars;

/// A Brite source code document. Source code is represented as text and turned into an AST through
/// the process of lexing and parsing. This object contains metadata about a source document
/// including the document’s URI, the full document text, and information for determining the
/// placement of source positions.
pub struct Document {
    /// The path to the document in the file system.
    path: PathBuf,
    /// The document’s contents as a UTF-8 string.
    text: String,
    /// Locations in our document where new lines begin. New lines are created by `\n`, `\r\n`,
    /// and `\r`.
    lines: Vec<Position>,
}

impl Document {
    /// Reads a file from the file system and creates a document out of it.
    pub fn read(path: PathBuf) -> Result<Self, io::Error> {
        let text = fs::read_to_string(&path)?;
        Ok(Document::new(path, text))
    }

    /// Creates a new source code document.
    pub fn new(path: PathBuf, text: String) -> Self {
        // Calculate all the line boundaries in our source code.
        let lines = {
            let mut lines = Vec::new();
            let mut i = 0;
            let bytes = text.as_bytes();
            while i < bytes.len() {
                let byte = bytes[i];
                i += 1;
                if byte == b'\n' {
                    lines.push(Position(i as u32));
                } else if byte == b'\r' {
                    // If the next byte is `\n` then skip it. We only want to add a single line for
                    // the sequence `\r\n`.
                    if i + 1 < bytes.len() && bytes[i] == b'\n' {
                        i += 1;
                    }
                    lines.push(Position(i as u32));
                }
            }
            lines
        };
        // Return the created document.
        Document { path, text, lines }
    }

    /// Returns the path to this document.
    pub fn path(&self) -> &Path {
        &self.path
    }

    /// The position our document starts at.
    pub fn start(&self) -> Position {
        Position(0)
    }

    /// The position our document ends at.
    pub fn end(&self) -> Position {
        Position(self.text.len() as u32)
    }

    /// Gets an iterator of characters in the source document along with the position of
    /// that character.
    pub fn chars(&self) -> DocumentChars {
        DocumentChars {
            chars: self.text.chars(),
            position: 0,
            lookahead: DocumentCharsLookahead::None,
        }
    }
}

/// An iterator of characters in a Brite source document. We don’t implement the `Iterator` trait
/// for this struct since it forces composition on us. We don’t care about iterator composition in
/// our parser. We’d prefer domain specific iterators at every step along the way.
///
/// Let’s illustrate what the methods of `DocumentChars` do. In the following diagram, the caret
/// (`^`) represents the current character returned by `DocumentChars::lookahead()`. The bar (`|`)
/// represents the current position returned by  `DocumentChars::position()`.
///
/// ```txt
/// |abcdef
///  ^
/// ```
///
/// We start by pointing at the first character. Calling `DocumentChars::advance()` returns `a` and
/// advances our iterator to the next character.
///
/// ```txt
/// a|bcdef
///   ^
/// ```
///
/// This continues until we reach the last character.
///
/// ```txt
/// abcde|f
///       ^
/// ```
///
/// Calling `DocumentChars::advance()` here will return `f` and puts us in the following state.
///
/// ```txt
/// abcdef|
///        ^
/// ```
///
/// Now calling `DocumentChars::advance()` will return `None` and will continue to return `None`
/// every time it is called. The position returned by `DocumentChars::position()` is the final
/// position in our document.
pub struct DocumentChars<'a> {
    chars: Chars<'a>,
    position: u32,
    lookahead: DocumentCharsLookahead,
}

/// Lookahead state for `DocumentChars`.
enum DocumentCharsLookahead {
    None,
    Lookahead1(Option<char>),
    Lookahead2(Option<char>, Option<char>),
}

impl<'a> DocumentChars<'a> {
    /// Consumes a character and advances our iterator to the next character. To look at the next
    /// character without consuming it, call `DocumentChars::lookahead()`.
    ///
    /// When `None` is returned we’ve reached the end of our document’s characters. Calling
    /// `DocumentChars::advance()` will only return `None` now.
    pub fn advance(&mut self) -> Option<char> {
        let next = match self.lookahead {
            DocumentCharsLookahead::None => self.chars.next(),
            DocumentCharsLookahead::Lookahead1(lookahead1) => {
                self.lookahead = DocumentCharsLookahead::None;
                lookahead1
            }
            DocumentCharsLookahead::Lookahead2(lookahead1, lookahead2) => {
                self.lookahead = DocumentCharsLookahead::Lookahead1(lookahead2);
                lookahead1
            }
        };
        if let Some(c) = next {
            self.position += c.len_utf8() as u32;
        }
        next
    }

    /// Looks at the next character without advancing the iterator.
    pub fn lookahead(&mut self) -> Option<char> {
        match self.lookahead {
            DocumentCharsLookahead::None => {
                let lookahead1 = self.chars.next();
                self.lookahead = DocumentCharsLookahead::Lookahead1(lookahead1);
                lookahead1
            }
            DocumentCharsLookahead::Lookahead1(lookahead1) => lookahead1,
            DocumentCharsLookahead::Lookahead2(lookahead1, _) => lookahead1,
        }
    }

    /// Looks two characters ahead without advancing the iterator.
    pub fn lookahead2(&mut self) -> Option<char> {
        match self.lookahead {
            DocumentCharsLookahead::None => {
                let lookahead1 = self.chars.next();
                let lookahead2 = self.chars.next();
                self.lookahead = DocumentCharsLookahead::Lookahead2(lookahead1, lookahead2);
                lookahead2
            }
            DocumentCharsLookahead::Lookahead1(lookahead1) => {
                let lookahead2 = self.chars.next();
                self.lookahead = DocumentCharsLookahead::Lookahead2(lookahead1, lookahead2);
                lookahead2
            }
            DocumentCharsLookahead::Lookahead2(_, lookahead2) => lookahead2,
        }
    }

    /// Returns the position between the previous character and the next character. See the
    /// documentation on `DocumentChars` for more information.
    pub fn position(&self) -> Position {
        Position(self.position)
    }

    /// Advance if the character we are advancing is equal to the provided character. Returns true
    /// if we were able to advance.
    pub fn advance_char(&mut self, c: char) -> bool {
        if self.lookahead() == Some(c) {
            self.advance();
            true
        } else {
            false
        }
    }

    /// Runs a test function on the lookahead character. If the lookahead character is `None` we
    /// return false.
    pub fn lookahead_is<F>(&mut self, f: F) -> bool
    where
        F: FnOnce(char) -> bool,
    {
        self.lookahead().map(f).unwrap_or(false)
    }
}

/// A position between two characters in a Brite source code document. This is the same as a
/// position in the [Language Server Protocol (LSP)][1]. To get the line and character locations of
/// a position you need a `Document` object.
///
/// Some examples of positions where `|` represents a position:
///
/// - `|abcdef`: Here the position is 0 since it is at the very beginning of our string.
/// - `a|bcdef`: Here the position is 1 since it is between our first and second characters.
/// - `abc|def`: Here the position is 3 since it is between our third and fourth characters.
/// - `abcdef|`: Here the position is 6 since it is after our sixth character at the end.
///
/// We need to keep this small as an AST will contain a _lot_ of positions. Currently a 32 bit
/// unsigned integer which represents the _byte_ offset into the source document.
///
/// [1]: https://microsoft.github.io/language-server-protocol/specification
#[derive(Copy, Clone, Eq, Ord, PartialEq, PartialOrd)]
pub struct Position(u32);

impl Position {
    /// The index of the position in a UTF-8 string.
    pub fn utf8_index(&self) -> u32 {
        self.0
    }

    /// Gets the zero-based line number of this position in the provided document. A new line is
    /// created by `\n`, `\r\n`, or `\r`.
    pub fn line(&self, document: &Document) -> usize {
        match document.lines.binary_search(self) {
            Ok(line) => line + 1,
            Err(line) => line,
        }
    }

    /// Gets the zero-based character number of this position in the provided document. As per the
    /// [LSP][1] specification, character offsets are measured in UTF-16 code units.
    ///
    /// [1]: https://microsoft.github.io/language-server-protocol/specification
    pub fn character(&self, document: &Document) -> usize {
        let bytes = document.text.as_bytes();
        let line = self.line(document);
        let start = if line == 0 {
            0
        } else {
            document.lines[line - 1].0 as usize
        };
        let end = self.0 as usize;
        if start >= bytes.len() {
            end - bytes.len()
        } else if end > bytes.len() {
            let line_bytes = &document.text.as_bytes()[start..];
            (end - bytes.len()) + String::from_utf8_lossy(line_bytes)
                .chars()
                .map(|c| c.len_utf16())
                .sum::<usize>()
        } else {
            let line_bytes = &document.text.as_bytes()[start..end];
            String::from_utf8_lossy(line_bytes)
                .chars()
                .map(|c| c.len_utf16())
                .sum()
        }
    }
}

impl fmt::Debug for Position {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "Position({})", self.0)
    }
}

/// A range in a text document expressed as start and end positions. A range is comparable to a
/// selection in an editor. Therefore the end position is exclusive.
///
/// We need to keep this small as an AST will contain a _lot_ of ranges. Currently 64 bits.
#[derive(Clone, Copy, Eq, PartialEq)]
pub struct Range {
    /// The range’s start position.
    start: Position,
    /// The length of characters covered by this range.
    length: u32,
}

impl Range {
    /// Creates a new range. `length` is the number of UTF-8 code units spanned by the range.
    pub fn new(start: Position, length: u32) -> Self {
        Range { start, length }
    }

    /// Creates a range between two positions.
    pub fn between(start: Position, end: Position) -> Self {
        if start <= end {
            let length = end.0 - start.0;
            Range { start, length }
        } else {
            let (start, end) = (end, start);
            let length = end.0 - start.0;
            Range { start, length }
        }
    }

    /// Returns the start position of our range.
    pub fn start(&self) -> Position {
        self.start
    }

    /// Returns the end position of our range. Will always be greater than or equal to the start
    /// position. Remember that range is not inclusive.
    pub fn end(&self) -> Position {
        Position(self.start.0 + self.length)
    }
}

impl fmt::Debug for Range {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "Range({}, {})", self.start.0, self.length)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn document_lines() {
        let document = Document::new(
            "/path/to/document.txt".into(),
            "abc\ndef\rghi\r\njkl".into(),
        );
        assert_eq!(document.lines, vec![Position(4), Position(8), Position(13)]);
    }

    #[test]
    fn position_line() {
        let document = Document::new(
            "/path/to/document.txt".into(),
            "abc\ndef\rghi\r\njkl".into(),
        );
        assert_eq!(document.lines, vec![Position(4), Position(8), Position(13)]);
        assert_eq!(Position(0).line(&document), 0);
        assert_eq!(Position(1).line(&document), 0);
        assert_eq!(Position(2).line(&document), 0);
        assert_eq!(Position(3).line(&document), 0);
        assert_eq!(Position(4).line(&document), 1);
        assert_eq!(Position(5).line(&document), 1);
        assert_eq!(Position(6).line(&document), 1);
        assert_eq!(Position(7).line(&document), 1);
        assert_eq!(Position(8).line(&document), 2);
        assert_eq!(Position(9).line(&document), 2);
        assert_eq!(Position(10).line(&document), 2);
        assert_eq!(Position(11).line(&document), 2);
        assert_eq!(Position(12).line(&document), 2);
        assert_eq!(Position(13).line(&document), 3);
        assert_eq!(Position(14).line(&document), 3);
        assert_eq!(Position(15).line(&document), 3);
        assert_eq!(Position(16).line(&document), 3);
        assert_eq!(Position(17).line(&document), 3);
        assert_eq!(Position(500).line(&document), 3);

        let document = Document::new("/path/to/document.txt".into(), "abc\n".into());
        assert_eq!(document.lines, vec![Position(4)]);
        assert_eq!(Position(0).line(&document), 0);
        assert_eq!(Position(1).line(&document), 0);
        assert_eq!(Position(2).line(&document), 0);
        assert_eq!(Position(3).line(&document), 0);
        assert_eq!(Position(4).line(&document), 1);
        assert_eq!(Position(5).line(&document), 1);
        assert_eq!(Position(6).line(&document), 1);
        assert_eq!(Position(500).line(&document), 1);

        let document = Document::new("/path/to/document.txt".into(), "\nabc".into());
        assert_eq!(document.lines, vec![Position(1)]);
        assert_eq!(Position(0).line(&document), 0);
        assert_eq!(Position(1).line(&document), 1);
        assert_eq!(Position(2).line(&document), 1);
        assert_eq!(Position(3).line(&document), 1);
        assert_eq!(Position(4).line(&document), 1);
        assert_eq!(Position(5).line(&document), 1);
        assert_eq!(Position(6).line(&document), 1);
        assert_eq!(Position(500).line(&document), 1);

        let document = Document::new("/path/to/document.txt".into(), "\nabc\n".into());
        assert_eq!(document.lines, vec![Position(1), Position(5)]);
        assert_eq!(Position(0).line(&document), 0);
        assert_eq!(Position(1).line(&document), 1);
        assert_eq!(Position(2).line(&document), 1);
        assert_eq!(Position(3).line(&document), 1);
        assert_eq!(Position(4).line(&document), 1);
        assert_eq!(Position(5).line(&document), 2);
        assert_eq!(Position(6).line(&document), 2);
        assert_eq!(Position(7).line(&document), 2);
        assert_eq!(Position(500).line(&document), 2);
    }

    #[test]
    fn position_character() {
        let document = Document::new("/path/to/document.txt".into(), "abc\ndef".into());
        assert_eq!(document.lines, vec![Position(4)]);
        assert_eq!(Position(0).character(&document), 0);
        assert_eq!(Position(1).character(&document), 1);
        assert_eq!(Position(2).character(&document), 2);
        assert_eq!(Position(3).character(&document), 3);
        assert_eq!(Position(4).character(&document), 0);
        assert_eq!(Position(5).character(&document), 1);
        assert_eq!(Position(6).character(&document), 2);
        assert_eq!(Position(7).character(&document), 3);
        assert_eq!(Position(8).character(&document), 4);
        assert_eq!(Position(500).character(&document), 496);

        let document = Document::new("/path/to/document.txt".into(), "abc\n".into());
        assert_eq!(document.lines, vec![Position(4)]);
        assert_eq!(Position(0).character(&document), 0);
        assert_eq!(Position(1).character(&document), 1);
        assert_eq!(Position(2).character(&document), 2);
        assert_eq!(Position(3).character(&document), 3);
        assert_eq!(Position(4).character(&document), 0);
        assert_eq!(Position(5).character(&document), 1);
        assert_eq!(Position(6).character(&document), 2);
        assert_eq!(Position(7).character(&document), 3);
        assert_eq!(Position(8).character(&document), 4);
        assert_eq!(Position(500).character(&document), 496);

        assert_eq!("\u{0041}".len(), 1);
        assert_eq!("\u{00DF}".len(), 2);
        assert_eq!("\u{4E01}".len(), 3);
        assert_eq!("\u{1F701}".len(), 4);

        let document = Document::new(
            "/path/to/document.txt".into(),
            "\u{0041}\u{00DF}\u{4E01}\u{1F701}".into(),
        );
        assert_eq!(document.lines, vec![]);
        assert_eq!(Position(0).character(&document), 0);
        assert_eq!(Position(1).character(&document), 1);
        assert_eq!(Position(2).character(&document), 2);
        assert_eq!(Position(3).character(&document), 2);
        assert_eq!(Position(4).character(&document), 3);
        assert_eq!(Position(5).character(&document), 3);
        assert_eq!(Position(6).character(&document), 3);
        assert_eq!(Position(7).character(&document), 4);
        assert_eq!(Position(8).character(&document), 4);
        assert_eq!(Position(9).character(&document), 4);
        assert_eq!(Position(10).character(&document), 5);
        assert_eq!(Position(11).character(&document), 6);
        assert_eq!(Position(12).character(&document), 7);
        assert_eq!(Position(13).character(&document), 8);
        assert_eq!(Position(14).character(&document), 9);
        assert_eq!(Position(500).character(&document), 495);
    }

    #[test]
    fn document_chars_end() {
        let document = Document::new("/path/to/document.txt".into(), "abc".into());
        let mut chars = document.chars();
        assert_eq!(chars.advance(), Some('a'));
        assert_eq!(chars.advance(), Some('b'));
        assert_eq!(chars.advance(), Some('c'));
        assert_eq!(chars.advance(), None);
        assert_eq!(chars.advance(), None);
        assert_eq!(chars.advance(), None);
    }

    #[test]
    fn document_chars_end_panic_lookahead() {
        let document = Document::new("/path/to/document.txt".into(), "abc".into());
        let mut chars = document.chars();
        assert_eq!(chars.lookahead(), Some('a'));
        assert_eq!(chars.lookahead(), Some('a'));
        assert_eq!(chars.advance(), Some('a'));
        assert_eq!(chars.lookahead(), Some('b'));
        assert_eq!(chars.lookahead(), Some('b'));
        assert_eq!(chars.advance(), Some('b'));
        assert_eq!(chars.lookahead(), Some('c'));
        assert_eq!(chars.lookahead(), Some('c'));
        assert_eq!(chars.advance(), Some('c'));
        assert_eq!(chars.lookahead(), None);
        assert_eq!(chars.lookahead(), None);
        assert_eq!(chars.advance(), None);
        assert_eq!(chars.lookahead(), None);
        assert_eq!(chars.lookahead(), None);
        assert_eq!(chars.advance(), None);
        assert_eq!(chars.lookahead(), None);
        assert_eq!(chars.lookahead(), None);
    }

}
