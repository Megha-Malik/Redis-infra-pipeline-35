output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "al2023_redis_private_ip" {
  value = aws_instance.al2023_redis.private_ip
}

output "ubuntu_redis_private_ip" {
  value = aws_instance.ubuntu_redis.private_ip
}