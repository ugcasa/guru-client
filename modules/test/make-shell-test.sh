#!/bin/bash
# make test
# TODO omg how old ways to do shit, review pls.

source $GURU_BIN/common.sh

process_opts () {

    TEMP=`getopt --long -o "vVfl" "$@"`
    eval set -- "$TEMP"
    while true ; do
        case "$1" in
            -v ) export GURU_VERBOSE=1      ; shift     ;;
            -V ) export GURU_VERBOSE=2      ; shift     ;;
            -f ) export GURU_FORCE=true     ; shift     ;;
            -l ) export GURU_LOGGING=true   ; shift     ;;
             * ) break                                  ;;
        esac
    done;
    _arg="$@"
    [[ "$_arg" != "--" ]] && ARGUMENTS="${_arg#* }"
}

process_opts $@

# TODO with or without file ending

[[ "$1" ]] && module=$1 || read -p "module name to create test for (no file ending): " module

if [[ -f "../../core/$module.sh" ]] ; then
        module_to_test="../../core/$module.sh"

    elif [[ -f "../../modules/$module.sh" ]] ; then
        module_to_test="../../modules/$module.sh"

    elif [[ -f "$GURU_BIN/$module.sh" ]] ; then
        module_to_test="$GURU_BIN/$module.sh"
    else
        gr.msg -c yellow "no module '$module' found in any location"
        return 12
    fi

gr.msg -c white "generating tester for $module_to_test"

# inldes only if space is left between function name and "()"
functions_to_test=($(cat $module_to_test |grep " ()" |cut -f1 -d " "))
tester_file_name="test-""$module"".sh"

gr.msg -v1 -c blue "module: $module_to_test"
gr.msg -v1 -c blue "output: $tester_file_name"
gr.msg "${#functions_to_test[@]} functions to test"

# check if tester exist
if [[ -f $tester_file_name ]] && gr.ask "tester '$tester_file_name' exist, overwrite?" ; then
            gr.msg "overwriting.."
        else
            gr.msg "canceling.."
            return 12
    fi

# start file manipulating
echo "#!/bin/bash "  > $tester_file_name
echo "# automatically generated tester for guru-client $module.sh $(date) casa@ujo.guru 2020"  >> $tester_file_name
echo                                                                        >> $tester_file_name

# sourcing and test variable space
echo 'source $GURU_BIN'"/common.sh"                                         >> $tester_file_name
echo "source $module_to_test "                                              >> $tester_file_name
echo                                                                        >> $tester_file_name
echo "## TODO add test initial conditions here"                             >> $tester_file_name
echo                                                                        >> $tester_file_name

# function and tests 1-9
echo "$module.test() {"                                                     >> $tester_file_name
echo '    local test_case=$1'                                               >> $tester_file_name
echo '    local _err=($0)'                                                  >> $tester_file_name
echo '    case "$test_case" in'                                             >> $tester_file_name
echo "           1) $module.status ; return $? ;;  # 1) quick check"        >> $tester_file_name

# all tests = all functions in introduction order
echo '         all) '                                                       >> $tester_file_name
echo '         # TODO: remove non wanted functions and check run order. '   >> $tester_file_name
_i=100
for _function in "${functions_to_test[@]}" ; do
        test_function_name=${_function//"$module."/"$module.test_"}
        (( _i++ ))
        echo "              echo ; $test_function_name"' || _err=("${_err[@]}" "'"$_i"'") ' >> $tester_file_name
    done

# "all" test error colletor
echo '              if [[ ${_err[1]} -gt 0 ]]; then echo "error: ${_err[@]}"; return ${_err[1]}; else return 0; fi ;; ' >> $tester_file_name

# no case and close function
echo '         *) gr.msg "test case $test_case not written"'                  >> $tester_file_name
echo '            return 1'                                                 >> $tester_file_name
echo '    esac'                                                             >> $tester_file_name
echo '}'                                                                    >> $tester_file_name
echo                                                                        >> $tester_file_name
# test function processor
for _function in "${functions_to_test[@]}" ; do
        test_function_name=${_function//"$module."/"$module.test_"}
        gr.msg -v2 -c light_blue "$_function"
        gr.msg -v2 -c light_green "$test_function_name"

        echo                                                                >> $tester_file_name
        echo  "$test_function_name () {"                                    >> $tester_file_name
        echo "    # function to test $module module function $_function"    >> $tester_file_name
        echo '    local _error=0'                                           >> $tester_file_name
        echo "    gr.msg -v0 -c white 'testing $_function'"                   >> $tester_file_name
        echo                                                                >> $tester_file_name
        echo '      ## TODO: add pre-conditions here '                      >> $tester_file_name
        echo                                                                >> $tester_file_name
        echo "      $_function"' ; _error=$?'                               >> $tester_file_name
        echo                                                                >> $tester_file_name
        echo '      ## TODO: add analysis here and manipulate $_error '     >> $tester_file_name
        echo                                                                >> $tester_file_name
        echo '    if  ((_error<1)) ; then '                                 >> $tester_file_name
        echo "       gr.msg -v0 -c green '$_function passed' "                >> $tester_file_name
        echo '       return 0'                                              >> $tester_file_name
        echo '    else'                                                     >> $tester_file_name
        echo "       gr.msg -v0 -c red '$_function failed' "                  >> $tester_file_name
        echo '       return $_error'                                        >> $tester_file_name
        echo '  fi'                                                         >> $tester_file_name
        echo "}"                                                            >> $tester_file_name
        echo                                                                >> $tester_file_name
    done

# add lonely runner check
echo                                                                        >> $tester_file_name
echo 'if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then '                        >> $tester_file_name
echo '    source "$GURU_RC" '                                               >> $tester_file_name
echo '    GURU_VERBOSE=2'                                                   >> $tester_file_name
echo "    $module.test "'$@'                                                >> $tester_file_name
echo 'fi'                                                                   >> $tester_file_name
echo                                                                        >> $tester_file_name

# make runnable
chmod +x "$tester_file_name"
# open for edit
$GURU_PREFERRED_EDITOR $tester_file_name