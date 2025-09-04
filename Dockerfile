ARG BUILD_TAG="v0.18.4.1"
# === Stage 1: Download, verify and extract ===
FROM debian:bookworm-slim AS builder

ARG BUILD_TAG
ARG MONERO_URL="https://downloads.getmonero.org/cli/"
ARG MONERO_ARCHIVE="monero-linux-x64-$BUILD_TAG.tar.bz2"
ARG MONERO_HASHES="https://getmonero.org/downloads/hashes.txt"

RUN apt update && apt-get install -y \
      wget ca-certificates binutils gpg dirmngr gnupg bzip2 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN wget "$MONERO_URL$MONERO_ARCHIVE" && \
    wget "$MONERO_HASHES" && \
    wget https://raw.githubusercontent.com/monero-project/monero/master/utils/gpg_keys/binaryfate.asc && \
    gpg --import binaryfate.asc && \
    gpg --verify hashes.txt || { echo '❌ Bad signature!'; exit 1; } && echo '✅ Signature OK' && \
    grep -E "^[a-f0-9]{64}  monero-linux-x64-${BUILD_TAG}\.tar\.bz2$" hashes.txt | sha256sum --check || { echo '❌ Hash mismatch!'; exit 1; } && echo '✅ Hash OK' && \
    tar --strip-components=1 -xvf "$MONERO_ARCHIVE"

COPY extract-deps.sh /build/extract-deps.sh
RUN chmod +x extract-deps.sh && \
    /build/extract-deps.sh /build/monero-wallet-cli /out && \
    /build/extract-deps.sh /build/monero-wallet-rpc /out

WORKDIR /out/bin
RUN ln -s monero-wallet-cli wallet && \
    ln -s monero-wallet-cli wallet-cli && \
    ln -s monero-wallet-rpc wallet-rpc

# === Stage 2: Minimal runtime ===
FROM scratch
ARG BUILD_TAG

COPY --from=builder /out/bin /bin
COPY --from=builder /out/lib /lib
COPY --from=builder /out/usr /usr
COPY --from=builder /out/lib64 /lib64

LABEL org.opencontainers.image.title="monero-wallet-zero" \
      org.opencontainers.image.description="A rootless, distroless, from-scratch Docker image for running monero wallet cli and rpc." \
      org.opencontainers.image.url="https://ghcr.io/lanjelin/monero-wallet-zero" \
      org.opencontainers.image.source="https://github.com/Lanjelin/monero-wallet-zero" \
      org.opencontainers.image.documentation="https://github.com/Lanjelin/monero-wallet-zero" \
      org.opencontainers.image.version="$BUILD_TAG" \
      org.opencontainers.image.authors="Lanjelin" \
      org.opencontainers.image.licenses="GPL-3"

USER 1000:1000
ENTRYPOINT ["/bin/monero-wallet-cli"]

