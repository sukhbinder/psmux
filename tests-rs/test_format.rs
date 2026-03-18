use super::*;

fn mock_app() -> AppState {
    let mut app = AppState::new("test_session".to_string());
    app.window_base_index = 0;
    app
}

#[test]
fn test_literal_modifier() {
    let app = mock_app();
    assert_eq!(expand_expression("l:hello", &app, 0), "hello");
}

#[test]
fn test_trim_modifier() {
    let app = mock_app();
    let result = expand_expression("=3:session_name", &app, 0);
    assert_eq!(result, "tes");
}

#[test]
fn test_trim_negative() {
    let app = mock_app();
    let result = expand_expression("=-3:session_name", &app, 0);
    assert_eq!(result, "ion");
}

#[test]
fn test_basename() {
    let app = mock_app();
    let val = apply_modifier(&Modifier::Basename, "/usr/src/tmux", &app, 0);
    assert_eq!(val, "tmux");
}

#[test]
fn test_dirname() {
    let app = mock_app();
    let val = apply_modifier(&Modifier::Dirname, "/usr/src/tmux", &app, 0);
    assert_eq!(val, "/usr/src");
}

#[test]
fn test_pad() {
    let app = mock_app();
    let val = apply_modifier(&Modifier::Pad(10), "foo", &app, 0);
    assert_eq!(val, "foo       ");
    let val = apply_modifier(&Modifier::Pad(-10), "foo", &app, 0);
    assert_eq!(val, "       foo");
}

#[test]
fn test_substitute() {
    let app = mock_app();
    let val = apply_modifier(
        &Modifier::Substitute { pattern: "foo".into(), replacement: "bar".into(), case_insensitive: false },
        "foobar", &app, 0
    );
    assert_eq!(val, "barbar");
}

#[test]
fn test_math_add() {
    let app = mock_app();
    let val = apply_modifier(
        &Modifier::MathExpr { op: '+', floating: false, decimals: 0 },
        "3,5", &app, 0
    );
    assert_eq!(val, "8");
}

#[test]
fn test_math_float_div() {
    let app = mock_app();
    let val = apply_modifier(
        &Modifier::MathExpr { op: '/', floating: true, decimals: 4 },
        "10,3", &app, 0
    );
    assert_eq!(val, "3.3333");
}

#[test]
fn test_boolean_or() {
    let app = mock_app();
    assert_eq!(expand_expression("||:1,0", &app, 0), "1");
    assert_eq!(expand_expression("||:0,0", &app, 0), "0");
}

#[test]
fn test_boolean_and() {
    let app = mock_app();
    assert_eq!(expand_expression("&&:1,1", &app, 0), "1");
    assert_eq!(expand_expression("&&:1,0", &app, 0), "0");
}

#[test]
fn test_comparison_eq() {
    let app = mock_app();
    assert_eq!(expand_expression("==:version,version", &app, 0), "1");
}

#[test]
fn test_glob_match_fn() {
    assert!(glob_match("*foo*", "barfoobar", false));
    assert!(!glob_match("*foo*", "barbaz", false));
    assert!(glob_match("*FOO*", "barfoobar", true));
}

#[test]
fn test_quote() {
    let app = mock_app();
    let val = apply_modifier(&Modifier::Quote, "(hello)", &app, 0);
    assert_eq!(val, "\\(hello\\)");
}
