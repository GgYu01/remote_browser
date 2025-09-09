FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates locales tzdata sudo procps iproute2 \
      xrdp xorgxrdp dbus-x11 dbus-user-session \
      lxqt-core lxqt-session openbox \
      fonts-dejavu-core fonts-noto-cjk \
      xorg xauth x11-xkb-utils \
      # fallback backend for reliability
      tigervnc-standalone-server \
      # browser
      firefox-esr \
      # for cert generation in entrypoint
      openssl \
    && rm -rf /var/lib/apt/lists/*

# locale
RUN sed -i 's/# zh_CN.UTF-8 UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

RUN mkdir -p /var/run/xrdp /var/log/xrdp && \
    chmod 0775 /var/run/xrdp /var/log/xrdp

EXPOSE 3389/tcp
ENTRYPOINT ["bash","-lc","/opt/xrdp-lxqt/entrypoint.sh"]
