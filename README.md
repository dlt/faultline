# Faultline

![Faultline](faultline.png)

A self-hosted error tracking engine for Rails 8+ applications. Track errors, get notified, and resolve issues—all without external services.

## Features

- **Automatic Error Capture** - Rack middleware + Rails error reporting API
- **Smart Grouping** - Errors are grouped by fingerprint (class + message + location)
- **Debugger Inspector** - Side-by-side source code and local variables view, like a real debugger
- **Local Variables Capture** - Automatic capture of variable values at the raise point
- **Full-Text Search** - Search errors by exception class, message, or file path
- **Status Management** - Mark errors as resolved, unresolved, or ignored
- **Auto-Reopen** - Resolved errors automatically reopen when they recur
- **GitHub Integration** - Create GitHub issues directly from errors with full context
- **Rate Limiting** - Configurable cooldown prevents notification spam during error storms
- **Pluggable Notifiers** - Telegram, Slack, Resend (email), webhooks, or build your own
- **Standalone Dashboard** - Clean Tailwind UI with interactive charts and time-range zooming
- **Configurable Authentication** - Integrate with Devise, Warden, or custom auth
- **Request Context** - Capture URL, params, headers, user info, and custom data

## Requirements

- Ruby >= 3.2
- Rails >= 8.0
- PostgreSQL, MySQL, or SQLite

## Installation

Add to your Gemfile:

```ruby
gem "faultline", git: "https://github.com/dlt/faultline.git"

# Or from RubyGems (when published)
# gem "faultline"
```

Run the installer:

```bash
bundle install
rails generate faultline:install
rails db:migrate
```

## Configuration

Edit `config/initializers/faultline.rb`:

### Authentication (Required for Production)

```ruby
Faultline.configure do |config|
  # Devise with admin role
  config.authenticate_with = lambda { |request|
    user = request.env["warden"]&.user
    user&.admin?
  }

  # Or any authenticated user
  config.authenticate_with = lambda { |request|
    request.env["warden"]&.authenticated?
  }
end
```

### Notifications

#### Telegram

```ruby
# Store in credentials: rails credentials:edit
# faultline:
#   telegram:
#     bot_token: "your-bot-token"
#     chat_id: "your-chat-id"

config.add_notifier(
  Faultline::Notifiers::Telegram.new(
    bot_token: Rails.application.credentials.dig(:faultline, :telegram, :bot_token),
    chat_id: Rails.application.credentials.dig(:faultline, :telegram, :chat_id)
  )
)
```

#### Slack

```ruby
config.add_notifier(
  Faultline::Notifiers::Slack.new(
    webhook_url: Rails.application.credentials.dig(:faultline, :slack, :webhook_url),
    channel: "#errors",
    username: "Faultline"
  )
)
```

#### Custom Webhook

```ruby
config.add_notifier(
  Faultline::Notifiers::Webhook.new(
    url: "https://your-service.com/errors",
    method: :post,
    headers: { "Authorization" => "Bearer #{ENV['WEBHOOK_TOKEN']}" }
  )
)
```

#### Resend (Email)

```ruby
# Store in credentials: rails credentials:edit
# faultline:
#   resend:
#     api_key: "re_xxxxx"

config.add_notifier(
  Faultline::Notifiers::Resend.new(
    api_key: Rails.application.credentials.dig(:faultline, :resend, :api_key),
    from: "errors@yourdomain.com",
    to: "team@example.com"  # or array: ["dev@example.com", "ops@example.com"]
  )
)
```

### GitHub Integration

Create GitHub issues directly from the error dashboard with full context including stack traces, local variables, and source code snippets.

```ruby
# Store in credentials: rails credentials:edit
# faultline:
#   github:
#     token: "ghp_xxxxx"

config.github_repo = "your-org/your-repo"
config.github_token = Rails.application.credentials.dig(:faultline, :github, :token)
config.github_labels = ["bug", "faultline"]  # default labels for created issues
```

### Rate Limiting

Prevent notification spam during error storms:

```ruby
config.notification_cooldown = 5.minutes  # default, nil to disable
```

### Notification Rules

```ruby
config.notification_rules = {
  on_first_occurrence: true,           # New error types
  on_reopen: true,                     # Resolved errors that recur
  on_threshold: [10, 50, 100, 500],    # At these occurrence counts
  critical_exceptions: [               # Always notify for these
    "Stripe::APIError",
    "ActiveRecord::StatementInvalid"
  ],
  notify_in_environments: ["production"]
}
```

### Rails Error Reporting API

Optionally subscribe to Rails' error reporting API to capture errors from background jobs and explicit `Rails.error` calls:

```ruby
config.register_error_subscriber = true
```

