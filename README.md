# deep-share-local
Local deployment based on the DeepShare browser extension. Use directly on your local computer, bypassing the fee.
[DeepShare](https://github.com/Yorick-Ryu/deep-share) 的本地转换扩展，用自建 Pandoc 服务替代原项目的付费 API，实现 DeepSeek 等 AI 对话的 Markdown → Word (DOCX) 免费转换。


## 原理

原项目通过远程 API (`api.ds.rick216.cn`) 完成转换，需要付费购买配额。本项目在本地运行一个 Flask 服务，拦截转换请求，调用本地 Pandoc 生成 DOCX，完全免费、无配额限制。

## 前置条件

| 依赖 | 安装方式 |
|------|----------|
| **Python** ≥ 3.10 | `https://www.python.org/downloads/` |
| **Pandoc** | `https://pandoc.org/installing.html`（Windows 下载 `.msi` 安装包） |

## 快速开始

Windows 用户也可以双击 start.bat

手动部署
1. 安装 Pandoc

从 [Pandoc 官网](https://pandoc.org/installing.html) 下载安装包并安装。

2. 安装依赖并启动
pip install -r requirements.txt
python server.py / 双击start.bat

```bash
## 配置 DeepShare 扩展

1. 打开浏览器中 DeepShare 扩展的弹窗
2. 修改两项设置：

| 设置项 | 值 |
|--------|-----|
| **Server URL** | `http://localhost:5050` |
| **API Key** | 任意填写（如 123），本地不验证 |

配置完成后，在 DeepSeek 对话页点击 转文档 即可使用。

## 自定义 Word 样式

生成的 DOCX 样式由模板文件控制：

```
templates/reference.docx    ← 用 Word 打开并修改此文件
```

可以直接修改的内容：

- **正文样式**（Normal）：字体、字号、行距
- **标题 1/2/3**（Heading 1/2/3）：各级标题样式
- **页面布局**：页边距、纸张方向
- **表格样式**（Table Grid）：表格边框
- **页眉/页脚**


## 自定义 Lua 过滤器

Lua 过滤器用于在转换过程中修改文档结构：

```
filters/disable-auto-numbering.lua    
```


