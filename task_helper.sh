#!/bin/bash
dirLimit=65
dirStartLimit=60

checkTimer=5
pc1_limit=10

fn_check_p1="sc-02-data-layer-1.dat"
fn_check_p2="sc-02-data-tree-c-0.dat"

function start_check() {
    for ((i=1; i > 0; i++))
    do
        taskList=`lotus-worker info |grep Task`

#		workerDirSize=`df -h lotus-worker |tail -1 |awk -F' ' '{ print $5 }' |awk -F'%' '{ print $1 }'`
#		if [ $workerDirSize -gt $dirLimit ] && [ $pc2Exist -gt 0 ]
#		then
#			lotus-worker tasks disable PC2
#			echo "[${i}] Disable PC2...`date`, 磁盘用量${workerDirSize}%" >> $logFile
#		elif [ $workerDirSize -lt $dirStartLimit ] && [ $pc2Exist -eq 0 ]
#		then
#			lotus-worker tasks enable PC2
 #                       echo "[${i}] Enable PC2...`date`, 磁盘用量${workerDirSize}%" >> $logFile
#		fi

        p1_count=`find ${LOTUS_WORKER_PATH} -name ${fn_check_p1} |wc -l`
        p2_count=`find ${LOTUS_WORKER_PATH} -name ${fn_check_p2} |wc -l`
        p1_running_count=$(expr ${p1_count} - ${p2_count})
        echo "[PC1] running count: ${p1_running_count}, [PC2] running count: ${p2_count}"

        if [[ ${taskList} =~ "PC1" ]]
        then
            if [ ${p1_running_count} -ge ${pc1_limit} ]
            then
                lotus-worker tasks disable PC1
                echo "PC1 disabled!"
            fi
        elif [ ${p1_running_count} -lt ${pc1_limit} ]
        then
            lotus-worker tasks enable PC1
            echo "PC1 enabled!"
        fi

        sleep ${checkTimer}m
    done
}

workerPort=$1
export LOTUS_WORKER_PATH=lotus-worker/worker-$workerPort
logFile=task_check_${workerPort}_$(date +%Y%m%d_%H).log
if [ -d $LOTUS_WORKER_PATH ]
then
    if [ "$2" == "start" ]
    then
        echo "Check start..."
        mv task_check_$workerPort*.log check-logs/.
        lotus-worker info >> $logFile
        echo "Log: $logFile"

        start_check
    elif [ "$2" == "stop" ]
    then
        kill `ps -ef |grep task_helper |grep ${workerPort} |grep -v grep |awk -F' ' '{ print $2 }'`
    else
        echo "命令用法："
        echo "./task_helper.sh [port] start|stop"
    fi
else
    echo "参数${workerPort}不对，目录${LOTUS_WORKER_PATH}不存在。"
fi