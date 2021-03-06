#!/usr/bin/bash
#
#   Launch an instance of pd in server mode on a remote machine,
#   then launch a pd-gui on this machine that connects to the
#   remote pd.
#
#   Remote machine must be one of gui.local, dac.local, core.local.
#
#   FGH 2021-04-27

#
#   Defines
#
PORT=3220

#
#    Check to make sure we are on the GUI host
#
if [ $(hostname) != gui ]; then
    echo "Error: $(basename $0) can only be run on the gui host"
    echo "Exiting"
    exit 1
fi

#
#  Process args
#
if [ $# -lt 1 -o $# -gt 2 ]; then
    echo "Usage: $(basename $0) <REMOTE_NAME> [<APP NAME>]"
    exit 1
fi
case $1 in
    gui|core|dac|all)
    ;;
    *)
        echo "Usage: $(basename $0) <REMOTE_NAME> [<APP NAME>]"
	echo "First argument must be one of: gui, core, dac, or all."
	exit 1
    ;;
esac
#
#
#	Define function that does all the work
#
#
doit() {

RN=$1
APP=$2

#
#
#   Use ssh to launch pd in server mode on remote host
#
if [ "X${APP}X" = "XX" ]; then
    APP_STRING=""
else
    APP_STRING=/home/${RN}/pd/patches/${APP}/${RN}/${APP}-${RN}.pd
fi
/usr/bin/ssh -o "StrictHostKeyChecking=no" -f ${RN}@${RN}.local /usr/local/bin/pd -nrt -server-mode ${PORT} ${APP_STRING}
sleep 1
#
#   Execute (most of) rest of script as local user corresponding 
#   to remote host - e.g., as user dac for host dac.local
#

/usr/bin/sudo -u ${RN} bash <<EOF
cd \$HOME
#
#   Except when the remote host is gui (usually the host that script is running  on)
#   make sure that the remote host file system is mounted on this host via
#   sshfs.
#
if [ ${RN} != gui ]; then
    /usr/bin/mount -t fuse.sshfs | grep -q ${RN}.local
    if [ \$? -ne 0 ]; then
        sudo /usr/bin/sshfs ${RN}@${RN}.local:/home/${RN}  /home/${RN} -o nonempty -o reconnect -o allow_other -o "IdentityFile=/home/gui/.ssh/id_rsa" -o "StrictHostKeyChecking=no" 
    fi 
fi
#
#    Start up the pd-gui on the local host and connect it to the already
#    running pd on the remote host
#
#
cd /home/${RN}/pd/patches
/usr/local/bin/pd-gui ${RN}.local:${PORT} &
EOF
#
#    End of code executed as the "corresponding" user
#

}

#
#    Function Definition
#

#
#	Call function as required
#
if [ $1 == all ]; then
    for RN in dac gui core
    do
	doit ${RN} $2
    done
else
    doit $1 $2
fi
sleep 5
exit 0


