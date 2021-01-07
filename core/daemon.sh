#!/bin/bash
# guru client background servicer
# casa@ujo.guru 2020
# TODO Jan 04 01:24:50 electra bash[413320]: /home/casa/bin/common.sh: line 83: printf: write error: Broken pipe

source $GURU_BIN/common.sh
source $GURU_BIN/corsair.sh

daemon_service_script="$HOME/.config/systemd/user/guru.service"

daemon.main () {
    local argument="$1" ; shift
    case "$argument" in
            start|stop|status|help|kill|poll)
                daemon.$argument
                return $?
                ;;
            install|remove)
                daemon.systemd $argument
                return $?
                ;;

            *)  gmsg "unknown daemon command"   ; return 1  ;;
        esac
    return 0
}


daemon.help () {
    gmsg -v 1 -c white "guru daemon help "
    gmsg -v 2
    gmsg -v 0 "usage:    $GURU_CALL daemon [start|stop|status|kill|poll]"
    gmsg -v 2
    gmsg -v 1 -c white "commands:"
    gmsg -v 1 " start        start daemon (same as $GURU_CALL start)"
    gmsg -v 1 " stop         stop daemon (same as $GURU_CALL stSop)"
    gmsg -v 1 " status       printout status"
    gmsg -v 1 " kill         kill jammed daemon"
    gmsg -v 2 " poll         start polling process"
    gmsg -v 2
    gmsg -v 1 -c white "example:"
    gmsg -v 1 "      $GURU_CALL daemon status"
    gmsg -v 2
}


daemon.status () {

    local _err=0

    if [[ -f "$GURU_SYSTEM_MOUNT/.daemon-pid" ]] ; then
            local _pid="$(cat $GURU_SYSTEM_MOUNT/.daemon-pid)"
            gmsg -v 1 -c green "${FUNCNAME[0]}: $_pid"
        else
            gmsg -v 1 -c dark_grey "${FUNCNAME[0]}: no pid reserved"
            _err=$((_err+10))
        fi

    if ps auxf | grep "$HOME/bin/daemon.sh start" | grep -v "grep"  | grep -v "status" >/dev/null ; then
            gmsg -v 1 -c green "${FUNCNAME[0]}: running"
        else
            gmsg -v 1 -c red "${FUNCNAME[0]}: not running"
            _err=$((_err+10))
        fi

    return $_err
}


