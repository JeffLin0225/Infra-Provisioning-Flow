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
variable "container_count" {
  description = "建立容器的數量 (Jenkins 點選的數量)"
  type        = number
  default     = 3
}

variable "start_port" {
  description = "SSH 對外映射的起始 Port"
  type        = number
  default     = 2222
}

variable "web_port_start" {
  description = "HTTP Web 服務對外映射的起始 Port"
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

  # 開機腳本：安裝 SSH 伺服器並啟動
  entrypoint = ["/bin/bash", "-c", "apt-get update && apt-get install -y openssh-server && mkdir /var/run/sshd && echo 'root:root' | chpasswd && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && /usr/sbin/sshd -D"]

  # SSH Port 映射：主機 2222/2223/2224 → 容器 22
  ports {
    internal = 22
    external = var.start_port + count.index
  }

  # HTTP Port 映射：主機 8081/8082/8083 → 容器 8080
  ports {
    internal = 8080
    external = var.web_port_start + count.index
  }

  # 探針驗收機制：強制 Terraform 留在原地輪詢，直到確認 SSH 真正啟動完成
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

  # 關鍵修正：Ansible 要求每個 host 有獨立別名，否則同名 localhost 會被去重複只剩一台！
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
