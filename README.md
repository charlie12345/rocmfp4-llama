# ROCmFP4 for llama.cpp

Experimental AMD-focused FP4 quantization and backend work for `llama.cpp`,
developed on Framework Desktop with AMD Strix Halo 395+ and 128 GB unified RAM.

ROCmFP4 adds new GGUF tensor formats, quantization presets, ROCm/HIP kernels,
Vulkan shader support, and reproducible regression guards for long-context MTP
inference. The goal is a practical 4-bit format for AMD systems that keeps model
coherence protected while improving memory use and decode speed.

> Status: experimental research build. Results are hardware-, driver-, model-,
> and prompt-sensitive. Do not treat these numbers as upstream llama.cpp claims
> until they are independently reproduced.

## What Is ROCmFP4?

ROCmFP4 is a custom 4-bit weight format for GGUF models:

- `Q4_0_ROCMFP4`: dual-scale 4.50 BPW layout using two finite UE4M3 scale bytes
  per 32-weight block.
- `Q4_0_ROCMFP4_FAST`: single-scale 4.25 BPW layout for speed-sensitive tensor
  roles.
- Tensor-aware presets that mix ROCmFP4 layouts with protected higher-precision
  tensors where quality matters.
- ROCm/HIP vector-dot, copy, dequant, and FlashAttention handling for the new
  layouts.
- Vulkan decode and MMQ shader support for the same GGUF tensor types.
- MTP regression guards for long-context target/draft decode.

ROCmFP4 is not MXFP4, NVFP4, or a renamed Q4 format. It uses a Codebook10 4-bit
value table and finite unsigned E4M3 half-scale semantics tuned for the current
AMD backend paths in this tree.

## Proven Local Results

Current strongest reproduced local result:

| Hardware | Model | Backend | Context | Profile | Decode |
|---|---|---:|---:|---|---:|
| Framework AMD Strix Halo 395+, 128 GB unified RAM | Qwen3.6 35B A3B MTP ROCmFP4 STRIX_LEAN | ROCm0 | 262144 | reasoning on, draft-MTP, q8 main KV, q4 draft KV | 104.4 tok/s short, 89.3 tok/s sustained |
| Framework AMD Strix Halo 395+, 128 GB unified RAM | Qwen3.6 27B MTP ROCmFP4 STRIX_LEAN | ROCm0 | 262144 | draft-MTP | 33.6 tok/s short, 28.0 tok/s sustained |

The benchmark policy is intentionally conservative: a microbenchmark win is not
promoted unless end-to-end decode guards hold or improve.

## Validation Matrix

| Target | Script | Status |
|---|---|---|
| Strix Halo / RDNA3.5 (`gfx1151`) | `scripts/build-strix-rocmfp4-mtp.sh` | Validated locally on Framework Desktop / Ryzen AI MAX+ 395 |
| RDNA3 (`gfx1100` class) | `scripts/build-rdna3.sh` | Build target provided; community validation wanted |
| RDNA2 (`gfx1030` class) | `scripts/build-rdna2.sh` | Build target provided; community validation wanted |
| RDNA4 (`gfx1200` class) | `scripts/build-rdna4.sh` | Experimental; requires ROCm support for `gfx1200` device libraries |
| Vulkan fallback | Manual CMake path | Recommended when HIP support is incomplete or a GPU is not mapped cleanly |

## Latest Validated Snapshot

- Validated integration snapshot: `4860505ee`
- Validation date: `2026-06-13`

This snapshot passed the promoted Strix Halo gate with:

- ROCmFP4 quantization tests
- MTMD C API smoke test
- ROCm copy and FlashAttention backend tests
- ROCmFP4 copy, FlashAttention, and runtime regression guards
- Qwen3.6 35B A3B MTP ROCmFP4 smoke test

## Documentation

| Guide | Who it's for |
|---|---|
| [`docs/STRIX-HALO-QUICKSTART.md`](docs/STRIX-HALO-QUICKSTART.md) | Strix Halo users — full install, quantize, run, validate |
| [`docs/BUILD-AMD-ARCHITECTURES.md`](docs/BUILD-AMD-ARCHITECTURES.md) | AMD GPU build flags and scripts, including RDNA2 through RDNA4 plus experimental gfx906 |
| [`docs/ROCmFP4-REPRODUCIBILITY.md`](docs/ROCmFP4-REPRODUCIBILITY.md) | Regression guards and proof commands |
| [`docs/ROCmFP4-MTP-COMPARISON.md`](docs/ROCmFP4-MTP-COMPARISON.md) | Benchmark history and promoted profiles |
| [`ggml/rocmfp4/README.md`](ggml/rocmfp4/README.md) | Format details and expert HIP tuning knobs |

