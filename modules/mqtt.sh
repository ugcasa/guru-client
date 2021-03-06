#!/bin/bash
# guru client mqtt functions
# casa@ujo.guru 2020
source $GURU_BIN/common.sh

mqtt.help () {
    gmsg -v1 -c white "guru-client mqtt help "
    gmsg -v2
    gmsg -v0 "usage:    $GURU_CALL mqtt start|end|status|help|install|remove|single|sub|pub "
    gmsg -v2
    gmsg -v1 -c white "commands: "
    gmsg -v1 " sub <topic>              subscribe to topic on local mqtt server "
    gmsg -v1 " single <topic>           subscribe to topic and wait for message, then exit "
    gmsg -v1 " pub <topic> <message>    printout mqtt service status "
    gmsg -v1 " log <topic> <log_file>   subscribe to topic and log it to file "
    gmsg -v1 " install                  install client requirements "
    gmsg -v1 " remove                   remove installed requirements "
    gmsg -v2 " help                     printout this help "
    gmsg -v3 " poll start|end           start or end module status polling "
    gmsg -v2
    gmsg -v1 -c white "example: "
    gmsg -v1 "         $GURU_CALL mqtt status "
    gmsg -v2
}


mqtt.main () {
    # command parser
    indicator_key="f$(poll_order mqtt)"

    local _cmd="$1" ; shift
    case "$_cmd" in
               status|help|install|remove|single|sub|pub|poll)
                            mqtt.$_cmd "$@" ; return $? ;;
               *)           echo "${FUNCNAME[0]}: unknown command"
        esac

    return 0
}



mqtt.online () {
    # check mqtt is functional, no printout
    _send () {
        # if mqtt message takes more than 2 seconds to return from closest mqtt server there is something wrong
        sleep 2
        mqtt.pub "$GURU_HOSTNAME/online" "$(date +$GURU_FORMAT_TIME)"
    }

    # delayed publish
    _send &

    # subscribe to channel
    if mqtt.single "$GURU_HOSTNAME/online" >/dev/null ; then
            return 0
        else
            return 1
    fi
}


mqtt.status () {
    # check mqtt broker is reachable.
    # printout and signal by corsair keyboard indicator led - if available
    source corsair.sh
    if mqtt.online "$GURU_MQTT_BROKER" "$GURU_MQTT_PORT" ; then
            gmsg -v1 -t -c green "${FUNCNAME[0]}: broker available " -k $indicator_key
            return 0
        else
            gmsg -v1 -t -c red "${FUNCNAME[0]}: broker unreachable " -k $indicator_key
            return 1
        fi
}


mqtt.sub () {
    # subscribe to channel, stay listening
    local _mqtt_topic="$1" ; shift
    mosquitto_sub -v -h $GURU_MQTT_BROKER -p $GURU_MQTT_PORT -t "$_mqtt_topic"
    return $?
}


mqtt.single () {
    # subscribe to channel, stay listening
    local _mqtt_topic="$1" ; shift
    mosquitto_sub -C 1 -v -h $GURU_MQTT_BROKER -p $GURU_MQTT_PORT -t "$_mqtt_topic"
    return $?
}


mqtt.pub () {
    local _mqtt_topic="$1" ; shift
    local _mqtt_message="$@"
    mosquitto_pub -h $GURU_MQTT_BROKER -p $GURU_MQTT_PORT -t "$_mqtt_topic" -m "$_mqtt_message"
    return $?
}


mqtt.log () {
    local _mqtt_topic="$1" ; shift
    local _log_file=$GURU_LOG ; [[ $1 ]] && _log_file="$1"
    mosquitto_sub -h $GURU_MQTT_BROKER -p $GURU_MQTT_PORT -t "$_mqtt_topic" >> $_log_file
    return $?
}


mqtt.poll () {

    local _cmd="$1" ; shift

    case $_cmd in
        start )
            gmsg -v1 -t -c black "${FUNCNAME[0]}: mqtt status polling started" -k $indicator_key
            ;;
        end )
            gmsg -v1 -t -c reset "${FUNCNAME[0]}: mqtt status polling ended" -k $indicator_key
            ;;
        status )
            mqtt.status $@
            ;;
        *)  mqtt.help
            ;;
        esac

}


mqtt.install () {
    sudo apt update && \
    sudo apt install mosquitto_clients
    return 0
}


mqtt.remove () {
    sudo apt remove mosquitto_clients
    return 0
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    source "$GURU_RC"
    mqtt.main "$@"
    exit "$?"
fi

