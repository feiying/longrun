#! /usr/bin/bash

# GLOBAL VAR
WAKE_ALAEM="/sys/class/rtc/rtc0/wakealarm"
FILE_AUTORUN_SERVICE="/etc/systemd/system/longrun.service"
AUTORUN_SERVICE=`basename ${FILE_AUTORUN_SERVICE}`
DIR_TMP_LONGRUN="/var/log/longrun/"
LONGRUN_LOG="${DIR_TMP_LONGRUN}/longrun.log"
LONGRUN_CONF="${DIR_TMP_LONGRUN}/longrun.conf"
AUTOLOGIN_CONF="/etc/gdm/custom.conf"
AUTORUN_SCRIPT="/etc/rc.d/loopsettings.sh"
time_waiting=60 # it's time which spend for waiting test.
timeout_running=20 # it's timeout clock for test.


# clean all temp and old data before running longrun.sh
function clean_settings_file_and_log ()
{ 
    if [ -e ${DIR_TMP_LONGRUN} ]; then rm ${DIR_TMP_LONGRUN} -rf; fi
    if [ -e ${AUTORUN_SCRIPT} ]; then rm ${AUTORUN_SCRIPT} -f; fi
    if [ -e ${FILE_AUTORUN_SERVICE} ]; then rm ${FILE_AUTORUN_SERVICE} -f; fi
    if [ -e ${AUTOLOGIN_CONF}".bak" ]; then mv ${AUTOLOGIN_CONF}".bak" ${AUTOLOGIN_CONF} -f; fi
    systemctl disable ${AUTORUN_SERVICE}
}


# create autostart service at startup
function autorun_service()
{
    # create auto startup script
    if [ -e ${AUTORUN_SCRIPT} ]; then
        rm -f ${AUTORUN_SCRIPT}
    fi

    cat >> ${AUTORUN_SCRIPT} << Autorunfile
#!/bin/bash 
rlt=1
while [ \$rlt -ne 0 ]
do
   if who | grep \\(:0\\);then
       rlt=\$?
   else who | grep \\(:1\\)
       rlt=\$?
   fi
   sleep 1
done
WAKE_ALAEM="/sys/class/rtc/rtc0/wakealarm"
chmod 666 \${WAKE_ALAEM}
echo 0 > \${WAKE_ALAEM} ; 
echo "# [INFO] \$0" >> /var/log/longsettings.log
`pwd`/longrun.sh --run
Autorunfile
    chmod +x ${AUTORUN_SCRIPT}


    if [ -e ${FILE_AUTORUN_SERVICE} ]; then
        rm -f ${FILE_AUTORUN_SERVICE}
    fi
    cat >> ${FILE_AUTORUN_SERVICE} << Autoexec
[Unit]
Description=CS2C Loop Run Test Service

[Service]
ExecStart=${AUTORUN_SCRIPT}
StandardOutput=syslog
Type=oneshot

[Install]
WantedBy=multi-user.target
Alias=cs2ctest.service
Autoexec
    chmod +x ${FILE_AUTORUN_SERVICE}
    systemctl enable ${AUTORUN_SERVICE} 
}


# create function of auto login
function auto_login()
{

    # get login user to do loop test
    if [ -e ${AUTOLOGIN_CONF} ]; then
        chmod 777 ${AUTOLOGIN_CONF} 
        mv -f -n ${AUTOLOGIN_CONF} ${AUTOLOGIN_CONF}".bak"
    fi
    cat >> ${AUTOLOGIN_CONF} << Autologin 
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=`logname`
Autologin
    chmod 777 ${AUTOLOGIN_CONF}
}


# s3 mode 
function test_s3()
{
    echo "# [INFO] $test_func total:$times_total" >> ${LONGRUN_LOG}
    while true; do
        times_loop=$(( $times_loop + 1 ))
        if [ $times_loop -gt $times_total ]
        then
            break
        fi
        notify-send  -t `expr $time_waiting \* 1000` -a -u "Longrun: ${test_func}" "[INFO] total: ${times_total} \n[INFO] cur: ${times_loop}"
        sleep $time_waiting

        echo "# [INFO] ${test_func} #total:${times_total} #loop:${times_loop}" >> ${LONGRUN_LOG}
        sed -i "s/^TIMES_LOOP=[0-9]*$/TIMES_LOOP=${times_loop}/g" ${LONGRUN_CONF} &>/dev/null
        /sbin/rtcwake -s $timeout_running -m mem >> ${LONGRUN_LOG}
    done 
    echo "# [INFO] ${test_func}test completely!" >> ${LONGRUN_LOG}
    notify-send  -t `expr $time_waiting \* 1000` -a -u "Longrun: ${test_func}" "[INFO] ${test_func}test completely!"
}


