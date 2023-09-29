#!/bin/bash

# MYKEY_RESULT=$(keytool -list -v -alias mykey1 -keystore $JAVA_HOME/jre/lib/security/cacerts -protected 2>/dev/null)
# Verify and retrive java version

check_java_version () {
  Found=$(type -p java)
  if [ -z "${Found}" ]; then
    _java=java
  elif [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]];  then
    _java="$JAVA_HOME/bin/java"
  else
    echo "no java found"
  fi

  if [[ "$_java" ]]; then
    version=$("$_java" -version 2>&1 | awk -F '"' '/version/ {print $2}')
    if [[ "$version" = "1.8"* ]] || [[ "$version" = "11"* ]] ; then
        echo "current Java version is: $version"
    else
        echo "Java 1.8 or 11 not found"
        exit 1
    fi
  fi

  }
verify_cert () {
  if [[ "$version" = "1.8"* ]]; then
    java_path="$JAVA_HOME/jre"
  elif [[ "$version" = "11"* ]] ; then
    java_path="$JAVA_HOME"
  fi
  VAL=$(keytool -list -v -alias "$1" -keystore "$java_path"/lib/security/cacerts -protected 2>/dev/null)
  VALID=$(keytool -list -v -alias "$1" -keystore "$java_path"/lib/security/cacerts -protected 2>/dev/null | grep "Valid from:")
  err=$(echo "$VAL" | grep "keytool error")
  ALIAS_NAME=$(echo "$VAL" | grep "Alias name:")
  if [[ "${err}" == *"keytool error"* ]]; then
    status="False"
    return
  fi

  #check certs expiry
  echo "validating certs expiry date......."
  cert_date=$(echo "$VALID" | sed 's/.*until: [a-zA-Z]\{3\} //')
  current_date=$(date +%s)
  cert_exp=$(date -d "$cert_date" +%s)
  if [ "$cert_exp" -lt "$current_date" ]; then echo "cert expired or invalid alias name"; else echo "Certificate is Valid and expiries on: $cert_date";fi
}
  check_java_version
  verify_cert "mykey"
if [[ ${status} = "False" ]]; then
  read -r -p "Do you have alias name (y/n): " input
    if [[ "$input" = "y" ]]; then
      read  -r -p "Provide alias name: " alias_name
      if [[ -z "$alias_name" ]]; then
        echo "No alias name passed, provider default or any alias name to validate"
        exit 1
      else
        verify_cert "$alias_name"
        if [[ ${status} = "False" ]]; then
          echo "Provide a alias name to validate certs(Default: mykey or alias name)"
          exit 1
        fi
    fi
      elif [[ "$input" = "" ]] || [[ "$input" = "n" ]]; then
      echo "Provide a alias name to validate certs(Default: mykey or alias name)"
      exit 1
    fi
fi

#checking package is available
#!/bin/bash
check_package () {
    pkg_arry=(perl python flex bison)
    echo "List of applications installed or not: ${pkg_arry[*]}"
    for binary in ${pkg_arry[@]}; do
        if which $binary 1>/dev/null; then
            echo "$binary --> installed"
        else
            echo "$binary --> not installed"
            if [[ $OS == RHEL ]]; then
                   yum install $binary
            elif [[ $OS == UBUNTU ]]; then
                   sudo apt-get install $binary -y
            elif [[ $OS == ALPINE ]]; then
                   apk add $binary
            else
                    echo "Failed to install"
            fi


        fi
    done
    echo "OS Version Information"
    egrep '^(VERSION|NAME)=' /etc/os-release
}


if [[ `which yum` ]]; then
   IS_RHEL=1
   echo "RHEL"
   OS=RHEL
   check_package
elif [[ `which apt` ]]; then
   IS_UBUNTU=1
   echo "UBUNTU"
   OS=UBUNTU
   check_package
elif [[ `which apk` ]]; then
   IS_ALPINE=1
   echo "ALPINE"
   OS=ALPINE
   check_package
else
   IS_UNKNOWN=1
fi

#server check
#!/bin/bash
read -r ip_addr
if nc -z $ip_addr 22; then
    echo "Ping successfully for IP address: $ip_addr"
else
    echo "Ping failed for IP address: $ip_addr"
fi

#Host Validation /etc/hosts
#!/bin/bash
ip_addr=$(sed -nE 's/(.*[^0-9]|)([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*/\2/p' /etc/hosts | uniq | grep -vE "127.0.0.1")

for ip in $ip_addr; do
  if nc -z $ip 22 1>/dev/null ; then
    echo "Ping successfully for IP address: $ip"
  else
    echo "Ping failed for IP address: $ip"
  fi
done

#to send logs into slack
#!/bin/bash
SLACK_BOT_TOKEN="xoxb-5967738064866-5964920924149-XoZjtOAXOZDx7OIqC2PiRIvx"
CHANNEL_NAME="#devops"

slack_not () {
        INFO=$1
        STAT=$2
        curl -X POST -H "Authorization: Bearer $SLACK_BOT_TOKEN" -H 'Content-type: application/json' --data "{\"channel\":\"$CHANNEL_NAME\", \"text\":\"$STAT\n$INFO\"}" "https://slack.com/api/chat.postMessage"
}


VAL=$(cat /var/log/auth.log 2>/dev/null)
USER=$(echo "$VAL" | grep "Accepted publickey" | awk 'END{ print }')
LOG=$(echo "$USER" |  awk -F":" '{print $1, $2, $3, $4}' )
ACT=$(echo "$LOG" | awk 'NR == 1 {$NF = ""} 1' )
slack_not "$ACT" "SSH Login detected"
CONN_CLOSED=$(echo "$VAL" | grep "Invalid user" | awk 'END{ print }')
slack_not "$CONN_CLOSED" "SSH Logout"
