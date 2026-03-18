use super::should_spawn_warm_server;
use crate::types::AppState;

#[test]
fn warm_server_is_disabled_for_destroy_unattached_sessions() {
    let mut app = AppState::new("demo".to_string());
    app.destroy_unattached = true;
    assert!(!should_spawn_warm_server(&app));
}

#[test]
fn warm_server_is_disabled_for_warm_session_itself() {
    let app = AppState::new("__warm__".to_string());
    assert!(!should_spawn_warm_server(&app));
}

#[test]
fn warm_server_is_allowed_for_normal_sessions() {
    let app = AppState::new("demo".to_string());
    assert!(should_spawn_warm_server(&app));
}
