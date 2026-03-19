# 家庭冰箱库存管理系统

一个基于 Flask 的 Web 应用，用于管理家庭冰箱库存。

## 功能特点

- ✅ 添加物品（名称、数量、类别、过期日期）
- ✅ 删除物品
- ✅ 编辑物品数量
- ✅ 智能过期提醒（3天内过期显示警告，已过期显示红色）
- ✅ 数据持久化（JSON 文件存储）
- ✅ 响应式设计，支持手机和电脑
- ✅ 实时统计（物品总数、即将过期、已过期数量）

## 项目结构

```
codebuddyTest/
├── app.py                  # Flask 应用主文件
├── templates/
│   └── index.html         # 前端页面
├── requirements.txt        # Python 依赖
├── fridge_inventory.json  # 数据存储文件（自动生成）
└── README.md              # 说明文档
```

## 安装步骤

### 1. 确保已安装 Python

需要 Python 3.7 或更高版本。

### 2. 安装依赖

在项目目录下运行：

```bash
pip install -r requirements.txt
```

### 3. 启动服务

```bash
python app.py
```

服务启动后，会看到类似以下的输出：

```
==================================================
家庭冰箱库存管理系统
==================================================
数据文件: d:\codebuddyTest\fridge_inventory.json
服务器启动在: http://127.0.0.1:5000
==================================================
```

### 4. 访问应用

在浏览器中打开：http://127.0.0.1:5000

## API 接口

### 获取所有物品
```
GET /api/inventory
```

### 添加物品
```
POST /api/inventory
Content-Type: application/json

{
  "name": "牛奶",
  "quantity": 2,
  "category": "乳制品",
  "expiry": "2024-03-20"
}
```

### 删除物品
```
DELETE /api/inventory/:id
```

### 更新物品数量
```
PUT /api/inventory/:id
Content-Type: application/json

{
  "quantity": 5
}
```

### 获取统计信息
```
GET /api/stats
```

返回：
```json
{
  "total": 10,
  "expiringSoon": 2,
  "expired": 1
}
```

## 数据存储

所有数据存储在 `fridge_inventory.json` 文件中，格式如下：

```json
[
  {
    "id": 1710844800000000,
    "name": "牛奶",
    "quantity": 2,
    "category": "乳制品",
    "expiry": "2024-03-20",
    "addedDate": "2024-03-19T00:00:00.000000"
  }
]
```

## 技术栈

- **后端**: Flask 3.0.0
- **前端**: HTML5 + CSS3 + JavaScript
- **数据存储**: JSON 文件
- **通信**: RESTful API

## 注意事项

1. 数据文件 `fridge_inventory.json` 会在首次启动时自动创建
2. 修改 `app.py` 后需要重启服务才能生效
3. 在开发模式下（debug=True），代码修改会自动重载
4. 建议定期备份 `fridge_inventory.json` 文件

## 常见问题

**Q: 如何修改端口号？**
A: 修改 `app.py` 最后一行的 `port=5000` 为你想要的端口号。

**Q: 如何在局域网内访问？**
A: 确保防火墙允许 5000 端口，然后在其他设备上访问 `http://[你的IP地址]:5000`。

**Q: 数据丢失了怎么办？**
A: 检查 `fridge_inventory.json` 文件是否存在，如果误删除可以恢复备份。
