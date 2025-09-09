FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# base system + toolchain (no xpra/xpra-html5 from apt)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates gnupg wget curl git \
      build-essential pkg-config \
      python3 python3-dev python3-venv python3-setuptools python3-wheel \
      # X11 runtime + fonts + firefox
      xvfb xauth x11-xserver-utils x11-xkb-utils \
      firefox-esr \
      fonts-dejavu-core fonts-noto-cjk \
      # codecs / libs often needed during build/runtime
      zlib1g-dev liblz4-dev libzstd-dev \
      libjpeg-dev libwebp-dev \
      # keep these general X11 dev headers; the rest可由 prehook 动态补齐
      libx11-dev libxext-dev \
      # introspection toolchain (pygobject may rely on it)
      gobject-introspection libgirepository1.0-dev \
      # locale/time
      locales tzdata procps \
    && rm -rf /var/lib/apt/lists/*

# locale
RUN sed -i 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

# prepare writable locations for venv/build cache
RUN mkdir -p /opt/xpra && chmod -R 0777 /opt/xpra

# Use entrypoint via volume-mounted scripts (no COPY here; compose will mount them)
EXPOSE 14500/tcp
ENTRYPOINT ["bash","-lc","/opt/xpra/entrypoint.sh"]