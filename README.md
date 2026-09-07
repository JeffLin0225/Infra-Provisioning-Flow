# 基礎建設自動化與 CI/CD 部署流程 (Infrastructure as Code & CI/CD Pipeline)

本專案實作了一套基於 **Jenkins**、**Terraform** 與 **Ansible** 的企業級端到端基礎設施自動化與應用交付流程。藉由 **Pipeline as Code** 設計，透過 Jenkins 參數化單鍵觸發，自動貫穿「虛擬容器叢集撥補（IaC）→ 埠位探針就緒驗收 → 動態資產清冊生成 → 程式碼靜態語法檢驗與封裝 → Ansible 平行派送與行程守護 → HTTP 服務健康驗收」的全自動化流水線，達成基礎架構與應用交付的百分之百程式碼化。

---

## 系統架構

```mermaid
flowchart TB
    %% 節點樣式定義
    classDef client fill:#e8f4fd,stroke:#2b7bb9,stroke-width:2px,color:#1e3d59;
    classDef pipeline fill:#fff3e0,stroke:#e65100,stroke-width:2px,color:#bf360c;
    classDef iac fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px,color:#4a148c;
    classDef runtime fill:#e8f8f5,stroke:#117864,stroke-width:2px,color:#0e6251;
    classDef config fill:#eaf2f8,stroke:#2471a3,stroke-width:2px,color:#154360;
    classDef teardown fill:#fdedec,stroke:#c0392b,stroke-width:2px,color:#922b21;

    %% 01. 觸發與控制層
    subgraph Layer1 ["01. 版本控制與觸發層 (SCM & Developer Interface)"]
        Dev["開發與維運人員<br>(Developer / DevOps)"]
        GitRepo["GitHub Repository<br>JeffLin0225/Infra-Provisioning-Flow"]
    end

    %% 02. CI/CD 調度中樞
    subgraph Layer2 ["02. CI/CD 管線調度層 (Pipeline Controller)"]
        Jenkins["Jenkins Pipeline Controller<br>Port: 8080 | Standalone WAR<br>(Zero-Pollution Isolated Data)"]
        Param["管線參數面板 (Build with Parameters)<br>ACTION: apply / destroy<br>VM_COUNT: 3 | START_PORT: 2222<br>WEB_PORT_START: 8081 | DEPLOY_TARGET: web_servers"]
    end

    %% 03. 基礎設施撥補層 (IaC)
    subgraph Layer3 ["03. 基礎設施即程式碼撥補層 (IaC Engine)"]
        TF["Terraform 核心引擎<br>(kreuzwerker/docker ~> 3.0.1)"]
        SSHProbe["SSH 連線探針 (local-exec)<br>nc -w 5 | grep SSH<br>Max Timeout: 180s (60 次輪詢)"]
        DynInv["動態清冊渲染 (local_file)<br>ansible/dynamic_hosts.ini<br>前 2 台: web_servers | 餘數: others"]
    end

    %% 04. 執行階段容器環境
    subgraph Layer4 ["04. 虛擬目標容器叢集 (Target Environment - Orbstack / Docker)"]
        DockerD[("Docker Daemon<br>Unix Socket API")]
        VM1["ansible-target-1 (Ubuntu 22.04)<br>SSH: 2222 -> 22 | HTTP: 8081 -> 8080<br>Group: [web_servers]"]
        VM2["ansible-target-2 (Ubuntu 22.04)<br>SSH: 2223 -> 22 | HTTP: 8082 -> 8080<br>Group: [web_servers]"]
        VM3["ansible-target-3 (Ubuntu 22.04)<br>SSH: 2224 -> 22 | HTTP: 8083 -> 8080<br>Group: [others]"]
    end

    %% 05. 應用建置與發布層
    subgraph Layer5 ["05. 應用打包與組態交付層 (Build & Configuration)"]
        BuildEngine["應用建置引擎 (build.sh)<br>1. py_compile 語法檢驗<br>2. zipfile 封裝產出 app.zip"]
        AnsibleEngine["Ansible 組態引擎 (Conda: codedev)<br>Playbook: demo_setup.yml<br>SSH 認證 (StrictHostKeyChecking=no)"]
        DeployOps["目標容器內生命週期管理<br>1. apt 安裝 python3, unzip<br>2. 依 app.pid 精準中止舊服務<br>3. nohup 背景啟動 app.py<br>4. 15s 內部 HTTP 8080 探針驗收"]
    end

    %% 06. 銷毀與治理流程
    subgraph Layer6 ["06. 資源回收與治理通道 (Teardown & Cleanup)"]
        DestroyAction["銷毀請求 (ACTION=destroy)"]
        TFDestroy["Terraform Destroy<br>自動化反撥補釋放所有容器與連接埠"]
    end

    %% 主鏈路步驟 (1. ~ 10.)
    Dev -->|"1. Git Push / 觸發管線"| GitRepo
    GitRepo -->|"2. SCM 拉取 Jenkinsfile"| Jenkins
    Jenkins -->|"3. 讀取調度參數"| Param
    Param -->|"4. 啟動基礎架構撥補"| TF
    TF -->|"5. 呼叫 Docker API 啟動 N 台容器"| DockerD
    DockerD --> VM1
    DockerD --> VM2
    DockerD --> VM3
    DockerD -->|"6. 驗證容器 OpenSSH 守護行程"| SSHProbe
    SSHProbe -->|"7. 驗收完成，渲染資產清冊"| DynInv
    Jenkins -->|"8. 觸發應用程式碼打包"| BuildEngine
    BuildEngine -->|"9. 移交 Artifact (app.zip)"| AnsibleEngine
    DynInv -.->|"注入動態節點清冊"| AnsibleEngine
    AnsibleEngine -->|"10. 平行 SSH 部署與守護"| DeployOps
    DeployOps -.->|"派送代碼並驗證上線"| VM1
    DeployOps -.->|"派送代碼並驗證上線"| VM2

    %% 銷毀治理鏈路步驟 (A. ~ C.)
    Param -.->|"A. 觸發銷毀流程"| DestroyAction
    DestroyAction -->|"B. 執行反撥補"| TFDestroy
    TFDestroy -->|"C. 一鍵釋放容器與關閉連接埠"| DockerD

    %% 套用樣式類別
    class Dev,GitRepo client;
    class Jenkins,Param pipeline;
    class TF,SSHProbe,DynInv iac;
    class DockerD,VM1,VM2,VM3 runtime;
    class BuildEngine,AnsibleEngine,DeployOps config;
    class DestroyAction,TFDestroy teardown;
```

