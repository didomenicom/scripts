#!/bin/bash
# Based on https://lists.samba.org/archive/samba/2005-June/106958.html
if [ ! -e /home/$1/$2 ]; then
	mkdir -p /home/$1/$2
	chown $2:"Domain Users" /home/$1/$2
fi

exit 0

