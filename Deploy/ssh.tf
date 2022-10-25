locals {
  is_windows = substr(pathexpand("~"), 0, 1) == "/" ? false : true
  key_name   = pathexpand("~/.ssh/ssh_${random_string.poc.result}.key")
}

locals {
  bash       = "chmod 400 ${local.key_name}"
  powershell = "icacls ${local.key_name} /inheritancelevel:r /grant:r username:R"

}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "ssh" {
  content  = tls_private_key.ssh.private_key_pem
  filename = local.key_name
  provisioner "local-exec" {
    command = local.is_windows ? local.powershell : local.bash
  }
}
