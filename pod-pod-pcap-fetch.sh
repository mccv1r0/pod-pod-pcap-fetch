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
    printf "\nCompleted TCPDump\n"
    pkill -P $$
    
    # Collect PCAPs
    echo "Collecting PCAPs"

    if [ "$allNodes" != \"FALSE\" ];
    then
	for pod in $(oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI get pods -l app=tcpdump-retrieve -o jsonpath='{range@.items[*]}{.metadata.name}{"\n"}{end}');
	do
	    oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI exec $pod -- bash -c 'tcpdump -nn -e --number -s 512 -XX -vvv -r /tmp/tcpdump_pcap/tcpdump-"$0".pcap > /tmp/tcpdump_pcap/tcpdump-"$0".out' $pod 
	    echo "*** tcpdump for ${pod} done";
	    oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI exec $pod -- tar czvf /tmp/tcpdump-${pod}.tgz /tmp/tcpdump_pcap/
	    echo "*** create tcpdump-${pod}.tgz completed";
	    oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI cp $pod:/tmp/tcpdump-${pod}.tgz ./tcpdump-${pod}.tgz
	    echo "*** copy of tcpdump-${pod}.tgz to local directory completed";
	    oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI exec $pod -- rm -rdf /tmp/tcpdump_pcap/
	done
    fi

    if [ "$podOne" != \"NONE\" ]; then
	oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI exec $capturePod1 -- bash -c 'tcpdump -nn -e --number -s 512 -XX -vvv -r /tmp/tcpdump_pcap/tcpdump-"$0".pcap > /tmp/tcpdump_pcap/tcpdump-"$0".out' $podOne 
	echo "*** tcpdump for pod 1 done";
	oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI exec $capturePod1 -- tar czvf /tmp/tcpdump-$podOne.tgz /tmp/tcpdump_pcap/
	echo "*** create tcpdump-$podOne.tgz completed";
	oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI cp $capturePod1:/tmp/tcpdump-$podOne.tgz ./tcpdump-$podOne.tgz
	echo "*** copy of tcpdump-$podOne.tgz to local directory completed";
    fi

    if [ "$podTwo" != \"NONE\" ]; then
	oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI exec $capturePod2 -- bash -c 'tcpdump -nn -e --number -s 512 -XX -vvv -r /tmp/tcpdump_pcap/tcpdump-"$0".pcap > /tmp/tcpdump_pcap/tcpdump-"$0".out' $podTwo 
	echo "*** tcpdump for pod 2 done";
	oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI exec $capturePod2 -- tar czvf /tmp/tcpdump-$podTwo.tgz /tmp/tcpdump_pcap/
	echo "*** create tcpdump-$podTwo.tgz completed";
	oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI cp $capturePod2:/tmp/tcpdump-$podTwo.tgz ./tcpdump-$podTwo.tgz
	echo "*** copy of tcpdump-$podTwo.tgz to local directory completed";
    fi

    CAPTURE=0;

    # clean up 
    if [ "$podOne" != \"NONE\" ]; then
	oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI exec $capturePod1 -- rm -rdf /tmp/tcpdump_pcap/
    fi
    if [ "$podTwo" != \"NONE\" ]; then
	oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI exec $capturePod2 -- rm -rdf /tmp/tcpdump_pcap/
    fi

    if [ "$nameSpaceCNI" == "openshift-ovn-kubernetes" ];
    then
	oc --kubeconfig $kubeconfig delete -f ./manifests/tcpdump-retrieve-daemonset-ovn.yaml
    else
	oc --kubeconfig $kubeconfig delete -f ./manifests/tcpdump-retrieve-daemonset-sdn.yaml
    fi 
}
trap term SIGTERM SIGINT


#echo "----------------------------------------------------------"
#echo "Find out what traffic to capture"
#echo "----------------------------------------------------------"

if [ $# -eq 0 ]; then 
      printf "Error: no argments supplied\n"
      exit 0
fi

while [ $# -gt 0 ]; do
  case "$1" in
    -k|--kubeconfig)
      kubeconfigIn="$2"
      ;;
    -p1|--podOne)
      podOneIn="$2"
      ;;
    -p2|--podTwo)
      podTwoIn="$2"
      ;;
    -nsCni|--namespaceCni)
      nameSpaceCniIn="$2"
      ;;
    -n1|--namespaceOne)
      nameSpace1In="$2"
      ;;
    -n2|--namespaceTwo)
      nameSpace2In="$2"
      ;;
    -pa|--pcapArgs)
      pcapArgsIn="$2"
      ;;
    -pf|--pcapFilter)
      pcapFilterIn="$2"
      ;;
    -all|--allNodes)
      allNodesIn="$2"
      ;;
    -h|--usage)
      printf "pod-pod-pcap-fetch.sh \n"
      printf "    parameters (in any order) \n"
      printf -- "        -k|--kubeconfig: path to kubeconfig if $KUBECONFIG env isn't set\n"
      printf -- "       -p1|--podOne: name of first pod \n"
      printf -- "       -n1|--namespaceOne: namespace of first pod (default: \"default\")\n"
      printf -- "       -p2|--podTwo: second Podname \n"
      printf -- "       -n2|--namespaceTwo: namespace of second pod (default: \"default\") \n"
      printf -- "    -nsCni|--namespaceCni: namespace used by OCP CNI (default: \"openshift-ovn-kubernetes\") \n"
      printf -- "       -pa|--pcapArgs: arguments to tcpdump (default: \"-nn -e --number -U -s 512 -i any\") \n"
      printf -- "       -pf|--pcapFilter: tcpdump filter (default: \"host <ip of podOne> and host <ip of podTwo>\") \n"
      printf -- "      -all|--allNodes: capture pcapArgs and pcapFilter on all nodes; not just where podOne and podTwo run\n"
      printf -- "        -h|--usage: This usage message \n"
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

