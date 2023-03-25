#!/bin/bash
# guru-client network module casa@ujo.guru 2022

declare -g net_rc="/tmp/guru-cli_net.rc"

net.help () {
    # user help
    gr.msg -n -v2 -c white "guru-cli net help "
    gr.msg -v1 "guru-cli network control module"
    gr.msg -v2
    gr.msg -v0 -c white  "usage:    net check|status|help"
    gr.msg -v2
    gr.msg -v1 -c white "commands: "
    gr.msg -v1 " status     return network status "
    gr.msg -v1 " check      check internet is reachable "
    gr.msg -v1 " server     check accesspoint is reachable "
    gr.msg -v1 " cloud      fileserver is reachable"
    gr.msg -v2 " help       printout this help "
    gr.msg -v2
    gr.msg -v1 -c white "examples:  "
    gr.msg -v1 "$GURU_CALL net      textual status info"
    gr.msg -v2
}


net.main () {
# main command parser

    local function="$1" ; shift
    ## declare one shot variables here only if really needed
    ## declare -g bubble_gum=̈́true

    case "$function" in
            ## add functions called from outside on this list
            check|status|help|poll)
                net.$function $@
                return $?
                ;;
            server|accesspoint|access)
                net.check_server $@
                return $?
                ;;
            cloud|fileserver|files)
                net.check_server $GURU_CLOUD_DOMAIN
                return $?
                ;;

            *)
                net.check_server && gr.msg -c green "server reachable" || gr.msg -c orange "server offline"
                net.check && gr.msg -c green "internet available" || gr.msg -c orange "internet unreachable"
                ;;
        esac
}


net.rc () {
# source configurations

    if  [[ ! -f $net_rc ]] || \
        [[ $(( $(stat -c %Y $GURU_CFG/$GURU_USER/net.cfg) - $(stat -c %Y $net_rc) )) -gt 0 ]]
        then
            net.make_rc && \
                gr.msg -v1 -c dark_gray "$net_rc updated"
        fi

    source $net_rc
}


net.make_rc () {
# make core module rc file out of configuration file

    if ! source config.sh ; then
            gr.msg -c yellow "unable to load configuration module"
            return 100
        fi

    if [[ -f $net_rc ]] ; then
            rm -f $net_rc
        fi

    if ! config.make_rc "$GURU_CFG/$GURU_USER/net.cfg" $net_rc ; then
            gr.msg -c yellow "configuration failed"
            return 101
        fi

    chmod +x $net_rc

    if ! source $net_rc ; then
            gr.msg -c red "unable to source configuration"
            return 202
        fi
}


net.listening () {
# printout list of used outpund ports
    netstat -nputwc
}


net.listen () {

# usage: tcpflow [-aBcCDhIpsvVZ] [-b max_bytes] [-d debug_level]
#      [-[eE] scanner] [-f max_fds] [-F[ctTXMkmg]] [-h|--help] [-i iface]
#      [-l files...] [-L semlock] [-m min_bytes] [-o outdir] [-r file] [-R file]
#      [-S name=value] [-T template] [-U|--relinquish-privileges user] [-v|--verbose]
#      [-w file] [-x scanner] [-X xmlfile] [-z|--chroot dir] [expression]
#    -a: do ALL post-processing.
#    -b max_bytes: max number of bytes per flow to save
#    -d debug_level: debug level; default is 1
#    -f: maximum number of file descriptors to use
#    -H: print detailed information about each scanner
#    -i: network interface on which to listen
#    -I: write for each flow another file *.findx to provide byte-indexed timestamps
#    -g: output each flow in alternating colors (note change!)
#    -l: treat non-flag arguments as input files rather than a pcap expression
#    -L  semlock - specifies that writes are locked using a named semaphore
#    -p: don't use promiscuous mode
#    -q: quiet mode - do not print warnings
#    -r file      : read packets from tcpdump pcap file (may be repeated)
#    -R file      : read packets from tcpdump pcap file TO FINISH CONNECTIONS
#    -v           : verbose operation equivalent to -d 10
#    -V           : print version number and exit
#    -w  file     : write packets not processed to file
#    -o  outdir   : specify output directory (default '.')
#    -X  filename : DFXML output to filename
#    -m  bytes    : specifies skip that starts a new stream (default 16777216).
#    -F{p} : filename prefix/suffix (-hh for options)
#    -T{t} : filename template (-hh for options; default %A.%a-%B.%b%V%v%C%c)
#    -Z       do not decompress gzip-compressed HTTP transactions

# Security:
#    -U user  relinquish privleges and become user (if running as root)
#    -z dir   chroot to dir (requires that -U be used).

# Control of Scanners:
#    -E scanner   - turn off all scanners except scanner
#    -S name=value  Set a configuration parameter (-hh for info)
    return 0
}

