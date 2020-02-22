#!/bin/bash

main () {
	case "$command" in 
		
		software|sw)
			remove-sw $@
			exit $?
			;;
		all)
			uninstall $@	
			remove-sw $@
			;;
		cfg)
			uninstall $@	
			remove-sw $@
			[ $GURU_CFG ] && rm -rf "$GURU_CFG"
			;;
		*)	
			uninstall $@
			exit $?
	esac
}


uninstall () {	 

	if [ ! -f "$HOME/.bashrc.giobackup" ]; then 
		echo "not installed, aborting.." >>$GURU_ERROR_MSG
		return 135
	fi		

	if [ -f $HOME/.gururc ]; then 
		 . $HOME/.gururc 
	else
		echo "$me no setup file exists, aborting.." >>$GURU_ERROR_MSG
		return 136	
	fi	

	if [ $GURU_BIN == "" ]; then 
		echo "no environment variables set, aborting.." >>$GURU_ERROR_MSG
		return 137		
	fi

#	printf "1:$HOME/.bashrc.giobackup \n2:$HOME/.gururc \n3:$GURU_BIN/$GURU_CALL $HOME/.kbbind.backup.cfg \n4:$GURU_CFG\n"
	mv -f "$HOME/.bashrc.giobackup" "$HOME/.bashrc"		
	rm -f "$HOME/.gururc"	
	rm -f "$GURU_BIN/$GURU_CALL"		
	[ $GURU_CFG ] && rm -f "$GURU_CFG/*"
	
	if [[ -f "$HOME/.kbbind.backup.cfg" ]]; then 
		dconf load /org/cinnamon/desktop/keybindings/ < $GURU_CFG/kbbind.backup.cfg
	fi
	
	case "$GURU_INSTALL" in 			# Installation type 

		desktop)			
			;;
		server)			
			;;
			*)
	esac
	
	#rm -fr "$GURU_BIN"				# TODO: own folder meaby?
	echo "successfully un-installed"
	return 0
}


remove-sw() { 		
	# not fully tested
	echo "pandoc xterm dconf-cli mosquitto-clients mps-youtube youtube_dl mpsyt"
	sudo apt remove pandoc xterm dconf-cli mosquitto-clients
	#rm /usr/bin/mpsyt
	#pip3 remove mps-youtube youtube_dl 

	[ -d $GURU_APP ] || rm -fr $GURU_APP
		
	if [ "$1" == "all" ]; then 
		echo "sublime-text git setuptools "
		#sudo apt remove sublime-text git 
		#pip3 remove setuptools 

	fi
}


me=${BASH_SOURCE[0]}
if [[ "$me" == "${0}" ]]; then
	command=$1
	shift
	main $@
fi