if [[ -z "${KUBECONFIG}" ]]; then
    kubeconfig=${kubeconfigIn:-"/tmp/kubeconfig"}
else
    kubeconfig="${KUBECONFIG}"
fi

allNodes=${allNodesIn:-\"FALSE\"}
podOne=${podOneIn:-\"NONE\"}
podTwo=${podTwoIn:-\"NONE\"}
nameSpaceOne=${nameSpace1In:-"default"}
nameSpaceTwo=${nameSpace2In:-"default"}
nameSpaceCNI=${nameSpaceCniIn:-"openshift-ovn-kubernetes"}

#
# We need at least podOne unless we will capture on all nodes
#
if [ "$allNodes" == \"FALSE\" ];
then
    if [ "$podOne" == \"NONE\" ]; then
	echo "podOne must be supplied";
	exit 1
    fi
fi

echo "Using kubeconfig $kubeconfig"

echo "----------------------------------------------------------"
echo "Starting daemonsets"
echo "----------------------------------------------------------"

if [ "$nameSpaceCNI" == "openshift-ovn-kubernetes" ];
then
    oc --kubeconfig $kubeconfig apply -f ./manifests/tcpdump-retrieve-daemonset-ovn.yaml
else
    oc --kubeconfig $kubeconfig apply -f ./manifests/tcpdump-retrieve-daemonset-sdn.yaml
fi
if [ $? != 0 ]
then
    echo "error: failed to start daemonsets"
    exit 1
fi

echo "----------------------------------------------------------"
echo "Don't do anything until daemonset images pulled and running."
echo "----------------------------------------------------------"

waitingToStart=1;
while [ "$waitingToStart" -eq 1 ];
do
    podList=$(oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI get pods -l app=tcpdump-retrieve --field-selector=status.phase!=Running --output=jsonpath={.items..metadata.name});

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

if [ "$podOne" != \"NONE\" ]; then
    echo "podOne is: " ${podOne} " in namespace " ${nameSpaceOne}
    clientIP=$(oc --kubeconfig $kubeconfig --namespace $nameSpaceOne get pod $podOne -o jsonpath='{.status.podIP}')
    echo "clientIP is " ${clientIP};
fi

if [ "$podTwo" != \"NONE\" ]; then
    echo "podTwo is: " ${podTwo} " in namespace " ${nameSpaceTwo}
    serverIP=$(oc --kubeconfig $kubeconfig --namespace $nameSpaceTwo get pod $podTwo -o jsonpath='{.status.podIP}')
    echo "serverIP is " ${serverIP};
fi

# find nodes where pods run
prefix="NODE ";

if [ "$podOne" != \"NONE\" ]; then
    podNode1=$(oc --kubeconfig $kubeconfig --namespace $nameSpaceOne get pod $podOne -o=custom-columns=NODE:.spec.nodeName)
    podNode1=$(echo $podNode1|tr -d '\n');
    podNode1=${podNode1#$prefix};
    echo "$podOne is on node: $podNode1"; 
fi

if [ "$podTwo" != \"NONE\" ]; then
    podNode2=$(oc --kubeconfig $kubeconfig --namespace $nameSpaceTwo get pod $podTwo -o=custom-columns=NODE:.spec.nodeName)
    podNode2=$(echo $podNode2|tr -d '\n');
    podNode2=${podNode2#$prefix};
    echo "$podTwo is on node: $podNode2"; 
fi

#
# Find the tcpdump pod on these nodes
#
for pod in $(oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI get pods -l app=tcpdump-retrieve -o jsonpath='{range@.items[*]}{.metadata.name}{"\n"}{end}');
do 
    # echo $pod;
    nodeName=$(oc --kubeconfig $kubeconfig -n $nameSpaceCNI get pod $pod -o=custom-columns=NODE:.spec.nodeName)
    nodeName=$(echo $nodeName|tr -d '\n');
    # prefix="NODE ";
    nodeName=${nodeName#$prefix};
    # echo $nodeName;

    if [ "$podOne" != \"NONE\" ]; then
	if [ "$nodeName" == "$podNode1" ]; then
	    capturePod1=$pod
	    echo "$podOne capture is being performed on host pod $capturePod1"
	fi
    fi
    
    if [ "$podTwo" != \"NONE\" ]; then
	if [ "$nodeName" == "$podNode2" ]; then
	    capturePod2=$pod
	    echo "$podTwo capture is being performed on host pod $capturePod2"
	fi
    fi
done


echo "----------------------------------------------------------"
echo "Starting the pcaps. These will run until failure of killed."
echo "  Kill with Crtl + C to copy back the contents"
echo "----------------------------------------------------------"

pcapArgs=${pcapArgsIn:-" -nn -e --number -U -s 512 -i any"}

#
# Determine if we were told to capture on all nodes on only nodes of
#  specific pod(s)
#
if [ "$allNodes" == \"FALSE\" ];
then
    if [ "$podTwo" != \"NONE\" ];
    then
	if [ "$nameSpaceCNI" == "openshift-ovn-kubernetes" ];
	then
	    pcapFilter=${pcapFilterIn:-" 'host $clientIP and host $serverIP or \(geneve and host $clientIP and host $serverIP\)'"}
	else
	    pcapFilter=${pcapFilterIn:-" host $clientIP and host $serverIP"}
	fi
    else
	if [ "$nameSpaceCNI" == "openshift-ovn-kubernetes" ];
	then
	    pcapFilter=${pcapFilterIn:-" 'host $clientIP' or \(geneve and host $clientIP\)'"}
	else
	    pcapFilter=${pcapFilterIn:-" host $clientIP"}
	fi
    fi

    if [ "$podOne" != \"NONE\" ]; then
	cmd1="tcpdump"
	cmd1="${cmd1} -w /tmp/tcpdump_pcap/tcpdump-${podOne}.pcap"
	cmd1="${cmd1} -U ${pcapArgs}"
	cmd1="${cmd1} ${pcapFilter}"
	echo "Command 1 is: ${cmd1}"
    fi
    
    if [ "$podTwo" != \"NONE\" ]; then
	cmd2="tcpdump"
	cmd2="${cmd2} -w /tmp/tcpdump_pcap/tcpdump-${podTwo}.pcap"
	cmd2="${cmd2} -U ${pcapArgs}"
	cmd2="${cmd2} ${pcapFilter}"
	echo "Command 2 is: ${cmd2}"
    fi
else
    pcapFilter=${pcapFilterIn:-""} 
    
    for pod in $(oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI get pods -l app=tcpdump-retrieve -o jsonpath='{range@.items[*]}{.metadata.name}{"\n"}{end}');
    do 
	# echo $pod;
	nodeName=$(oc --kubeconfig $kubeconfig -n $nameSpaceCNI get pod $pod -o=custom-columns=NODE:.spec.nodeName)
	nodeName=$(echo $nodeName|tr -d '\n');
	# prefix="NODE ";
	nodeName=${nodeName#$prefix};
	# echo $nodeName;

	cmd="tcpdump"
	cmd="${cmd} -U ${pcapArgs}"
	cmd="${cmd} -w /tmp/tcpdump_pcap/tcpdump-${pod}.pcap"
	cmd="${cmd} ${pcapFilter}"
	echo "Command is: ${cmd}"	
	
	oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI exec $pod -- mkdir -p /tmp/tcpdump_pcap 
	oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI exec $pod -- /bin/bash -c "eval ${cmd}" & 
	# capAllpid=$!
	# echo "capAllpid is ${capAllpid}"
	done
fi

# run tcpdump -i any using podIPs as filters (if supplied).
# only need to run on nodes where supplied pods are running.

if [ "$allNodes" == \"FALSE\" ];
then
    if [ "$podOne" != \"NONE\" ]; then
	oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI exec $capturePod1 -- mkdir -p /tmp/tcpdump_pcap 
	oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI exec $capturePod1 -- /bin/bash -c "eval ${cmd1}" & 
	cap1pid=$!
	echo "cap1pid is ${cap1pid}"
    fi
    
    if [ "$podTwo" != \"NONE\" ]; then
	oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI exec $capturePod2 -- mkdir -p /tmp/tcpdump_pcap 
	oc --kubeconfig $kubeconfig --namespace $nameSpaceCNI exec $capturePod2 -- /bin/bash -c "eval ${cmd2}" & 
	cap2pid=$!
	echo "cap2pid is ${cap2pid}"
    fi
fi

# Now just wait for ctrl-c
keepalive;
