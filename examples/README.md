# Zui showcases on Omarchy

This catalog is synchronized from the standalone
[Zui examples](https://github.com/AdamMusa/zui/tree/main/examples). Each application,
test, asset, and normal `main.rb` launcher is byte-for-byte identical to its Zui source.
Omarchy UI adds only `omarchy.rb`, the distribution adapter entrypoint.

Run the same application as an ordinary cross-platform Zui desktop app:

```bash
zui run examples/tesla_drive_dashboard/main.rb
```

Run it with the Omarchy integration layer:

```bash
omarchy_ui run examples/tesla_drive_dashboard/omarchy.rb
```

The adapter entrypoint contains no application implementation. Its only behavioral
line is:

```ruby
OmarchyUI.run(TeslaDriveDashboard)
```

Use `ZUI_SOURCE_DIR=/path/to/zui scripts/sync-zui-examples.rb --sync` after a
Zui showcase changes. `scripts/test.sh` checks the complete catalog for drift.
