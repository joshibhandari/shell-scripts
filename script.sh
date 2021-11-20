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
