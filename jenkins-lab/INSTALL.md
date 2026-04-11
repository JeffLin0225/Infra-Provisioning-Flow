# Jenkins 獨立環境 (Standalone) 啟動教學

為了確保開發環境能實現高效的**資源集中管理**，並避免與本機上的其他系統配置產生耦合與干擾，本專案不採用全域安裝方式 (如 Homebrew 等工具)。

我們將直接採用 Jenkins 最純粹的 Java 核心檔 (`jenkins.war`)，並透過指定專屬資料夾的方式，實作檔案等級的完全隔離。此作法也讓 Jenkins 能自然地存取本機的 Docker 引擎與 Terraform 工具，大幅簡化架構的複雜度。

## 1. 環境前置作業

您需要確保本機已安裝 **Java (建議 Java 17 或 Java 21 LTS)**。
您可以開啟終端機確認版本：
```bash
java -version
```

## 2. 下載 Jenkins 核心程式

請使用終端機進入專案的 `jenkins-lab` 目錄，然後透過以下指令直接向官方伺服器下載最新的 LTS (長期支援) 穩定版核心檔。載完後，目錄下會多出一個大約 90MB 的 `jenkins.war`。

```bash
cd YOUR_PROJECT_ROOT/jenkins-lab
curl -sLO https://get.jenkins.io/war-stable/latest/jenkins.war
```
*(請將上述路徑換成您實際專案的目錄位置)*

## 3. 指定專屬工作區並啟動服務 (集中化管理)

請在 `jenkins-lab` 目錄中執行以下指令來啟動：

```bash
JENKINS_HOME=./jenkins_data java -jar jenkins.war
```

**架構優勢解說：**
- `JENKINS_HOME=./jenkins_data`：透過宣告此環境變數，我們強制將當前目錄的 `jenkins_data` 設為 Jenkins 的根目錄。這代表所有的外掛套件、日誌檔及專案工作區都會集中收納於此。未來若是需要遷移或是一次性移除服務，只需搬移或刪除該資料夾即可，不會在您的系統根目錄留下任何無關的紀錄。

## 4. 取得初始密碼

上述啟動指令執行後，因 Jenkins 為伺服器類型服務，您的終端機視窗將會持續輸出系統日誌。**請保留該視窗運行**。
在日誌輸出中，尋找被星號包圍的區塊，即可取得第一次登入所需的驗證碼：

```text
*************************************************************
*************************************************************
*************************************************************

Jenkins initial setup is required. An admin user has been created and a password generated.
Please use the following password to proceed to installation:

abcd1234efgh5678ijkl9012mnop3456

This may also be found at: /path/to/your/project/jenkins-lab/jenkins_data/secrets/initialAdminPassword
*************************************************************
*************************************************************
*************************************************************
```

## 5. 完成網頁端初始化

1. 打開瀏覽器，前往 **[http://localhost:8080](http://localhost:8080)**。
2. 貼上剛剛於 Terminal 取得的密碼。
3. 推薦點選 **Install suggested plugins (安裝建議的外掛程式)**，系統會自動處理基礎環境。
4. 建立一組您的管理員專屬帳號與密碼。
5. 設定完成後即可進入 Jenkins 主控台，接續後續管線之建立與測試操作！
