[English](README.md) | 中文

# OCRPDF-TO-PPT（PowerOCR Presentation）

一个轻量级桌面工具：把图片 / PDF 页面通过 OCR 识别，转换成 **可编辑的 PowerPoint（.pptx）**。

核心思路：
- 每一页 PPT 以原图（或“去字后的纯背景图”）作为底图。
- OCR 识别出的文本区域会变成 **可编辑的 PPT 文本框**，并按位置叠加在底图上。

## 功能特性

- 导入：图片（PNG/JPG/...）与 PDF（逐页渲染成图片）
- OCR：兼容 PaddleOCR 2.x / 3.x（自动识别版本），CPU/GPU（GPU 不可用会自动回退 CPU）
- 多页工作流：缩略图列表、新建/复制/排序页面、撤销/重做
- 画布编辑：移动/缩放文本框、编辑文字、复制/剪切/粘贴、格式刷
- 选区（ROI）：只对选定区域执行 OCR / 去字（更快、更精准）
- 文本框背景：全局/单框背景色与透明度、吸管取色
- 导出 PPTX + 一键预览（F5）
- 可选：调用 **IOPaint** API 做“去字”，避免导出后出现“底图文字 + 文本框文字”重影

## 环境要求

- Python 3.13（64 位；项目自带的 Windows 安装与启动脚本要求此版本）
- 系统：Windows 体验最佳；macOS/Linux 取决于 PaddlePaddle 是否提供对应 wheel

关于 PaddlePaddle：
- 不同系统 / Python 版本对 PaddlePaddle wheel 支持不同。
- 若需要 GPU，请按官方安装指引选择正确的 GPU 版本（CUDA/驱动匹配）。

## 安装（从源码运行）

1）克隆仓库

```bash
git clone https://github.com/frp769/OCRPDF-TO-PPT.git
cd OCRPDF-TO-PPT
```

2）创建并激活虚拟环境

Windows（PowerShell）：
```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

macOS / Linux：
```bash
python3 -m venv .venv
source .venv/bin/activate
```

3）安装依赖

```bash
pip install -U pip
pip install -r requirements.txt
```

如果安装 `paddlepaddle` 失败，建议先按官方文档安装 PaddlePaddle，再安装其它依赖：
- PaddlePaddle 安装指引：https://www.paddlepaddle.org.cn/install/quick

## 运行

```bash
python main.py
```

提示：首次执行 OCR 时 PaddleOCR/PaddleX 可能会下载模型，默认缓存到 `model/official_models/`（可在软件内修改缓存目录）。

## 使用说明（详细步骤）

### 1）导入图片 / PDF

- 导入图片：点击 `导入图片`（快捷键 `Ctrl+O`）
- 导入 PDF：点击 `导入PDF`（快捷键 `Ctrl+Shift+O`）
  - 程序会把 PDF 每一页渲染成图片并加入左侧缩略图列表。

### 2）（可选）框选选区 ROI（只对选区做 OCR / 去字）

- 点击 `框选选区`（快捷键 `Ctrl+Alt+A`）
- 在画布上拖拽框选一个矩形区域
- 点击 `清除选区`（快捷键 `Ctrl+Alt+Shift+A`）恢复全图

### 3）执行 OCR

- OCR 本页：`OCR本页`（快捷键 `Ctrl+Enter`）
- OCR 全部：`OCR全部`（快捷键 `Ctrl+R`）

OCR 后你可以直接在画布上修正：
- 拖拽移动文本框；拖拽控制点缩放
- 双击文本框编辑文字
- `Delete` 删除选中文本框
- `Ctrl+C / Ctrl+X / Ctrl+V` 复制/剪切/粘贴文本框
- `格式刷`：把当前选中文本框的样式复制，下一次点击其它文本框会应用（一次性）

### 4）（推荐）用 IOPaint 去字：避免“文字重影”

为什么要去字：很多扫描图/截图本身就带文字，导出后底图文字仍在，叠加 OCR 文本框可能出现“双层字/重影”。

1）启动 IOPaint 服务（示例）：
```bash
iopaint start --host 127.0.0.1 --port 8080
```

2）在软件中设置：`设置` 标签 → `IOPaint 设置`
- 勾选启用
- 填写 API 地址（默认）：`http://127.0.0.1:8080/api/v1/inpaint`
- 需要时可调“文本框外扩（遮罩）/裁剪外扩（API 加速）”

3）执行去字：
- 去字本页：`去字本页`（`Ctrl+I`）
- 去字全部：`去字全部`（`Ctrl+Shift+I`）

常用对比/恢复：
- `去字预览`：切换显示原图/去字底图（`Ctrl+Alt+B`）
- `恢复原图`：清除本页去字底图（`Ctrl+Alt+Shift+B`）

### 5）导出 / 预览 PPT

- 导出：`导出PPT`（`Ctrl+S`）
- 预览：`预览PPT`（`F5`）

导出规则：
- 如果某一页存在“去字底图”，导出会优先使用去字底图作为背景。
- 导出的文本框在 PowerPoint 中可继续编辑。

### 6）导出显示效果（视图标签）

在 `视图` 标签 → `PPT导出设置`：
- 开/关“文本框背景色”
- 设置全局背景色与透明度
- 吸管从当前图片取色
- 单框背景：选中文本框后，可在右侧属性面板中设置“单独背景色/透明度”

## 快捷键

在软件内按 `F1` 可以打开快捷键速查表。

## 配置说明

程序运行时会在 `settings.json` 里保存配置（由软件自动读写）。该文件可能包含本机路径或私有服务地址，因此已明确排除在 Git 之外。需要配置模板时可复制 `settings.example.json`；示例只引用 localhost。

### OCR 模型缓存目录

`设置` 标签 → `OCR 设置`：
- `模型缓存目录（PADDLE_PDX_CACHE_HOME）`：PaddleOCR/PaddleX 模型下载目录（其下会生成 `official_models/`）
- 可选：手动指定 det/rec 模型目录（存在才会使用）
- 可选：启用 GPU（GPU 不可用会自动回退 CPU）

## 常见问题（Troubleshooting）

- 缺少 qtawesome：运行 `pip install qtawesome`
- OCR 初始化失败 / 下载模型失败：
  - 首次运行需要下载模型，确认网络可用
  - 在 `OCR 设置` 中把模型缓存目录改为可写目录
  - 若启用 GPU：确认安装了匹配的 PaddlePaddle GPU wheel + CUDA 运行环境
- PDF 导入失败：
  - 确认已安装 PyMuPDF（`pip install pymupdf`）
- IOPaint 去字失败：
  - 确认 IOPaint 服务已启动
  - 检查 `IOPaint 设置` 中 API 地址（默认：`http://127.0.0.1:8080/api/v1/inpaint`）

## 项目结构

- `main.py`：GUI + 工作流（导入/OCR/编辑/导出）
- `ocr_engine.py`：PaddleOCR 封装（兼容 2.x/3.x）
- `ppt_export.py`：生成可编辑的 PPTX（文本框位置/字体/背景/透明度等）

## 致谢

- PaddleOCR / PaddlePaddle
- PySide6（Qt）
- python-pptx
- PyMuPDF（PDF 导入）
- IOPaint（可选去字后端）
- QtAwesome（图标）

## 来源与许可状态

本项目基于 [Tansuo2021/OCRPDF-TO-PPT](https://github.com/Tansuo2021/OCRPDF-TO-PPT)。来源说明和许可状态见 [NOTICE.md](NOTICE.md)。准备此私有仓库时，上游没有提供明确的许可证；在获得许可或确认许可证条款前，请勿将仓库公开或重新分发代码。
