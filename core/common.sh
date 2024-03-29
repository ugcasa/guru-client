#!/bin/bash
# guru-client common functions
# collection of functions be sourced every time module needs it
# casa@ujo.guru 2019 - 2022

## TODO remove common.sh, not practical way cause of namespacing
##  - no rush, good enough for now
##  - ISSUE function naming should be fixed dough

# TBD re think function naming
# gr.contain <- contains
# gr.import <- import
# gr.google <- google -> alias google='gr.google'

gr.dump () {
    # dump environmental status to file
    # TBD revisit this
    echo "core dumped to $GURU_CORE_DUMP"
    set > "$GURU_CORE_DUMP"
}


gr.poll () {
    # set get polling order

    local _to_find="$1"
    local i=0
    #source "$HOME/.gururc"

    for val in ${GURU_DAEMON_POLL_ORDER[@]} ; do
        ((i++))
        #echo "$i: $val"
        if [[ "$val" == "$_to_find" ]] ; then break ; fi
    done

    if [[ "$i" -gt "${#GURU_DAEMON_POLL_ORDER[@]}" ]] ; then
            echo "NA"
            return 1
        else
            echo $i
            return 0
        fi
}


gr.source () {
    # source only wanted functions. slow ~0,03 sec, but saves environment space

    local file=$1 ; shift
    local functions=($@)

    # use ram disk as a temp to avoid ssd wear out and might be little faster?
    if df -T | grep /dev/shm >/dev/null; then
            gtemp=/dev/shm/guru
        else
            gtemp=/tmp/guru
        fi

    if ! [[ -d $gtemp ]] ; then
            mkdir -p $gtemp
        fi

    for function in ${functions[@]} ; do
        sed -n "/$function ()/,/}/p" $file >> $gtemp/functions.sh
    done

    source $gtemp/functions.sh
    rm $gtemp/functions.sh
}