---

## 專案結構

```text
.
├── .gitignore                   # Git 排除清單 (包含 tfstate、動態主機清單、jenkins.war 等)
├── README.md                    # 專案架構說明與維運手冊 (本文件)
│
├── jenkins-lab/                 # 【① CI/CD 調度中樞】
│   ├── INSTALL.md               # Jenkins 本機綠色版 (WAR) 零污染安裝與初始化指南
│   ├── README.md                # Jenkins 模組管線架構與運作邏輯解析
│   ├── Jenkinsfile              # 宣告式流水線腳本 (涵蓋環境檢查、IaC、打包、部署全階段)
│   ├── jenkins.war              # Jenkins 核心可執行檔 (首次執行請依文件手動下載)
│   └── jenkins_data/            # Jenkins 本機執行目錄 (含插件與 Job 狀態，自動生成)
│
├── terraform-lab/               # 【② 基礎設施撥補模組】
│   ├── main.tf                  # HCL 基礎設施定義：容器叢集、SSH 探針驗收、動態清冊渲染
│   ├── main.bak                 # 早期基礎架構設計歷史備份檔
│   └── README.md                # Terraform 模組使用說明與變數設定文件
│
├── app-src/                     # 【③ 輕量 Web 應用原始碼】
│   ├── app.py                   # 原生 Python 3 極輕量 HTTP 伺服器 (包含主機名動態辨識，零依賴)
│   └── build.sh                 # 應用打包腳本 (py_compile 語法檢驗 + 封裝為 app.zip)
│
└── ansible/                     # 【④ 組態管理與自動發布模組】
    ├── demo_setup.yml           # 核心部署 Playbook：環境初始化、解壓、進程清理、背景啟動與探針檢驗
    ├── dynamic_hosts.ini        # 由 Terraform 動態產出之主機清冊 (依 Port 與群組配置)
    ├── demo_hosts.ini           # 靜態主機清單範本 (歷史驗證參考)
    ├── local_setup.yml          # 本機環境部署演練腳本 (參考用)
    ├── index.html               # 靜態首頁範本 (早期測試用)
    └── README.md                # Ansible Playbook 任務流程與分群派送說明
```

---

## 模組總覽與核心職責

本專案採用關注點分離 (Separation of Concerns) 架構，模組可由 Jenkins 集中調度，亦支援工程師手動獨立執行與驗證：

