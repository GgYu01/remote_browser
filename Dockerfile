FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive

# 1. 安装核心组件
# xorg: 显示服务
# openbox: 窗口管理器
# xrdp, xorgxrdp: 远程桌面协议及后端驱动
# chromium: 浏览器
# supervisor: 进程守护
# ttf-wqy-zenhei: 必须安装中文字体，否则中文网页乱码
RUN apt-get update && apt-get install -y --no-install-recommends \
    xorg \
    openbox \
    xrdp \
    xorgxrdp \
    chromium \
    supervisor \
    fonts-wqy-zenhei \
    ca-certificates \
    curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# 2. XRDP 权限修复与 ssl 证书生成 (虽然不考虑安全，但xrdp启动需要)
RUN rm /etc/xrdp/rsakeys.ini /etc/xrdp/cert.pem /etc/xrdp/key.pem || true && \
    xrdp-keygen xrdp auto && \
    mkdir -p /var/run/xrdp && \
    chmod 777 /var/run/xrdp

# 3. 创建专用用户 'engineer' 并设置固定密码
# 修正说明：设置密码为 'password' 以通过 XRDP 的 PAM 认证
RUN useradd -m -s /bin/bash engineer && \
    echo "engineer:password" | chpasswd && \
    echo "engineer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

USER engineer
WORKDIR /home/engineer

# 创建 .xsession
# 1. 启动窗口管理器
# 2. 启动 Chromium
#    --no-sandbox: 容器内必须
#    --disable-gpu: 1 CPU 软解，避免 GPU 进程开销
#    --incognito: 无痕模式，本地不留存缓存
#    --window-position/size: 强制铺满
#    --disable-smooth-scrolling: 关键！平滑滚动会产生大量帧数，导致 RDP 卡顿。禁用后按行跳变，体验更流畅。
RUN echo "openbox-session &" > .xsession && \
    echo "exec chromium \
    --no-sandbox \
    --disable-gpu \
    --disable-software-rasterizer \
    --disable-dev-shm-usage \
    --disable-smooth-scrolling \
    --disable-background-networking \
    --no-first-run \
    --start-maximized \
    --incognito \
    http://www.google.com" >> .xsession && \
    chmod +x .xsession
    
USER root    

# 4. 配置文件注入
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY xrdp.ini /etc/xrdp/xrdp.ini
COPY Xwrapper.config /etc/X11/Xwrapper.config

# 5. 暴露 RDP 端口
EXPOSE 3389

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]