#!/bin/bash
set -e

echo "==> 開始進行應用程式建置 (Build Application) <=="

# 模擬測試階段
echo "執行輕量級 Python 語法檢查 (Linting)..."
python3 -m py_compile app.py
echo "==> 語法檢查 ✅ 通過！"

# 開始打包階段
echo "正在將代碼打包為 artifact (app.zip)..."
# 清除舊的打包檔
rm -f app.zip

# 執行打包 (沒有裝 zip 可以用 tar，但 Mac 跟 Ubuntu 基本都有 zip 或 built-in python zip)
python3 -m zipfile -c app.zip app.py

echo "==> 打包完成！"
ls -lh app.zip
