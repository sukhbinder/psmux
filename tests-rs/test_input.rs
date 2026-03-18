use super::*;
use crossterm::event::{KeyCode, KeyEvent, KeyEventKind, KeyEventState, KeyModifiers};

/// Helper: build a KeyEvent with the given code and modifiers.
fn key(code: KeyCode, modifiers: KeyModifiers) -> KeyEvent {
    KeyEvent {
        code,
        modifiers,
        kind: KeyEventKind::Press,
        state: KeyEventState::NONE,
    }
}

// ── AltGr characters (Ctrl+Alt on Windows) should be forwarded verbatim ──

#[test]
fn altgr_backslash_german_layout() {
    // German: AltGr+ß → '\'   reported as Ctrl+Alt+'\'
    let ev = key(KeyCode::Char('\\'), KeyModifiers::CONTROL | KeyModifiers::ALT);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, b"\\", "AltGr+backslash must produce literal backslash");
}

#[test]
fn altgr_at_sign_german_layout() {
    // German: AltGr+Q → '@'   reported as Ctrl+Alt+'@'
    let ev = key(KeyCode::Char('@'), KeyModifiers::CONTROL | KeyModifiers::ALT);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, b"@", "AltGr+@ must produce literal @");
}

#[test]
fn altgr_open_curly_brace() {
    // German: AltGr+7 → '{'   reported as Ctrl+Alt+'{'
    let ev = key(KeyCode::Char('{'), KeyModifiers::CONTROL | KeyModifiers::ALT);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, b"{", "AltGr+{{ must produce literal {{");
}

#[test]
fn altgr_close_curly_brace() {
    // German: AltGr+0 → '}'
    let ev = key(KeyCode::Char('}'), KeyModifiers::CONTROL | KeyModifiers::ALT);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, b"}", "AltGr+}} must produce literal }}");
}

#[test]
fn altgr_open_bracket() {
    // German: AltGr+8 → '['
    let ev = key(KeyCode::Char('['), KeyModifiers::CONTROL | KeyModifiers::ALT);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, b"[", "AltGr+[ must produce literal [");
}

#[test]
fn altgr_close_bracket() {
    // German: AltGr+9 → ']'
    let ev = key(KeyCode::Char(']'), KeyModifiers::CONTROL | KeyModifiers::ALT);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, b"]", "AltGr+] must produce literal ]");
}

#[test]
fn altgr_pipe() {
    // German: AltGr+< → '|'
    let ev = key(KeyCode::Char('|'), KeyModifiers::CONTROL | KeyModifiers::ALT);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, b"|", "AltGr+| must produce literal |");
}

#[test]
fn altgr_tilde() {
    // German: AltGr++ → '~'
    let ev = key(KeyCode::Char('~'), KeyModifiers::CONTROL | KeyModifiers::ALT);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, b"~", "AltGr+~ must produce literal ~");
}

#[test]
fn altgr_euro_sign() {
    // German: AltGr+E → '€'   (multi-byte UTF-8)
    let ev = key(KeyCode::Char('€'), KeyModifiers::CONTROL | KeyModifiers::ALT);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, "€".as_bytes(), "AltGr+euro must produce UTF-8 euro sign");
}

#[test]
fn altgr_dollar_czech_layout() {
    // Czech: AltGr produces '$'
    let ev = key(KeyCode::Char('$'), KeyModifiers::CONTROL | KeyModifiers::ALT);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, b"$", "AltGr+$ must produce literal $");
}

// ── Genuine Ctrl+Alt+letter must still produce ESC + ctrl-char ──

#[test]
fn ctrl_alt_a_is_esc_ctrl_a() {
    let ev = key(KeyCode::Char('a'), KeyModifiers::CONTROL | KeyModifiers::ALT);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, vec![0x1b, 0x01], "Ctrl+Alt+a → ESC + ^A");
}

#[test]
fn ctrl_alt_c_is_esc_ctrl_c() {
    let ev = key(KeyCode::Char('c'), KeyModifiers::CONTROL | KeyModifiers::ALT);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, vec![0x1b, 0x03], "Ctrl+Alt+c → ESC + ^C");
}

#[test]
fn ctrl_alt_z_is_esc_ctrl_z() {
    let ev = key(KeyCode::Char('z'), KeyModifiers::CONTROL | KeyModifiers::ALT);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, vec![0x1b, 0x1a], "Ctrl+Alt+z → ESC + ^Z");
}

// ── Plain characters / other modifier combos (regression checks) ──

#[test]
fn plain_char_no_modifiers() {
    let ev = key(KeyCode::Char('a'), KeyModifiers::NONE);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, b"a");
}

#[test]
fn alt_a_produces_esc_a() {
    let ev = key(KeyCode::Char('a'), KeyModifiers::ALT);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, b"\x1ba");
}

#[test]
fn ctrl_a_produces_soh() {
    let ev = key(KeyCode::Char('a'), KeyModifiers::CONTROL);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, vec![0x01]); // ^A = SOH
}

#[test]
fn plain_backslash_no_modifiers() {
    let ev = key(KeyCode::Char('\\'), KeyModifiers::NONE);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, b"\\");
}

// ── Modified Enter key tests (PR #115) ──

#[test]
fn plain_enter_produces_cr() {
    let ev = key(KeyCode::Enter, KeyModifiers::NONE);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, b"\r", "plain Enter must produce CR");
}

#[test]
fn shift_enter_produces_correct_encoding() {
    let ev = key(KeyCode::Enter, KeyModifiers::SHIFT);
    let bytes = encode_key_event(&ev).unwrap();
    #[cfg(windows)]
    assert_eq!(bytes, b"\x1b\r", "Shift+Enter on Windows must produce ESC+CR for ConPTY");
    #[cfg(not(windows))]
    assert_eq!(bytes, b"\x1b[13;2~", "Shift+Enter must produce CSI 13;2~");
}

