#! /bin/bash

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


TERRAFORM_VERSION='0.7.13'


APP_NAME=${1}
ENV_TYPE=${2}
NODES_NUMBER=${3}
SERVER_TYPE=${4}

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

#Print Help
if [ $1 == "-h" ]; then
	helpME
	exit 0
else

	case $ENV_TYPE in
		dev)
			echo "Building for DEV"
			;;
		prod)
			echo "Buildin for PROD"
			;;
		*)
			echo "${red}Incorrect value for <environment>${reset}"
			helpME
			exit 1
			;;
	esac

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

fi

echo "${cyan}Prepearing Environment${reset}"
apt-get update -y && apt-get install -y \
								unzip \
								wget


echo "${cyan}Prepearing Terraform${reset}"
wget -O ./downloads/terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
unzip -o -d ./bin ./downloads/terraform.zip && \
echo "${green}Prepearing Terraform - COMPLETE${reset}"

echo "${cyan}Prepearing Ansible${reset}"
apt-get install -y \
			software-properties-common && \
apt-add-repository -y ppa:ansible/ansible && \
apt-get update -y && \
apt-get install -y ansible && \
echo "${green}Prepearing Ansible - COMPLETE${reset}"






function clean {
	echo "${cyan}Cleaning${reset}" && \
	rm -rf ./downloads/ && \
	apt-get clean && \
	echo "${cyan}Cleaning - COMPLETE${reset}"
}
