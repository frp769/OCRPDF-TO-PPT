[English](README.md) | 中文

# OCRPDF-TO-PPT（PowerOCR Presentation）

OCRPDF-TO-PPT 是一款面向 Windows 的桌面工具，可将图片或 PDF 页面经过 OCR 识别后导出为可继续编辑的 PowerPoint（`.pptx`）。导出时，原图或去字后的图片作为幻灯片背景，识别出的文字区域则转换成可移动、可修改、可重新排版的 PPT 文本框。

日常使用无需打开控制台：安装依赖后，双击项目根目录的 **`一键启动 OCRPDF-TO-PPT.bat`** 即可启动。

![PowerOCR 当前主界面](docs/images/main-window.png)

## 当前版本亮点

- Ribbon 风格界面：功能集中在“开始 / 视图 / 设置”三个选项卡中。
- 多页编辑：支持导入图片与 PDF、新建空白页、复制页面、调整顺序和缩略图导航。
- 拖放导入：可把图片和 PDF 混合拖入窗口，自动去重并提示不支持的文件。
- OCR 与选区：可识别当前页或全部页面，也可框选 ROI 后只处理指定区域。
- 可编辑文本框：支持移动、缩放、双击改字、字体大小、颜色、粗体、对齐、背景色和透明度。
- **多选删除**：按住 `Ctrl` 依次点击多个文本框可增减选择，按 `Delete` 会一次删除所有已选文本框。
- 三种去字方式：智能去字、纯色填充、IOPaint；均提供当前页与全部页面操作。
- 可编辑 PPTX：导出的文本仍是 PowerPoint 文本框，可在 PowerPoint 中继续修改。
- 防损坏保存：设置文件异常时可从备份恢复；PPT 导出失败时不会覆盖原有文件。
- 一键启动：脚本自动使用项目专用环境并以无控制台方式启动 GUI。

## 当前界面

“视图”选项卡集中管理文本框背景、取色、透明度与 PPT 预览；“设置”选项卡提供 OCR、去字、语言和编辑操作。

<p>
  <img src="docs/images/view-tab.png" alt="视图选项卡" width="49%">
  <img src="docs/images/settings-tab.png" alt="设置选项卡" width="49%">
</p>

### 开始

- 剪贴板：粘贴文本框或图片。
- 页面：新建空白页、复制页、删除页、上移和下移。
- 导入：图片、PDF、文本框。
- OCR：当前页、全部页面。
- 导出：生成 PPTX。
- 选区：框选 ROI、清除 ROI。
- 去字：智能去字、纯色填充、IOPaint，以及预览和恢复原图。

### 视图

- 控制导出时是否显示文本框背景。
- 设置全局背景色、从图片吸取颜色并调整背景透明度。
- 一键预览当前 PPT 导出效果。

### 设置

- 打开 OCR 设置、重新加载 OCR 引擎和去字设置。
- 切换自动/跟随系统、中文或英文界面。
- 提供撤销、重做、剪切、复制和粘贴操作。

## 系统要求

- Windows 10 1809 或更高版本、Windows 11，Intel/AMD x86-64。
- 无需预先安装 Python；修复脚本会下载并校验项目内 CPython 3.13.14。
- 首次安装依赖和首次下载 OCR 模型时需要网络连接。
- 建议预留数 GB 磁盘空间供 Python 环境和 OCR 模型使用。

PaddlePaddle 对 Python、CUDA 和显卡驱动的组合有版本要求。默认使用 CPU 即可；如需 GPU，请按照 PaddlePaddle 官方文档安装与本机 CUDA 匹配的版本。

## 快速开始（推荐）

### 1. 获取项目

```powershell
git clone https://github.com/frp769/OCRPDF-TO-PPT.git
cd OCRPDF-TO-PPT
```

也可以从 GitHub 下载 ZIP 后解压。

### 2. 一键启动

双击 `一键启动 OCRPDF-TO-PPT.bat`。

启动器会检查项目内的 `.runtime` 和 `.venv-launcher`。在新设备、全新解压目录或依赖损坏时，它会下载 Python 官方 CPython 3.13.14 x64 NuGet 运行时、核对固定 SHA-256 校验值，再依据 `requirements-lock-win10.txt` 创建或修复项目专用环境；检查通过后使用该环境中的 `pythonw.exe` 打开图形界面。因此**不需要安装系统 Python，也不需要在控制台中运行 `python main.py`**。

如果自动准备失败，可双击 `安装或修复依赖.bat` 查看完整安装过程；如需强制重装并核验所有依赖，可双击 `检查并修复程序.bat`。常见原因是 NuGet/PyPI 被网络或代理阻断、安全软件拦截、项目目录只读，或磁盘空间不足。

