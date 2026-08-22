# Runtime build and verification

Omarchy UI bundles a native x86-64 mruby executable so deployed plugins do not require Ruby.
The runtime is built entirely from this repository and the pinned mruby source revision.

## Pinned inputs

- mruby version: `4.0.0`
- mruby source revision: `831da26b9021de0369d17b71b5667e2941a1a32d`
- build configuration: `runtime/build_config.rb`
- Omarchy UI sources: `runtime/mrbgem/`

## Rebuild

On an x86-64 Linux builder with Git, a C toolchain, Ruby, and Rake installed:

```bash
git clone https://github.com/AdamMusa/omarchy-ui.git
cd omarchy-ui
scripts/build-mruby-runtime.sh
sha256sum build/runtime/omarchy-ui-runtime
```

The script checks out the exact mruby revision above, sets `SOURCE_DATE_EPOCH` from the Omarchy UI
commit, builds with the committed configuration, strips the executable, and places it at
`build/runtime/omarchy-ui-runtime`.

Released plugins include a `RUNTIME_PROVENANCE.md` and `omarchy-ui-runtime.sha256` beside the
runtime. Reviewers can check out the recorded Omarchy UI revision, run the command above, and
compare the resulting SHA-256 digest with both files in the plugin repository.
