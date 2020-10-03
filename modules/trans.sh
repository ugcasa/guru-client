#!/bin/bash
# ujo.guru 2019
source $GURU_BIN/common.sh

trans.main() {
    # command paerser
    local _cmd="$1" ; shift
    case "$_cmd" in
            get|help|status)  trans.$_cmd $@     ;;
                          *)  trans.get "$_cmd"  ;;
        esac
}


trans.help () {
    gmsg -v0 "usage:    $GURU_CALL trans source_l:targed_l <text>"
    exit 0
}


trans.status () {
    gmsg -v1 -x 1 "no status information"
    exit 0
}


trans.get () {
     # terminal based translator
     # TODO: bullshit, re-write (handy shit dow, in daily use)

     if ! [ -f $GURU_BIN/trans ]; then
        cd $GURU_BIN
        wget git.io/trans
        chmod +x ./trans
    fi

    if [[ $1 == *"-"* ]]; then
        argument1=$1
        shift
    else
        argument1=""
    fi

    if [[ $1 == *"-"* ]]; then
        argument2=$1
        shift
    else
        argument2=""
    fi

    if [[ $1 == *":"* ]]; then
        #echo "iz variable: $variable"
        variable=$1
        shift
        word=$@

    else
        #echo "iz word: $word"
        word=$@
        variable=""
    fi

    $GURU_BIN/trans $argument1 $argument2 $variable "$word"
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then    # stand alone vs. include. main wont be called if included
        source "$HOME/.gururc2"
        trans.main "$@"
        exit $?                                     # otherwise can be non zero even all fine TODO check why, case function feature?
    fi