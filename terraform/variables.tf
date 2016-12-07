variable "access_key" {}
variable "secret_key" {}
variable "region" {
	default = "us-east-1"
}
variable "instance_type" {
	defaut = "t2.micro"
}
variable "instance_count" {
	default = 2
}
variable app_name {}
variable environment{
	default = "b"
}
variable my_name {
	default = "anton_lebiedyntsev"
}
variable control_cidr {
	default = "217.20.167.181/32"
}
variable subnet_cidr{
	default = "10.1.0.0/24"
}