import os
from http.server import BaseHTTPRequestHandler, HTTPServer
import socket

# 取得容器的 Hostname，用來辨識這是哪一台 VM 在回應
hostname = socket.gethostname()
port = 8080

class SimpleHandler(BaseHTTPRequestHandler):
    """極輕量 HTTP 處理器，收到 GET 請求時回傳一個簡單的 HTML 頁面"""
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-type', 'text/html; charset=utf-8')
        self.end_headers()
        html = f"""
        <html>
            <head>
                <title>Auto Infra CI/CD App</title>
                <style>
                    body {{ font-family: 'Helvetica Neue', Arial, sans-serif; text-align: center; margin-top: 80px; background: #282c34; color: white; }}
                    h1 {{ color: #61dafb; font-size: 3em; }}
                    .highlight {{ color: #ffeb3b; }}
                </style>
            </head>
            <body>
                <h1>🚀 CI/CD 自動化部署成功！</h1>
                <h2>目前回應的伺服器是 <span class="highlight">{hostname}</span></h2>
                <p>容器內部監聽 Port：<span class="highlight">{port}</span></p>
                <p>這支 Python 微型服務由 Jenkins 進行建置打包，並由 Ansible 全自動派送上線。</p>
            </body>
        </html>
        """
        self.wfile.write(html.encode("utf-8"))

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', port), SimpleHandler)
    print(f"Python Web Server 已在 Port {port} 啟動，等待連線中...")
    server.serve_forever()
