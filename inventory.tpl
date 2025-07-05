[aws_servers]
aws-web ansible_host=${aws_ip} ansible_user=ec2-user ansible_ssh_private_key_file=${ssh_key_path}

[gcp_servers]
gcp-web ansible_host=${gcp_ip} ansible_user=debian ansible_ssh_private_key_file=${ssh_key_path}

[monitoring_servers]
monitoring-server ansible_host=${monitoring_ip} ansible_user=ec2-user ansible_ssh_private_key_file=${ssh_key_path}

[webservers:children]
aws_servers
gcp_servers

[webservers:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[monitoring_servers:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'