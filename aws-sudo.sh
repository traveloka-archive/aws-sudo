#!/usr/bin/env bash

set -e

while [ "$#" -gt 0 ]; do
    case "$1" in
        -x) clear=1; shift 1;;
        *) ROLE_TO_ASSUME=$1; shift 1;;
    esac
done

if [ "$ROLE_TO_ASSUME" = "clear" -o "$clear" = "1" ]
then
	echo "unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SECURITY_TOKEN AWS_SESSION_TOKEN"
	exit
fi

response=$(aws sts assume-role --output text \
               --role-arn "$ROLE_TO_ASSUME" \
               --role-session-name="aws_sudo" \
               --query Credentials)

echo export \
     AWS_ACCESS_KEY_ID=$(echo $response | awk '{print $1}') \
     AWS_SECRET_ACCESS_KEY=$(echo $response | awk '{print $3}') \
     AWS_SESSION_TOKEN=$(echo $response | awk '{print $4}')

