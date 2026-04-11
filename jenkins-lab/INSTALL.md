# Jenkins 安裝教學 (基於 Orbstack Container)

本教學將引導您如何在 macOS 上透過 **Orbstack** (作為 Docker 引擎的輕量化替代方案) 快速安裝並啟動 Jenkins 服務。

## 1. 環境準備

1. **安裝 Orbstack**: 
   如果您尚未安裝 Orbstack，可以前往 [Orbstack 官方網站](https://orbstack.dev/) 下載並安裝。它是一個輕量、快速的 macOS Docker Desktop 替代品。
2. 啟動 Orbstack，確保您可以在終端機中正常執行 `docker` 指令。
   ```bash
   docker --version
   ```

## 2. 取得映像檔並建立 Jenkins 容器

我們會使用官方的 Jenkins LTS (長期支援) 映像檔。為了能夠清楚看到下載進度，我們先將它拉取到本地，再啟動服務。請在終端機中依序執行：

**第一步：拉取映像檔**
```bash
docker pull jenkins/jenkins:lts
```

**第二步：啟動容器**
```bash
docker run -d --name jenkins-server --restart=on-failure -p 8080:8080 -p 50000:50000 -v jenkins_home:/var/jenkins_home jenkins/jenkins:lts
```

**指令說明：**
- `-d`: 在背景執行容器 (Detached mode)。
- `--name jenkins-server`: 將容器命名為 `jenkins-server`，方便後續管理。
- `--restart=on-failure`: 如果容器意外退出，則自動重新啟動。
- `-p 8080:8080`: 將本機的 8080 port 對應到容器內的 8080 port (Jenkins 網頁介面預設 port)。
- `-p 50000:50000`: 對應 50000 port，這是 Jenkins master 與 worker 節點之間通訊用的 port (JnlpPort)。
- `-v jenkins_home:/var/jenkins_home`: 建立一份 Docker Volume 命名為 `jenkins_home`，用於持久化儲存 Jenkins 的設定、管線腳本與安裝的套件。這樣即使容器被刪除，資料也不會遺失。
- `jenkins/jenkins:lts`: 使用官方 jenkins 映像檔的 lts (Long Term Support) 穩定版本。

## 3. 取得初始管理員密碼

Jenkins 首次啟動時，會產生一組隨機的管理員密碼。我們需要這組密碼才能完成初始化的網頁設定。

您可以透過查看容器日誌來取得密碼：

```bash
docker logs jenkins-server
```

在日誌輸出中，找到類似下面這段文字，下方的一長串字串即為密碼：

```text
*************************************************************
*************************************************************
*************************************************************

Jenkins initial setup is required. An admin user has been created and a password generated.
Please use the following password to proceed to installation:

abcd1234efgh5678ijkl9012mnop3456

This may also be found at: /var/jenkins_home/secrets/initialAdminPassword

*************************************************************
*************************************************************
*************************************************************
```

*備註：您也可以使用 `docker exec -it jenkins-server cat /var/jenkins_home/secrets/initialAdminPassword` 直接印出密碼。*

## 4. 完成 Jenkins 初始化設定

1. 打開瀏覽器，前往 [http://localhost:8080](http://localhost:8080)。
2. 畫面會提示您 **"Unlock Jenkins"**，請將步驟 3 取得的密碼貼上並點擊 **Continue**。
3. 接下來會進入插件安裝畫面，建議選擇 **"Install suggested plugins"** (安裝建議的套件)，這會自動為您安裝 Git, Pipeline 等常用的基礎套件。
4. 套件安裝完成後，系統會提示您建立第一位管理員 (First Admin User)。依序填入您的帳號、密碼、全名與電子郵件。
5. 最後確認 Jenkins URL (通常維持 `http://localhost:8080/` 即可)，點擊 **Save and Finish**。

看到 **"Jenkins is ready!"** 畫面後，點擊 **Start using Jenkins** 即可進入主控台。

## 5. 日常管理指令

- **停止 Jenkins 服務:**
  ```bash
  docker stop jenkins-server
  ```
- **啟動 Jenkins 服務:**
  ```bash
  docker start jenkins-server
  ```
- **查看運作狀態:**
  ```bash
  docker ps -a | grep jenkins-server
  ```