## Repository Layout

- `ggml/rocmfp4/` — ROCmFP4 format definitions, CPU reference quant/dequant, and
  HIP helper kernels
- `ggml/src/ggml-cuda/` — upstream HIP/CUDA backend files with AMD ROCmFP4
  integration (HIP builds use this directory even with `-DGGML_CUDA=OFF`)
- `ggml/src/ggml-vulkan/vulkan-shaders/` — Vulkan shader support for ROCmFP4
- `scripts/build-*.sh` — build scripts per AMD GPU generation
- `scripts/check-rocmfp4-*.sh` — correctness and performance regression guards

## Build

CI-validated build configurations for Linux and Windows. All commands below
have been verified in automated CI (see `.github/workflows/build-linux.yml` and
`build-windows.yml`).

### Clone

```bash
git clone https://github.com/charlie12345/rocmfp4-llama.git
cd rocmfp4-llama
git checkout mtp-rocmfp4-strix
```

### Linux

The CI uses `ubuntu-latest` (24.04) for CPU and Vulkan, and `ubuntu-26.04` for
ROCm builds.

#### CPU Build

```bash
# Dependencies
sudo apt-get install build-essential cmake git pkg-config ninja-build libssl-dev

# Configure & build
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_BUILD_SERVER=ON \
  -DLLAMA_BUILD_WEBUI=OFF \
  -DLLAMA_USE_PREBUILT_WEBUI=OFF \
  -DGGML_RPC=ON \
  -DLLAMA_FATAL_WARNINGS=ON
cmake --build build --config Release -j $(nproc)
```

#### Vulkan Build

Requires `gcc-14` on Ubuntu 24.04 (`ubuntu-latest`). Older GCC versions may
fail with Vulkan header compilation errors.

```bash
# Dependencies
sudo apt-get install gcc-14 g++-14 build-essential cmake git pkg-config \
  ninja-build libssl-dev vulkan-tools libvulkan-dev spirv-headers glslc
export CC=gcc-14 CXX=g++-14

# Configure & build
cmake -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_VULKAN=ON \
  -DGGML_BACKEND_DL=ON \
  -DGGML_CPU_ALL_VARIANTS=ON \
  -DLLAMA_BUILD_SERVER=ON \
  -DLLAMA_BUILD_WEBUI=OFF \
  -DLLAMA_USE_PREBUILT_WEBUI=OFF \
  -DGGML_RPC=ON \
  -DLLAMA_FATAL_WARNINGS=ON
cmake --build build --config Release -j $(nproc)
```

#### ROCm / HIP Build

Requires Ubuntu 26.04 with ROCm 7.2.4 from the `noble` repo. The `lld` linker
shipped with ROCm depends on `libxml2.so.2` and `libicu74` which are not
available on 26.04 natively, so they are extracted from Ubuntu 24.04 `.deb`
packages as a workaround.

