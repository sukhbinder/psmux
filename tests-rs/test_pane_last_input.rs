// `#{pane_last_input}` — the human-text-keystroke classifier that gates the
// per-pane last-input timestamp. Only printable text (no control codes, no
// Ctrl/Alt) marks "a human typed", so Enter / navigation / shortcuts and
// modified chords don't count. This is what keeps the signal "human typing",
// distinct from injected input (send-keys takes a different path entirely).

use crate::input::is_human_text_key;
use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};

fn k(code: KeyCode, mods: KeyModifiers) -> KeyEvent {
    KeyEvent::new(code, mods)
}

#[test]
fn printable_text_counts() {
    assert!(is_human_text_key(&k(KeyCode::Char('a'), KeyModifiers::NONE)));
    assert!(is_human_text_key(&k(KeyCode::Char('Z'), KeyModifiers::SHIFT))); // capitals
    assert!(is_human_text_key(&k(KeyCode::Char(' '), KeyModifiers::NONE))); // space is text
    assert!(is_human_text_key(&k(KeyCode::Char('é'), KeyModifiers::NONE))); // non-ASCII
}

#[test]
fn control_nav_and_modified_do_not_count() {
    assert!(!is_human_text_key(&k(KeyCode::Char('c'), KeyModifiers::CONTROL))); // Ctrl-C
    assert!(!is_human_text_key(&k(KeyCode::Char('x'), KeyModifiers::ALT))); // Alt-x
    assert!(!is_human_text_key(&k(KeyCode::Enter, KeyModifiers::NONE)));
    assert!(!is_human_text_key(&k(KeyCode::Tab, KeyModifiers::NONE)));
    assert!(!is_human_text_key(&k(KeyCode::Backspace, KeyModifiers::NONE)));
    assert!(!is_human_text_key(&k(KeyCode::Left, KeyModifiers::NONE))); // navigation
    assert!(!is_human_text_key(&k(KeyCode::F(9), KeyModifiers::NONE))); // function key
}