This captures errors reported via:
- `Rails.error.handle { ... }` - handled errors (swallowed)
- `Rails.error.record { ... }` - errors re-raised after reporting
- `Rails.error.report(exception)` - manual reporting

The middleware captures unhandled exceptions with local variable capture. The error subscriber captures everything else. Both can be enabled together.

### Error Filtering

```ruby
# Exceptions to ignore
config.ignored_exceptions = [
  "ActiveRecord::RecordNotFound",
  "ActionController::RoutingError"
]

# Bots/crawlers to ignore
config.ignored_user_agents = [/bot/i, /crawler/i, /Googlebot/i]

# Paths to ignore
config.middleware_ignore_paths = ["/assets", "/health"]
```

### Multi-tenant Support

```ruby
config.user_class = "User"
config.user_method = :current_user
config.account_method = :current_account  # Optional
```

## Usage

### Dashboard

Visit `/faultline` to access the error dashboard.

### Manual Tracking

```ruby
begin
  risky_operation
rescue => e
  Faultline.track(e, {
    request: request,
    user: current_user,
    custom_data: { order_id: @order.id }
  })
  raise
end
```

### Local Variables Capture

Faultline automatically captures local variables at the point where exceptions are raised. This helps you debug errors without needing to reproduce them.

Variables are:
- **Automatically captured** via `TracePoint` when exceptions are raised
- **Filtered** for sensitive data (passwords, tokens, API keys, etc.)
- **Serialized safely** with depth limits and circular reference handling
- **Displayed** in the occurrence detail page

No configuration needed—it works out of the box.

### Callbacks

```ruby
# Skip certain errors
config.before_track = lambda { |exception, context|
  return false if exception.message.include?("Timeout")
  true
}

# Post-tracking integration
config.after_track = lambda { |error_group, occurrence|
  Analytics.track("error", { type: error_group.exception_class })
}
```

### Custom Fingerprinting

```ruby
# Group errors by custom criteria
config.custom_fingerprint = lambda { |exception, context|
  { extra_components: [context.dig(:custom_data, :tenant_id)] }
}
```

## Building Custom Notifiers

```ruby
class MyNotifier < Faultline::Notifiers::Base
  def initialize(api_key:)
    @api_key = api_key
  end

  def call(error_group, error_occurrence)
    data = format_message(error_group, error_occurrence)
    # Send to your service
    MyService.notify(data, api_key: @api_key)
  end

  # Optional: control when to notify
  def should_notify?(error_group, error_occurrence)
    error_group.occurrences_count < 100  # Stop after 100
  end
end

# Usage
config.add_notifier(MyNotifier.new(api_key: "..."))
```

## Database Tables

The engine creates three tables:

- `faultline_error_groups` - Grouped errors by fingerprint
- `faultline_error_occurrences` - Individual error instances
- `faultline_error_contexts` - Custom key-value context data

## Data Retention

Configure automatic cleanup:

```ruby
config.retention_days = 90  # nil = keep forever
```

Set up a scheduled job to clean old data:

```ruby
# In a cron job or Sidekiq scheduler
Faultline::ErrorOccurrence
  .where("created_at < ?", 90.days.ago)
  .in_batches
  .delete_all
```

## Comparison with Alternatives

| Feature | Faultline | Solid Errors | Sentry | Honeybadger | Rollbar |
|---------|-----------|--------------|--------|-------------|---------|
| Self-hosted | ✅ | ✅ | ⚠️ Paid | ❌ | ❌ |
| Free tier | ✅ Unlimited | ✅ Unlimited | 5K errors/mo | 1 project | 5K errors/mo |
| Rails native | ✅ | ✅ | ✅ | ✅ | ✅ |
| Local variables | ✅ | ❌ | ✅ | ✅ | ❌ |
| GitHub integration | ✅ | ❌ | ✅ | ✅ | ✅ |
| Full-text search | ✅ | ❌ | ✅ | ✅ | ✅ |
| Notifications | ✅ | ❌ | ✅ | ✅ | ✅ |
| Error grouping | ✅ | ❌ | ✅ | ✅ | ✅ |
| Source maps (JS) | ❌ | ❌ | ✅ | ✅ | ✅ |
| Performance/APM | ❌ | ❌ | ✅ | ✅ | ❌ |
| Multi-language | Ruby | Ruby | 30+ | 10+ | 20+ |

**Faultline is ideal for:**
- Teams wanting full control over error data
- Projects with privacy/compliance requirements (GDPR, HIPAA)
- Rails-only applications without complex frontend needs
- Developers who prefer simplicity over feature bloat
- Organizations avoiding vendor lock-in and recurring SaaS costs

## Development

```bash
cd engines/faultline
bundle install
bundle exec rspec
```

## License

MIT License. See [LICENSE](LICENSE) for details.