首次执行 OCR 时，PaddleOCR/PaddleX 可能下载模型。模型保存在本地缓存目录，不会上传到 GitHub。

### 跨设备运行原理

- BAT 和 PowerShell 脚本都从自身位置计算项目根目录，不绑定原电脑的盘符、用户名或绝对路径；带空格或中文的目录也可使用。
- 基础 Python 下载到 `.runtime\python313`，不依赖也不修改系统 Python。
- `.venv-launcher` 始终创建在当前项目目录内，启动时明确设置 `VIRTUAL_ENV` 并禁用系统用户级 Python 包。
- Windows 锁定依赖文件保证不同日期安装时使用相同版本，而不是临时获取最新版。
- `.runtime`、`.venv-launcher` 和模型目录不会上传 GitHub，因此 Git 克隆会在每台电脑本地重建；如果直接完整复制已经准备好的项目文件夹，启动器会先修复移动后的虚拟环境路径再运行。

完整支持范围、限制和不支持的平台见 [PORTABLE_COMPATIBILITY.md](PORTABLE_COMPATIBILITY.md)。

## 使用流程

### 1. 导入图片或 PDF

- 点击“导入图片”，或按 `Ctrl+O`。
- 点击“导入 PDF”，或按 `Ctrl+Shift+O`。
- 也可以把一个或多个图片/PDF 直接拖放到程序窗口。
- PDF 会按页渲染为图片，并显示在左侧缩略图列表中。
- 也可以新建空白页、复制当前页、删除页面或调整页面顺序。

### 2. 执行 OCR

- “OCR 本页”：只识别当前页面，快捷键 `Ctrl+Enter`。
- “OCR 全部”：依次识别所有页面，快捷键 `Ctrl+R`。
- 如只需处理局部内容，可先使用“框选选区”拖出 ROI；完成后可“清除选区”恢复整页范围。

### 3. 编辑识别结果

- 单击文本框进行选择；拖动文本框可移动，拖动控制点可缩放。
- 双击文本框可直接修改文字。
- 右侧属性面板可调整文字、字号、颜色、粗体、对齐、背景色和透明度。
- 可为单个文本框设置是否参与去字以及使用哪种去字模式。
- “将样式应用到本页所有文本框”可快速统一当前页格式。
- 支持 `Ctrl+C / Ctrl+X / Ctrl+V` 复制、剪切和粘贴文本框。
- 未选择文本框时，`Ctrl+V` 可粘贴剪贴板图片；`Ctrl+Shift+V` 可直接粘贴图片。

#### 多选与批量删除

1. 按住 `Ctrl`，依次点击需要选择或取消选择的文本框；
2. 所有已选文本框会保持选中状态；
3. 按 `Delete`，或点击右侧面板的“删除选中文本框”，即可一次删除全部已选项；
4. 如有误操作，可按 `Ctrl+Z` 撤销。

### 4. 去除底图文字

去字可以减少“底图原文字 + OCR 文本框”叠加造成的重影。当前版本提供：

- **智能去字**：自动决定优先使用 IOPaint 或纯色填充，适合多数页面。
- **纯色填充**：使用背景色填充文字区域，适合背景颜色较均匀的页面。
- **IOPaint**：调用本机 IOPaint API 进行修复，适合纹理或复杂背景；此功能可选。

每种模式均可处理当前页或全部页面。可通过“去字预览”切换原图与处理后背景，也可以使用“恢复原图”清除当前页的去字结果。

如需 IOPaint，可在本机启动服务，例如：

```powershell
iopaint start --host 127.0.0.1 --port 8080
```

然后在“设置 → 去字设置”中启用并确认 API 地址。默认示例地址为 `http://127.0.0.1:8080/api/v1/inpaint`。

### 5. 预览并导出 PPT

- 按 `F5` 或点击“预览 PPT”查看效果。
- 按 `Ctrl+S` 或点击“导出 PPT”保存 `.pptx`。
- 若页面已有去字背景，导出会优先使用该背景。
- OCR 文本会作为独立文本框导出，仍可在 PowerPoint 中继续修改。

## 快捷键

在程序中按 `F1` 可打开快捷键速查。

