#!/usr/bin/env bash

set -e

cfg_file="$HOME/.aws-sudo"

while [ "$#" -gt 0 ]; do
    case "$1" in
        -n) session_name="$2"; shift 2;;
        -c) command="$2"; shift 2;;
        -x) clear=1; shift 1;;
        -f) cfg_file="$2"; shift 2;;
        *) argument=$1; shift 1;;
    esac
done

if [ "$argument" = "clear" -o "$clear" = "1" ]
then
	echo "unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SECURITY_TOKEN AWS_SESSION_TOKEN"
	exit
fi

# if the arg doesn't look like an arn, check for aliases
if [[ "$argument" =~ arn:aws:iam::[0-9]{12}:role/ ]]; then
    role="$argument"
else
    if [ -r $cfg_file ]; then
        alias=$(grep "^alias $argument" $cfg_file | head -n 1)
        role=$(echo "$alias" | awk '{print $3}')

        # if no session name was specified, look for one in the alias
        session_name=${session_name:-$(echo "$alias" | awk '{print $4}')}
    fi
fi

# if argument is an aws account number, look for a default role name
# in the config.  If found, build the role arn using that default
if [[ -z "$role" && "$argument" =~ ^[0-9]{12}$ ]]; then
       def_role_name=$(grep "^default role " $cfg_file | awk '{print $3}')
       if [ -n "$def_role_name" ]; then
           role="arn:aws:iam::${argument}:role/${def_role_name}"
       fi
fi

# if no session name was provided, try to find a default
if [ -z "$session_name" ]; then
    def_session_name=$(grep "^default session_name" $cfg_file | awk '{print $3}')
    session_name=${def_session_name:-aws_sudo}
fi

# verify that a valid role arn was found or provided; awscli gives
# terrible error messages if you try to assume some non-arn junk
if ! [[ "$role" =~ arn:aws:iam::[0-9]{12}:role/ ]]; then
    echo "$argument is neither a role ARN nor a configured alias" 1>&2
    exit 1
fi

response=$(aws sts assume-role --output text \
               --role-arn "$role" \
               --role-session-name="$session_name" \
               --query Credentials)

if [ -n "$command" ]; then
    env -i \
        AWS_ACCESS_KEY_ID=$(echo $response | awk '{print $1}') \
        AWS_SECRET_ACCESS_KEY=$(echo $response | awk '{print $3}') \
        AWS_SESSION_TOKEN=$(echo $response | awk '{print $4}') \
        sh -c "$command"
else
    echo export \
         AWS_ACCESS_KEY_ID=$(echo $response | awk '{print $1}') \
         AWS_SECRET_ACCESS_KEY=$(echo $response | awk '{print $3}') \
         AWS_SESSION_TOKEN=$(echo $response | awk '{print $4}')
fi
