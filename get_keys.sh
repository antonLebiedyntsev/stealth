#! /bin/bash

if [  -z "$AWS_SECRET_ACCESS_KEY" ]; then
	echo "Need to set AWS_SECRET_ACCESS_KEY" && \
	read -p "Enter: " AWS_SECRET_ACCESS_KEY && \
	export AWS_SECRET_ACCESS_KEY && \
	echo "AWS_SECRET_ACCESS_KEY Key installed"
fi

if [  -z "$AWS_ACCESS_KEY_ID" ]; then
	echo "Need to set AWS_ACCESS_KEY_ID" && \
	read -p "Enter: " AWS_ACCESS_KEY_ID && \
	export AWS_ACCESS_KEY_ID && \
	echo "AWS_ACCESS_KEY_ID Key installed"
fi