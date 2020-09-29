#!/bin/bash
# guru-client corsair led notification functions
# casa@ujo.guru 2020

# todo
#   - automated keyboard shortcut and pipe configurations for ckb-next
#   - able keys to go blink in background
#   - more colors and key > pipe file bindings
#   - shortcuts behind indicator key presses

# keys pipe files
# NOTE: these need to correlate with cbk-next animation settings!
    ESC="/tmp/ckbpipe000"
     F1="/tmp/ckbpipe001"
     F2="/tmp/ckbpipe002"
     F3="/tmp/ckbpipe003"
     F4="/tmp/ckbpipe004"
     F5="/tmp/ckbpipe005"
     F6="/tmp/ckbpipe006"
     F7="/tmp/ckbpipe007"
     F8="/tmp/ckbpipe008"
     F9="/tmp/ckbpipe009"
    F10="/tmp/ckbpipe010"
    F11="/tmp/ckbpipe011"
    F12="/tmp/ckbpipe012"
   CPLC="/tmp/ckbpipe059"

# rgb color codes [R|G|B|Brightness]
   _RED="ff0000ff"
 _GREEN="00ff00ff"
  _BLUE="0000ffff"
_YELLOW="ffff00ff"
 _WHITE="ffffffff"
   _OFF="000000ff"

# active key list
key_list=$(file /tmp/ckbpipe0* |grep fifo |cut -f1 -d ":")


corsair.main () {
    # command parser
    corsair.check                   # check than ckb-next-darmon, ckb-next and pipes are started and start is not
    local _cmd="$1" ; shift         # get command
    case "$_cmd" in start|end|status|help|install|remove|write)
            corsair.$_cmd $@ ; return $? ;;
        *)  echo "unknown command"
    esac
    return 0
}


corsair.help () {
    gmsg -v 1 -c white "guru-client corsair driver help -----------------------------------------"
    gmsg -v 2
    gmsg -v 0 "usage:    $GURU_CALL corsair [start|end|status|help|install|remove|write <key> <color>]"
    gmsg -v 2
    gmsg -v 1 -c white "commands:"
    gmsg -v 1 " install         install requirements "
    gmsg -v 1 " remove          remove corsair driver "
    gmsg -v 2 " help            this help "
    gmsg -v 1 " write           write key color (described below)  "
    gmsg -v 1 "    <KEY>        up-case key name like 'F1'  "
    gmsg -v 1 " _<COLOR>        up-case color with '_' on front of it "     # todo: go better
    gmsg -v 1 " start           starting procedure"
    gmsg -v 1 " end             ending procedure"
    #        start_blink     make key to blink (details below)
    #           <freq>       frequency in milliseconds
    #           <ratio>      10 = 10 of freq/100
    #        status          launch keyboard status view for testing
    gmsg -v 2
    gmsg -v 1 -c white "example:"
    gmsg -v 1 "          $GURU_CALL corsair status "
    gmsg -v 2
}


corsair.check () {
    # Check keyboard driver is available, app and pipes are started and executes if needed
    if ! ps auxf |grep "ckb-next-daemon" | grep -v grep >/dev/null ; then
            gmsg -v1 -t "starting ckb-next-daemon.."
            ckb-next-daemon --nonroot >/dev/null
            sleep 2
        else gmsg -v1 -t "ckb-next-daemon $(OK)" ; fi

    # Check is keyboard setup interface, start if not
    if ! ps auxf |grep "ckb-next " | grep -v grep >/dev/null 2>&1 ; then
            gmsg -v1 -t "starting ckb-next.."
            ckb-next >/dev/null 2>&1 &
            sleep 2
        else gmsg -v1 -t "ckb-next $(OK)" ; fi

    # Check are pipes started, start if not

    corsair.init status
    if ! ps auxf |grep "ckb-next" | grep "ckb-next-animations/pipe" | grep -v grep>/dev/null ; then
            gmsg "set pipes in cbk-next gui: K68 > Lighting > select a key(s) > New animation > Pipe > ... and try again"
            return 100
        else gmsg -v1 -t "ckb-next pipes $(OK)" ; fi

    return 0
}


