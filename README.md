# 家庭冰箱库存管理系统

一个基于 Flask 的轻量库存管理工具，支持物品记录、临期提醒、低库存提醒、批量删除、补货建议和数据导出。

## 最低门槛部署

### 方案一：Docker Compose，一条命令启动

前提：

- 已安装 [Docker Desktop](https://www.docker.com/products/docker-desktop/) 或 Docker Engine
- 当前目录就是项目根目录

Windows PowerShell：

```powershell
.\deploy-compose.ps1
```

通用命令：

```bash
docker compose up -d --build
```

启动后访问：

```text
http://localhost:5000
```

停止服务：

```bash
docker compose down
```

## 打包镜像

### PowerShell 脚本

```powershell
.\build-image.ps1
```

指定镜像名：

```powershell
.\build-image.ps1 my-fridge-app:1.0.0
```

### 原生命令

```bash
docker build -t fridge-inventory:latest .
```

## 直接运行镜像

如果你不想用 Compose，也可以单独运行容器：

```bash
docker run -d \
  --name fridge-inventory \
  -p 5000:5000 \
  -v $(pwd)/fridge_inventory.json:/app/fridge_inventory.json \
  fridge-inventory:latest
```

Windows PowerShell 示例：

```powershell
docker run -d `
  --name fridge-inventory `
  -p 5000:5000 `
  -v "${PWD}\fridge_inventory.json:/app/fridge_inventory.json" `
  fridge-inventory:latest
```

## Docker Compose 说明

项目已内置 [docker-compose.yml](/D:/codebuddyTest/docker-compose.yml)，默认配置如下：

- 服务名：`fridge-inventory`
- 容器名：`fridge-inventory`
- 对外端口：`5000`
- 数据文件挂载：`./fridge_inventory.json -> /app/fridge_inventory.json`
- 重启策略：`unless-stopped`

如果要修改端口，可以临时指定：

```bash
APP_PORT=8080 docker compose up -d --build
```

PowerShell：

```powershell
$env:APP_PORT=8080
docker compose up -d --build
```

访问地址就变成：

```text
http://localhost:8080
```

## 项目内置的部署文件

- [Dockerfile](/D:/codebuddyTest/Dockerfile)：用于构建运行镜像
- [docker-compose.yml](/D:/codebuddyTest/docker-compose.yml)：用于本地或服务器一键部署
- [build-image.ps1](/D:/codebuddyTest/build-image.ps1)：Windows 下构建镜像脚本
- [deploy-compose.ps1](/D:/codebuddyTest/deploy-compose.ps1)：Windows 下 Compose 一键启动脚本
- [.dockerignore](/D:/codebuddyTest/.dockerignore)：减少构建上下文，加快镜像构建

## 本地开发

### 方式一：Python 直接运行

```bash
pip install -r requirements.txt
python app.py
```

访问：

```text
http://127.0.0.1:5000
```

### 可选环境变量

- `PORT`：服务端口，默认 `5000`
- `HOST`：监听地址，默认 `0.0.0.0`
- `FLASK_DEBUG`：是否开启调试模式，默认关闭

示例：

```bash
FLASK_DEBUG=1 python app.py
```

## 数据持久化

库存数据保存在：

```text
fridge_inventory.json
```

Docker Compose 已经把这个文件挂载到容器内，所以：

- 重启容器不会丢数据
- 重建镜像不会丢数据
- 直接备份这个 JSON 文件即可

如果这个文件不存在，`deploy-compose.ps1` 会自动创建一个空文件。

## 服务器部署建议

如果部署到云服务器，推荐流程：

1. 安装 Docker 和 Docker Compose。
2. 上传整个项目目录。
3. 在项目目录执行 `docker compose up -d --build`。
4. 放通服务器安全组或防火墙的目标端口，例如 `5000`。
5. 浏览器访问 `http://服务器IP:5000`。

如果要配域名，建议再加一层 Nginx 或 Traefik 做反向代理。

## 常用运维命令

查看容器状态：

```bash
docker compose ps
```

查看日志：

```bash
docker compose logs -f
```

重启服务：

```bash
docker compose restart
```

重新构建并启动：

```bash
docker compose up -d --build
```

删除容器但保留数据文件：

```bash
docker compose down
```