| 順序 | 模組目錄 | 核心技術 | 職責與架構亮點 | 參考文件 |
|:---:|:---|:---|:---|:---|
| ① | `jenkins-lab/` | **Jenkins 2.x** (Pipeline as Code) | **CI/CD 控制中樞**：集中調度各階段任務，透過參數面板控制拓撲規格與發布策略。 | [`INSTALL.md`](file:///Users/jeff/Desktop/change/Infra-Provisioning-Flow/jenkins-lab/INSTALL.md)<br>[`README.md`](file:///Users/jeff/Desktop/change/Infra-Provisioning-Flow/jenkins-lab/README.md) |
| ② | `terraform-lab/` | **Terraform** (Docker Provider) | **IaC 資源撥補**：動態開通多節點 Ubuntu 容器，結合本機 `nc` 探針防範假開機，自動模板化輸出 Inventory。 | [`README.md`](file:///Users/jeff/Desktop/change/Infra-Provisioning-Flow/terraform-lab/README.md) |
| ③ | `app-src/` | **Python 3** (標準函式庫) | **應用建置**：零外部相依微服務，內建 `py_compile` 語法靜態檢查與輕量 ZIP 建置封裝。 | [`build.sh`](file:///Users/jeff/Desktop/change/Infra-Provisioning-Flow/app-src/build.sh) |
| ④ | `ansible/` | **Ansible** (Conda 虛擬環境) | **組態交付**：自動化套件佈署、精準 PID 舊行程汰換、`nohup` 背景生命週期託管與 HTTP 連線驗收。 | [`README.md`](file:///Users/jeff/Desktop/change/Infra-Provisioning-Flow/ansible/README.md) |

---

## 事前準備

### 1. 運行環境與相依工具
- **作業系統**：macOS (Apple Silicon 或 Intel 架構均可)。
- **容器引擎**：Docker Desktop 或 OrbStack (確認 `docker ps` 可正常運作)。
- **Java 環境**：Java 17 或 Java 21 (用於驅動本機獨立 Jenkins WAR)。
- **Terraform**：v1.5.0+。
- **Python / Conda**：安裝 Conda 並建立具備 Ansible 的環境：
  ```bash
  conda create -n codedev python=3.10 -y
  conda activate codedev
  pip install ansible
  ```

---

## 快速開始

### Step 1：啟動本機 Jenkins 控制台
```bash
cd jenkins-lab
# 首次使用需手動下載 jenkins.war (詳見 INSTALL.md)
JENKINS_HOME=./jenkins_data java -jar jenkins.war --httpPort=8080
```
瀏覽器訪問 `http://localhost:8080` 完成管理員帳號初始化。

### Step 2：建立 Pipeline 專案
1. 進入 Jenkins 儀表板 → 點選「新增作業 (New Item)」。
2. 輸入名稱 (例如 `Infra-Provisioning-Flow`)，選擇 **Pipeline** 類型。
3. 在設定頁面捲動至 **Pipeline** 區塊：
   - **Definition**：選擇 `Pipeline script from SCM`。
   - **SCM**：選擇 `Git`。
   - **Repository URL**：`https://github.com/JeffLin0225/Infra-Provisioning-Flow.git`。
   - **Branch Specifier**：`*/main` (或對應的工作分支)。
   - **Script Path**：`jenkins-lab/Jenkinsfile`。
4. 點選儲存後，系統將自動解析出參數面板。

### Step 3：參數化一鍵觸發
點選左側「**Build with Parameters**」，依需求調整參數：

| 參數名稱 | 建議值 | 規格說明 |
|:---|:---:|:---|
| `ACTION` | `apply` | 選擇 `apply` 進行開機與部署；選擇 `destroy` 進行環境清空 |
| `VM_COUNT` | `3` | 虛擬目標主機 (容器) 開通總數量 |
| `START_PORT` | `2222` | SSH 映射本機的起始連接埠 (遞增分配：2222, 2223, 2224...) |
| `WEB_PORT_START` | `8081` | Web 服務對外暴露之起始連接埠 (遞增分配：8081, 8082, 8083...) |
| `DEPLOY_TARGET` | `web_servers` | Ansible 部署目標群組：`web_servers` (前2台)、`others` (第3台起)、`all`、`none` (純開機不發布) |

按下 **Build**，管線即會自動執行全流程。

---

## 驗收與維運指令

### 1. HTTP 服務端點驗證
管線執行完畢後，開啟終端機或瀏覽器檢驗部署節點回應：
```bash
# 驗證節點 1 (web_servers)
curl -s http://localhost:8081 | grep "CI/CD 自動化部署成功"

# 驗證節點 2 (web_servers)
curl -s http://localhost:8082 | grep "CI/CD 自動化部署成功"

# 驗證節點 3 (others，未在 web_servers 群組故應無服務監聽)
curl -I http://localhost:8083
```

### 2. SSH 容器穿透手動除錯
如需進入容器檢查日誌或行程狀態，可直接透過對外 Port 連入：
```bash
# 登入 VM-1 (密碼: root)
ssh -p 2222 root@localhost -o StrictHostKeyChecking=no

# 於容器內部檢查行程與日誌
ps aux | grep app.py
cat /opt/auto-infra-app/app.log
cat /opt/auto-infra-app/app.pid
```

### 3. 一鍵銷毀環境 (Teardown)
當完成驗證或需重設環境時：
1. 回到 Jenkins 介面點選 **Build with Parameters**。
2. 將 `ACTION` 改選為 `destroy` 並執行。
3. 管線將調用 `terraform destroy -auto-approve`，毫秒級釋放所有容器資源與連接埠佔用。
