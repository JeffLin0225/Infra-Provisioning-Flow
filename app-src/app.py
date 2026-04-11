import os
from http.server import BaseHTTPRequestHandler, HTTPServer
import socket

# 取得機器的 Hostname 方便辨識這是哪一台 VM
hostname = socket.gethostname()
port = 8080

class SimpleHandler(BaseHTTPRequestHandler):
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
                <h1>🚀 恭喜！CI/CD 自動化極速發布大成功！</h1>
                <h2>歡迎來到伺服器，我是 <span class="highlight">{hostname}</span> 號機</h2>
                <p>這支 Python 微型服務由 Jenkins 進行 Build (建置打包)，並由 Ansible 全自動派送上線！</p>
                <p>零外部依賴、秒級啟動，是極輕量化部署的最佳示範方案！</p>
            </body>
        </html>
        """
        self.wfile.write(html.encode("utf-8"))

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', port), SimpleHandler)
    print(f"極輕量 Python Server 已在 Port {port} 啟動...")
    server.serve_forever()
