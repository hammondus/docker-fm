SERVER_NAME="${BOLD}Claris FileMaker Server${NORMAL}"
DEPLOYMENT_NAME="$SERVER_NAME"
HELPER_PROC=fmshelper
SERVER_PROC=fmserverd


call_trace()  { echo "      > $*"; }
debug_trace() { echo "      > $*"; }

stopApache()
{
	call_trace "${FUNCNAME[0]}()"
	if [[ -L "com.filemaker.httpd.start.service" ||
	      -f "com.filemaker.httpd.start.service" ]]; then
		echo "Stop Apache service."
		for a in start stop restart graceful
		do
			for b in path service
			do
				/bin/systemctl stop "com.filemaker.httpd.${a}.${b}" > /dev/null 2>&1
			done
		done
	fi
}

stopNginx()
{
	if [[ -L "com.filemaker.nginx.start.service" ||
	      -f "com.filemaker.nginx.start.service" ]]; then
		echo "Stop Nginx service."
		for a in start stop restart graceful
		do
			for b in path service
			do
				/bin/systemctl stop "com.filemaker.nginx.${a}.${b}" > /dev/null 2>&1
			done
		done
	fi
}

stopSystemNginx()
{
	local result=$ERROR_NONE
	apt list --installed  2>&1 | grep -w $NGINX_PROC > /dev/null
	result=$?
	if  [[ $result -eq $ERROR_NONE ]]; then
		/bin/systemctl is-active $NGINX_PROC > /dev/null 2>&1
		result=$?
		if [[ $result -eq $ERROR_NONE ]]; then
			echo "Stop system Nginx server service..."
			/bin/systemctl stop $NGINX_PROC > /dev/null 2>&1
			result=$?
			if [[ $result -ne $ERROR_NONE ]]; then
				echo "$WARNING Fail to stop system Nginx server service..."
			fi
		fi

		/bin/systemctl is-enabled $NGINX_PROC > /dev/null 2>&1
		result=$?
		if [[ $result -eq $ERROR_NONE ]]; then
			echo "      > Disable system Nginx server service..."
			/bin/systemctl disable $NGINX_PROC > /dev/null 2>&1
			result=$?
			if [[ $result -ne $ERROR_NONE ]]; then
				echo "      > $WARNING Fail to disable system Nginx server service..."
			fi
		fi
	fi
}

stopServices()
{
	local loopCount=0
	local helperGone=false
	local procCount=0
	local result=$ERROR_NONE

	pushd /etc/systemd/system > /dev/null
	if [[ -L fmshelper.service || -f fmshelper.service ]]; then
		echo "      > Stop and disable $DEPLOYMENT_NAME service..."
		/bin/systemctl stop fmshelper.service > /dev/null 2>&1
		procCount=$(pgrep -c "$HELPER_PROC")
		if [[ "$procCount" -ne 0 ]]; then
			while [[ $loopCount -le 15 ]]
			do
				/bin/sleep 2
				procCount=$(pgrep -c "$HELPER_PROC")
				if [[ "$procCount" -ne 0 ]]; then
					loopCount=$(( ++loopCount ))
				else
					helperGone=true
					break
				fi
			done
		else
			helperGone=true
		fi

		if [[ $helperGone = true ]]; then
			result=$ERROR_NONE
		else
			echo "      > Failed to stop $DEPLOYMENT_NAME services." 
		fi
	fi

	popd > /dev/null
}

CheckProcess="fmshelper fmsib fmserverd fmslogtrimmer fmsased fmxdbc_listener fmwipd fmsadmin"
for runningProcee in $CheckProcess ; do
	fmserver=`ps -A | sed "s/.*:..... /\"/" | sed s/$/\"/ | grep $runningProcee`
	if [[ -z $fmserver ]] ; then
		continue
	else
		stopServices
		break
	fi
done

procCount=$(pgrep -c "nginx")
if [[ "$procCount" -ne 0 ]]; then
    stopSystemNginx
	stopNginx
fi

procCount=$(pgrep -c "apache2")
if [[ "$procCount" -ne 0 ]]; then
	stopApache
fi
