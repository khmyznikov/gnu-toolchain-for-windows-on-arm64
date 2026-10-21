# Windows-Native and Linux/macOS-Hosted GNU Toolchain for Windows Arm64 (MinGW/Cygwin) targets

[![Weekly Build](https://github.com/arm/gnu-toolchain-for-windows-on-arm64/actions/workflows/weekly-build.yml/badge.svg)](https://github.com/arm/gnu-toolchain-for-windows-on-arm64/actions/workflows/weekly-build.yml)

[Experimental weekly builds](https://github.com/arm/gnu-toolchain-for-windows-on-arm64/releases) and the scripts to build
Windows-native and Linux/macOS-hosted GNU Toolchain for Windows Arm64, targeting
MinGW (`aarch64-w64-mingw32`) and Cygwin (`aarch64-pc-cygwin`), built on hosts
such as (`aarch64-w64-mingw32`, `x86_64-pc-linux-gnu`, `aarch64-pc-linux-gnu`,
`arm64-apple-darwin*` or others). The resulting toolchain produces binaries
that can be run on Windows Arm64. It is a **work in progress**.

# Toolchain status

|Target|Host|Status|
|:-|:-|:-|
|aarch64-w64-mingw32|aarch64-unknown-linux-gnu|[Available](https://github.com/arm/gnu-toolchain-for-windows-on-arm64/releases)|
|aarch64-w64-mingw32|arm64-apple-darwin|[Available](https://github.com/arm/gnu-toolchain-for-windows-on-arm64/releases)|
|aarch64-w64-mingw32|native|Work in progress|
|aarch64-pc-cygwin|aarch64-unknown-linux-gnu|Work in progress|
|aarch64-pc-cygwin|arm64-apple-darwin|Work in progress|
|aarch64-pc-cygwin|native|Work in progress|

# Issues

Please report issues [here](https://github.com/arm/gnu-toolchain-for-windows-on-arm64/issues),
including those specific to Binutils/GCC/MinGW/Cygwin.

# Building the Cross-Toolchain

To build the cross-toolchain and install it into a
`~/install/toolchains/<host name>/aarch64-w64-mingw32-msvcrt` folder, run the
build script:

```bash
./build.sh
```

The toolchain uses the `aarch64-w64-mingw32` target by default. The `PLATFORM`
variable should be specified to change the target to `aarch64-pc-cygwin`.
```bash
PLATFORM=pc-cygwin ./build.sh
```

To install the toolchain into a different folder `TOOLCHAIN_PATH` environment
variable should be used:
```bash
TOOLCHAIN_PATH=/opt/aarch64-w64-mingw32 ./build.sh
```

To skip the dependencies bootstrapping process and fetching source code
repositories for consecutive builds `RUN_BOOTSTRAP` and `UPDATE_SOURCES`
environment variables should be used:
```bash
RUN_BOOTSTRAP=0 UPDATE_SOURCES=0 ./build.sh
```

The build script does multiple things:

- Installs the dependency Ubuntu packages.
- Clones several dependency source code repositories:
  - Binutils from [upstream](https://sourceware.org/git/?p=binutils-gdb.git;a=shortlog;h=refs/heads/master),
  - GCC from [upstream](https://gcc.gnu.org/git/?p=gcc.git;a=shortlog;h=refs/heads/master),
  - MinGW from [upstream](https://sourceforge.net/p/mingw-w64/mingw-w64/ci/master/log/?path).
  - Cygwin from [upstream](https://cygwin.com/cgit/newlib-cygwin/log/?h=master).
- Bootstraps the binutils and GCC sources with `gmp`, `mpfr`, `isl`, etc.
  dependencies.
- Builds and installs binutils, stage 1 GCC, MinGW runtimes, GCC with libgcc,
  and then the entire MinGW.

# Using the Cross-Compiler

After building the toolchain, to build a simple C source code file run:
```bash
source ~/install/toolchains/<host name>/aarch64-w64-mingw32-msvcrt/toolchain.sh --activate
aarch64-w64-mingw32-gcc hello.c -o hello.exe
```

To build a set of basic AArch64-specific tests:
```bash
.github/scripts/tests/build.sh
```

The test script requires a working CMake executable in the environment and will
place the resulting binaries into the `tests/build/bin` folder.

# Installing Build Dependencies

The [main build script](https://github.com/arm/gnu-toolchain-for-windows-on-arm64/blob/master/build.sh)
installs its dependencies automatically when the `RUN_BOOTSTRAP=1` environment
variable is defined, which is the default. To see what will be installed refer
to
[`.github/scripts/install-dependencies.sh`](https://github.com/arm/gnu-toolchain-for-windows-on-arm64/blob/master/.github/scripts/install-dependencies.sh).

# Building the Native GNU Toolchain for Windows Arm64

**Experimental.** Build on Linux (including Ubuntu in WSL2) or macOS, then
copy the resulting toolchain to Windows. The final compiler and binutils
are Windows Arm64 executables and do not require WSL to run.

On Windows, clone the repository using Linux Git inside the WSL Linux
filesystem, rather than building a Windows checkout through `/mnt/c` or
`/mnt/x`. This preserves Unix line endings, executable permissions, and
symbolic links:

```bash
cd ~
git -c core.autocrlf=false clone https://github.com/arm/gnu-toolchain-for-windows-on-arm64.git
cd gnu-toolchain-for-windows-on-arm64
CRT=ucrt ./build.sh --native-toolchain
```

Use UCRT for this native build. The default MSVCRT configuration is still
available for cross-toolchains, but native builds currently encounter
incompatible assumptions about the writable `environ` variable in
libiberty on Windows Arm64. UCRT is included with Windows 10 and later;
no replacement of Windows system DLLs is needed.

The native build first builds a Linux/macOS-hosted cross-toolchain. It
then uses that compiler to build Windows Arm64 zlib and rebuild the GNU
toolchain with `HOST=aarch64-w64-mingw32`. The build applies
`.github/scripts/toolchain/gcc-native-host.patch`, which rebases the
[earlier native-host configuration fixes](https://github.com/Windows-on-ARM-Experiments/gcc-woarm64/commit/5106036a437498f0f3236f701f4d181eb68866e6)
onto upstream GCC.

The GCC patch also fixes the AdvSIMD preprocessor scanner to count bits
in its full 64-bit mask. Windows Arm64 uses 32-bit `long`, so the upstream
`__builtin_ctzl` call truncates that mask and corrupts header parsing.

The native binutils patch reuses the Windows header's `UuidCreate`
function type instead of redeclaring x86 calling-convention attributes,
which are not applicable to Arm64. Native GDB, gdbserver, and simulators
are not built.

zlib build and installation directories are separate for each CRT, so
an earlier MSVCRT build cannot be reused accidentally by a UCRT build.

The native installation is placed in
`~/install/toolchains/aarch64-w64-mingw32/aarch64-w64-mingw32-ucrt`.
Copy this entire directory to Windows, including its headers, libraries,
compiler subprocesses, and runtime DLLs. Do not copy only the executables
from `bin`.

For transfer to Windows, create an archive that dereferences Linux
symbolic links:

```bash
HOST=aarch64-w64-mingw32 CRT=ucrt PACK_TOOLCHAIN=1 \
  TOOLCHAIN_PACKAGE_NAME=windows-arm64-ucrt.tar.gz \
  .github/scripts/toolchain/pack.sh
```

Extract `artifact/windows-arm64-ucrt.tar.gz` on Windows and add its `bin`
directory to `PATH`. The native compiler can be invoked as `gcc.exe` or
`aarch64-w64-mingw32-gcc.exe`; native binutils use names such as `as.exe`
and `ld.exe`.

To resume a prepared build without reinstalling dependencies or fetching
sources:

```bash
RUN_BOOTSTRAP=0 UPDATE_SOURCES=0 CRT=ucrt ./build.sh --native-toolchain
```

Use `INSTALL_PATH` to relocate both installations together. Do not set a
single shared `TOOLCHAIN_PATH` or `BUILD_PATH` for the two passes, since
the Linux/macOS-hosted and Windows-hosted tools need separate directories.

The WSL native UCRT build used the following upstream source snapshot:

|Component|Commit|
|:-|:-|
|GCC|`dacd72c18fe6470601f59c70415df111871fbbd7`|
|Binutils|`91dc787c65d9f5f9aba59bcadbee8c3d14a53236`|
|MinGW-w64|`b13721ccf8ba8da2441e059e536f91992109510b`|
|zlib|`767c4c947852e143f582c85f14cf573411df1b35`|

# Repeating the UCRT Build in CI

The [UCRT Toolchain Build](.github/workflows/ucrt-build.yml) workflow
repeats this build on an `ubuntu-24.04-arm` Linux runner. Start it manually
from **Actions > UCRT Toolchain Build > Run workflow**. No WSL or Windows
runner is needed: all compilation runs on Linux.
GitHub requires a new manually dispatched workflow to be present on the
repository's default branch before it can be started.

The workflow pins the four upstream commits listed above, builds the
Windows-native toolchain with `CRT=ucrt`, cross-compiles the existing toolchain tests,
and checks that the native executables and DLLs are Windows Arm64 PE
files. It does not execute Windows binaries on the Linux runner.
The Linux-hosted cross-compiler is only an internal bootstrap dependency;
it is not packaged or published by this workflow.

Download the `aarch64-w64-mingw32-ucrt-windows-arm64` artifact. It contains a
toolchain archive, its SHA-256 checksum, and the source revisions and
native-patch checksums. Build logs are uploaded even if the build fails.
Artifacts are retained for three days. This workflow does not change the
existing weekly release workflow or publish a release.
