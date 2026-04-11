pipeline {
    agent any

    // 定義 Jenkins 在啟動任务時，跳出對話框讓您填寫的參數
    parameters {
        string(name: 'VM_COUNT', defaultValue: '3', description: '想要建立幾台目標 VM (容器)？')
        string(name: 'START_PORT', defaultValue: '2222', description: 'SSH 預設起始 Port 號？')
    }



    stages {
        stage('Checkout Code') {
            steps {
                echo '由於是本機實驗，跳過 Git 拉取動作，將直接進入本機開發目錄...'
            }
        }

        stage('Terraform Init') {
            steps {
                // 使用 dir 強制指定工作目錄為您本機目前的開發目錄
                dir('/Users/jefflin/Desktop/auto-infra-build/terraform-lab') {
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Apply (開機器)') {
            steps {
                dir('/Users/jefflin/Desktop/auto-infra-build/terraform-lab') {
                    // 使用 sh 執行指令，並帶入 -auto-approve 省略 yes 輸入
                    // 並將上方定義的 Parameters 塞到 -var 裡面！
                    sh """
                    terraform apply -auto-approve \
                        -var="container_count=${params.VM_COUNT}" \
                        -var="start_port=${params.START_PORT}"
                    """
                }
            }
        }
    }
}