gr.msg () {
    # function for output messages and make log notifications

    local verbose_trigger=0
    local verbose_limiter=5                         # maximum + 1 verbose level
    local _newline="\n"                             # newline is on by default
    local _pre_newline=                             # newline before text disable by default
    local _timestamp=                               # timestamp is disabled by default
    local _message=                                 # message container
    local _logging=                                 # logging is disabled by default
    local _say=                                     # speak
    local _color=
    local _color_code=                              # default color if none
    local _exit=                                    # exit with code (exit not return!)
    local _mqtt_topic=
    local _indicator_key=
    local _color_only=
    local _c_var=
    local _column_width

    # parse flags
    TEMP=`getopt --long -o "tlsnhNx:w:V:v:c:C:q:k:m:" "$@"`
    eval set -- "$TEMP"

    while true ; do
            case "$1" in
                -t ) _timestamp="$(date +$GURU_FORMAT_TIME) "   ; shift ;;
                -l ) _logging=true                              ; shift ;;
                -s ) _say=true                                  ; shift ;;
                -h ) _color_code="$C_HEADER"                    ; shift ;;
                -n ) _newline=                                  ; shift ;;
                -N ) _pre_newline="\n"                          ; shift ;;
                -x ) _exit=$2                                   ; shift 2 ;;
                -w ) _column_width=$2                           ; shift 2 ;;
                -V ) verbose_limiter=$2                         ; shift 2 ;;
                -v ) verbose_trigger=$2                         ; shift 2 ;;
                -m ) _mqtt_topic="$2"                           ; shift 2 ;;
                -q ) _mqtt_topic="$GURU_HOSTNAME/$2"            ; shift 2 ;;
                -k ) _indicator_key=$2                          ; shift 2 ;;
                -C ) _color=$2
                     _color_only=true
                     _c_var="C_${_color^^}"
                     _color_code=${!_c_var}
                     shift 2 ;;
                -c ) _color=$2
                     _c_var="C_${_color^^}"
                     _color_code=${!_c_var}
                     shift 2 ;;
                 * ) break
            esac
        done

    # --) check message for long parameters (don't remember why like this)
    local _arg="$@"
    [[ "$_arg" != "--" ]] && _message="${_arg#* }"

    # -x) add exit code to message
    [[ $_exit -gt 0 ]] && _message="$_exit: $_message"

    if [[ $_say ]] ; then
            #_color_code=
            _message=$(echo ${_message[@]} | sed $'s/\e\\[[0-9;:]*[a-zA-Z]//g' )
            [[ $GURU_VERBOSE -gt 0 ]] && printf "%s\n" "$_message"
            espeak -p $GURU_SPEAK_PITCH -s $GURU_SPEAK_SPEED -v $GURU_SPEAK_LANG "$_message"
            return 0
        fi

    # -k) set corsair key is '-k <key>' used
    if [[ $_indicator_key ]] && [[ $GURU_CORSAIR_ENABLED ]] ; then
            # TBD: check corsair (or other kb led) module installed
            #      now in corsair is part of core what it should not to be
            source corsair.sh
            if [[ "$_color" == "reset" ]] ; then
                    corsair.main reset "$_indicator_key"
                else
                    corsair.main set "$_indicator_key" "$_color"
                fi
       fi

    # -m) publish to mqtt if '-q|-m <topic>' used
    if [[ $_mqtt_topic ]] && [[ $GURU_MQTT_ENABLED ]]; then
            source mqtt.sh
            # mqtt.enabled || return 0
            mqtt.pub "$_mqtt_topic" "$_message"
        fi

    # -C) print only color code
    if [[ $_color_only ]] ; then
            echo -n "$_color_code"
            return 0
        fi

    # -v) given verbose level is lower than trigger level, do not print
    # "print only if higher verbose level than this"
    if [[ $verbose_trigger -gt $GURU_VERBOSE ]] ; then
            return 0
        fi

    # -V) given verbose level is higher than high limiter, do not print
    # "do not print after this verbose level"
    if [[ $verbose_limiter -le $GURU_VERBOSE ]] ; then
            return 0
        fi

    # On verbose level 3+ timestamp is always on
    if [[ $verbose_trigger -gt 3 ]] && [[ ${#_message} -gt 1 ]]; then
            _timestamp="$(date +$GURU_FORMAT_TIME.%3N) DEBUG: "
        fi

    # -w) fill message length to column limiter
    if ! [[ $_column_width ]] ; then
            _column_width=${#_message}
        fi

    # -c) color printout
    if [[ $GURU_COLOR ]] && ! [[ $GURU_VERBOSE -eq 0 ]]; then
        printf "$_pre_newline$_color_code%s%-${_column_width}s$_newline\033[0m" "${_timestamp}" "${_message:0:$_column_width}"
        return 0
    fi

    # *) normal printout without formatting
    printf "$_pre_newline%s%-${_column_width}s$_newline" "${_timestamp}" "${_message:0:$_column_width}"
    return 0

    # -x) printout and exit for development use
    [[ $_exit ]] && exit $_exit

    return 0
}


gr.end () {
    # stop blinking in next cycle

    local key="esc"
    [[ $1 ]] && key=$1 ; shift

    [[ -f /tmp/blink_$key ]] && rm /tmp/blink_$key
    return 0
}


gr.ind () {
    # indicate status by message, voice  and keyboard indicators

    local _timestamp=
    local _mqtt_topic="/status/$(hostname)"
    local _indicator_key="esc"
    local _color="black"
    local _status="message"
    local _message=""

    # parse arguments
    TEMP=`getopt --long -o "tlnhNx:w:V:v:c:C:q:k:m:" "$@"`
    eval set -- "$TEMP"

    while true ; do
            case "$1" in
                -t ) _timestamp="$(date +$GURU_FORMAT_TIME) "   ; shift ;;
                -m ) _message="$2 "                             ; shift 2 ;;
                -k ) _indicator_key=$2                          ; shift 2 ;;
                -c ) _color=$2                                  ; shift 2 ;;
                 * ) break
            esac
        done
    # --) check message for long parameters (don't remember why like this)
    local _arg="$@"
    [[ "$_arg" != "--" ]] && _status="${_arg#* }"

    if ! [[ $_status ]] ; then
            return 0
        fi

    if [[ $GURU_CORSAIR_ENABLED ]] && [[ $_indicator_key ]] ; then
            source corsair.sh
            corsair.main indicate $_status $_indicator_key
        fi

    if [[ $_message ]] ; then

            if [[ $_color ]] ; then
                    gr.msg -v3 -c $_color "$timestamp$_status: $_message"
                else
                    gr.msg -v3 "$timestamp$_status: $_message"
                fi

            if [[ $GURU_MQTT_ENABLED ]] && [[ $_mqtt_topic ]] ; then
                    source mqtt.sh
                    #mqtt.pub $_mqtt_topic $_message
                    mqtt.pub $_mqtt_topic "$timestamp$_status $_message"
                fi
        fi

    if [[ $GURU_SOUND_ENABLED ]] ; then

        # TBD source sound.sh
        # TBD sound.main nnn

        [[ $_message ]] || _message=$_status
        case $_status in
            say)            espeak -p 85 -s 130 -v en "$_message" ;;
            done)           espeak -p 100 -s 120 -v en "$_message done! " ;;
            available)      espeak -p 100 -s 130 -v en "$_message" ;;
            recovery)       espeak -p 85 -s 130 -v en "recovering $_message" ;;
            working)        espeak -p 85 -s 130 -v en "working... $_message" ;;
            pause)          espeak -p 85 -s 130 -v en "$_message is paused" ;;
            cancel)         espeak -p 85 -s 130 -v en "$_messagasde is canceled. I repeat, $_message is canceled" ;;
            error)          espeak -p 85 -s 130 -v en "Error! $_message. I repeat, $_message" ;;
            offline)        espeak -p 85 -s 130 -v en "$_message" ;;
            warning)        espeak -p 85 -s 130 -v en "Warning! $_message. I repeat, $_message" ;;
            alert)          espeak -p 85 -s 130 -v en "Alarm! $_message. I repeat, $_message" ;;
            panic)          espeak -p 85 -s 130 -v en-sc "Critical alarm! $_message... ${_message^} Critical alarm! ${_message^^}" ;;
            passed|pass)    espeak -p 85 -s 130 -v en-us  "$_message... passed" ;;
            fail|failed)    espeak -p 85 -s 130 -v en-us "$_message... failed" ;;
            message)        espeak -p 85 -s 130 -v fi  "Message! $_message! new message $_message" ;;
            flash)          espeak -p 0 -s 100 -v fi "Thunder" ;;
            cops)           espeak -p 85 -s 130 -v en "Police patrol located at $_message" ;;
            police)         espeak -p 85 -s 130 -v en "Police in block! Dump your stash and duck! ... $_message" ;;
            calm)           espeak -p 0 -s 80 -v en-us  "Breath... slowly... in... and... out. and calm down. " ;;
            hacker)         espeak -p 85 -s 130 -v en-us  "Warning! An hacker activity detected. $_message" ;;
            russia)         espeak -p 5 -s 90 -v russian  "Warning! An Russian hacker activity detected... releasing honeypot vodka bottles on the battle field" ;;
            china)          espeak -p 10 -s 180 -v cantonese "Warning! An Chinese hacker activity detected. please disconnect mainframe from internetz" ;;
            call)           for i in {0..5} ; do
                                espeak -p 60 -s 80 -v en-sc "Incoming call from number $(echo $_message | sed 's/./& /g')"
                                [[ -f /tmp/blink_$_indicator_key ]] || break
                                sleep 2
                            done ;;
            customer)       for i in {0..5} ; do
                                espeak -p 75 -s 90 -v finnish "$_message,"
                                espeak -p 75 -s 90 -v en-us  "is calling! "
                                [[ -f /tmp/blink_$_indicator_key ]] || break
                                sleep 2
                            done ;;
        esac
    fi
}


