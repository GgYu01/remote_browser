FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive

# 1. 安装核心组件
RUN apt-get update && apt-get install -y --no-install-recommends \
    xorg \
    xserver-xorg-legacy \
    openbox \
    xrdp \
    xorgxrdp \
    chromium \
    supervisor \
    fonts-wqy-zenhei \
    ca-certificates \
    curl \
    dbus-x11 \
    procps \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. 核心修复：定位 XRDP 协议库 libxup.so (The Real Fix)
# XRDP 进程需要加载 libxup.so 来与 Xorg 通信，而不是加载 Xorg 的驱动模块
RUN mkdir -p /usr/lib/xrdp && \
    # 查找 libxup.so (通常在 multiarch 目录中)
    XUP_PATH=$(find /usr/lib -name "libxup.so" | head -n 1) && \
    if [ -z "$XUP_PATH" ]; then \
        echo "!! FATAL: libxup.so (XRDP User Protocol Lib) not found !!" && exit 1; \
    fi && \
    echo "Found libxup.so at: $XUP_PATH" && \
    # 链接到 XRDP 默认搜索路径
    ln -s "$XUP_PATH" /usr/lib/xrdp/libxup.so

# 3. XRDP 权限修复与 ssl 证书生成
RUN rm /etc/xrdp/rsakeys.ini /etc/xrdp/cert.pem /etc/xrdp/key.pem || true && \
    xrdp-keygen xrdp auto && \
    mkdir -p /var/run/xrdp && \
    chmod 777 /var/run/xrdp

# 4. 创建用户
RUN useradd -m -s /bin/bash engineer && \
    echo "engineer:password" | chpasswd && \
    echo "engineer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 5. 配置文件注入
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY xrdp.ini /etc/xrdp/xrdp.ini

# 6. Xwrapper 权限放宽
RUN echo "allowed_users=anybody" > /etc/X11/Xwrapper.config && \
    echo "needs_root_rights=no" >> /etc/X11/Xwrapper.config

# 7. 配置用户环境
USER engineer
WORKDIR /home/engineer

# 生成 .xsession
# 新增参数说明：
# --disable-gpu-compositing: 完全禁用 GPU 合成，避免模拟 GPU 带来的 CPU 开销
# --disable-smooth-scrolling: 禁用平滑滚动（最关键），让滚动变成“跳变”，减少传输帧数
# --disable-threaded-animation: 禁用动画线程
# --disable-threaded-scrolling: 禁用滚动线程
# --wm-window-animations-disabled: 禁用窗口动画
RUN echo "openbox-session &" > .xsession && \
    echo "exec chromium \
    --no-sandbox \
    --disable-gpu \
    --disable-software-rasterizer \
    --disable-dev-shm-usage \
    --disable-gpu-compositing \
    --disable-smooth-scrolling \
    --disable-threaded-animation \
    --disable-threaded-scrolling \
    --wm-window-animations-disabled \
    --disable-background-networking \
    --no-first-run \
    --start-maximized \
    --incognito \
    http://www.google.com" >> .xsession && \
    chmod +x .xsession

USER root
EXPOSE 3389

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]