```bash
# Install ROCm 7.2.4
sudo mkdir --parents --mode=0755 /etc/apt/keyrings
wget https://repo.radeon.com/rocm/rocm.gpg.key -O - | \
  gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null
sudo tee /etc/apt/sources.list.d/rocm.list <<'EOF'
deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/7.2.4 noble main
EOF
sudo apt-get update
sudo apt-get install -y rocm-hip-sdk rocm-opencl-sdk

# Fix lld linker dependencies (libxml2 + libicu74)
ROCM_LIB="/opt/rocm/lib"
cd /tmp
wget -q http://archive.ubuntu.com/ubuntu/pool/main/libx/libxml2/libxml2_2.9.14+dfsg-1.3ubuntu3_amd64.deb
dpkg-deb -x libxml2_*.deb /tmp/libxml2-extract/
sudo cp /tmp/libxml2-extract/usr/lib/x86_64-linux-gnu/libxml2.so.2.9.14 "$ROCM_LIB/"
sudo ln -sf libxml2.so.2.9.14 "$ROCM_LIB/libxml2.so.2"
wget -q http://archive.ubuntu.com/ubuntu/pool/main/i/icu/libicu74_74.2-1ubuntu3_amd64.deb
dpkg-deb -x libicu74_*.deb /tmp/libicu74-extract/
sudo cp /tmp/libicu74-extract/usr/lib/x86_64-linux-gnu/libicudata.so.74.2 "$ROCM_LIB/"
sudo cp /tmp/libicu74-extract/usr/lib/x86_64-linux-gnu/libicuuc.so.74.2 "$ROCM_LIB/"
sudo cp /tmp/libicu74-extract/usr/lib/x86_64-linux-gnu/libicui18n.so.74.2 "$ROCM_LIB/"
cd "$ROCM_LIB"
sudo ln -sf libicudata.so.74.2 libicudata.so.74
sudo ln -sf libicuuc.so.74.2 libicuuc.so.74
sudo ln -sf libicui18n.so.74.2 libicui18n.so.74

# Build for your GPU target (replace gfx1030 with gfx1100, gfx1151, etc.)
cmake -S . -B build \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_HIP=ON \
  -DGPU_TARGETS=gfx1030 \
  -DGGML_BACKEND_DL=ON \
  -DGGML_CPU_ALL_VARIANTS=ON \
  -DGGML_NATIVE=OFF \
  -DLLAMA_BUILD_SERVER=ON \
  -DLLAMA_BUILD_WEBUI=OFF \
  -DLLAMA_USE_PREBUILT_WEBUI=OFF \
  -DGGML_RPC=ON \
  -DLLAMA_FATAL_WARNINGS=ON
cmake --build build --config Release -j $(nproc)
```

For Strix Halo (`gfx1151`), add these recommended flags:

```bash
  -DGGML_HIP_NO_VMM=ON \
  -DGGML_HIP_ROCWMMA_FATTN=OFF \
  -DGGML_HIP_MMQ_MFMA=ON
```

Pick the `GPU_TARGETS` that matches your GPU:

| GPU generation | `GPU_TARGETS` |
|---|---|
| RDNA2 (RX 6000) | `gfx1030` |
| RDNA3 (RX 7000) | `gfx1100` |
| RDNA3.5 / Strix Halo | `gfx1151` |
| RDNA4 (RX 9000) | `gfx1200` |

### Windows

The CI uses `windows-2025` runners with LLVM/clang toolchain.

#### x64 CPU (Static)

```powershell
# Install Ninja
choco install ninja

# Configure & build
cmake -B build `
  -G "Ninja Multi-Config" `
  -D CMAKE_TOOLCHAIN_FILE=cmake/x64-windows-llvm.cmake `
  -DGGML_NATIVE=OFF `
  -DLLAMA_BUILD_SERVER=ON `
  -DLLAMA_BUILD_WEBUI=OFF `
  -DLLAMA_USE_PREBUILT_WEBUI=OFF `
  -DGGML_RPC=ON `
  -DBUILD_SHARED_LIBS=OFF
cmake --build build --config Release
```

#### x64 OpenBLAS

```powershell
# Download OpenBLAS (replace 0.3.23 with latest)
set OPENBLAS_VERSION=0.3.23
curl.exe -o %RUNNER_TEMP%/openblas.zip -L "https://github.com/xianyi/OpenBLAS/releases/download/v%OPENBLAS_VERSION%/OpenBLAS-%OPENBLAS_VERSION%-x64.zip"
mkdir %RUNNER_TEMP%/openblas
tar.exe -xvf %RUNNER_TEMP%/openblas.zip -C %RUNNER_TEMP%/openblas

# Build
cmake -B build `
  -G "Ninja Multi-Config" `
  -D CMAKE_TOOLCHAIN_FILE=cmake/x64-windows-llvm.cmake `
  -DGGML_NATIVE=OFF `
  -DLLAMA_BUILD_SERVER=ON `
  -DLLAMA_BUILD_WEBUI=OFF `
  -DLLAMA_USE_PREBUILT_WEBUI=OFF `
  -DGGML_RPC=ON `
  -DGGML_BACKEND_DL=ON `
  -DGGML_CPU_ALL_VARIANTS=ON `
  -DGGML_OPENMP=OFF `
  -DGGML_BLAS=ON `
  -DGGML_BLAS_VENDOR=OpenBLAS `
  -DBLAS_INCLUDE_DIRS="%RUNNER_TEMP%/openblas/include" `
  -DBLAS_LIBRARIES="%RUNNER_TEMP%/openblas/lib/openblas.lib"
cmake --build build --config Release
```

