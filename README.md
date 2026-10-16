# hugo-docker

基于 Hugo 的 Docker 镜像，支持多架构构建。

## 镜像信息

- **基础镜像**: iflyelf/ubuntu:latest (构建阶段) + iflyelf/ubuntu:lite (运行阶段)
- **支持架构**: linux/amd64, linux/arm64
- **自动更新**: 每日自动构建最新 Hugo 版本

## 镜像仓库

- Docker Hub: `iflyelf/hugo:latest`
- 华为云 SWR: `swr.cn-east-3.myhuaweicloud.com/iflyelf/hugo:latest`

## 使用方法

```bash
# 拉取镜像
docker pull iflyelf/hugo:latest

# 使用 docker-compose 启动
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
| `HUGO_PORT` | 监听端口 | `80` |

## 多阶段构建

本镜像采用多阶段构建优化：

1. **构建阶段** (`iflyelf/ubuntu:latest`): 包含完整工具链，用于编译 Hugo、Sass 等
2. **运行阶段** (`iflyelf/ubuntu:lite`): 仅包含运行时依赖，镜像更小更安全

## 功能特性

- ✅ 自动获取最新 Hugo Extended 版本
- ✅ 内置 Dart Sass 支持
- ✅ PWA 相关工具支持 (workbox, gulp)
- ✅ 支持多架构构建 (amd64, arm64)
- ✅ 定时自动构建并推送至 Docker Hub 和华为云 SWR
- ✅ 自动更新版本标签

## 许可证

MIT License

## 作者

iflyelf - https://www.xiaonuo.live
