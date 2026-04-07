output "hub_vpc_id" {
  value = aws_vpc.hub.id
}
output "spoke1_vpc_id" {
  value = aws_vpc.spoke1.id
}
output "spoke2_vpc_id" {
  value = aws_vpc.spoke2.id
}
output "transit_gateway_id" {
  value = aws_ec2_transit_gateway.main.id
}
output "hub_test_instance_ip" {
  description = "Hub test instance private IP"
  value       = aws_instance.hub_test.private_ip
}
output "hub_vm_public_ip" {
  description = "Hub test instance public IP (EIP)"
  value       = aws_eip.hub_test.public_ip
}
output "spoke1_test_instance_ip" {
  value = aws_instance.spoke1_test.private_ip
}
output "spoke2_test_instance_ip" {
  value = aws_instance.spoke2_test.private_ip
}
output "tgw_route_table_id" {
  value = aws_ec2_transit_gateway_route_table.main.id
}
output "flow_log_group_name" {
  value = aws_cloudwatch_log_group.vpc_flow_logs.name
}
