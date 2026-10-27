#############################################################################
#  hugo 多阶段构建
#  - builder(构建阶段) = iflyelf/ubuntu:latest : 已预装 curl/jq/wget/tar/Node,
#      在构建平台上按目标架构下载 hugo / dart-sass, 并安装 PWA 依赖
#  - runtime(运行阶段) = iflyelf/ubuntu:lite : 仅拷贝产物 + 安装运行所需依赖
#  版本号由 .github/workflows/update-version.yml 自动更新(GitHub API 最新稳定版)
#############################################################################

####################################################################
#               构建阶段 (builder) = ubuntu:latest                  #
####################################################################
FROM --platform=$BUILDPLATFORM iflyelf/ubuntu:latest AS builder

LABEL org.opencontainers.image.authors="iflyelf" \
      org.opencontainers.image.vendor="iflyelf"

# buildx 自动注入的目标架构
ARG TARGETARCH

# hugo 版本(自动更新)
ARG HUGO_VERSION=0.169.0
# dart-sass 版本(自动更新)
ARG SASS_VERSION=1.106.1

# HUGO站点路径
ARG HUGO_PATH=/blog
ENV HUGO_PATH=$HUGO_PATH

# PWA依赖包
ARG PWA_DEPS="\
    workbox-build \
    gulp \
    gulp-uglify \
    readable-stream \
    uglify-es"
ENV PWA_DEPS=$PWA_DEPS

# ***** 按目标架构下载 hugo(extended) 与 dart-sass *****
RUN set -eux && \
    case "${TARGETARCH}" in \
        amd64) HUGO_ARCH="linux-amd64"; SASS_ARCH="linux-x64" ;; \
        arm64) HUGO_ARCH="linux-arm64"; SASS_ARCH="linux-arm64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    mkdir -p /out/bin /tmp/hugo && \
    wget -q -O - "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_${HUGO_ARCH}.tar.gz" \
        | tar -xz -C /tmp/hugo && \
    install -m 0755 /tmp/hugo/hugo /out/bin/hugo && \
    # dart-sass 包结构: dart-sass/sass(启动脚本) + dart-sass/src/{dart,sass.snapshot}
    wget -q -O - "https://github.com/sass/dart-sass/releases/download/${SASS_VERSION}/dart-sass-${SASS_VERSION}-${SASS_ARCH}.tar.gz" \
        | tar -xz -C /out && \
    chmod +x /out/dart-sass/sass /out/dart-sass/src/dart && \
    rm -rf /tmp/*

# ***** 安装 PWA 依赖(纯 JS 包, 与架构无关) *****
WORKDIR ${HUGO_PATH}
RUN set -eux && \
    npm install $PWA_DEPS --save-dev && \
    npm cache clean --force


####################################################################
#              运行阶段 (runtime) = ubuntu:lite                     #
####################################################################
FROM iflyelf/ubuntu:lite AS runtime

LABEL org.opencontainers.image.authors="iflyelf" \
      org.opencontainers.image.vendor="iflyelf" \
      org.opencontainers.image.description="hugo(extended) + dart-sass, runtime on ubuntu:lite"

# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=zh_CN.UTF-8
ENV LANG=$LANG

# 环境设置
ARG DEBIAN_FRONTEND=noninteractive
ENV DEBIAN_FRONTEND=$DEBIAN_FRONTEND

# 镜像变量
ARG DOCKER_IMAGE=iflyelf/hugo
ENV DOCKER_IMAGE=$DOCKER_IMAGE

# HUGO站点路径
ARG HUGO_PATH=/blog
ENV HUGO_PATH=$HUGO_PATH
# HUGO输出静态文件路径
ARG HUGO_DESTINATION=/src
ENV HUGO_DESTINATION=$HUGO_DESTINATION
# HUGO监听端口
ARG HUGO_PORT=80
ENV HUGO_PORT=$HUGO_PORT

# dart-sass 进 PATH; PWA 依赖的可执行文件进 PATH
ENV PATH=/opt/dart-sass:${HUGO_PATH}/node_modules/.bin:$PATH

# ***** 运行阶段按需依赖 *****
# ubuntu:lite 已含 git/curl/wget/ca-certificates/tzdata/locales/tini
# libstdc++6  -> hugo extended(CGO, libsass/webp) 运行库
# nodejs npm  -> PWA(workbox/gulp) 与 hugo 调用 postcss 等 npm 工具
# python3     -> 兼容原镜像的脚本能力
# sudo        -> entrypoint.sh 中使用
ARG RUNTIME_DEPS="\
    libstdc++6 \
    nodejs \
    npm \
    python3 \
    python3-pip \
    sudo"
ENV RUNTIME_DEPS=$RUNTIME_DEPS

# ***** 安装运行依赖 *****
RUN set -eux && \
   DEBIAN_FRONTEND=noninteractive apt-get update -qqy && apt-get upgrade -qqy && \
   DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends $RUNTIME_DEPS --option=Dpkg::Options::=--force-confdef && \
   # 验证依赖包是否真正安装成功(逐个检查 dpkg 状态, 缺失则构建失败)
   for pkg in $RUNTIME_DEPS; do \
       if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then \
           echo "ERROR: 运行依赖未成功安装: $pkg" >&2 && exit 1; \
       fi; \
   done && \
   echo "运行依赖验证通过" && \
   # pip / npm 国内镜像源(系统 Python 受 PEP 668 保护, 允许全局安装)
   python3 -m pip config set global.break-system-packages true && \
   python3 -m pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/ && \
   npm config set registry https://registry.npmmirror.com && \
   DEBIAN_FRONTEND=noninteractive apt-get -qqy autoremove --purge && \
   DEBIAN_FRONTEND=noninteractive apt-get -qqy autoclean && \
   rm -rf /var/lib/apt/lists/* /var/cache/apt/* /tmp/* /root/.cache && \
   # 更新时区
   ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
   echo ${TZ} > /etc/timezone

# ***** 拷贝编译产物 *****
COPY --from=builder /out/bin/hugo /usr/bin/hugo
COPY --from=builder /out/dart-sass /opt/dart-sass
COPY --from=builder ${HUGO_PATH}/node_modules ${HUGO_PATH}/node_modules
COPY --from=builder ${HUGO_PATH}/package.json ${HUGO_PATH}/package.json

# ***** 入口脚本 *****
COPY ["./entrypoint.sh", "/entrypoint.sh"]

# ***** 授权 + smoke test *****
RUN set -eux && \
    chmod +x /entrypoint.sh /usr/bin/hugo && \
    hugo version && \
    sass --version && \
    node --version

# ***** 工作目录 *****
WORKDIR ${HUGO_PATH}

# ***** 挂载目录 *****
VOLUME ${HUGO_PATH}
VOLUME ${HUGO_DESTINATION}

# ***** 暴露端口 *****
EXPOSE ${HUGO_PORT}

# ***** 入口(tini 作为 init, 优雅处理信号) *****
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
