#!/bin/bash

CAPTURE=1;

# Keepalive is to avoid stale/timout issues with `oc debug/exec` requests
keepalive() {
    while [ "$CAPTURE" -eq 1 ]; do
        sleep 1
        echo -n .
    done
    echo "Finished"
}

term() {
    echo "Completed TCPDump"
    pkill -P $$
    
    # Collect PCAPs
    echo "Collecting PCAPs"

    # oc --kubeconfig /tmp/kubeconfig --namespace openshift-ovn-kubernetes exec $capturePod1 -- tcpdump -nn -vvv -r /tmp/tcpdump_pcap/tcpdump-$podOne.pcap > /tmp/tcpdump_pcap/tcpdump-$podOne.out 
    oc --kubeconfig /tmp/kubeconfig --namespace openshift-ovn-kubernetes exec $capturePod1 -- bash -c 'tcpdump -nn -vvv -r /tmp/tcpdump_pcap/tcpdump-"$0".pcap > /tmp/tcpdump_pcap/tcpdump-"$0".out' $podOne 
    echo "*** tcpdump for pod 1 done";
    oc --kubeconfig /tmp/kubeconfig --namespace openshift-ovn-kubernetes exec $capturePod1 -- tar czvf /tmp/tcpdump-$podOne.tgz /tmp/tcpdump_pcap/
    echo "*** create tarball for pod 1 done";
    oc --kubeconfig /tmp/kubeconfig --namespace openshift-ovn-kubernetes cp $capturePod1:/tmp/tcpdump-$podOne.tgz ./tcpdump-$podOne.tgz
    # oc --kubeconfig /tmp/kubeconfig --namespace openshift-ovn-kubernetes exec $capturePod1 -- cat /tmp/tcpdump-$podOne.tgz > ./local-tcpdump-$podOne.tgz
    echo "*** copy for pod 1 done";

    # oc --kubeconfig /tmp/kubeconfig --namespace openshift-ovn-kubernetes exec $capturePod2 -- tcpdump -nn -vvv -r /tmp/tcpdump_pcap/tcpdump-$podTwo.pcap > /tmp/tcpdump_pcap/tcpdump-$podTwo.out
    oc --kubeconfig /tmp/kubeconfig --namespace openshift-ovn-kubernetes exec $capturePod2 -- bash -c 'tcpdump -nn -vvv -r /tmp/tcpdump_pcap/tcpdump-"$0".pcap > /tmp/tcpdump_pcap/tcpdump-"$0".out' $podTwo 
    echo "*** tcpdump for pod 2 done";
    oc --kubeconfig /tmp/kubeconfig --namespace openshift-ovn-kubernetes exec $capturePod2 -- tar czvf /tmp/tcpdump-$podTwo.tgz /tmp/tcpdump_pcap/
    echo "*** create tarball for pod 2 done";
    oc --kubeconfig /tmp/kubeconfig --namespace openshift-ovn-kubernetes cp $capturePod2:/tmp/tcpdump-$podTwo.tgz ./tcpdump-$podTwo.tgz
    # oc --kubeconfig /tmp/kubeconfig --namespace openshift-ovn-kubernetes exec $capturePod2 -- cat /tmp/tcpdump-$podTwo.tgz > ./local-tcpdump-$podTwo.tgz
    echo "*** copy for pod 2 done";

    CAPTURE=0;

    oc --kubeconfig /tmp/kubeconfig delete -f ./manifests/tcpdump-retrieve-daemonset-ovn.yaml
}
trap term SIGTERM SIGINT


echo "----------------------------------------------------------"
echo "Find out what traffic to capture"
echo "----------------------------------------------------------"

if [ $# -eq 0 ]; then 
      printf "Error: no argments supplied\n"
      exit 0
fi

while [ $# -gt 0 ]; do
  case "$1" in
    -p1|--podOne)
      podOneIn="$2"
      ;;
    -p2|--podTwo)
      podTwoIn="$2"
      ;;
    -n1|--namespaceOne)
      nameSpace1In="$2"
      ;;
    -n2|--namespaceTwo)
      nameSpace2In="$2"
      ;;
    -h|--usage)
      printf "pod-pod-pcap-fetch.sh \n"
      printf "    parameters (in any order) \n"
      printf -- "    -p1|--podOne: name of first pod \n"
      printf -- "    -n1|--namespaceOne: namespace of first pod (default: \"default\")\n"
      printf -- "    -p2|--podTwo: second Podname \n"
      printf -- "    -n2|--namespaceTwo: namespace of second pod (default: \"default\") \n"
      printf -- "     -h|--usage: This usage message \n"
      exit 1
      ;;
    *)
      printf "***************************\n"
      printf "* Error: Invalid argument.*\n"
      printf "***************************\n"
      exit 1
  esac
  shift
  shift
done

