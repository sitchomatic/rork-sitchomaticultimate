import Foundation

/// Hardcoded default CSS selectors used across all login automation services.
nonisolated enum LoginSelectorConstants {
    static let email = "#email"
    static let password = "#login-password"
    static let submit = "#login-submit"

    static let fallbackEmail = [
        "input[type='email']",
        "input[type='text'][name*='email' i]",
        "input#email",
        "input#username",
        "input[name='username']",
        "input[autocomplete='email']",
        "input[autocomplete='username']",
    ]

    static let fallbackPassword = [
        "input[type='password']",
        "input#password",
        "input#login-password",
        "input[name='password']",
    ]

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
