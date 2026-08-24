# Omarchy UI

The native Ruby application and plugin adapter for Omarchy, powered by the
[Zui](https://github.com/AdamMusa/zui) desktop UI framework.

Omarchy UI provides the Omarchy host, Quickshell integration, plugin lifecycle,
packaging, and embedded Ruby runtime. Zui provides the Ruby DSL, component catalog,
state, events, bindings, animation, tasks, commands, rendering protocol, and Qt runtime.

Applications contain Ruby and assets only. Application-owned QML is not required.

## Requirements

- Omarchy on x86-64 Linux
- Ruby 3.1 or newer for development
- Optional Qt modules for features such as Quick 3D, WebEngine, and Multimedia

Components fail with an explicit error when a required Qt module or resource is
unavailable. Omarchy UI does not substitute fallback components.

## Installation

```bash
gem install omarchy-ui
```

The gem installs Zui as a dependency.

## Create an application

```bash
omarchy_ui new Counter
cd counter
omarchy_ui run main.rb
```

Generated projects use a host-independent Zui application module and one Omarchy
launcher:

```text
counter/
├── app.rb
├── components/
│   └── welcome.rb
├── main.rb
└── README.md
```

### Application module

`app.rb` contains the reusable application implementation:

```ruby
require "zui"

module Counter
  module UI
    def counter_screen
      column spacing: 16, padding: 24 do
        text { "Count: #{state.count}" }, style: :heading
        button("Increment") { state.count += 1 }
      end
    end
  end

  def self.build
    Zui::Application.new(ui: UI) do
      state :count, 0
      app(:main, title: "Counter", width: 640, height: 420) { counter_screen }
    end
  end

  def self.run = build.run
end
```

### Omarchy launcher

`main.rb` selects the Omarchy host:

```ruby
require "omarchy_ui"
require_relative "app"

OmarchyUI.run(Counter)
```

`OmarchyUI.run` accepts an application module whose `build` method returns a
`Zui::Application`, or an already-built `Zui::Application` instance.

The same `app.rb` can be used in a standalone Zui project on Linux, macOS, or
Windows. See [Zui platform support](https://github.com/AdamMusa/zui/blob/main/docs/platforms.md).

## Create an Omarchy plugin

Plugins use the same Ruby DSL and add an Omarchy `manifest.json`:

```ruby
require "omarchy_ui"

OmarchyUI.plugin do
  bar_widget do
    button("Open") { open_panel :status }
  end

  panel :status do
    column spacing: 12, padding: 20 do
      text "System ready", style: :heading
      badge 8
    end
  end
end
```

Validate and install a plugin:

```bash
omarchy_ui validate path/to/plugin
omarchy_ui push path/to/plugin
```

`push` stages and validates the plugin, installs it atomically, enables it, and
restarts the shell. Use `--no-enable` or `--no-restart` during development.

## Commands

| Command | Purpose |
| --- | --- |
| `omarchy_ui new NAME` | Generate a Ruby application |
| `omarchy_ui run FILE` | Run an application through the Omarchy host |
| `omarchy_ui bundle [DIRECTORY]` | Build a self-contained Omarchy bundle |
| `omarchy_ui validate [DIRECTORY]` | Validate an Omarchy plugin |
| `omarchy_ui push [DIRECTORY]` | Install and activate an Omarchy plugin |
| `omarchy_ui version` | Print the installed version |

## Packaging

```bash
omarchy_ui bundle
./dist/myapp/run
```

Application bundles include the Zui catalog, Qt controls and theme, Omarchy host,
and embedded mruby runtime. Ruby and the framework gems are not required on the
destination Omarchy system.

## Component catalog

The Zui catalog includes 242 Ruby-first Qt Quick, Controls, Layouts, Dialogs,
Multimedia, WebEngine, Quick 3D, shader, chart, animation, state, input,
navigation, and data components.

- [Complete component catalog](https://github.com/AdamMusa/zui/blob/main/docs/component-coverage.md)
- [Platform support](https://github.com/AdamMusa/zui/blob/main/docs/platforms.md)
- [Omarchy QML boundary](docs/qml-support.md)
- [Embedded runtime provenance](docs/runtime-build.md)
- [Showcase applications](examples/)

## Development

Clone Zui and Omarchy UI as sibling repositories:

```bash
git clone https://github.com/AdamMusa/zui.git
git clone https://github.com/AdamMusa/omarchy-ui.git
cd omarchy-ui
ZUI_SOURCE_DIR=../zui scripts/test.sh
```

Framework and component changes belong in Zui. This repository contains the
Omarchy adapter, lifecycle tooling, host files, and synchronized showcase
distributions.

## License

MIT