#### x64 Vulkan

```powershell
# Install Vulkan SDK (replace 1.4.313.2 with latest)
set VULKAN_VERSION=1.4.313.2
curl.exe -o %RUNNER_TEMP%/VulkanSDK-Installer.exe -L "https://sdk.lunarg.com/sdk/download/%VULKAN_VERSION%/windows/vulkansdk-windows-X64-%VULKAN_VERSION%.exe"
%RUNNER_TEMP%\VulkanSDK-Installer.exe --accept-licenses --default-answer --confirm-command install
set VULKAN_SDK=C:\VulkanSDK\%VULKAN_VERSION%

# Configure & build
cmake -B build `
  -DCMAKE_BUILD_TYPE=Release `
  -DGGML_NATIVE=OFF `
  -DLLAMA_BUILD_SERVER=ON `
  -DLLAMA_BUILD_WEBUI=OFF `
  -DLLAMA_USE_PREBUILT_WEBUI=OFF `
  -DGGML_RPC=ON `
  -DGGML_BACKEND_DL=ON `
  -DGGML_CPU_ALL_VARIANTS=ON `
  -DGGML_VULKAN=ON
cmake --build build --config Release
```

#### ARM64

```powershell
# Install Ninja
choco install ninja

# Configure & build (uses cmake/arm64-windows-llvm.cmake toolchain)
cmake -B build `
  -G "Ninja Multi-Config" `
  -D CMAKE_TOOLCHAIN_FILE=cmake/arm64-windows-llvm.cmake `
  -DGGML_NATIVE=OFF `
  -DLLAMA_BUILD_SERVER=ON `
  -DLLAMA_BUILD_WEBUI=OFF `
  -DLLAMA_USE_PREBUILT_WEBUI=OFF
cmake --build build --config Release
```

#### ROCm (HIP)

Requires ROCm SDK for Windows (installer version 26.Q1). Uses
`windows-2022` runner.

```powershell
# Install ROCm SDK (automated in CI via .github/actions/windows-setup-rocm)
# Then build:
$rocmPath = Get-ChildItem 'C:\Program Files\AMD\ROCm' | Select-Object -First 1 | ForEach-Object { $_.FullName }
$env:PATH = "$rocmPath\bin;$env:PATH"

cmake -B build `
  -G "Ninja Multi-Config" `
  -DCMAKE_C_COMPILER=clang `
  -DCMAKE_CXX_COMPILER=clang++ `
  -DGGML_HIP=ON `
  -DGPU_TARGETS="gfx906;gfx908;gfx90a;gfx1030;gfx1100;gfx1101;gfx1102;gfx1151" `
  -DGGML_NATIVE=OFF `
  -DLLAMA_BUILD_SERVER=ON `
  -DLLAMA_BUILD_WEBUI=OFF `
  -DLLAMA_USE_PREBUILT_WEBUI=OFF `
  -DGGML_RPC=ON `
  -DGGML_BACKEND_DL=ON
cmake --build build --config Release
```

#### MSVC (Visual Studio) Builds

Local builds using Visual Studio's MSVC compiler — no Clang/LLVM toolchain
needed. Open a **Developer Command Prompt for VS 2025** from the Start menu,
then run the commands below.

Prerequisites:
- Visual Studio 2025+ with the "Desktop development with C++" workload
- Ninja (optional, for faster builds): `choco install ninja`

##### x64 CPU (MSVC)

```cmd
cmake -B build -G "Ninja Multi-Config" ^
  -DGGML_NATIVE=OFF ^
  -DLLAMA_BUILD_SERVER=ON ^
  -DLLAMA_BUILD_WEBUI=OFF ^
  -DLLAMA_USE_PREBUILT_WEBUI=OFF ^
  -DLLAMA_OPENSSL=OFF
cmake --build build --config Release
```

