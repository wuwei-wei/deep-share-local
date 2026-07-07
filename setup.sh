#!/usr/bin/env bash
set -e

# ── Colors ──────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_step() { echo -e "\n${CYAN}[$1/4]${NC} $2"; }
print_ok()   { echo -e "  ${GREEN}[✓]${NC} $1"; }
print_err()  { echo -e "  ${RED}[✗]${NC} $1"; }
print_warn() { echo -e "  ${YELLOW}[!]${NC} $1"; }

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║     DeepShare Local DOCX Server - 一键安装程序      ║"
echo "╚══════════════════════════════════════════════════════╝"

# ── Detect OS ───────────────────────────────────────────
OS="unknown"
case "$(uname -s)" in
    Darwin)  OS="macos" ;;
    Linux)   OS="linux" ;;
    MINGW*|MSYS*|CYGWIN*) OS="windows" ;;
esac

# ── Step 1: Check Python ────────────────────────────────
print_step "1/4" "检查 Python 环境..."
if command -v python3 &>/dev/null; then
    print_ok "已检测到 $(python3 --version)"
    PYTHON="python3"
elif command -v python &>/dev/null; then
    print_ok "已检测到 $(python --version)"
    PYTHON="python"
else
    print_err "未检测到 Python"
    echo ""
    echo "  请先安装 Python 3.10+:"
    echo "    macOS:  brew install python@3.12"
    echo "    Ubuntu: sudo apt install python3 python3-pip"
    echo "    或访问: https://www.python.org/downloads/"
    exit 1
fi

# ── Step 2: Check Pandoc ────────────────────────────────
print_step "2/4" "检查 Pandoc 环境..."
if command -v pandoc &>/dev/null; then
    print_ok "已检测到 $(pandoc --version | head -1)"
else
    print_err "未检测到 Pandoc"
    echo ""
    echo "  正在尝试自动安装..."

    case "$OS" in
        macos)
            if command -v brew &>/dev/null; then
                echo "  → brew install pandoc"
                brew install pandoc
                print_ok "Pandoc 安装完成"
            else
                print_err "请先安装 Homebrew (https://brew.sh)，然后运行: brew install pandoc"
                exit 1
            fi
            ;;
        linux)
            if command -v apt-get &>/dev/null; then
                echo "  → sudo apt-get install -y pandoc"
                sudo apt-get update -qq
                sudo apt-get install -y pandoc
                print_ok "Pandoc 安装完成"
            elif command -v dnf &>/dev/null; then
                echo "  → sudo dnf install -y pandoc"
                sudo dnf install -y pandoc
                print_ok "Pandoc 安装完成"
            else
                print_err "无法自动安装，请手动安装: https://pandoc.org/installing.html"
                exit 1
            fi
            ;;
    esac
fi

# ── Step 3: Install Python dependencies ─────────────────
print_step "3/4" "安装 Python 依赖..."
$PYTHON -m pip install -r "$(dirname "$0")/requirements.txt" -q 2>/dev/null || {
    print_warn "静默安装失败，重试..."
    $PYTHON -m pip install -r "$(dirname "$0")/requirements.txt"
}
print_ok "Python 依赖安装完成"

# ── Step 4: Generate reference template ─────────────────
print_step "4/4" "生成 Word 参考模板..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ ! -f "$SCRIPT_DIR/templates/reference.docx" ]; then
    pandoc -o "$SCRIPT_DIR/templates/reference.docx" --print-default-data-file reference.docx 2>/dev/null && {
        print_ok "参考模板已生成: templates/reference.docx"
    } || {
        print_warn "模板生成失败（不影响使用，将使用 Pandoc 默认样式）"
    }
else
    print_ok "参考模板已存在: templates/reference.docx"
fi

# ── Done ────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              ✓  安装完成！                           ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "  启动方式:"
echo "    python server.py"
echo ""
echo "  启动后，在 DeepShare 扩展中设置:"
echo "    Server URL: http://localhost:5050"
echo "    API Key:    任意填写（本地不验证）"
echo ""
echo -n "  现在启动服务？(y/N) "
read -r answer
case "$answer" in
    [Yy]*)
        echo ""
        $PYTHON "$SCRIPT_DIR/server.py"
        ;;
esac
