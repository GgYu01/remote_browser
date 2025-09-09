FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# base deps + firefox
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      firefox-esr ca-certificates \
      fonts-dejavu-core fonts-noto-cjk \
      locales tzdata \
      wget curl xz-utils procps \
    && rm -rf /var/lib/apt/lists/*

# locale
RUN sed -i 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

# install browsh (static release)
# NOTE: check latest version at https://github.com/browsh-org/browsh/releases
ARG BROWSH_VERSION=1.8.3
RUN arch=$(dpkg --print-architecture) && \
    case "$arch" in \
      amd64)  tarball="browsh_${BROWSH_VERSION}_linux_amd64.tar.gz" ;; \
      arm64)  tarball="browsh_${BROWSH_VERSION}_linux_arm64.tar.gz" ;; \
      *) echo "Unsupported arch: $arch" && exit 1 ;; \
    esac && \
    cd /usr/local/bin && \
    wget -q https://github.com/browsh-org/browsh/releases/download/v${BROWSH_VERSION}/${tarball} && \
    tar xf ${tarball} && \
    rm -f ${tarball} && \
    chmod +x /usr/local/bin/browsh

# unprivileged user
RUN useradd -m -s /bin/bash app
USER app
WORKDIR /home/app

# firefox profile
RUN mkdir -p /home/app/.mozilla/firefox/profile.default
COPY firefox-userjs/user.js /home/app/.mozilla/firefox/profile.default/user.js

# entrypoint
USER root
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && \
    chown -R app:app /home/app

USER app
EXPOSE 8080/tcp
ENTRYPOINT ["/entrypoint.sh"]