gr.ask () {
    # yes or no with blinky bling. if first is number 1-99 it is set as timeout

    local _answer=
    local _def_answer='n'
    local _ano_answer='y'
    local _options=
    local _timeout=
    local _message=
    local _box=

    # parse arguments
    TEMP=`getopt --long -o "t:d:" "$@"`
    eval set -- "$TEMP"

    while true ; do
            case "$1" in
                -t )
                    _timeout=$2
                    _options="-t $_timeout "
                    shift 2
                    ;;
                -d )
                    _def_answer=$2

                        case $_def_answer in
                            y) _ano_answer='n' ;;
                            n) _ano_answer='y' ;;
                            *) gr.msg "just 'y' or 'n' please" ;;
                        esac
                    _answer=$2
                    shift 2
                    ;;
                 * )
                  break
            esac
        done

    local _arg="$@"
    [[ "$_arg" != "--" ]] && _message="${_arg#* }"

    # format timeout box
    if [[ $_timeout ]] ; then
            _message="$_message ($_timeout sec timeout)"
         fi

    # make y and n blinky on keyboard
    if [[ GURU_CORSAIR_ENABLED ]] ; then
            source corsair.sh
            corsair.indicate yes y 2>/dev/null >/dev/null
            sleep 0.75
            corsair.indicate no n 2>/dev/null >/dev/null
        fi

    # format [Y/n]: box
    case $_def_answer in
        y) _box="[${_def_answer^^}/${_ano_answer,,}]: " ;;
        n) _box="[${_ano_answer,,}/${_def_answer^^}]: " ;;
    esac

    # ask from user
    read $_options-n 1 -p "$_message $_box" _answer

    if [[ GURU_CORSAIR_ENABLED ]] ; then
            corsair.blink_stop y
            corsair.blink_stop n
        fi

    # sense timeout
    (( $? > 128 )) && _answer=$_def_answer
    echo

    # return for callers if statment
    case ${_answer^^} in Y)
            return 0
        esac
    return 1
}


