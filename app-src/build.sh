#!/bin/bash
set -e

echo "==> 開始進行應用程式建置 (Build) <=="

# 語法檢查：使用 Python 內建的 py_compile 模組驗證語法正確性
echo "執行 Python 語法檢查..."
python3 -m py_compile app.py
echo "==> 語法檢查通過 ✅"

# 打包階段：將應用程式打包為 zip，供 Ansible 傳送到目標容器
echo "正在將程式碼打包為 app.zip..."
rm -f app.zip
python3 -m zipfile -c app.zip app.py

echo "==> 打包完成 ✅"
ls -lh app.zip
