# remote-browser

- Xpra HTML5 + Firefox：完整浏览器兼容，采用 WebP/JPEG 差分帧，适合超低带宽但需要“真实渲染”的场景。
- Browsh + Firefox：极省带宽，画质更粗糙但可读性尚可。

参照根目录的使用说明与各子目录说明进行调优。

tail -n +1 docker-compose.yml xpra/build_xpra.sh  xpra/Dockerfile xpra/entrypoint.sh xpra/firefox-userjs/user.js  xpra/prehook.sh xpra/run_xpra.sh  > /root/log.log 2>&1

我需要你给出一个XRDP+LXQT，远程被控主机1核CPU，1G内存 2Gswap，相对我本地主机传输延迟高带宽低网络不稳定，完全放弃全部画质的方案，优先保证流畅度，降低内存和CPU开销。