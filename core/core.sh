#!/bin/bash
# guru-client - main command parser
# caa@ujo.guru 2020

# global variables variable
declare -x GURU_VERSION="0.6.6.6"
declare -x GURU_RC="$HOME/.gururc"
declare -x GURU_BIN="$HOME/bin"

case "$1" in
        ver|version|--ver|--version)
            echo "guru-client v$GURU_VERSION"
            exit 0
    esac

if [[ -f $GURU_RC ]] ; then
        source $GURU_RC
    else
        # run configs exporting function to produce file for current os user
        source $HOME/bin/config.sh
        config.main export $USER
        source $GURU_RC
    fi

# user configuration overwrites
[[ $GURU_SYSTEM_NAME ]] && export GURU_CALL=$GURU_SYSTEM_NAME

core.process_opts () {
    # argument parser

    # default values
    GURU_HOSTNAME="$(hostname)"
    GURU_VERBOSE=$GURU_FLAG_VERBOSE
    GURU_COLOR=$GURU_FLAG_COLOR
    GURU_DEBUG=$GURU_FLAG_DEBUG
    GURU_FORCE=
    GURU_LOGGING=

    # go trought arguments and overwrite defualt if set or value given
    TEMP=`getopt --long -o "scfldv:u:h:" "$@"`
    eval set -- "$TEMP"
    while true ; do
        case "$1" in
            -c ) GURU_COLOR=            ; shift     ;;
            -s ) GURU_VERBOSE=          ; shift     ;;
            -d ) GURU_DEBUG=true        ; shift     ;;
            -f ) GURU_FORCE=true        ; shift     ;;
            -l ) GURU_LOGGING=true      ; shift     ;;
            -v ) GURU_VERBOSE=$2        ; shift 2   ;;
            -u ) core.change_user "$2"  ; shift 2   ;;
            -h ) GURU_HOSTNAME=$2       ; shift 2   ;;
             * ) break                  ;;
        esac
    done;
    _arg="$@"

    # TBD can this use to deliver -- variables to modules?
    [[ "$_arg" != "--" ]] && ARGUMENTS="${_arg#* }"
    gmsg -v3 -c pink "arguments: $ARGUMENTS"

    # check if colors possible, and overwrite user input and user.cfg
    if echo "$TERM" | grep "256" >/dev/null ; then
        if ! echo "$COLORTERM" | grep "true" >/dev/null ; then
                export GURU_COLOR=
            fi
        fi

    # export set values
    export GURU_HOSTNAME
    export GURU_VERBOSE
    export GURU_COLOR
    export GURU_DEBUG
    export GURU_FORCE
    export GURU_LOGGING
}


core.main () {
    # main command parser

    local tool="$1" ; shift

    # TBD expired method to let modules know the command before client was not: to remove check is it used and remove
    export GURU_CMD="$tool"

    case "$tool" in
                       all)  core.multi_module_function "$@"        ; _error_code=$? ;;
                    status)  core.multi_module_function status      ; _error_code=$? ;;
           start|poll|kill)  daemon.$tool                           ; _error_code=$? ;;
                     pause)  system.flag pause \
                             && system.flag rm pause \
                             || system.flag set pause               ;;
                      stop)  system.main flag set stop              ; return 0  ;;
                  document)  $tool "$@"                             ; _error_code=$? ;;
                     radio)  DISPLAY=0; $tool.py "$@"               ; _error_code=$? ;;
                     shell)  core.shell "$@"                        ; _error_code=$? ;;
                 uninstall)  bash "$GURU_BIN/$tool.sh" "$@"         ; _error_code=$? ;;
                   help|-h)  core.help $@                           ; _error_code=$? ;;
                        "")  core.shell                             ; _error_code=$? ;;
                         *)  core.run_module "$tool" "$@"           ; _error_code=$? ;;
        esac

    # on verbose -v print onle errors
    if (( _error_code > 99 )) ; then
            gmsg -v1 -c red  "error code $_error_code"
    elif (( _error_code > 0 )) ; then
            gmsg -v2 -c yellow "warning code $_error_code"
        fi

    return $_error_code
}


core.change_user () {
    # change user to unput ans

    local _input_user=$1
    if [[ "$_input_user" == "$GURU_USER" ]] ; then
            gmsg -c yellow "user is already $_input_user"
            return 0
        fi

    export GURU_USER=$_input_user

    if [[ -d "$GURU_CFG/$GURU_USER" ]] ; then
            gmsg -c white "changing user to $_input_user"
            config.main export $_input_user
        else
            gmsg -c yellow "user configuration not exits"
        fi
}