##### x64 OpenBLAS (MSVC)

```cmd
set OPENBLAS_VERSION=0.3.23
curl.exe -o %RUNNER_TEMP%\openblas.zip -L "https://github.com/xianyi/OpenBLAS/releases/download/v%OPENBLAS_VERSION%/OpenBLAS-%OPENBLAS_VERSION%-x64.zip"
mkdir %RUNNER_TEMP%\openblas
tar.exe -xvf %RUNNER_TEMP%\openblas.zip -C %RUNNER_TEMP%\openblas

cmake -B build -G "Ninja Multi-Config" ^
  -DGGML_NATIVE=OFF ^
  -DLLAMA_BUILD_SERVER=ON ^
  -DLLAMA_BUILD_WEBUI=OFF ^
  -DLLAMA_USE_PREBUILT_WEBUI=OFF ^
  -DLLAMA_OPENSSL=OFF ^
  -DGGML_RPC=ON ^
  -DGGML_BACKEND_DL=ON ^
  -DGGML_CPU_ALL_VARIANTS=ON ^
  -DGGML_OPENMP=ON ^
  -DGGML_BLAS=ON ^
  -DGGML_BLAS_VENDOR=OpenBLAS ^
  -DBLAS_INCLUDE_DIRS="%RUNNER_TEMP%\openblas\include" ^
  -DBLAS_LIBRARIES="%RUNNER_TEMP%\openblas\lib\openblas.lib"
cmake --build build --config Release
```

##### x64 Vulkan (MSVC)

```cmd
:: Install Vulkan SDK from https://vulkan.lunarg.com/ first
cmake -B build -G "Ninja Multi-Config" ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DGGML_NATIVE=OFF ^
  -DGGML_VULKAN=ON ^
  -DLLAMA_BUILD_SERVER=ON ^
  -DLLAMA_BUILD_WEBUI=OFF ^
  -DLLAMA_USE_PREBUILT_WEBUI=OFF ^
  -DLLAMA_OPENSSL=OFF
cmake --build build --config Release
```

##### OpenSSL and Portable Builds

By default, `LLAMA_OPENSSL=ON` (the upstream default). Ifcmake finds OpenSSL on
your system at build time, the resulting executables will depend on
`libssl-3-x64.dll` and `libcrypto-3-x64.dll` at runtime. This is fine on the
build machine but breaks on machines without OpenSSL installed.

The `-DLLAMA_OPENSSL=OFF` flag shown above disables HTTPS support in the
built-in server. The server still works (HTTP only), and no extra DLLs are
needed. If you need HTTPS, use `-DLLAMA_BUILD_BORINGSSL=ON` instead — it
fetches and statically links BoringSSL, giving you TLS without external
dependencies.

If using PowerShell, append `2>&1` to see error messages:

```powershell
.\llama-cli.exe -m model.gguf 2>&1
```

Without it, PowerShell may render stderr in red text that can be missed or
scroll past. Alternatively, use **cmd.exe** where all output appears by
default.

### AMD GPU Scripts (Linux only)

For convenience, per-architecture build scripts are provided:

| Your GPU | Script | Output folder |
|---|---|---|
| Strix Halo / RDNA3.5 | `env JOBS=16 scripts/build-strix-rocmfp4-mtp.sh` | `build-strix-rocmfp4/` |
| RDNA2 (RX 6000) | `env JOBS=16 scripts/build-rdna2.sh` | `build-rdna2/` |
| RDNA3 (RX 7000) | `env JOBS=16 scripts/build-rdna3.sh` | `build-rdna3/` |
| RDNA4 (RX 9000) | `env JOBS=16 scripts/build-rdna4.sh` | `build-rdna4/` |
| Vega 20 / gfx906 experimental | `env JOBS=16 scripts/build-gfx906.sh` | `build-gfx906/` |

Not sure which GPU you have? See
[`docs/BUILD-AMD-ARCHITECTURES.md`](docs/BUILD-AMD-ARCHITECTURES.md) for the full
`gfx` target table, runtime environment variables, and Vulkan-only builds.

Strix Halo users: follow
[`docs/STRIX-HALO-QUICKSTART.md`](docs/STRIX-HALO-QUICKSTART.md) for
prerequisites, MTP flags, and troubleshooting.