#[test]
fn ctrl_enter_produces_csi_13_5() {
    let ev = key(KeyCode::Enter, KeyModifiers::CONTROL);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, b"\x1b[13;5~", "Ctrl+Enter must produce CSI 13;5~");
}

#[test]
fn ctrl_shift_enter_produces_csi_13_6() {
    let ev = key(KeyCode::Enter, KeyModifiers::CONTROL | KeyModifiers::SHIFT);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, b"\x1b[13;6~", "Ctrl+Shift+Enter must produce CSI 13;6~");
}

#[test]
fn alt_enter_produces_correct_encoding() {
    let ev = key(KeyCode::Enter, KeyModifiers::ALT);
    let bytes = encode_key_event(&ev).unwrap();
    #[cfg(windows)]
    assert_eq!(bytes, b"\x1b\r", "Alt+Enter on Windows must produce ESC+CR for ConPTY");
    #[cfg(not(windows))]
    assert_eq!(bytes, b"\x1b[13;3~", "Alt+Enter must produce CSI 13;3~");
}

// ── parse_modified_special_key tests (PR #115) ──

#[test]
fn parse_shift_enter() {
    assert_eq!(parse_modified_special_key("S-Enter"), Some("\x1b[13;2~".to_string()));
}

#[test]
fn parse_ctrl_enter() {
    assert_eq!(parse_modified_special_key("C-Enter"), Some("\x1b[13;5~".to_string()));
}

#[test]
fn parse_ctrl_shift_enter() {
    assert_eq!(parse_modified_special_key("C-S-Enter"), Some("\x1b[13;6~".to_string()));
}

#[test]
fn parse_plain_enter_returns_none() {
    assert_eq!(parse_modified_special_key("enter"), None, "no modifiers should return None");
}

#[test]
fn parse_shift_left_works() {
    // Regression: S-Left was broken because m started at 1 and S- did m|=1 (no-op)
    assert_eq!(parse_modified_special_key("S-Left"), Some("\x1b[1;2D".to_string()));
}

#[test]
fn parse_ctrl_tab_unchanged() {
    assert_eq!(parse_modified_special_key("C-Tab"), Some("\x1b[9;5~".to_string()));
}

#[test]
fn parse_ctrl_left_unchanged() {
    assert_eq!(parse_modified_special_key("C-Left"), Some("\x1b[1;5D".to_string()));
}

// ── PR #131: paste line-ending normalization tests ──

/// Helper: capture what write_paste_chunked writes to a Vec<u8>.
fn capture_paste(text: &[u8], bracket: bool) -> Vec<u8> {
    let mut buf: Vec<u8> = Vec::new();
    super::write_paste_chunked(&mut buf, text, bracket);
    buf
}

#[test]
fn paste_lf_normalized_to_cr() {
    // Multi-line paste with LF line endings should produce CR
    let input = b"line1\nline2\nline3";
    let output = capture_paste(input, false);
    assert_eq!(output, b"line1\rline2\rline3",
        "bare LF must be normalized to CR for ConPTY; got {:?}", String::from_utf8_lossy(&output));
}

#[test]
fn paste_crlf_normalized_to_cr() {
    // Multi-line paste with CRLF line endings should produce CR (not CRLF)
    let input = b"line1\r\nline2\r\nline3";
    let output = capture_paste(input, false);
    assert_eq!(output, b"line1\rline2\rline3",
        "CRLF must be normalized to CR for ConPTY; got {:?}", String::from_utf8_lossy(&output));
}

#[test]
fn paste_mixed_endings_normalized() {
    // Mixed: some lines LF, some CRLF
    let input = b"a\nb\r\nc";
    let output = capture_paste(input, false);
    assert_eq!(output, b"a\rb\rc",
        "mixed line endings must all become CR; got {:?}", String::from_utf8_lossy(&output));
}

#[test]
fn paste_no_line_endings_unchanged() {
    // Text without newlines should pass through unchanged
    let input = b"hello world";
    let output = capture_paste(input, false);
    assert_eq!(output, b"hello world");
}

#[test]
fn paste_bracket_markers_with_normalization() {
    // Bracketed paste should still wrap with markers AND normalize
    let input = b"a\nb";
    let output = capture_paste(input, true);
    assert_eq!(output, b"\x1b[200~a\rb\x1b[201~",
        "bracketed paste must normalize line endings; got {:?}", String::from_utf8_lossy(&output));
}

// ── PR #132: Shift+Enter ConPTY encoding tests ──

#[cfg(windows)]
#[test]
fn shift_enter_encoding_for_conpty() {
    // On Windows, Shift+Enter should produce \x1b\r (ESC+CR) instead of
    // \x1b[13;2~ which ConPTY drops (code 13 is non-standard).
    let ev = key(KeyCode::Enter, KeyModifiers::SHIFT);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, b"\x1b\r",
        "Shift+Enter on Windows must produce ESC+CR for ConPTY compatibility; got {:?}", bytes);
}

#[cfg(windows)]
#[test]
fn alt_enter_encoding_for_conpty() {
    // Alt+Enter should also produce \x1b\r on Windows
    let ev = key(KeyCode::Enter, KeyModifiers::ALT);
    let bytes = encode_key_event(&ev).unwrap();
    assert_eq!(bytes, b"\x1b\r",
        "Alt+Enter on Windows must produce ESC+CR for ConPTY; got {:?}", bytes);
}