core.run_module () {
    # check is given tool in module list and lauch first hit

    local tool=$1 ; shift
    local type_list=(".sh" ".py" "")

    for _module in ${GURU_MODULES[@]} ; do
            if [[ "$_module" == "$tool" ]] ; then
                for _type in ${type_list[@]} ; do
                    if [[ -f "$GURU_BIN/$_module$_type" ]] ; then $_module$_type "$@" ; return $? ; fi
                done
            fi
        done

    gmsg -v1 -c yellow "unknown command: $tool"
    return $?

    # gmsg -v1 -c yellow "unknown module passing request to os.."
    # $tool $@
}


core.run_module_function () {
    # run module functions

    local tool=$1 ; shift
    local function_to_run=$1 ; shift

    for _module in ${GURU_MODULES[@]} ; do
                if [[ "$_module" == "$tool" ]] ; then
                    # fun shell script module functions
                    if [[ -f "$GURU_BIN/$_module.sh" ]] ; then
                            source $GURU_BIN/$_module.sh
                            $_module.main "$function_to_run" "$@"
                            return $?
                        fi
                    # run python module functions
                    if [[ -f "$GURU_BIN/$_module.py" ]] ; then
                            $_module.py "$function_to_run" "$@"
                            return $?
                        fi
                    # run binary module functions
                    if [[ -f "$GURU_BIN/$_module" ]] ; then
                            $_module "$function_to_run" "$@"
                            return $?
                        fi
                    fi
        done
    return 1
}


core.multi_module_function () {
    # run function name of all installed modules

    local function_to_run=$1 ; shift
    for _module in ${GURU_MODULES[@]} ; do
                gmsg -c dark_golden_rod "$_module $function_to_run"

                # fun shell script module functions
                if [[ -f "$GURU_BIN/$_module.sh" ]] ; then
                        source $GURU_BIN/$_module.sh
                        $_module.main "$function_to_run" "$@"
                    fi
                # run python module functions
                if [[ -f "$GURU_BIN/$_module.py" ]] ; then
                        $_module.py "$function_to_run" "$@"
                    fi
                # run binary module functions
                if [[ -f "$GURU_BIN/$_module" ]] ; then
                        $_module "$function_to_run" "$@"
                    fi
        done
    return 1
}


core.shell () {
    # terminal looper

    render_path () {
            # todo this is broken
            local _path="$(pwd)"
            if [[ "$_path" == "$HOME" ]] ; then _path='~' ; fi
            local _source=$(eval echo '${GURU_MOUNT_'"${_item}[1]}")
            local c_user=$(eval echo '$C_'"${GURU_COLOR_PATH_USER^^}")
            local c_at=$(eval echo '$C_'"${GURU_COLOR_PATH_AT^^}")
            local c_call=$(eval echo '$C_'"${GURU_COLOR_PATH_CALL^^}")
            local c_sepa=$(eval echo '$C_'"${GURU_COLOR_PATH_SEPA^^}")
            local c_dir=$(eval echo '$C_'"${GURU_COLOR_PATH_DIR^^}")
            local c_input=$(eval echo '$C_'"${GURU_COLOR_PATH_INPUT^^}")

            printf "$c_user$GURU_USER$c_at@$c_call$_GURU_CALL$c_sepa:$c_dir$_path$ $c_input"
            gmsg -n -c normal
        }

    inc_verbose () {

            (( _verbose<2 )) && let _verbose++
            cmd=
        }

    dec_verbose () {
            (( _verbose>0 )) && let _verbose--
            cmd=
        }


    gmsg "$GURU_CALL in shell mode (type 'help' enter for help)"

    local _verbose=1

    while : ; do
            # config.export "$GURU_CFG/$GURU_USER/user.cfg" >/dev/null
            source $GURU_RC
            GURU_VERBOSE=$_verbose

            # set call name off for sub processes, affects some help content
            local _GURU_CALL="$GURU_CALL"
            GURU_CALL=

            read -e -p "$(render_path)" "cmd"

            case "$cmd" in exit|q|quit)  break ;;
                                     '+')  inc_verbose ;;
                                     '-')  dec_verbose ;;
                esac
            [[ $cmd ]] && core.parser $cmd
        done

    gmsg -v2 "take care!"
    return $?
}


