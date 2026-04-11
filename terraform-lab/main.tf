### 練習建立三個 ubuntu 容器 ### 

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}

provider "docker" {}

# 加入變數宣告，讓 Jenkins 或外部指令可以動態代入
variable "container_count" {
  description = "建立容器的數量 (Jenkins 點選的數量)"
  type        = number
  default     = 3     # 如果外部沒傳入，預設是 3 台
}

variable "start_port" {
  description = "SSH 對外映射的起始 Port"
  type        = number
  default     = 2222  # 如果外部沒傳入，預設從 2222 開始
}

# 1. 使用官方 Ubuntu 22.04 
resource "docker_image" "ubuntu_official" {
  name = "ubuntu:22.04"
}

# 2. 啟動容器並「手動」開啟 SSH 門口
resource "docker_container" "my_local_vms" {
  count = var.container_count

  name  = "ansible-target-${count.index + 1}"
  image = docker_image.ubuntu_official.image_id

  # 讓容器保持運行並執行安裝 SSH 的指令
  entrypoint = ["/bin/bash", "-c", "apt-get update && apt-get install -y openssh-server && mkdir /var/run/sshd && echo 'root:root' | chpasswd && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && /usr/sbin/sshd -D"]

  ports {
    internal = 22
    # 對外 Port 會從設定的 start_port 開始往上加
    external = var.start_port + count.index
  }
}

# 3. 動態產生 Ansible Inventory 檔案
resource "local_file" "ansible_inventory" {
  # 放在上層的 ansible 資料夾內
  filename = "../ansible/dynamic_hosts.ini"
  
  # 使用 Terraform template 語法，依據 VM 數量自動分群組
  content = <<-EOT
[web_servers]
%{ for i in range(var.container_count) ~}
%{ if i < 2 ~}
localhost:${var.start_port + i}
%{ endif ~}
%{ endfor ~}

[others]
%{ for i in range(var.container_count) ~}
%{ if i >= 2 ~}
localhost:${var.start_port + i}
%{ endif ~}
%{ endfor ~}

[all:vars]
ansible_user=root
ansible_ssh_pass=root
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOT
}