# s4 mode 
function test_s4()
{
    echo "# [INFO] $test_func total:$times_total" >> ${LONGRUN_LOG}
    while true; do
        times_loop=$(( $times_loop + 1 ))
        if [ $times_loop -gt $times_total ]
        then
            break
        fi
        notify-send  -t `expr $time_waiting \* 1000` -a -u "Longrun: ${test_func}" "[INFO] total: ${times_total} \n[INFO] cur: ${times_loop}"
        sleep $time_waiting

        echo "# [INFO] ${test_func} #total:${times_total} #loop:${times_loop}" >> ${LONGRUN_LOG}
        sed -i "s/^TIMES_LOOP=[0-9]*$/TIMES_LOOP=${times_loop}/g" ${LONGRUN_CONF} &>/dev/null
        /sbin/rtcwake -s $timeout_running -m disk >> ${LONGRUN_LOG}
    done 
    echo "# [INFO] ${test_func}test completely!" >> ${LONGRUN_LOG}
    notify-send  -t `expr $time_waiting \* 1000` -a -u "Longrun: ${test_func}" "[INFO] ${test_func}test completely!"
}


# reboot mode 
function test_reboot()
{
    if ! grep "AutomaticLoginEnable=true" ${AUTOLOGIN_CONF} &>/dev/null
    then
        echo "# [INFO] create /etc/gdm/custom.conf" >> ${LONGRUN_LOG}
        auto_login 
    fi

    if [ ! -e ${FILE_AUTORUN_SERVICE} ]; then
        echo "# [INFO] create autorun service" >> ${LONGRUN_LOG}
        autorun_service
    fi

    times_loop=`grep 'TIMES_LOOP' ${LONGRUN_CONF} | sed -r 's/TIMES_LOOP=//'`
    if [ "${times_loop}" -eq "0" ]; then
        echo "# [INFO] ${test_func} total:${times_total}"  >> ${LONGRUN_LOG}
    elif [ "$times_loop" -eq "$times_total" ]; then
        echo "# [INFO] ${test_func} total:${times_total} loop:${times_loop}"  >> ${LONGRUN_LOG}
        echo "# [INFO] Test completely!" >> ${LONGRUN_LOG}
        notify-send  -t `expr $time_waiting \* 1000` -a -u "Longrun: ${test_func}" "[INFO] ${test_func}test completely!"
        exit 0;
    fi

    times_loop=$(( $times_loop + 1 ))
    notify-send  -t `expr $time_waiting \* 1000` -a -u "Longrun: ${test_func}" "[INFO] total: ${times_total} \n[INFO] cur: ${times_loop}"
    sleep $time_waiting
    echo "# [INFO] ${test_func} total:${times_total} loop:${times_loop}"  >> ${LONGRUN_LOG}
    sed -i "s/^TIMES_LOOP=[0-9]*$/TIMES_LOOP=${times_loop}/g" ${LONGRUN_CONF} &>/dev/null
    sleep 2; /sbin/reboot -f &>/dev/null
}


