# Runtime build and verification

Omarchy UI bundles an x86-64 mruby executable so installed plugins do not need a
system Ruby. The executable embeds Zui's Ruby core and the small Omarchy adapter;
it does not contain a second framework implementation.

## Pinned release inputs

- Omarchy UI revision: `33ee34c3baf676517b66af7ab27342c111ec5709`
- Zui revision: `6b4bc277fe4dc78ebd10017ab35662df70fcd4c7`
- mruby revision: `831da26b9021de0369d17b71b5667e2941a1a32d`
- build configuration: `runtime/build_config.rb`
- target: x86-64 Linux

## Rebuild

Clone the two repositories as siblings, check out the pinned revisions, and run
the build on x86-64 Linux with Git, a C toolchain, Ruby, and Rake installed:

```bash
git clone https://github.com/AdamMusa/zui.git
git clone https://github.com/AdamMusa/omarchy-ui.git
git -C zui checkout 6b4bc277fe4dc78ebd10017ab35662df70fcd4c7
git -C omarchy-ui checkout 33ee34c3baf676517b66af7ab27342c111ec5709
cd omarchy-ui
ZUI_SOURCE_DIR=../zui scripts/build-mruby-runtime.sh
sha256sum build/runtime/omarchy-ui-runtime
```

The expected SHA-256 is
`0d628ffc059551d85de1668ab611d3105ef560c842e40fe4ffd3d24c7946cf7e`.
The build script checks out the exact mruby revision, uses the committed Zui
sources, applies `SOURCE_DATE_EPOCH`, strips the executable, and writes it to
`build/runtime/omarchy-ui-runtime`.