net.portmap () {
# check open ports of domain $1
    return 0
}


net.proxy (){
# listen localhost port $1 and proxy to destnation domain $2 and port $3
# optional log_file_location $4
    return 0
}


net.check_server () {
# quick check accesspoint connection, no analysis

    local _server=$GURU_ACCESS_DOMAIN
    [[ $1 ]] && _server=$1

    gr.msg -n -t -v3 "ping $_server.. "
    if timeout 2 ping $_server -W 2 -c 1 -q >/dev/null 2>/dev/null ; then
        gr.msg -v3 "ok "
        gr.end $GURU_NET_INDICATOR_KEY
        return 0
    else
        gr.msg -v3 "$_server unreachable! "
        gr.ind offline -m "$_server unreachable" -k $GURU_NET_INDICATOR_KEY
        return 127
    fi
}


net.check () {
# quick check network connection, no analysis
    gr.msg -n -t -v3 "ping google.com.. "
    if timeout 3 ping google.com -W 2 -c 1 -q >/dev/null 2>/dev/null ; then

        gr.end $GURU_NET_INDICATOR_KEY
        gr.msg -c green "online " -k $GURU_NET_INDICATOR_KEY
        return 0
    else
        gr.msg -c red "offline "
        gr.ind offline -m "network offline" -k $GURU_NET_INDICATOR_KEY
        return 127
    fi
}

net.status () {
# output net status
    local _return=0
    gr.msg -n -t -v1 "${FUNCNAME[0]}: "

    # check net is enabled
    if [[ $GURU_NET_ENABLED ]] ; then
            gr.msg -n -v1 -c green "enabled, "
        else
            gr.msg -v1 -c black "disabled" -k $GURU_NET_INDICATOR_KEY
            return 1
        fi

    # other tests with output, return errors

    if net.check >/dev/null; then
            gr.msg -n -v1 -c green "online, "
        else
            if [[ $GURU_NET_LOG ]] ; then
                    [[ -d $GURU_NET_LOG_FOLDER ]] || mkdir -p "$GURU_NET_LOG_FOLDER"
                    gr.msg "$(date "+%Y-%m-%d %H:%M:%S") network offline" >>"$GURU_NET_LOG_FOLDER/net.log"
                fi
            _return=101
        fi

    if net.check_server >/dev/null; then
            gr.msg -v1 -c aqua "connected to $GURU_ACCESS_DOMAIN "
        else
            gr.msg -v1 -c orange "$GURU_ACCESS_DOMAIN unreachable"
            _return=102
        fi
    return $_return
    }


net.poll () {
# daemon interface

    # check is indicator set (should be, but wanted to be sure)
    [[ $GURU_NET_INDICATOR_KEY ]] || \
        GURU_NET_INDICATOR_KEY="f$(gr.poll net)"

    local _cmd="$1" ; shift
    case $_cmd in
        start)
            gr.msg -v1 -t -c black "${FUNCNAME[0]}: started" -k $GURU_NET_INDICATOR_KEY
            ;;
        end)
            gr.msg -v1 -t -c reset "${FUNCNAME[0]}: ended" -k $GURU_NET_INDICATOR_KEY
            ;;
        status)
            net.status $@
            ;;
        *)  net.help
            ;;
        esac
}


## if net requires tools or libraries to work installation is done here
net.install () {

    # sudo apt update || gr.msg -c red "not able to update"
    sudo apt-get install -y portmap tcpflow
    # pip3 install --user ...
    return 0
}

## instructions to remove installed tools.
## DO NOT remove any tools that might be considered as basic hacker tools even net did those install those install
net.remove () {

    # sudo apt remove -y ...
    # pip3 remove --user ...
    gr.msg "nothing to remove"
    return 0
}

net.rc

# if called net.sh file configuration is sourced and main net.main called
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    #source "$GURU_RC"
    net.main "$@"
    exit "$?"
fi

