# Zui showcases on Omarchy

The Omarchy showcase catalog is synchronized from the standalone
[Zui examples](https://github.com/AdamMusa/zui/tree/main/examples). Application code,
tests, and assets remain byte-for-byte identical to Zui. Each `main.rb` selects the
Omarchy UI host without changing the application module.

Run an application:

```bash
omarchy_ui run examples/tesla_drive_dashboard/main.rb
```

The launcher contains no application implementation:

```ruby
OmarchyUI.run(TeslaDriveDashboard)
```

Use `ZUI_SOURCE_DIR=/path/to/zui scripts/sync-zui-examples.rb --sync` after a
Zui showcase changes. The repository test suite checks the complete catalog for drift.