| 操作 | 快捷键 |
| --- | --- |
| 导入图片 / 导入 PDF | `Ctrl+O` / `Ctrl+Shift+O` |
| OCR 当前页 / 全部页面 | `Ctrl+Enter` / `Ctrl+R` |
| 智能去字当前页 / 全部页面 | `Ctrl+I` / `Ctrl+Shift+I` |
| 导出 / 预览 PPT | `Ctrl+S` / `F5` |
| 新建 / 复制当前页 | `Ctrl+N` / `Ctrl+D` |
| 页面上移 / 下移 | `Alt+Up` / `Alt+Down` |
| 上一页 / 下一页 | `PageUp` / `PageDown` |
| 多选或取消选择文本框 | `Ctrl+单击` |
| 删除全部已选文本框 | `Delete` |
| 撤销 / 重做 | `Ctrl+Z` / `Ctrl+Y` |
| 粘贴图片 | `Ctrl+Shift+V` |
| 适合窗口 | `Ctrl+0` |
| 放大 / 缩小 | `Ctrl++` / `Ctrl+-` |
| 切换缩略图栏 | `Ctrl+Alt+L` |
| 切换右侧属性栏 | `Ctrl+Alt+R` |
| 快捷键帮助 | `F1` |

画布还支持 `Ctrl+滚轮` 缩放，以及按住滚轮拖动画布。

## 高级：从控制台手动运行

一键启动已经覆盖日常使用。只有在开发或排查问题时，才需要手动运行：

```powershell
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -U pip
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe main.py
```

手动环境与一键启动使用的 `.venv-launcher` 相互独立。

## 配置与隐私

- 程序运行配置保存在本地 `settings.json`。
- 设置采用原子写入；上一份有效配置保留为 `settings.json.bak`，主文件损坏时自动恢复。
- `settings.json` 可能包含本机路径或私有服务地址，因此已被 `.gitignore` 排除。
- 可复制 `settings.example.json` 作为安全配置模板；示例只使用 localhost。
- 虚拟环境、日志、模型缓存、AI/去字缓存、生成的 PDF/PPT 和压缩包均不会提交到 Git。
- 发布前仍应检查自己的截图、示例文件和新增配置，避免意外包含个人信息。

## 常见问题

### 双击一键启动后没有出现窗口

1. 查看 `logs/launcher.log`；
2. 双击 `检查并修复程序.bat`；
3. 确认当前网络能够访问 NuGet 和 PyPI；
4. 若安全软件拦截脚本，请允许项目目录中的 BAT、PowerShell 和 `pythonw.exe`。

### OCR 首次启动较慢

首次 OCR 可能需要下载并初始化模型。请保持网络畅通，并确认模型缓存目录可写。

### PDF 无法导入

重新运行依赖安装脚本，并确认 PyMuPDF 已成功安装。

### GPU 不可用

程序会尝试回退到 CPU。若必须使用 GPU，请检查 PaddlePaddle GPU wheel、CUDA 和显卡驱动是否匹配。

### IOPaint 去字失败

确认 IOPaint 服务已在本机启动，并在“设置 → 去字设置”中检查 API 地址。智能去字与纯色填充不要求启动 IOPaint。

## 项目结构

```text
OCRPDF-TO-PPT/
├─ 一键启动 OCRPDF-TO-PPT.bat   # 日常启动入口
├─ 安装或修复依赖.bat           # 首次安装与环境修复
├─ 检查并修复程序.bat           # 强制核验并重装锁定依赖
├─ requirements-lock-win10.txt  # Windows 可复现依赖版本
├─ scripts/
│  ├─ start.ps1                 # 自动修复、依赖预检与无控制台启动
│  ├─ setup.ps1                 # Python 3.13 环境安装/修复
│  └─ preflight.py              # 启动前依赖检查
├─ launcher.pyw                 # Windows 图形启动器
├─ main.py                      # Ribbon 界面与主工作流
├─ ocr_engine.py                # PaddleOCR 2.x/3.x 兼容封装
├─ ppt_export.py                # 可编辑 PPTX 导出
├─ persistence.py               # 设置原子写入和备份恢复
├─ settings.example.json        # 安全的本地配置示例
├─ docs/images/                 # 当前界面截图
└─ tests/                       # 核心自动化测试
```

## 开发验证

安装依赖后可运行：

```powershell
.\.venv-launcher\Scripts\python.exe scripts\preflight.py
.\.venv-launcher\Scripts\python.exe -m unittest discover -s tests -v
```

## 来源与许可状态

本项目基于 [Tansuo2021/OCRPDF-TO-PPT](https://github.com/Tansuo2021/OCRPDF-TO-PPT)。来源说明和许可状态见 [NOTICE.md](NOTICE.md)。

准备此私有仓库时，上游没有提供明确的许可证，因此本仓库保持私有。在获得许可或确认许可证条款前，请勿公开仓库或重新分发代码。

## 致谢

- PaddleOCR / PaddlePaddle
- PySide6（Qt）
- python-pptx
- PyMuPDF
- IOPaint（可选去字后端）
- QtAwesome
