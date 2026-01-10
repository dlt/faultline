# Changelog

All notable changes to Faultline will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Database agnostic: supports PostgreSQL, MySQL, and SQLite
- Rails error reporting API support (`config.register_error_subscriber = true`)
- Local variables capture via TracePoint when exceptions are raised
- Full-text search for errors by exception class, message, or file path
- Rate limiting with configurable notification cooldown
- Resend email notifier for error alerts via Resend API
- Charts with occurrence trends on dashboard
- Zoom feature for occurrence detail backtrace

## [0.1.0] - 2025-01-10

### Added

- Initial release
- Core error tracking with automatic grouping by fingerprint
- Rack middleware for automatic exception capture
- Three-tier data model: ErrorGroup → ErrorOccurrence → ErrorContext
- Standalone dashboard UI with Tailwind CSS
- Status management: unresolved, resolved, ignored
- Auto-reopen for resolved errors that recur
- Pluggable notification system:
  - Telegram notifier
  - Slack notifier
  - Generic webhook notifier
  - Base class for custom notifiers
- Configurable notification rules:
  - On first occurrence
  - On reopen
  - At occurrence thresholds
  - For critical exception classes
- Request context capture:
  - URL, method, params, headers
  - User agent, IP address
  - Session ID
  - Custom data via ErrorContext
- Security features:
  - Automatic parameter filtering
  - Safe header extraction (whitelist)
  - Backtrace line limits
- Install generator with migrations and initializer
- Authentication via configurable lambda
- Multi-tenant support (user_class, account_method)
- Callbacks: before_track, after_track, custom_fingerprint

### Security

- Sensitive parameters automatically filtered using Rails' ParameterFilter
- Only safe HTTP headers captured (whitelist approach)
- Dashboard authentication required for production

[Unreleased]: https://github.com/dlt/faultline/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/dlt/faultline/releases/tag/v0.1.0
