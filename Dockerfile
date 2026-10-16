#############################
#     构建阶段               #
#############################
FROM --platform=$BUILDPLATFORM iflyelf/ubuntu:latest AS builder

# 作者描述信息
MAINTAINER iflyelf
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=zh_CN.UTF-8
ENV LANG=$LANG

# 镜像变量
ARG DOCKER_IMAGE=iflyelf/hugo
ENV DOCKER_IMAGE=$DOCKER_IMAGE
ARG DOCKER_IMAGE_OS=ubuntu
ENV DOCKER_IMAGE_OS=$DOCKER_IMAGE_OS
ARG DOCKER_IMAGE_TAG=jammy
ENV DOCKER_IMAGE_TAG=$DOCKER_IMAGE_TAG

# HUGO站点路径
ARG HUGO_PATH=/blog
ENV HUGO_PATH=$HUGO_PATH
# HUGO输出静态文件路径
ARG HUGO_DESTINATION=/src
ENV HUGO_DESTINATION=$HUGO_DESTINATION
# HUGO监听端口
ARG HUGO_PORT=80
ENV HUGO_PORT=$HUGO_PORT

# PWA依赖包
ARG PWA_DEPS="\
    workbox-build \
    gulp \
    gulp-uglify \
    readable-stream \
    uglify-es"
ENV PWA_DEPS=$PWA_DEPS

# 构建阶段：安装 HUGO
RUN set -eux && \
    export HUGO_DOWN=$(curl -s https://api.github.com/repos/gohugoio/hugo/releases |jq -r .[].assets[].browser_download_url| grep -i 'extended'| grep -i 'Linux-64bit.tar.gz'|head -n 1) && \
    wget --no-check-certificate -O - $HUGO_DOWN | tar -xz -C /tmp && \
    mv /tmp/hugo /usr/local/bin/hugo && \
    chmod +x /usr/local/bin/hugo && \
    rm -rf /tmp/*

# 构建阶段：安装 SASS
RUN set -eux && \
    export SASS_DOWN=$(curl -s https://api.github.com/repos/sass/dart-sass/releases | jq -r .[].assets[].browser_download_url | grep -i 'linux-x64.tar.gz'| head -n 1) && \
    wget --no-check-certificate -O - $SASS_DOWN | tar -xz -C /tmp && \
    cp -rfp /tmp/dart-sass/* /usr/local/bin/ && \
    chmod +x /usr/local/bin/sass && \
    rm -rf /tmp/*

# 工作目录
WORKDIR ${HUGO_PATH}

# 构建阶段：安装 PWA 依赖
RUN set -eux && \
    npm install $PWA_DEPS --save-dev && npm update

#############################
#     运行阶段               #
#############################
FROM iflyelf/ubuntu:lite AS runtime

# 作者描述信息
MAINTAINER iflyelf
# 时区设置
ARG TZ=Asia/Shanghai
ENV TZ=$TZ
# 语言设置
ARG LANG=zh_CN.UTF-8
ENV LANG=$LANG

# 镜像变量
ARG DOCKER_IMAGE=iflyelf/hugo
ENV DOCKER_IMAGE=$DOCKER_IMAGE
ARG DOCKER_IMAGE_OS=ubuntu
ENV DOCKER_IMAGE_OS=$DOCKER_IMAGE_OS
ARG DOCKER_IMAGE_TAG=jammy
ENV DOCKER_IMAGE_TAG=$DOCKER_IMAGE_TAG

# HUGO站点路径
ARG HUGO_PATH=/blog
ENV HUGO_PATH=$HUGO_PATH
# HUGO输出静态文件路径
ARG HUGO_DESTINATION=/src
ENV HUGO_DESTINATION=$HUGO_DESTINATION
# HUGO监听端口
ARG HUGO_PORT=80
ENV HUGO_PORT=$HUGO_PORT

# 运行时依赖包（按需精简）
ARG RUNTIME_DEPS="\
    ca-certificates \
    git \
    curl \
    wget \
    nodejs \
    npm \
    python3 \
    python3-pip \
    sudo \
    tzdata \
    locales"
ENV RUNTIME_DEPS=$RUNTIME_DEPS

# 安装运行时依赖
RUN set -eux && \
   # 更新源地址
   sed -i s@http://*.*ubuntu.com@https://mirrors.aliyun.com@g /etc/apt/sources.list && \
   sed -i 's?# deb-src?deb-src?g' /etc/apt/sources.list && \
   # 解决证书认证失败问题
   touch /etc/apt/apt.conf.d/99verify-peer.conf && echo >>/etc/apt/apt.conf.d/99verify-peer.conf "Acquire { https::Verify-Peer false }" && \
   # 更新系统软件
   DEBIAN_FRONTEND=noninteractive apt-get update -qqy && apt-get upgrade -qqy && \
   # 安装依赖包
   DEBIAN_FRONTEND=noninteractive apt-get install -qqy --no-install-recommends $RUNTIME_DEPS && \
   DEBIAN_FRONTEND=noninteractive apt-get -qqy --no-install-recommends autoremove --purge && \
   DEBIAN_FRONTEND=noninteractive apt-get -qqy --no-install-recommends autoclean && \
   rm -rf /var/lib/apt/lists/* && \
   # 更新时区
   ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
   # 更新时间
   echo ${TZ} > /etc/timezone && \
   # 配置语言
   locale-gen zh_CN.UTF-8 && localedef -f UTF-8 -i zh_CN zh_CN.UTF-8 && locale-gen

# 从构建阶段复制编译产物
COPY --from=builder /usr/local/bin/hugo /usr/bin/hugo
COPY --from=builder /usr/local/bin/sass /usr/local/bin/sass
COPY --from=builder /usr/local/bin/dart /usr/local/bin/dart
COPY --from=builder /usr/local/bin/src /usr/local/bin/src
COPY --from=builder ${HUGO_PATH}/node_modules ${HUGO_PATH}/node_modules

# 配置 Python pip
RUN set -eux && \
    pip3 config set global.index-url http://mirrors.aliyun.com/pypi/simple/ && \
    pip3 config set install.trusted-host mirrors.aliyun.com && \
    pip3 install --no-cache-dir --upgrade pip setuptools wheel && \
    rm -rf /root/.cache

# 设置HUGO环境变量
ENV PATH /usr/bin/hugo:$PATH

# 工作目录
WORKDIR ${HUGO_PATH}

# 挂载目录
VOLUME ${HUGO_PATH}
VOLUME ${HUGO_DESTINATION}

# 增加文件
ADD entrypoint.sh /entrypoint.sh

# 增加文件权限
RUN chmod +x /entrypoint.sh /usr/bin/hugo

# 命令执行入口
ENTRYPOINT ["/entrypoint.sh"]

# 暴露端口
EXPOSE ${HUGO_PORT}
