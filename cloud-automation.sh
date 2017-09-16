#! /usr/bin/env bash


# test

###
#	This is buildin tool for docker deployments to AWS
#	Creates AWS infrastructure
#	Plepears hosts with docker and etc
#	Puls and runs docker 
#	
#	Author: Anton Lebieydntsev
#	
#	Required parameters
#		$1 - app name
#		$2 - environment
#		$3 - number of nodes
#		$4 - server type
#	
###

#Fancy stuff
reset=`tput sgr0` 
red=`tput setaf 1`
green=`tput setaf 2`
cyan=`tput setaf 6`

#Extra params for Terraform
TERRAFORM_VERSION='0.7.13'
AWS_SSH_CIDR="217.20.167.181/32"
AWS_REGION=""
AWS_ZONE=""
AWS_CONTROL_CIDR=""
AWS_AMI_ID=""
AWS_KEY_PUB=""
AWS_ELB_HOSTNAME=""

#Ansible Config
ANSIBLE_HOST_KEY_CHECKING=false && \
export ANSIBLE_HOST_KEY_CHECKING

APP_NAME=${1}
ENV_TYPE=${2}
NODES_NUMBER=${3}
SERVER_TYPE=${4}

WORK_DIR=${PWD}

function helpME {
	cat <<EOF
HELP:
	${cyan}cloud-automation.sh <app> <environment> <num_servers> <server_size>${reset}
	<app> - app_name
	<environment> - Deploy environment [dev, prod]
	<num_servers> - number of nodes >=2. Default 2
	<server_size> - AWS server type. Default t2.micro

	Example:

	cloud-automation.sh hello_world dev 2 t1.micro

EOF
}

function clean {
	echo "${cyan}Cleaning${reset}" && \
	rm -rf ./downloads/ && \
	rm -rf ./terraform/elb_hostname && \
	apt-get clean && \
	echo "${cyan}Cleaning - COMPLETE${reset}"
	exit 
}

#Print Help
if [ "$1" == "-h" ] || [ -z "$1"  ]; then
	helpME
	exit 0
fi

case $ENV_TYPE in
	dev)
		AWS_CONTROL_CIDR="217.20.167.181/32"
		AWS_ZONE="b"
		AWS_REGION="us-east-1"
		AWS_AMI_ID="ami-1081b807"
		;;
	prod)
		AWS_CONTROL_CIDR="0.0.0.0/0"
		AWS_ZONE="b"
		AWS_REGION="us-west-2"
		AWS_AMI_ID="ami-01f05461"
		;;
	*)
		echo "${red}Incorrect value for <environment>${reset}"
		helpME
		exit 1
		;;
esac
echo "Building for ${ENV_TYPE}"

if [ $NODES_NUMBER -lt 2 ]; then
	echo "${red}Number of nodes less than 2. ${reset}"
	helpME

# Catch typo
elif [ $NODES_NUMBER -gt 9 ]; then
	read -p "You wnat to launch $NODES_NUMBER. Are you shure? y/n:" -n 1 -r
	echo    # (optional) move to a new line
	if [[ ! $REPLY =~ ^[Yy]$ ]]; then
		echo "${red}Exiting. Incorrect number of nodes${reset}"
		exit 1
	fi

fi


echo "${cyan}Prepearing Local Environment${reset}"
apt-get update -y && apt-get install -y \
								unzip \
								wget \
								dig
if [ ! -f ./bin/terraform ]; then

	echo "${cyan}Prepearing Terraform${reset}"
	wget -O ./downloads/terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
	unzip -o -d ./bin ./downloads/terraform.zip && \
	echo "${green}Prepearing Terraform - COMPLETE${reset}"
fi

echo "${cyan}Prepearing Ansible${reset}"
apt-get install -y \
			software-properties-common && \
apt-add-repository -y ppa:ansible/ansible && \
apt-get update -y && \
apt-get install -y ansible \
				   python-boto && \
echo "${green}Prepearing Ansible - COMPLETE${reset}"

AWS_KEY_NAME="${APP_NAME}_${ENV_TYPE}"

if [ ! -f ./ssh/$AWS_KEY_NAME ]; then

	echo "${cyan}Generating SSH key ${AWS_KEY_NAME}${reset}"
	apt-get -y install openssh-client && \
	if [ ! -d ./ssh ]; then
		mkdir ./ssh/
	fi
	ssh-keygen -b 2048 -t rsa -f ./ssh/$AWS_KEY_NAME -q -N "" && \
	chmod 600 ./ssh/$AWS_KEY_NAME && \
	echo "./ssh/${AWS_KEY_NAME} Generated" && \
	echo "${green}Generating SSH key - COMPLETE${reset}"

fi
AWS_KEY_PUB=$(<./ssh/$AWS_KEY_NAME.pub)
source ./get_keys.sh || exit 1 
echo "${green}Prepearing Local Environment - COMPLETE${reset}"

echo "${cyan}Prepearing AWS Environment with Terraform${reset}"
cd ./terraform && \
../bin/terraform apply \
	-var "access_key=${AWS_ACCESS_KEY_ID}" \
	-var "secret_key=${AWS_SECRET_ACCESS_KEY}" \
	-var "region=$AWS_REGION" \
	-var "instance_type=$SERVER_TYPE" \
	-var "instance_count=$NODES_NUMBER" \
	-var "app_name=$APP_NAME" \
	-var "zone=$AWS_ZONE" \
	-var "ami_id=$AWS_AMI_ID" \
	-var "key_name=$AWS_KEY_NAME" \
	-var "public_key=$AWS_KEY_PUB" \
	-var "environment=$ENV_TYPE" \
	-var "web_cidr=$AWS_CONTROL_CIDR" \
	-var "control_cidr=$AWS_SSH_CIDR" && \
AWS_ELB_HOSTNAME=$(../bin/terraform output elb.hostname) && \

echo "${green}Prepearing AWS Environment with Terraform - COMPLETE${reset}"

echo "${cyan}Prepearing Hosts with Ansible${reset}"
echo "SHH KEY: ../ssh/$AWS_KEY_NAME"
echo "AWS region: ${AWS_REGION}${AWS_ZONE}"
cd $WORK_DIR && \
cd ./ansible && \
echo $PWD
ansible-playbook -i ec2.py --private-key=../ssh/$AWS_KEY_NAME -u ubuntu nodes.yml --extra-vars \
	"\
	app_name=${APP_NAME} \
	db_hostname="mysql" \
	" && \
echo "${green}Prepearing Hosts with Ansible - COMPLETE${reset}"



cd $WORK_DIR && \
if [ ! -z "$AWS_ELB_HOSTNAME" ]; then
	echo "http://${AWS_ELB_HOSTNAME}"
fi
clean