corsair.status () {
    # get status and print it out to kb leds
    if corsair.check ; then
            corsair.write f4 green
            return 0
        else
            corsair.write f4 red
            return 1
        fi
}


corsair.init () {
    # load default profile and set wanted mode
    local _mode="status" ; [[ $1 ]] && _mode=$1
    if ! ckb-next -p guru -m $_mode ; then
            gmsg -v -x $? -c yellow "corsair init failure"
        fi
    return 0
}


corsair.start () {
    # reserve some keys for future purposes by coloring them now
    # todo: I think this can be removed, used to be test interface before daemon

    gmsg -v1 -t "starting corsair"

    for _key_pipe in $key_list ; do
        gmsg -v2 -t "$_key_pipe off"
        corsair.raw_write $_key_pipe $_OFF
        sleep 0.1
    done
}


corsair.end () {
    # return normal, assuming that normal really exits
    gmsg -v1 "resetting keyboard indicators"

    for _key_pipe in $key_list ; do
        gmsg -v2 -t "$_key_pipe white"
        corsair.raw_write $_key_pipe $_WHITE
        sleep 0.1
    done
}


corsair.raw_write () {
    # write color to key: input <KEY_PIPE_FILE> _<COLOR_CODE>
    #corsair.check || return 100         # check is corsair up ünd running
    local _button=$1 ; shift            # get input key pipe file
    local _color=$1 ; shift             # get input color code
    echo "rgb $_color" > "$_button"     # write color code to button pipe file
    sleep 0.1                           # let device to receive and process command (surprisingly slow)
    return 0
}


corsair.write () {
    # write color to key: input <key> <color>
    local _button=${1^^}
    local _color='_'"${2^^}"

    gmsg -v1 -t "$_button to $2"
    # get input key pipe file location
    _button=$(eval echo '$'$_button)
    [[ $_button ]] || gmsg -c yellow -x 101 "no such button"
    # get input color code
    _color=$(eval echo '$'$_color)
    [[ $_color ]] || gmsg  -c yellow -x 102 "no such color"
    gmsg -v2 -t "$_button <- $_color"

    # write color code to button pipe file and let device to receive and process command (surprisingly slow)
    if file $_button |grep fifo >/dev/null ; then
            echo "rgb $_color" > "$_button"
            sleep 0.05
        else
            gmsg -c yellow -x 103 "io error, pipe file $_button is not set in cbk-next"
        fi

    return 0
}


corsair.start_blink () {
    # ask daemon to blink a key
    echo "TBD"
}


corsair.stop_blink () {
    # ask daemon to stop to blink a key
    echo "TBD"
}


corsair.install () {
    # install essentials, driver and application
    sudo apt-get install -y build-essential cmake libudev-dev qt5-default zlib1g-dev libappindicator-dev libpulse-dev libquazip5-dev libqt5x11extras5-dev libxcb-screensaver0-dev libxcb-ewmh-dev libxcb1-dev qttools5-dev git pavucontrol
    cd /tmp
    git clone https://github.com/ckb-next/ckb-next.git
    cd ckb-next
    ./quickinstall

    if ! lsusb |grep "Corsair" ; then
        echo "no corsair devices connected, exiting.."
        return 100
    fi
}


corsair.remove () {
    # get rid of driver and shit
    if [[ /tmp/ckb-next ]] ; then
        cd /tmp/ckb-next
        sudo cmake --build build --target uninstall
    else
        cd /tmp
        git clone https://github.com/ckb-next/ckb-next.git
        cd ckb-next
        cmake -H. -Bbuild -DCMAKE_BUILD_TYPE=Release -DSAFE_INSTALL=ON -DSAFE_UNINSTALL=ON -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBEXECDIR=lib
        cmake --build build --target all -- -j 4
        sudo cmake --build build --target install       # The compilation and installation steps are required because install target generates an install manifest that later allows to determine which files to remove and what is their location.
        sudo cmake --build build --target uninstall
    fi
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        source "$HOME/.gururc2"
        export GURU_VERBOSE=2
        source "$GURU_BIN/deco.sh"
        corsair.main "$@"
        exit "$?"
fi
