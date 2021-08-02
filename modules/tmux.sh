#!/bin/bash
# tmux controller
# casa@ujo.guru 2020 - 2021
# thanks samoshkin! https://github.com/samoshkin/tmux-config
# [vim + tmux - OMG!Code](https://www.youtube.com/watch?v=5r6yzFEXajQ)
# [Complete tmux Tutorial](https://www.youtube.com/watch?v=Yl7NFenTgIo)
# config location: (overrides defaults in:)

source $GURU_BIN/common.sh
tmux_indicator_key="f$(daemon.poll_order tmux)"


tmux.help () {
    gmsg -v1 -c white "guru-client tmux help "
    gmsg -v2
    gmsg -v0 "usage:    $GURU_CALL tmux status|config|start|end|help|install|remove "
    gmsg -v2
    gmsg -v1 -c white "commands: "
    gmsg -v1 " config                   open configuration in dialog"
    gmsg -v1 " config edit              open configuration in $GURU_PREFERRED_EDITOR"
    gmsg -v1 " status                   show status of default tmux server "
    gmsg -v1 " install                  install client requirements "
    gmsg -v1 " remove                   remove installed requirements "
    gmsg -v3 " poll start|end           start or end module status polling "
    gmsg -v2 " help                     printout this help "
    gmsg -v2
    gmsg -v1 -c white "examples: "
    gmsg -v1 "         $GURU_CALL tmux config "
    gmsg -v2
}


tmux.main () {
    # tmux main command parser
    local _cmd="$1" ; shift
    tmux_indicator_key="f$(daemon.poll_order tmux)"


    case "$_cmd" in
               help|install|remove|poll|status|config)
                    tmux.$_cmd "$@"
                    return $?
                    ;;

               *)   gmsg -c yellow "${FUNCNAME[0]}: unknown command: $_cmd"
                    return 2
        esac

    return 0
}



tmux.config () {
    # tmux configuration manager
    local editor='dialog'
    [[ $1 ]] && editor='$1'
    config_file="$HOME/.tmux.conf"

    if ! [[ -f $config_file ]] ; then
        if gask "user configuration fur user did not found, create from template?" ; then
                [[ -f /usr/share/doc/tmux/example_tmux.conf ]] \
                    && cp /usr/share/doc/tmux/example_tmux.conf $config_file \
                    || gmsg -c yellow "tmux default file not found try to install '$GURU_CALL tmux install'"
            else
                gmsg -v1 "nothing changed, using tmux default config"
                return 0
            fi
        fi

    case $1 in

                edit)
                    $GURU_PREFERRED_EDITOR $config_file
                    return 0
                    ;;
                undo|return)
                    tmux.config_undo $config_file
                    ;;
                dialog|*)
                    tmux.config_dialog $config_file
                    ;;
       esac
}



tmux.config_dialog () {
    # open ialog to make changes to tmux dxonfig file

    # gmsg -v3 "checking dialog installation.."
    dialog --version >>/dev/null || sudo apt install dialog
    local config_file="$HOME/fuckedup.conf"
    [[ $1 ]] && config_file="$1"

    # open temporary file handle and redirect it to stdout
    exec 3>&1
    new_file="$(dialog --editbox "$config_file" "0" "0" 2>&1 1>&3)"
    return_code=$?
    # close new file handle
    exec 3>&-
    clear

    if (( return_code > 0 )) ; then
            gmsg -v1 "nothing changed.."
            return 0
        fi

    if gask "overwrite settings" ; then
            cp -f "$config_file" "$config_file.old"
            gmsg -v1 "backup saved $config_file.old"
            echo "$new_file" >"$config_file"
            gmsg -v1 -c white "configure saved"
        else
            gmsg -v1 -c dark_golden_rod "nothing changed"
            gmsg -v1 -c white "to get previous configurations from sever type: '$GURU_CALL config undo'"
        fi
    return 0
}


tmux.config_undo () {

    if [[ $1 ]] ; then
            local config_file="$1"
        else
            gmsg -c yellow "configfile '$1' does not exist"
            return 0
        fi

    if gask "undo changes?" ; then
            mv -f "$config_file" "$config_file.tmp"
            cp -f "$config_file.old" "$config_file"
            mv -f "$config_file.tmp" "$config_file.old"
            gmsg -v1 -c white "previous configure retuned"
        else
            gmsg -v1 -c dark_golden_rod "nothing changed"
        fi
}



tmux.status () {
    # check tmux broker is reachable.
    # printout and signal by corsair keyboard indicator led - if available
    tmux_indicator_key="f$(daemon.poll_order tmux)"

    gmsg -n -v1 -t "${FUNCNAME[0]}: "

    if [[ $GURU_TMUX_ENABLED ]] ; then
            gmsg -v1 -n -c green "enabled, "
        else
            gmsg -v1 -c black "disabled " \
                 -k $tmux_indicator_key
            return 1
        fi
}


tmux.poll () {
    # daemon required polling functions
    local _cmd="$1" ; shift

    case $_cmd in
        start )
            gmsg -v1 -t -c black \
                -k $tmux_indicator_key \
                "${FUNCNAME[0]}: tmux status polling started"
            ;;
        end )
            gmsg -v1 -t -c reset \
                -k $tmux_indicator_key \
                "${FUNCNAME[0]}: tmux status polling ended"
            ;;
        status )
            tmux.status
            ;;
        *)  tmux.help
            ;;
        esac
}


tmux.install () {
    # install mosquitto tmux clients
    sudo apt update
    sudo apt install tmux \
        && gmsg -c green "guru is now ready to tmux" \
        || gmsg -c yellow "error $? during install tmux"
    return 0

}


tmux.remove () {
    # remove mosquitto tmux clients
    sudo apt remove tmux && return 0
    return 1
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    tmux.main "$@"
    exit "$?"
fi