core.help () {
    # functional core help

    core.help_flags () {
            gmsg -v2
            gmsg -v1 -c white "general flags:"
            gmsg -v2
            gmsg -v1 " -s               be more silent, printout only errors and warnings"
            gmsg -v1 " -v 1..4          verbose level, adds headers and some details"
            gmsg -v1 " -u <username>    change guru user name temporary  "
            gmsg -v1 " -h <hosname>     change computer host name name temporary "
            gmsg -v1 " -l               set logging on to file $GURU_LOG"
            gmsg -v1 " -f               set force mode on, be more aggressive"
            gmsg -v1 " -c               disable colors in terminal"
            gmsg -v2
            return 0
        }


    core.help_system () {
            gmsg -v2
            gmsg -v1 -c white  "system tools"
            gmsg -v1 "  install         install tools "
            gmsg -v1 "  uninstall       remove guru toolkit "
            gmsg -v1 "  upgrade         upgrade guru toolkit "
            gmsg -v1 "  status          status of stuff"
            gmsg -v1 "  shell           start guru shell"
            gmsg -v1 "  version         printout version "
            gmsg -v2
            gmsg -v2 "to refer detailed tool help, type '$GURU_CALL <module> help'"
            return 0
        }

    core.help_newbie () {
        if [[ -f $HOME/.data/.newbie ]] ; then
            gmsg
            gmsg -c white "if problems after installation"
            gmsg
            gmsg "1) logout and login to set path by .profiles or set path:"
            gmsg
            gmsg '   PATH=$PATH:$HOME/bin'
            gmsg
            gmsg "2) if no access to ujo.guru access point, create fake data mount"
            gmsg
            gmsg '   mkdir $HOME/.data ; touch $HOME/.data/.online'
            gmsg
            gmsg "3) to edit user configurations run:"
            gmsg
            gmsg "   $GURU_CALL config user"
            gmsg
            gmsg "4) remove newbie help view by: "
            gmsg
            gmsg "   rm $HOME/.data/.newbie"
            gmsg
            export GURU_VERBOSE=1
        fi
    }


    local _arg="$1"
    if [[ "$_arg" ]] ; then

            case "$_arg" in
                    all) core.multi_module_function help        ; return 0 ;;
                    flags) core.help_flags                      ; return 0 ;;
                      *) core.run_module_function "$_arg" help  ; return 0 ;;
                    esac
        fi

    core.help_newbie
    gmsg -v1 -c white "guru-client help "
    gmsg -v2
    gmsg -v0  "usage:    $GURU_CALL [-flags] [tool] [argument] [variables]"
    core.help_flags
    gmsg -v1 -c white  "connection tools"
    gmsg -v1 "  remote          accesspoint access tools"
    gmsg -v1 "  ssh             ssh key and connection tools"
    gmsg -v1 "  mount|umount    mount remote locations"
    gmsg -v1 "  phone           get data from android phone"
    gmsg -v2
    gmsg -v1 -c white  "work track and documentation"
    gmsg -v1 "  note            create and edit daily notes"
    gmsg -v1 "  timer           work track tools"
    gmsg -v1 "  trans           google translator in terminal"
    gmsg -v1 "  document        compile markdown to .odt format"
    gmsg -v1 "  scan            sane scanner tools"
    gmsg -v2
    gmsg -v1 -c white  "clipboard tools"
    gmsg -v1 "  stamp           time stamp to clipboard and terminal"
    gmsg -v2
    gmsg -v1 -c white  "entertainment"
    gmsg -v1 "  news            text tv type reader for rss news feeds"
    gmsg -v1 "  play            play videos and music"
    gmsg -v1 "  silence         kill all audio and lights"
    gmsg -v2
    gmsg -v1 -c white  "hardware and io devices"
    gmsg -v1 "  input           to control varies input devices (keyboard etc)"
    gmsg -v1 "  keyboard        to setup keyboard shortcuts"
    gmsg -v1 "  radio           listen FM- radio (HW required)"
    gmsg -v2
    gmsg -v1 -c white  "examples"
    gmsg -v1 "  $GURU_CALL note yesterday           open yesterdays notes"
    gmsg -v2 "  $GURU_CALL install mqtt-server      install mqtt server"
    gmsg -v1 "  $GURU_CALL ssh key add github       add ssh keys to github server"
    gmsg -v1 "  $GURU_CALL timer start at 12:00     start work time timer"
    gmsg -v1
    gmsg -v1 -c white  "More detailed help, type '$GURU_CALL <tool> help'"
    gmsg -v1 "Use verbose mode '-v' to get more information in help printout. "
    gmsg -v1 "Even more detailed, try '-V' or '-W' "
    gmsg -v1

}

# if launched as a script, not as library
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] ; then

    # process '-' arguments, returns rest of argument in $ARGUMENTS variable
    core.process_opts $@

    # import needed modules
    source $GURU_BIN/config.sh
    source $GURU_BIN/common.sh
    source $GURU_BIN/mount.sh
    source $GURU_BIN/daemon.sh
    source $GURU_BIN/corsair.sh
    source $GURU_BIN/system.sh

    # check is accesspoint enabled and mount is not already done
    if [[ $GURU_ACCESS_ENABLED ]] ; then
        # check is system folder mounted
        source $GURU_BIN/mount.sh
        mount.main system
    fi
        core.main $ARGUMENTS
        exit $?
fi
