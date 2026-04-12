### 自動開機與 SSH/HTTP 就緒的 Ubuntu 容器叢集 ###

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}

provider "docker" {}

# ==================== 變數宣告 ====================
# 以下變數可由 Jenkins Pipeline 動態傳入，也可使用預設值在本機手動執行

variable "container_count" {
  description = "建立容器的數量"
  type        = number
  default     = 3
}

variable "start_port" {
  description = "SSH 對外映射的起始 Port (每台容器遞增 +1)"
  type        = number
  default     = 2222
}

variable "web_port_start" {
  description = "HTTP 對外映射的起始 Port (每台容器遞增 +1)"
  type        = number
  default     = 8081
}

# ==================== 映像檔 ====================

resource "docker_image" "ubuntu_official" {
  name = "ubuntu:22.04"
}

# ==================== 容器叢集 ====================

resource "docker_container" "my_local_vms" {
  count = var.container_count

  name  = "ansible-target-${count.index + 1}"
  image = docker_image.ubuntu_official.image_id

  # 開機腳本：因為 Docker 映像檔不含 SSH，需要在啟動時安裝並開啟 SSH 服務
  # 在真實雲端環境 (AWS EC2 等)，作業系統本身就內建 SSH，不需要這段
  entrypoint = ["/bin/bash", "-c", "apt-get update && apt-get install -y openssh-server && mkdir /var/run/sshd && echo 'root:root' | chpasswd && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && /usr/sbin/sshd -D"]

  # SSH 通道：供 Ansible 透過 SSH 連入進行自動化部署
  ports {
    internal = 22
    external = var.start_port + count.index
  }

  # HTTP 通道：供瀏覽器存取部署完成的 Python Web 服務
  ports {
    internal = 8080
    external = var.web_port_start + count.index
  }

  # SSH 探針驗收：Terraform 會持續偵測直到 SSH 真正啟動，才會宣告資源完成
  # 避免 Docker Port 代理的假象 (Port 開了但 SSH 尚未安裝完成) 導致後續 Ansible 連線失敗
  provisioner "local-exec" {
    command = <<-EOT
      echo '開始驗收 VM ${count.index + 1} 的 SSH 服務...'
      for i in $(seq 1 60); do
        if nc -w 5 localhost ${var.start_port + count.index} < /dev/null 2>/dev/null | grep -q 'SSH'; then
          echo '驗收成功！SSH 已經開放。'
          exit 0
        fi
        sleep 3
      done
      echo '等候超時 (大於 3 分鐘)，SSH 開機失敗！'
      exit 1
    EOT
  }
}

# ==================== 動態產生 Ansible Inventory ====================

resource "local_file" "ansible_inventory" {
  filename = "../ansible/dynamic_hosts.ini"

  # 依據容器數量自動分群組：前 2 台歸為 web_servers，其餘歸為 others
  # 每台 VM 使用獨立別名 (vm-1, vm-2...)，避免 Ansible 對同名主機去重複
  content = <<-EOT
[web_servers]
%{ for i in range(var.container_count) ~}
%{ if i < 2 ~}
vm-${i + 1} ansible_host=localhost ansible_port=${var.start_port + i}
%{ endif ~}
%{ endfor ~}

[others]
%{ for i in range(var.container_count) ~}
%{ if i >= 2 ~}
vm-${i + 1} ansible_host=localhost ansible_port=${var.start_port + i}
%{ endif ~}
%{ endfor ~}

[all:vars]
ansible_user=root
ansible_ssh_pass=root
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
EOT
}
