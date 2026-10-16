# hugo-docker

基于 Hugo Extended + Dart Sass 的 Docker 镜像，多阶段构建，支持 linux/amd64、linux/arm64。

## 镜像仓库

| 仓库 | 地址 |
|------|------|
| Docker Hub | `iflyelf/hugo:latest` / `iflyelf/hugo:<hugo版本>` |
| 华为云 SWR | `swr.cn-east-3.myhuaweicloud.com/iflyelf/hugo:latest` |

## 多阶段构建

| 阶段 | 基础镜像 | 说明 |
|------|----------|------|
| builder | `iflyelf/ubuntu:latest` | 已预装 Node / 工具链，按目标架构下载 hugo、dart-sass，安装 PWA 依赖 |
| runtime | `iflyelf/ubuntu:lite` | 仅拷贝产物，并安装运行所需依赖（libstdc++6、nodejs、npm、python3、sudo） |

产物位置：

- `hugo` → `/usr/bin/hugo`
- `dart-sass` → `/opt/dart-sass`（已加入 `PATH`）
- PWA 依赖（workbox-build、gulp 等）→ `/blog/node_modules`

## 版本管理

Hugo 与 Dart Sass 版本固定在 `Dockerfile` 的 `ARG HUGO_VERSION` / `ARG SASS_VERSION` 中：

- `update-version.yml`：每天 UTC 20:00 通过 GitHub API 检查最新稳定 release，有更新时自动提交 `Dockerfile` 并触发镜像构建
- `docker-publish.yml`：每天 UTC 21:00 定时构建，同时在 `Dockerfile` / `entrypoint.sh` 变更时触发；同一分支只保留最新一次构建

## 使用方法

```bash
docker pull iflyelf/hugo:latest
docker-compose up -d
```

## 环境变量

| 变量名 | 说明 | 默认值 |
|--------|------|--------|
| `HUGO_NEWSITE` | 是否创建新站点 | `false` |
| `HUGO_WATCH` | 是否监听文件变化 | `false` |
| `HUGO_PUB` | 是否发布静态文件 | `true` |
| `HUGO_THEME` | Hugo 主题 | `FixIt` |
| `HUGO_PATH` | 站点路径 | `/blog` |
| `HUGO_DESTINATION` | 输出路径 | `/src` |
| `HUGO_BASEURL` | 站点 URL | `http://www.xiaonuo.live` |
| `HUGO_BIND` | 监听地址 | `::` |
| `HUGO_PORT` | 监听端口 | `80` |

## GitHub Secrets

| 名称 | 用途 |
|------|------|
| `DOCKER_USERNAME` / `DOCKER_PASSWORD` | Docker Hub 登录 |
| `SWR_USERNAME` / `SWR_PASSWORD` | 华为云 SWR 登录 |
| `SWR_AK` / `SWR_SK` | 推送后将 SWR 仓库设为公开（可选） |

## 许可证

MIT License
