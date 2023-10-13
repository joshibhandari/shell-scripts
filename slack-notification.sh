#!/bin/bash
O_VAL=0
O_LO_VAL=0
O_CLOSED_VAL=0
SLACK_BOT_TOKEN="xoxb-5967738064866-5991818814832-9nEeQ7G4yxPA4DajCff7aikB"
CHANNEL_NAME="#devops"

slack_not (){
        INFO=$1
        STAT=$2
        curl -X POST -H "Authorization: Bearer $SLACK_BOT_TOKEN" -H 'Content-type: application/json' --data "{\"channel\":\"$CHANNEL_NAME\", \"text\":\"$STAT\n$INFO\"}" "https://slack.com/api/chat.postMessage"
}

while :; do

  CONN_INVAL="SSH Invalid User"
  CONN_IN="SSH Login detected"
  CONN_CLOSED="SSH Closed connection"

  VAL=$(tail -n 5 /var/log/auth.log | grep "Accepted publickey" | awk 'END{ print }')
  if [[ $VAL == *"Accepted publickey"* ]]; then
    LOG=$(echo "$VAL" |  awk -F":" '{print $1, $2, $3, $4}' )
    ACT=$(echo "$LOG" | awk 'NR == 1 {$NF = ""} 1' )
    L_VAL=$(echo "$ACT" | awk '{print $NF}' )
    while [ "$L_VAL" != "$O_VAL" ];
    do
      O_VAL=$L_VAL
      #echo "$O_VAL" "$L_VAL while block"
      #slack_not "$ACT" "$CONN_IN"
    done

  fi
  VAL_C=$(tail -n 5 /var/log/auth.log | grep "Invalid user" | awk 'END{ print }')
  if [[ $VAL_C == *"Invalid user"* ]]; then
    L_VAL_INV=$(echo "$VAL_C" | awk '{print $NF}' )
    while [ "$L_VAL_INV" != "$O_LO_VAL" ];
    do
      O_LO_VAL=$L_VAL_INV
      #echo "$O_LO_VAL" "$L_VAL_INV while block-invalid"
      #slack_not "$VAL_C" "$CONN_INVAL"
    done

  fi

  CLOSED=$(tail -n 5 /var/log/auth.log | grep "Connection closed\|Disconnected from" | awk 'END{ print }')
  if [[ $CLOSED == *"Connection closed"* ]] || [[ $CLOSED == *"Disconnected from"* ]]; then
    CLOSED_U=$(echo "$CLOSED" | awk 'NR == 1 {$NF = ""} 1' )
    L_CLOSED_U=$(echo "$CLOSED_U" | awk '{print $NF}' )
    while [ "$L_CLOSED_U" != "$O_CLOSED_VAL" ];
    do
      O_CLOSED_VAL=$L_CLOSED_U
      #echo "$O_LO_VAL" "$L_VAL_INV while block-invalid"
      slack_not "$CLOSED_U" "$CONN_CLOSED"
    done

  fi

        sleep 2
done