# shutdown mode 
function test_shutdown()
{
    times_loop=`grep 'TIMES_LOOP' ${LONGRUN_CONF} | sed -r 's/TIMES_LOOP=//'`
    if [ "${times_loop}" -eq "0" ]; then
        echo "# [INFO] ${test_func} total:${times_total}"  >> ${LONGRUN_LOG}
    elif [ "$times_loop" -eq "$times_total" ]; then

        echo "# [INFO] ${test_func} total:${times_total} loop:${times_loop}"  >> ${LONGRUN_LOG}
        echo "# [INFO] Test success!" >> ${LONGRUN_LOG}
        notify-send  -t `expr $time_waiting \* 1000` -a -u "Longrun: ${test_func}" "[INFO] ${test_func}test completely!"
        exit 0;
    fi

    if ! grep "AutomaticLoginEnable=true" ${AUTOLOGIN_CONF} &>/dev/null
    then
        echo "# [INFO] create /etc/gdm/custom.conf" >> ${LONGRUN_LOG}
        auto_login 
    fi

    if [ ! -e ${FILE_AUTORUN_SERVICE} ]; then
        echo "# [INFO] create autorun service" >> ${LONGRUN_LOG}
        autorun_service
    fi

    #if [ $times_loop -ge $times_total ]
    #then
    #    echo "# [INFO] disable autorun service" >> ${LONGRUN_LOG}
    #    systemctl disable ${AUTORUN_SERVICE}
    #    exit 0 
    #fi
    #echo "##### dmesg start #####" >> ${LONGRUN_LOG}
    #/bin/dmesg >> ${LONGRUN_LOG}
    #echo "##### dmesg end #####" >> ${LONGRUN_LOG}
    times_loop=$(( $times_loop + 1 ))
    notify-send  -t `expr $time_waiting \* 1000` -a -u "Longrun: ${test_func}" "[INFO] total: ${times_total} \n[INFO] cur: ${times_loop}"
    sleep $time_waiting
    echo "# [INFO] ${test_func} total:${times_total} loop:${times_loop}"  >> ${LONGRUN_LOG}
    sed -i "s/^TIMES_LOOP=[0-9]*$/TIMES_LOOP=${times_loop}/g" ${LONGRUN_CONF} &>/dev/null

    chmod 666 ${WAKE_ALAEM}; echo 0 > ${WAKE_ALAEM} ;
    echo "+${timeout_running} seconds" > ${WAKE_ALAEM} ; sleep 2
    /sbin/poweroff -f &>/dev/null
}


# main #
if [ $UID -ne 0 ];then
    echo "# [ERROR] Please switch to root before running this program." 
    exit 2
fi


if [ "$1" == "--reset" ]; then
    clean_settings_file_and_log
    exit 0
elif [ "$1" == "--run" ]; then
    echo "# [INFO] Start to long run ..."
else
    echo "$0 [Options]"
    echo " --reset, clean all message and retrieve to original status."
    echo " --run, start to longrun test."
    exit 1
fi


if [ -e ${LONGRUN_CONF} ];then
    test_func=`grep 'FUNC' ${LONGRUN_CONF} | sed -r 's/FUNC=//'`
    times_total=`grep 'TIMES_TOTAL' ${LONGRUN_CONF} | sed -r 's/TIMES_TOTAL=//'`
else
    mkdir -p ${DIR_TMP_LONGRUN} 
    if [ ! -e ${LONGRUN_LOG} ]; then
        touch ${LONGRUN_LOG}
        chmod 666 ${LONGRUN_LOG}
    fi
    echo "# [INFO] create dir \"${DIR_TMP_LONGRUN}\"" >> ${LONGRUN_LOG}

    cat >> ${LONGRUN_CONF} << fileconf
FUNC=
TIMES_TOTAL=0
TIMES_LOOP=0
fileconf
    chmod 666 ${LONGRUN_CONF}
    printf "\n# [INFO] Please choose task as follow: \n*) S3\n*) S4\n*) Reboot \n*) Shutdown\nanswer:"
    read test_func 
fi


while true; do
    if !([ "$test_func" = "S3" ] || [ "$test_func" = "S4" ] || [ "$test_func" = "Reboot" ] || [ "$test_func" = "Shutdown" ]);    then
        echo "# [ERROR] Please confirm and re-input."
    else
        echo "# [INFO] test_func:${test_func}" >> ${LONGRUN_LOG}
        sed -i "s/^FUNC=*$/FUNC=${test_func}/g" ${LONGRUN_CONF}
        break
    fi
    printf "# [INFO] Please choose task as follow: \n*) S3\n*) S4\n*) Reboot \n*) Shutdown\nanswer:"
    read test_func 
done


while true; do
    times_total=$(( $times_total + 0 ))
    if [ $times_total -gt 0 ]; then
       sed -i "s/^TIMES_TOTAL=[0-9]*$/TIMES_TOTAL=${times_total}/g" ${LONGRUN_CONF}
       break
    fi
    printf "# [INFO] Please input test times:"
    read times_total 
done


if [ "$test_func" = "S3" ]
then
    test_s3
elif [ "$test_func" = "S4" ]
then
    test_s4
elif [ "$test_func" = "Reboot" ]
then
    test_reboot
elif [ "$test_func" = "Shutdown" ]
then
    test_shutdown
else
    echo "# [INFO] ALL is well !" 
fi
