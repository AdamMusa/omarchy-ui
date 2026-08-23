# Omarchy UI

Omarchy UI is the official Omarchy adapter for
[Zui](https://github.com/AdamMusa/zui), the platform-neutral Ruby desktop UI
framework powered by Qt and QML.

Applications remain pure Ruby. Zui owns the component catalog, renderer,
state, events, bindings, animations, tasks, commands, and JSON protocol.
Omarchy UI adds only the desktop integration needed for an app or shell
plugin to feel native on Omarchy: Quickshell surfaces, bar and panel hosts,
plugin validation, atomic installation, shell activation, and an embedded
mruby runtime.

```text
Ruby app or plugin
  -> omarchy_ui adapter and Omarchy lifecycle
  -> zui DSL, state, events, and complete component catalog
  -> Omarchy/Quickshell host
  -> Qt Quick renderer
```

Zui never depends on Omarchy UI. Omarchy UI declares `zui` as a gem dependency
and delegates its core constants directly, so `OmarchyUI::Builder` and
`Zui::Builder` are the same class rather than competing implementations.

## Install

On Omarchy x86-64:

```bash
gem install omarchy-ui
```

RubyGems installs Zui automatically. Apps using optional Qt modules such as Qt
Quick 3D, WebEngine, or Multimedia must also install those system modules.
Missing modules and invalid resources are reported as component errors; the
framework does not silently replace one component with another.

For a normal Linux or macOS desktop app without Omarchy integration, install
and use [`zui`](https://github.com/AdamMusa/zui) directly.

## Pure Ruby application

```ruby
require "omarchy_ui"

OmarchyUI.app do
  state :count, 0

  app :main, title: "Counter", width: 640, height: 420 do
    column spacing: 16, padding: 24 do
      text { "Count: #{state.count}" }, style: :heading
      button("Increment") { state.count += 1 }
    end
  end
end
```

Create and run it:

```bash
omarchy_ui new Counter
cd counter
omarchy_ui run main.rb
```

The generated project contains Ruby and assets only. Adapter and renderer QML
are installed into a temporary runtime directory; developers do not write or
copy QML into their application.

## Omarchy shell plugin

A plugin uses the same Ruby DSL and adds an Omarchy `manifest.json`:

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

```bash
omarchy_ui validate path/to/plugin
omarchy_ui push path/to/plugin
```

`push` stages the project, adds Zui plus the Omarchy host, validates it with
Omarchy, backs up an existing installation, installs atomically, optionally
enables it, and restarts the shell. `--no-enable` and `--no-restart` are
available for development.

## Packaging

```bash
omarchy_ui bundle
./dist/myapp/run
```

An Omarchy application bundle includes the Zui catalog, neutral controls and
theme, the Omarchy host QML, and the Zui-backed embedded mruby runtime. The
destination Omarchy computer does not need Ruby or either gem installed.

For Linux application directories and native macOS `.app` bundles, use
`zui bundle`; see [Zui platform support](https://github.com/AdamMusa/zui/blob/main/docs/platforms.md).

## Component catalog

The catalog is versioned and tested in Zui. It includes 242 Ruby-first Qt
Quick, Controls, Layouts, Dialogs, Multimedia, WebEngine, Quick 3D, shader,
chart, animation, state, input, navigation, and data components.

- [Complete catalog](https://github.com/AdamMusa/zui/blob/main/docs/component-coverage.md)
- [Platform support](https://github.com/AdamMusa/zui/blob/main/docs/platforms.md)
- [Adapter QML boundary](docs/qml-support.md)
- [Embedded runtime provenance](docs/runtime-build.md)

The showcase applications under `examples/` remain pure Ruby and exercise
images, media, shaders, GPU/3D, state, events, drag interaction, simulation,
charts, and Omarchy window/plugin integration.

## Developing both repositories

Clone the repositories as siblings. During local development, Omarchy UI finds
`../zui` automatically; an explicit source tree can be selected with
`ZUI_SOURCE_DIR`:

```bash
git clone https://github.com/AdamMusa/zui.git
git clone https://github.com/AdamMusa/omarchy-ui.git
cd omarchy-ui
ZUI_SOURCE_DIR=../zui scripts/test.sh
```

Core changes belong in Zui. This repository should contain only Omarchy
adapter behavior and Omarchy-specific examples.

## License

MIT