Key binaries after a successful build:

```text
bin/llama-cli
bin/llama-server
bin/llama-quantize
bin/llama-bench
bin/test-backend-ops
bin/test-quantize-fns
bin/test-quantize-perf
```

## Quantize a Model

Start from an F16 or BF16 GGUF source model. Quantizing an already heavily
quantized GGUF into ROCmFP4 is useful for smoke tests only; for real quality,
use an F16/BF16 source.

Compact Strix profile:

```bash
./build-strix-rocmfp4/bin/llama-quantize \
  /path/to/source-bf16.gguf \
  /path/to/model-ROCmFP4-STRIX_LEAN.gguf \
  Q4_0_ROCMFP4_STRIX_LEAN
```

Quality-biased Strix profile:

```bash
./build-strix-rocmfp4/bin/llama-quantize \
  /path/to/source-bf16.gguf \
  /path/to/model-ROCmFP4-STRIX.gguf \
  Q4_0_ROCMFP4_STRIX
```

Pure experimental formats:

```bash
./build-strix-rocmfp4/bin/llama-quantize source.gguf out-dual.gguf Q4_0_ROCMFP4
./build-strix-rocmfp4/bin/llama-quantize source.gguf out-fast.gguf Q4_0_ROCMFP4_FAST
```

Use the Strix presets for serious testing. The pure FAST format is smaller and
can be faster, but may trade away too much coherence on sensitive tensors.

## Run a ROCmFP4 Model

Example interactive run:

```bash
cd rocmfp4-llama
HSA_OVERRIDE_GFX_VERSION=11.5.1 \
GGML_HIP_ENABLE_UNIFIED_MEMORY=1 \
./build-strix-rocmfp4/bin/llama-cli \
  -m /path/to/model-ROCmFP4-STRIX_LEAN.gguf \
  -dev ROCm0 \
  -ngl 999 \
  -c 262144 \
  -b 512 \
  -ub 512 \
  -fa on \
  -ctk q8_0 \
  -ctv q8_0 \
  --spec-type draft-mtp \
  --spec-draft-n-max 3 \
  --spec-draft-n-min 0 \
  --spec-draft-p-min 0.0 \
  --spec-draft-p-split 0.10 \
  --spec-draft-type-k q4_0 \
  --spec-draft-type-v q4_0 \
  --reasoning on \
  --jinja
```

For models that do not support MTP or reasoning, remove the `--spec-*` and
`--reasoning` flags.

## Regression Guards

Run the full promoted gate:

```bash
env HSA_OVERRIDE_GFX_VERSION=11.5.1 scripts/check-rocmfp4-all-regression.sh
```

Focused guards:

```bash
scripts/check-rocmfp4-quant-regression.sh
scripts/check-rocmfp4-rocm-runtime-regression.sh
scripts/check-rocmfp4-rocm-fattn-regression.sh
scripts/check-rocmfp4-vulkan-runtime-regression.sh
scripts/check-rocmfp4-qwen-mtp-regression.sh
scripts/check-rocmfp4-qwen35-a3b-mtp-regression.sh
```

The scripts accept environment overrides for model paths, binary paths, context,
cache type, MTP settings, and speed floors. See each script for the exact
variables.

## Design Principles

- Coherence first: tensor-aware presets are preferred over pure speed profiles.
- AMD-specific work must be isolated and measurable.
- ROCm and Vulkan paths must avoid silent fallback where ROCmFP4-specific
  kernels exist.
- Rejected experiments are recorded so they are not repeatedly rediscovered.
- Claims must cite model, backend, context window, flags, hardware, and date.

## Current Limitations

- This is not native FP4 tensor-core execution. rocWMMA FP4 input support is not
  available in the local headers used by this build.
- ROCmFP4 is currently optimized for AMD Strix Halo behavior and may need
  retuning on other GPUs.
- TurboQuant and TriAttention are not runtime flags in this isolated tree.
- Some scripts reference local model defaults; override `MODEL`, `ROCMFP4_MODEL`,
  or `BASELINE_MODEL` for your checkout.

## License

This repository is based on `llama.cpp` and keeps the upstream MIT license. See
`LICENSE` for details. Bundled third-party notices are listed in
`THIRD_PARTY_NOTICES.md`.
