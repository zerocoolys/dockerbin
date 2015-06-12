#!/bin/bash

IMG_NAME=elasticsearch:v1

MASTER_MEM=16g
QUERY_MEM=16g
DATA_MEM=32g

MASTER_NUM=( 0 1)
MASTER_HTTP=2920
MASTER_NODE=2930

QUERY_NUM=( 0 1 )
QUERY_HTTP=3000
QUERY_NODE=3010

DATA_NUM=( 0 1 2 3 )
DATA_HTTP=2950
DATA_NODE=2960

HOST=172.17.42.1
TARGET_UP=211.99.254.181
UNICAST_HOSTS=():

join(){
  local IFS="$1";
  shift;
  echo "$*";
}


#all_nodes
#docker run -d -p 29300:29300 -p 29200:29200 -v /usr/local/elasticsearch/master/:/usr/local/elasticsearch/config -v /es/master1/:/data -e ES_MIN_MEM=16g -e ES_MAX_MEM=16g elasticsearch:v1 /start.sh
init_unicast(){
  total=0
  for idx in "${MASTER_NUM[@]}";
  do
    UNICAST_HOSTS[${total}]=${HOST}:${MASTER_NODE}${idx}
    total=$(expr ${total} + 1)
  done
    
  for idx in "${QUERY_NUM[@]}";
        do
                UNICAST_HOSTS[${total}]=${HOST}:${QUERY_NODE}${idx}
                total=$(expr ${total} + 1)
        done
       
  for idx in "${DATA_NUM[@]}";
        do
                UNICAST_HOSTS[${total}]=${HOST}:${DATA_NODE}${idx}
                total=$(expr ${total} + 1)
        done
}

start_all_nodes(){
  start_masters
  start_querys
  start_datas
}

start_masters(){
  
  for idx in "${MASTER_NUM[@]}";
  do
    start_node master${idx}
  done
}

start_datas(){
  for idx in "${DATA_NUM[@]}";
  do
    start_node data${idx}
  done
}

start_querys(){
  for idx in "${QUERY_NUM[@]}";
  do
    start_node query${idx}
  done
}

start_node(){
  docker start $1
}


ARRAY=()


run_nodes(){
  stop_all_nodes

  run_masters
  run_datas
  run_querys
}

run_masters(){
  ROLE=master
  ARRAY=( ${MASTER_NUM[@]} )
  loop_nodes 0 ${ROLE} ${MASTER_HTTP} ${MASTER_NODE} ${MASTER_MEM}

}

run_querys(){
  ROLE=query
  ARRAY=( ${QUERY_NUM[@]} )
  loop_nodes 0 ${ROLE} ${QUERY_HTTP} ${QUERY_NODE} ${QUERY_MEM}
}

run_datas(){
  ROLE=data
  ARRAY=( ${DATA_NUM[@]} )
  loop_nodes 0 ${ROLE} ${DATA_HTTP} ${DATA_NODE} ${DATA_MEM}
}

# {1,2,3.....} {master|query|data} {2920} {2930} {16g|32g}
loop_nodes(){
  ROLE=$2
  HTTP=$3
  NODE=$4
  MEM=$5
  for idx in ${ARRAY[@]}
  do
    run_node ${ROLE}${idx} ${ROLE} ${HTTP}${idx} ${NODE}${idx} ${MEM}
  done
}


# run node by parameter
# {nodename} {master|lb|data} {http_port} {node_port} 
run_node(){
  NODE_NAME=$1
  NODE_ROLE=$2
  HOST_HTTP_PORT=$3
  HOST_NODE_PORT=$4
  MEM_SIZE=$5
  
  CMD="docker run -d --name ${NODE_NAME} -p ${HOST_HTTP_PORT}:29200 -p ${HOST_NODE_PORT}:29300 -v /usr/local/elasticsearch/${NODE_ROLE}/:/usr/local/elasticsearch/config -v /es/${NODE_NAME}:/data -e ES_MIN_MEM=${MEM_SIZE} -e ES_MAX_MEM=${MEM_SIZE} -e NODE_NAME=${NODE_NAME} -e UNICAST_HOSTS=${UNICAST_HOSTS_STR} ${IMG_NAME} /start.sh"


  echo 'Now running:' ${NODE_NAME}
  docker rm ${NODE_NAME}
  ${CMD}

  sleep 20
}

stop_all_nodes(){
  curl -XPOST 'http://211.99.254.181:29200/_cluster/nodes/_all/_shutdown'
  stop_masters
  sleep 10
  stop_datas
  sleep 10
  stop_querys
}

stop_masters(){
  
  for idx in "${MASTER_NUM[@]}";
  do
    stop_nodes master${idx}
  done
}

stop_datas(){
  for idx in "${DATA_NUM[@]}";
  do
    stop_nodes data${idx}
  done
}

stop_querys(){
  for idx in "${QUERY_NUM[@]}";
  do
    stop_nodes query${idx}
  done
}
stop_nodes(){
  docker stop $1
}


case $1 in
  run)
    init_unicast
    UNICAST_HOSTS_STR=`join , ${UNICAST_HOSTS[@]}`
    #echo $UNICAST_HOSTS_STR
    run_nodes
    exit 0
  ;;
  start)
    start_all_nodes
    exit 0
  ;;
  stop)
    stop_all_nodes
    exit 0
  ;;
  start_master)
    init_unicast
    UNICAST_HOSTS_STR=`join , ${UNICAST_HOSTS[@]}`
    #echo $UNICAST_HOSTS_STR
    start_masters
    exit 0
  ;;
  start_querys)
    init_unicast
    UNICAST_HOSTS_STR=`join , ${UNICAST_HOSTS[@]}`
    #echo $UNICAST_HOSTS_STR
    start_querys
    exit 0
  ;;
  start_datas)
    init_unicast
    UNICAST_HOSTS_STR=`join , ${UNICAST_HOSTS[@]}`
    #echo $UNICAST_HOSTS_STR
    start_datas
    exit 0
  ;;
  stop_masters)
    stop_masters
    exit 0
  ;;
  stop_querys)
    stop_querys
    exit 0
  ;;
  stop_datas)
    stop_datas;
    exit 0
  ;;
esac