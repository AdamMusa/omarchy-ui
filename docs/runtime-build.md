# Runtime build and verification

Omarchy UI's x86-64 Linux mruby runtime is released by a pinned GitHub Actions
workflow. The workflow performs two clean builds, requires byte-identical
outputs, publishes the executable and checksum, and creates a signed GitHub
artifact attestation that binds the executable digest to the tagged source
revision and workflow run.

## Pinned inputs

The complete machine-readable input set is committed in
[`runtime/inputs.env`](../runtime/inputs.env):

- Zui revision `74b48f047d5811b53667e5cc0fb7f0bb63548764` (`0.0.10`)
- mruby revision `831da26b9021de0369d17b71b5667e2941a1a32d` (`4.0.0`)
- exact revisions for `mruby-json`, `mruby-regexp-pcre`, `mruby-env`, and
  `mruby-process`
- build configuration `runtime/build_config.rb`
- target `x86-64 Linux`

The build script rejects a Zui checkout whose Git revision does not match the
committed input. Release CI also binds the Omarchy UI checkout to the workflow's
exact source revision.

## Rebuild from reviewed source

Check out the Omarchy UI revision recorded by the release attestation and the
pinned Zui revision, then build:

```bash
git clone https://github.com/AdamMusa/omarchy-ui.git
git clone https://github.com/AdamMusa/zui.git
git -C omarchy-ui checkout <omarchy-ui-source-sha>
git -C zui checkout 74b48f047d5811b53667e5cc0fb7f0bb63548764
cd omarchy-ui
OMARCHY_UI_SOURCE_REVISION=$(git rev-parse HEAD) \
  ZUI_SOURCE_DIR=../zui scripts/build-mruby-runtime.sh
sha256sum build/runtime/omarchy-ui-runtime
```

The script checks out every external mruby input at its committed digest, sets
`SOURCE_DATE_EPOCH` from the Omarchy UI source commit, strips the executable,
removes the linker-generated build ID (whose value otherwise varies with the
temporary build directory), and writes it to `build/runtime/omarchy-ui-runtime`.

## Verify a published runtime

Download the release artifacts and verify both checksum and signed provenance:

```bash
gh release download runtime-v0.1.1 \
  --repo AdamMusa/omarchy-ui \
  --pattern 'omarchy-ui-runtime*'
sha256sum --check omarchy-ui-runtime.sha256
gh attestation verify omarchy-ui-runtime \
  --repo AdamMusa/omarchy-ui
```

The attestation verification result identifies the exact repository, source
revision, release workflow, and digest used by the remote build. The release
also includes `runtime-provenance.json` with immutable input and workflow links.
