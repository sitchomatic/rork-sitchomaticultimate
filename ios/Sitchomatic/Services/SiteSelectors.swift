import Foundation

/// Hardcoded default CSS selectors used across all login automation services.
enum LoginSelectorConstants {
    static let email = "#email"
    static let password = "#login-password"
    static let submit = "#login-submit"

    /// Ordered fallback selectors for the submit button, used in JS-based click helpers.
    static let fallbackSubmit = [
        "button[type='submit']",
        "#loginSubmit",
        "#login-submit",
        "button.login-btn",
        "input[type='submit']",
        "#loginButton",
        "button.login-button",
    ]
}
