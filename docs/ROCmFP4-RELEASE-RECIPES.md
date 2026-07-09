# ROCmFP4 Released Model Recipe Map

The Hugging Face card and GGUF filename define a released model's identity.
`ROCmFP4 Strix Lean` is recipe metadata and must not replace or normalize the
published model name.

The released ROCmFP4 artifacts currently use two internal recipe contracts:

- `rocmfp4.qwen35.dense.strix-lean.v1`
- `rocmfp4.qwen35.moe.strix-lean.v1`

The current contracts resolve to the same llama-quantize preset,
`Q4_0_ROCMFP4_STRIX_LEAN`, but remain separate so a future tensor policy can be
optimized for dense and MoE topologies without renaming released models.

## Published Artifacts

| Published GGUF artifact | Hugging Face repository | Topology | Internal recipe ID |
| --- | --- | --- | --- |
| `Qwen3.6-35B-A3B-NSC-ACE-SABER-MTP-F16-to-ROCmFP4-STRIX_LEAN.gguf` | `jcbtc/chadrock-35b-ace-saber-rocmfp4-mtp` | MoE | `rocmfp4.qwen35.moe.strix-lean.v1` |
| `Qwopus3.6-27B-v2-MTP-BF16-to-ROCmFP4-STRIX_LEAN.gguf` | `jcbtc/qwopus3.6-27b-v2-chadrock-rocmfp4-mtp` | dense | `rocmfp4.qwen35.dense.strix-lean.v1` |
| `CHADROCK3.6-35B-UNCENSORED-MTP-STRIX-LEAN.gguf` | `jcbtc/CHADROCK3.6-35B-UNCENSORED-MTP-STRIX-LEAN` | MoE | `rocmfp4.qwen35.moe.strix-lean.v1` |
| `CHADROCK3.6-27B-Coder-MTP-ROCmFP4-STRIX_LEAN.gguf` | `jcbtc/chadrock3.6-27b-coder-rocmfp4-mtp` | dense | `rocmfp4.qwen35.dense.strix-lean.v1` |
| `CHADROCK3.6-40B-Opus-Deckard-Uncensored-Thinking-NEO-CODE-Di-IMatrix-ROCmFP4.gguf` | `jcbtc/chadrock3.6-40b-opus-deckard-uncensored-thinking-neo-code-di-imatrix-rocmfp4` | dense | `rocmfp4.qwen35.dense.strix-lean.v1` |
| `CHADROCK3.6-27B-Pi-Agent-MTP-ROCmFP4-STRIX_LEAN.gguf` | `jcbtc/chadrock3.6-27b-pi-agent-rocmfp4-mtp` | dense | `rocmfp4.qwen35.dense.strix-lean.v1` |
| `Qwable-5-27B-Chadrock-v2-ROCmFP4.gguf` | `jcbtc/qwable-5-27b-chadrock-v2-rocmfp4` | dense | `rocmfp4.qwen35.dense.strix-lean.v1` |

The Ace Saber and Coder Hugging Face repositories also contain additive
ROCmFPX MoEQuality artifacts. Those are separate model artifacts produced by
`rocmfpx.qwen35.moe.moequality.v1`; they are not ROCmFP4 Strix Lean models.

`Chadrock` is model/release/runtime branding, not a quantization recipe.
Fine-tune identity such as Ace Saber, Qwopus, Qwable, Pi Agent, or Deckard does
not require a new recipe when implementation family and topology match and the
standard quality gates pass.

## Family Boundaries

Recipe reuse requires an implementation and topology match. Qwen35 dense,
Qwen35 MoE, Step35 MoE, Gemma4 dense QAT, and Gemma4 MoE QAT are different
contracts because their attention, SSM, expert, embedding, and MTP structures
differ.

Future Gemma4 work should begin with separate provisional IDs such as
`rocmfp4.gemma4.dense-qat.strix-lean.v1` and
`rocmfp4.gemma4.moe-qat.strix-lean.v1`. These are not released or validated
recipes yet.

The machine-readable release map is
[`rocmfp4-release-recipe-map.tsv`](rocmfp4-release-recipe-map.tsv).

## Validation Gate

Before reusing a recipe for a new model:

1. Confirm llama.cpp implementation family and dense/MoE topology.
2. Review tensor selection against the target architecture.
3. Compare PPL or KLD with the source model.
4. Run a family-relevant behavior benchmark.
5. Measure MTP acceptance, memory, and end-to-end speed when MTP is included.