gr.installed () {
    # check is module installed

    local i=0
    local _to_find=$1

    while [[ "$i" -lt "${#GURU_MODULES[@]}" ]] ; do
            if [[ "${GURU_MODULES[$i]}" == "$_to_find" ]] ; then
                    return 0
                fi
            ((i++))
        done
    return 100
}


gr.local () {

    case $1 in
        stop|end)
                touch /tmp/hello.killer
                return 0
                ;;
            esac

    [[ -f /tmp/hello.killer ]] && rm /tmp/hello.killer

    source android.sh
    local _interv=5

    gr.msg "checking $GURU_ANDROID_NAME wifi every $_interv seconds.."

    while true ; do

            if [[ -f /tmp/hello.killer ]] ; then
                    rm /tmp/hello.killer
                    gr.msg "stopping.."
                    return 0
                fi

            if android.connected ; then

                if [[ -f /tmp/hello.indicator ]] ; then
                        guru start
                        gr.ind available -m "$GURU_USER seems to be activated"
                        guru mount
                        # guru note
                        rm /tmp/hello.indicator
                    fi

                else
                    # me leaving
                    if ! [[ -f /tmp/hello.indicator ]] ; then
                            touch /tmp/hello.indicator
                            gr.ind available -m "$GURU_USER has left the building"
                            guru unmount all
                            guru daemon stop
                            cinnamon-screensaver-command --lock
                            # sleep 10
                            # guru system suspend now
                        fi
                fi
            sleep $_interv
        done
}

# export -f gr.poll
export -f gr.msg
export -f gr.ask
export -f gr.end
export -f gr.ind
