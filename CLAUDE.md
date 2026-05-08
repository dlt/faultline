# CLAUDE.md

Guidance for Claude Code when working in this repository.

## About

Faultline is a self-hosted error tracking Rails engine for Rails 8+ apps. It captures errors (with local variables), groups them by fingerprint, sends notifications, can open GitHub issues, and ships a basic APM. It is distributed as a gem and mounted into a host app at `/faultline`.

Requires Ruby >= 3.2 and Rails >= 8.0 (see `faultline.gemspec`).

## Commands

```bash
bundle install                                    # install dependencies
bundle exec rspec                                 # run all tests
bundle exec rspec spec/lib/faultline/tracker_spec.rb       # single file
bundle exec rspec spec/lib/faultline/tracker_spec.rb:25    # single example
```

Tests run against the dummy Rails app in `spec/dummy/` with SQLite. Factories live in `spec/factories/`, shared helpers in `spec/support/` and `spec/helpers/`.

## Architecture

### Layout

- `lib/faultline.rb` — top-level module. Provides `Faultline.configure`, `Faultline.track(exception, context)`, and `Faultline.notify(group, occurrence)`.
- `lib/faultline/engine.rb` — Rails engine. Initializers wire up middleware, the Rails error subscriber, the APM collector, and assets. Warns at boot if `authenticate_with` is unset in production.
- `lib/faultline/configuration.rb` — single source of truth for config options and defaults.
- `lib/faultline/tracker.rb` — creates/updates `ErrorGroup` + `ErrorOccurrence` and triggers notifications. **`Tracker.should_track?` is the authoritative filter** for exception class and user agent rules; middleware only handles path-based ignores.
- `lib/faultline/middleware.rb` — Rack middleware. Uses `TracePoint` (`:line` + `:raise`) to capture local variables, including when the exception originates inside a gem (falls back to the last app-code binding).
- `lib/faultline/error_subscriber.rb` — subscribes to `Rails.error` so exceptions reported via `Rails.error.report` are captured even when middleware is bypassed. Opt-in via `register_error_subscriber`.
- `lib/faultline/variable_serializer.rb` — safely serializes captured locals for storage.
- `lib/faultline/sql_time_grouping.rb` — adapter-aware SQL fragments for time-bucketed aggregation (PostgreSQL / MySQL / SQLite) used by the dashboard charts.
- `lib/faultline/github_issue_creator.rb` — creates GitHub issues from an `ErrorGroup` (gated by `github_configured?`).
- `lib/faultline/notifiers/` — `Base` defines `should_notify?` / `format_message`; concrete notifiers: `Telegram`, `Slack`, `Webhook`, `Resend`, `Email`.
- `lib/faultline/apm/` — `Collector`, `SpanCollector`, `ProfileCollector`, `SpeedscopeConverter`, and `instrumenters/` (SQL, view, HTTP, Redis). Required and started only when `enable_apm` is true.
- `app/models/faultline/` — `ErrorGroup`, `ErrorOccurrence`, `ErrorContext`, `RequestTrace`, `RequestProfile`, plus `ApplicationRecord`.
- `app/controllers/faultline/` — dashboard controllers: `error_groups`, `error_occurrences`, `performance`, `traces`. All inherit from `Faultline::ApplicationController`, which applies `authenticate_with` / `authorize_with`.
- `config/routes.rb` — engine routes; mounted by the host at `/faultline`.

### Error tracking flow

```
Exception
  ├── Rack middleware (enable_middleware, default on)
  │     TracePoint captures locals → Faultline.track
  └── Rails.error.report → ErrorSubscriber (register_error_subscriber, opt-in)
                              → Faultline.track
                                    ↓
                       Tracker.should_track? (class / user-agent filters)
                                    ↓
                  ErrorGroup (find/create by fingerprint) + ErrorOccurrence
                                    ↓
                       Faultline.notify → matching notifiers
```

`ErrorGroup#last_notified_at` is bumped via `update_column` to skip callbacks and `updated_at` (cooldown bookkeeping should not look like activity).

### APM flow

```
process_action.action_controller (ActiveSupport::Notifications)
    ↓
Apm::Collector + SpanCollector (SQL/view/HTTP/Redis instrumenters)
    ↓
RequestTrace (+ optional RequestProfile via Vernier)
```

APM is opt-in (`enable_apm = true`). Profiling is a further opt-in (`apm_enable_profiling`).

### Configuration

All options and defaults live in `lib/faultline/configuration.rb`. Common ones:

- `authenticate_with` / `authorize_with` — dashboard auth lambdas.
- `enable_middleware` (default `true`), `register_error_subscriber` (default `false`).
- `ignored_exceptions`, `ignored_user_agents`, `middleware_ignore_paths`.
- `notifiers`, `notification_rules`, `notification_cooldown` (default 5 minutes).
- `sanitize_fields`, `filter_parameters` — merged with `Rails.application.config.filter_parameters` via `resolved_filter_parameters`.
- `retention_days` (errors), `apm_retention_days`.
- `github_repo`, `github_token`, `github_labels` — gate `github_configured?`.
- `enable_apm`, `apm_sample_rate`, `apm_capture_spans`, `apm_enable_profiling`, `apm_profile_*`.

## Conventions

- Everything is namespaced under `Faultline::` (engine uses `isolate_namespace`).
- All Ruby files start with `# frozen_string_literal: true`.
- Use `Rails.logger.error`/`debug` with a `[Faultline]` prefix for engine-side logs.
- New tests go alongside existing ones: `spec/lib/...` for plain Ruby, `spec/models/...` for models, `spec/requests/...` for controllers.
