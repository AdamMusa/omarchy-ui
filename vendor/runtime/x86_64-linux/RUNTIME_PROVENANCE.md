# Omarchy UI runtime provenance

The bundled executable is byte-for-byte the artifact published by the independently
attested `runtime-v0.1.1` release.

- Omarchy UI release: https://github.com/AdamMusa/omarchy-ui/releases/tag/runtime-v0.1.1
- Omarchy UI revision: `eec479d6974db46dcc6fc4246219e5e326be8e92`
- Zui revision: `74b48f047d5811b53667e5cc0fb7f0bb63548764` (`0.0.10`)
- mruby revision: `831da26b9021de0369d17b71b5667e2941a1a32d` (`4.0.0`)
- Remote build: https://github.com/AdamMusa/omarchy-ui/actions/runs/33294299488
- Signed attestation: https://github.com/AdamMusa/omarchy-ui/attestations/43924917
- Target: x86-64 Linux
- Size: `1,868,040` bytes
- SHA-256: `ccf010017a5f6d2ae06def4357e6bce2b344e6f245f195c5dbee92cd048017b0`

The workflow checks out every external input at a full commit digest, performs two clean
builds, requires byte-identical executables, and signs the resulting SHA through GitHub's
artifact attestation service. Machine-readable provenance is included in
`runtime-provenance.json`; independent verification instructions are in
[`docs/runtime-build.md`](../../../docs/runtime-build.md).