daemon.start () {

    if [[ -f "$GURU_SYSTEM_MOUNT/.daemon-pid" ]] ; then
            local _pid=$(cat "$GURU_SYSTEM_MOUNT/.daemon-pid")
            gmsg -v 1 "${FUNCNAME[0]}:  killing $_pid"
            kill -9 $_pid
        fi

    if system.suspend flag ; then
            system.suspend rm_flag
            corsair.systemd_restart
        fi

    #for module in ${GURU_DAEMON_POLL_LIST[@]} ; do
    for ((i=0; i <= ${#GURU_DAEMON_POLL_LIST[@]}; i++)) ; do

        module=${GURU_DAEMON_POLL_LIST[i-1]}
        case $module in
            null|empty )
                ;;
            *)
                gmsg -n -v2 -c dark_golden_rod "module_$i:$module: "
                if [[ -f "$GURU_BIN/$module.sh" ]] ; then
                        source "$GURU_BIN/$module.sh"
                        # gmsg -v3 ": $GURU_BIN/$GURU_BIN/$module.sh"
                        $module.main poll start
                    else
                        gmsg -v1 -c yellow "${FUNCNAME[0]}: module $module not installed"
                    fi
                ;;
            esac
        done

    daemon.poll &
}


daemon.stop () {
    # stop daemon

    # remove stop flag
    [[ -f "$HOME/.guru-stop" ]] && rm "$HOME/.guru-stop"

    # if pid file is not exist
    if ! [[ -f "$GURU_SYSTEM_MOUNT/.daemon-pid" ]] ; then
            gmsg "${FUNCNAME[0]}: daemon not running"
            gmsg -v1 "start daemon by typing 'guru start'"
            return 0
        fi

    local _pid=$(cat $GURU_SYSTEM_MOUNT/.daemon-pid)

    gmsg -v1 "stopping modules.. "
    #for module in ${GURU_DAEMON_POLL_LIST[@]} ; do

    for ((i=0; i <= ${#GURU_DAEMON_POLL_LIST[@]}; i++)) ; do

        module=${GURU_DAEMON_POLL_LIST[i-1]}
        #gmsg -v3 -c dark_golden_rod "$i $module"
        case $module in
            null|empty )
                #gmsg -v3 -c dark_grey "skipping $module"
                ;;
            * )
                gmsg -n -v2 -c dark_golden_rod "module_$i:$module: "
                if [[ -f "$GURU_BIN/$module.sh" ]] ; then
                        source "$GURU_BIN/$module.sh"
                        $module.main poll end
                        # gmsg -v3 "module: $GURU_BIN/$GURU_BIN/$module.sh"
                        # gmsg -v2 "command: $module.main poll end"
                    else
                        gmsg -v1 "${FUNCNAME[0]}: module '$module' not installed"
                    fi
                ;;
            esac
        done

    gmsg -v1 "stopping guru-daemon.. "
    [[ -f $GURU_SYSTEM_MOUNT/.daemon-pid ]] && rm -f $GURU_SYSTEM_MOUNT/.daemon-pid
    kill -9 "$_pid" || gmsg -v 1 "$ERROR guru-daemon pid $_pid cannot be killed, try to 'guru kill $_pid'"

}



daemon.kill () {
    if pkill guru ; then
            gmsg -v1 "${FUNCNAME[0]}: guru-daemon killed.."
        else
            gmsg -v1 "${FUNCNAME[0]}: guru-daemon not running"
        fi

    if ps auxf | grep "$GURU_BIN/guru" | grep "start" | grep -v "grep" >/dev/null ; then
            gmsg -v1 -c yellow "${FUNCNAME[0]}: daemon still running, try to 'sudo guru kill'"
            return 100
        else
            gmsg -v1 -c white "${FUNCNAME[0]}: kill verified"
            [[ -f $GURU_SYSTEM_MOUNT/.daemon-pid ]] && rm -f $GURU_SYSTEM_MOUNT/.daemon-pid
            return 0
        fi
}


daemon.poll () {
    source $GURU_RC
    [[ -f "$HOME/.guru-stop" ]] && rm -f "$HOME/.guru-stop"
    echo "$(sh -c 'echo "$PPID"')" > "$GURU_SYSTEM_MOUNT/.daemon-pid"

    GURU_FORCE=
    # DAEMON POLL LOOP
    while true ; do
        # to update configurations is user changes them
        source $GURU_RC
        #for module in ${GURU_DAEMON_POLL_LIST[@]} ; do

        if system.suspend flag ; then
                corsair.systemd_restart
                system.suspend rm_flag
                rm -f /tmp/guru-fast.flag
                sleep 4
            fi

        gmsg -N -v2 -c $GURU_CORSAIR_EFECT_COLOR -k esc "daemon active"

        local i=
        for ((i=0; i <= ${#GURU_DAEMON_POLL_LIST[@]}; i++)) ; do
            module=${GURU_DAEMON_POLL_LIST[i-1]}
            case $module in
                null|empty )
                    gmsg -v4 -c dark_grey "skipping $module"
                    ;;
                * )
                    gmsg -n -v2 -c dark_golden_rod "module_$i:$module: "

                    if [[ -f "$GURU_BIN/$module.sh" ]] ; then
                            source "$GURU_BIN/$module.sh"
                            $module.main poll status
                        else
                            gmsg -v1 -c yellow "${FUNCNAME[0]}: module '$module' not installed"
                        fi
                    ;;
                esac
            done

        #gmsg -v2 -c black -k cplc "ignore disable keys"
        gmsg -n -v2 -c reset -k esc "daemon sleeps $GURU_DAEMON_INTERVAL seconds "

        local _seconds=
        for (( _seconds = 0; _seconds < $GURU_DAEMON_INTERVAL; _seconds++ )); do
            [[ -f /tmp/guru-fast.flag ]] && break || sleep 1
            gmsg -v2 -n -c reset "."
        done

        # check is stop command given, exit if so
        [[ -f "$HOME/.guru-stop" ]] && break
    done
    daemon.stop
}


daemon.process_opts () {
    # argument parser
    TEMP=`getopt --long -o "vVflu:h:" "$@"`
    eval set -- "$TEMP"
    while true ; do
        case "$1" in
            -v ) export GURU_VERBOSE=1      ; shift     ;;
            -V ) export GURU_VERBOSE=2      ; shift     ;;
            -f ) export GURU_FORCE=true     ; shift     ;;
            -l ) export GURU_LOGGING=true   ; shift     ;;
            -u ) export GURU_USER_NAME=$2   ; shift 2   ;;
            -h ) export GURU_HOSTNAME=$2    ; shift 2   ;;

             * ) break                  ;;
        esac
    done;
    _arg="$@"
    [[ "$_arg" != "--" ]] && ARGUMENTS="${_arg#* }"
}


daemon.systemd () {

    local cmd=$1 ; shift
    case $cmd in
            install|remove|enable|disable)
                        daemon.systemd_$cmd $@
                        return $?
                    ;;
              * ) gmsg -c yellow "unknown command '$cmd'"
                  return 127
        esac

}


daemon.systemd_install () {
    temp="/tmp/starter.temp"
    gmsg -v1 -V2 -n "setting starter script.. "
    gmsg -v2 -n "setting starter script $daemon_service_script.. "

    if ! [[ -d  ${daemon_service_script%/*} ]] ; then
        mkdir -p ${daemon_service_script%/*} \
        || gmsg -x 100 "no permission to create folder ${daemon_service_script%/*}"
    fi

    [[ -d  ${temp%/*} ]] || sudo mkdir -p ${temp%/*}
    [[ -f $temp ]] && rm $temp

cat >"$temp" <<EOL
[Unit]
Description=guru daemon process manager

[Service]
ExecStart=bash -c '/home/$USER/bin/core.sh daemon start'
ExecStop=bash -c '/home/$USER/bin/core.sh daemon stop'
Type=simple
Restart=always
RemainAfterExit=yes

[Install]
WantedBy=graphical-session.target
EOL

    if ! cp -f $temp $daemon_service_script ; then
            gmsg -c red "script copy failed"
            return 101
        fi

    chmod +x $daemon_service_script
    systemctl --user enable guru.service
    systemctl --user daemon-reload
    systemctl --user restart guru.service

    # clean
    rm -f $temp
    gmsg -v1 -c green "ok"
    return 0

}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then                        # user and platform settings (implement here, always up to date)
        source $GURU_RC
        daemon.process_opts $@
        daemon.main $ARGUMENTS
        exit $?
    fi
