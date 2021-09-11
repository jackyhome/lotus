#!/bin/bash
checkTimer=5
disableWaiteRound=2 #disable时的额外等待次数

fn_check_p1="sc-02-data-layer-1.dat"
fn_check_p2="sc-02-data-tree-c-0.dat"

function start_check() {
    pc1_limit=$pc1Limit
    pre_pc1_num=0
    for ((i=1; i > 0; i++))
    do
        taskList=`lotus-worker info |grep Task`

        p1_count=`find ${LOTUS_WORKER_PATH}/cache -name ${fn_check_p1} |wc -l`
        p2_count=`find ${LOTUS_WORKER_PATH}/cache -name ${fn_check_p2} |wc -l`
        p1_running_count=$(expr ${p1_count} - ${p2_count})

        if [[ ${pre_pc1_num} -eq 0 ]]
        then
            pre_pc1_num=$p1_running_count
        fi

        if [[ ${pre_pc1_num} -lt ${p1_running_count} ]]
        then
            lotus-worker tasks disable PC1
            pre_pc1_num=$p1_running_count
            echo "New PC1 running count: ${pre_pc1_num}, wait for ${disableWaiteRound} round..." >> ${logFile}
            sleep $((checkTimer * disableWaiteRound))m
            if [[ ${p1_running_count} -lt ${pc1_limit} ]]
            then
                lotus-worker tasks enable PC1
                echo "Enable PC1 again..." >> ${logFile}
            fi
        fi

        echo "[PC1] running count: ${p1_running_count}, [PC2] running count: ${p2_count}" >> ${logFile}

        if [[ ${taskList} =~ "PC1" ]]
        then
            if [ ${p1_running_count} -ge ${pc1_limit} ]
            then
                lotus-worker tasks disable PC1
                echo "PC1 disabled! Will sleep for $((checkTimer * disableWaiteRound)) minutes" >> ${logFile}
                sleep $((checkTimer * disableWaiteRound))m
            fi
        elif [ ${p1_running_count} -lt ${pc1_limit} ]
        then
            lotus-worker tasks enable PC1
            echo "PC1 enabled!" >> ${logFile}
        fi

        sleep ${checkTimer}m
    done
}


function helpFunction()
{
   echo ""
   echo "命令用法: $0 --port workerPort --limit pc1Limit [--type optType]"
   echo "    -p --port 端口"
   echo "    -l --limit PC1限制数"
   echo "    -t --type 启动类型(start|stop)"
   exit 1 # Exit script after printing help
}

optType="start"
while true
do
    case $1 in
    -p|--port)
        shift
        export workerPort=$1
        ;;
    -l|--limit)
        shift
        export pc1Limit=$1
        ;;
    -t|--type)
        shift
        export optType=$1
        ;;
    *)
        shift
        break
        ;;
    esac
shift
done

# Print helpFunction in case parameters are empty
if [ -z "$workerPort" ] || [ -z "$pc1Limit" ] || [ -z "$optType" ]
then
   helpFunction
fi

# Begin script in case all parameters are correct


export LOTUS_WORKER_PATH=lotus-worker/worker-$workerPort
logFile=task_check_${workerPort}_$(date +%Y%m%d_%H).log
if [ -d $LOTUS_WORKER_PATH ]
then
    if [ "$optType" == "start" ]
    then
        echo "为${workerPort}开启检查程序...限制PC1个数为${pc1Limit}."
	mv task_check_$workerPort*.log check-logs/.

	echo "为${workerPort}开启检查程序...限制PC1个数为${pc1Limit}." >> $logFile
        lotus-worker info >> $logFile
        echo "Log: $logFile"

        start_check
    elif [ "$optType" == "stop" ]
    then
        kill `ps -ef |grep task_helper |grep ${workerPort} |grep -v grep |awk -F' ' '{ print $2 }'`
    else
        helpFunction
    fi
else
    echo "参数${workerPort}不对，目录${LOTUS_WORKER_PATH}不存在。"
fi