podOne=${podOneIn:-\"TODO\"}
podTwo=${podTwoIn:-\"TODO\"}
nameSpaceOne=${nameSpace1In:-"default"}
nameSpaceTwo=${nameSpace2In:-"default"}

if [ "$podOne" == \"TODO\" ]; then
    echo "podOne must be supplied";
    exit 1
fi
if [ "$podTwo" == \"TODO\" ]; then
    echo "podTwo must be supplied";
    exit 1
fi


echo "----------------------------------------------------------"
echo "Starting daemonsets"
echo "----------------------------------------------------------"

oc --kubeconfig /tmp/kubeconfig apply -f ./manifests/tcpdump-retrieve-daemonset-ovn.yaml

echo "----------------------------------------------------------"
echo "Don't do anything until daemonset images pulled and running."
echo "----------------------------------------------------------"

waitingToStart=1;
while [ "$waitingToStart" -eq 1 ];
do
    podList=$(oc --kubeconfig /tmp/kubeconfig --namespace openshift-ovn-kubernetes get pods -l app=tcpdump-retrieve --field-selector=status.phase!=Running --output=jsonpath={.items..metadata.name});

    if [[ -z $podList || $podList = "" ]]
    then
	waitingToStart=0;
	echo "Daemonsets Running";
    else
	echo "Waiting for " ${podList} "to become Ready...";
    fi

    sleep 1;
done

# get pod IP addresses we need to capture

echo "podOne is: " ${podOne} " in namespace " ${nameSpaceOne}
echo "podTwo is: " ${podTwo} " in namespace " ${nameSpaceTwo}

clientIP=$(oc --kubeconfig /tmp/kubeconfig --namespace $nameSpaceOne get pod $podOne -o jsonpath='{.status.podIP}')
serverIP=$(oc --kubeconfig /tmp/kubeconfig --namespace $nameSpaceTwo get pod $podTwo -o jsonpath='{.status.podIP}')

echo "clientIP is " ${clientIP};
echo "serverIP is " ${serverIP};

# find nodes where pods run
prefix="NODE ";

podNode1=$(oc --kubeconfig /tmp/kubeconfig --namespace $nameSpaceOne get pod $podOne -o=custom-columns=NODE:.spec.nodeName)
podNode1=$(echo $podNode1|tr -d '\n');
podNode1=${podNode1#$prefix};

echo "$podOne is on node: $podNode1"; 

podNode2=$(oc --kubeconfig /tmp/kubeconfig --namespace $nameSpaceTwo get pod $podTwo -o=custom-columns=NODE:.spec.nodeName)
podNode2=$(echo $podNode2|tr -d '\n');
podNode2=${podNode2#$prefix};

echo "$podTwo is on node: $podNode2"; 

#
# Find the tcpdump pod on these nodes
#
for pod in $(oc --kubeconfig /tmp/kubeconfig --namespace openshift-ovn-kubernetes get pods -l app=tcpdump-retrieve -o jsonpath='{range@.items[*]}{.metadata.name}{"\n"}{end}');
do 
    # echo $pod;
    nodeName=$(oc --kubeconfig /tmp/kubeconfig -n openshift-ovn-kubernetes get pod $pod -o=custom-columns=NODE:.spec.nodeName)
    nodeName=$(echo $nodeName|tr -d '\n');
    # prefix="NODE ";
    nodeName=${nodeName#$prefix};
    # echo $nodeName;

    if [ "$nodeName" == "$podNode1" ]; then
	capturePod1=$pod
    fi
    
    if [ "$nodeName" == "$podNode2" ]; then
	capturePod2=$pod
    fi    
done

echo "$podOne capture is being performed on host pod $capturePod1"
echo "$podTwo capture is being performed on host pod $capturePod2"

echo "----------------------------------------------------------"
echo "Starting the pcaps. These will run until failure of killed."
echo "  Kill with Crtl + C to copy back the contents"
echo "----------------------------------------------------------"

# run tcpdump -i any using podIPs as filters (if supplied).
# only need to run on nodes where supplied pods are running.
# TODO add filters "host $podOne and host $podTwo" 
oc --kubeconfig /tmp/kubeconfig --namespace openshift-ovn-kubernetes exec $capturePod1 -- mkdir -p /tmp/tcpdump_pcap 
oc --kubeconfig /tmp/kubeconfig --namespace openshift-ovn-kubernetes exec $capturePod1 -- tcpdump -nn --number -U -s 512 -i any -w /tmp/tcpdump_pcap/tcpdump-$podOne.pcap host $clientIP and host $serverIP & 
# oc --kubeconfig /tmp/kubeconfig --namespace openshift-ovn-kubernetes exec $capturePod1 -- tcpdump -nn --number -U -s 512 -i any -w /tmp/tcpdump_pcap/tcpdump-$podOne.pcap & 
cap1pid=$!

oc --kubeconfig /tmp/kubeconfig --namespace openshift-ovn-kubernetes exec $capturePod2 -- mkdir -p /tmp/tcpdump_pcap 
oc --kubeconfig /tmp/kubeconfig --namespace openshift-ovn-kubernetes exec $capturePod2 -- tcpdump -nn --number -U -s 512 -i any -w /tmp/tcpdump_pcap/tcpdump-$podTwo.pcap host $clientIP and host $serverIP & 
cap2pid=$!

# Now just wait for ctrl-c
keepalive;
