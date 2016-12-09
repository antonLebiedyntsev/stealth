output "elb.hostname" {
  value = "${aws_elb.stealth.dns_name}"
}