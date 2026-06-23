# kernelsu-goldfish-builder

How to compile and install KernelSU into a custom Android Studio Android Virtual Device Android Emulator (codename "goldfish")

### How to use

Likely requirements:

- Docker
- Ability to run QEMU/KVM outside of Docker
- 16 core 64-bit CPU
- 160 GB RAM + Swap
- 4 TB storage
- 250 Mbps
- 48 hours

```bash
docker build --output=. .
tar xf goldfish.tar.gz
export PATH="$(pwd)/linux-x86_64:$PATH"
export ANDROID_BUILD_TOP="$(pwd)"
export ANDROID_PRODUCT_OUT="$(pwd)/emu64x"
emulator -grpc 8554 -show-kernel -verbose
```

```bash
# separate terminal
curl -O -L https://nightly.link/tiann/KernelSU/actions/runs/27767799331/manager.zip
unzip manager.zip
adb install KernelSU_v3.2.4-64-g6c97d1dd_32521-release.apk
```
