# 基礎建設自動化與 CI/CD 部署流程 (Infrastructure as Code & CI/CD Pipeline)

本專案展示了一個基於 **Jenkins**, **Terraform** 與 **Ansible** 的全自動化基礎建設與持續整合/持續部署 (CI/CD) 解決方案。透過將基礎架構腳本化 (IaC) 以及組態管理自動化，實現從開發端提交程式碼到伺服器資源開通、應用軟體部署的一鍵式工作流。

## 架構概覽與系統角色

本系統由三個核心元件組成，各自負責自動化生命週期的不同階段：

1. **Jenkins (CI/CD 自動化管線 控制中心)**：
   作為自動化排程的核心，負責監聽版本控制系統 (如 Git) 的變更。當偵測到更新時，觸發自動化管線 (Pipeline)，依序指揮後續的資源建置與組態配置任務。

2. **Terraform (基礎建設即程式碼 IaC)**：
   負責下層運算資源的管理與開通。本專案透過 Terraform 與 Docker Provider (本地 Orbstack 環境) 互動，動態配置出具備 SSH 連線能力的 Ubuntu 目標伺服器容器。

3. **Ansible (組態管理與自動化部署)**：
   負責伺服器內部的組態設定。在伺服器（容器）開通後，Ansible 會透過 SSH 自動連入目標機器，並依照 Playbook 定義的流程安裝系統軟體 (Nginx, Java) 與部署前端應用程式 (`index.html`)。

## 總體系統邏輯架構圖 (System Architecture)

本專案建構於單機開發環境中，精確劃分了「本機開發層」與「容器運行層」的邊界。以下架構圖展示了 macOS 本機工具、存放原始碼的 GitHub，以及運作在 Orbstack 引擎上的容器（Jenkins 與 Target VM）之間是如何連動配合的：

```mermaid
flowchart TD
    Git["GitHub Repository<br>(版本控制與程式碼中樞)"]
    
    subgraph macOS [macOS 本機開發層]
        Dev("開發人員")
        LocalTools["本機工具鏈<br>(Terraform, Ansible)"]
        Dev -.->|"本地編輯腳本與除錯"| LocalTools
        Dev -->|"Push 提交程式碼變更"| Git
    end
    
    subgraph Orbstack [Orbstack 容器運行層]
        Jenkins{"Jenkins Server<br>(容器自動化管線)"}
        DockerAPI[("Docker Daemon<br>(底層資源分配)")]
        VMCluster["目標伺服器叢集<br>(Ubuntu Container VM 陣列)"]
    end
    
    Git -->|"Webhook 觸發部署事件"| Jenkins
    
    Jenkins -->|"Phase 1: 調用 Terraform 執行 IaC"| DockerAPI
    DockerAPI -.->|"開通與孵化機器"| VMCluster
    Jenkins -->|"Phase 2: 調用 Ansible 透過 SSH 連線"| VMCluster
    
    VMCluster -.->|"組態完畢，提供對外服務"| App("Nginx 網頁伺服器 + Java 環境")

    classDef jenk fill:#fadbd8,stroke:#943126,stroke-width:2px,color:#000;
    class Jenkins jenk;
```

## 專案資料夾結構

```text
auto-infra-build/
├── README.md               # 專案總覽文件 (本文件)
├── jenkins-lab/
│   └── README.md           # Jenkins 管線流程說明與架構
├── terraform-lab/
│   ├── main.tf             # Terraform IaC 啟動目標伺服器之定義檔
│   └── README.md           # Terraform 資源配置說明與架構
└── ansible/
    ├── gcp_setup.yml       # Ansible 組態腳本 (安裝 Nginx, Java 及部署網頁)
    ├── index.html          # Web 前端應用檔案
    └── README.md           # Ansible 部署流程說明與架構
```

## 端到端自動化運作流程 (Pipeline Architecture)

以下流程圖說明當有新程式碼提交時，這三套系統如何協同完成從環境建置到服務上線的完整自動化流程：

```mermaid
sequenceDiagram
    participant Dev as 開發人員 (Developer)
    participant Git as 版本控制 (Git Repository)
    participant Jenkins as Jenkins (CI/CD Server)
    participant Terraform as Terraform
    participant Ansible as Ansible
    participant Infra as 目標環境 (Ubuntu Server)

    Dev->>Git: 1. 提交程式碼與設定變更 (Push)
    Git->>Jenkins: 2. 觸發 CI/CD Pipeline (Webhook)
    Jenkins->>Jenkins: 進入自動化管線流程
    
    rect rgb(200, 220, 240)
        Note over Jenkins, Infra: Phase 1: 基礎設施開通 (Provisioning)
        Jenkins->>Terraform: 3. 執行 `terraform apply`
        Terraform->>Infra: 配置與啟動運算資源 (Docker Container)
        Infra-->>Terraform: 回傳連線資訊 (IP/Port 2222)
        Terraform-->>Jenkins: 基礎設施就緒
    end
    
    rect rgb(220, 240, 200)
        Note over Jenkins, Infra: Phase 2: 組態設定與軟體部署 (Configuration & Deployment)
        Jenkins->>Ansible: 4. 執行 `ansible-playbook`
        Ansible->>Infra: 透過 SSH 連入目標環境
        Ansible->>Infra: 自動安裝相依軟體 (Nginx, Java), 部署網頁
        Infra-->>Ansible: 應用程式就緒
        Ansible-->>Jenkins: 部署完成
    end

    Jenkins->>Dev: 5. 輸出維運報表與通知 (Notification)
```
