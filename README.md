# pod-pod-pcap-fetch

The pod-pod-pcap-fetch script will start daemonset with an image used to capture traffic between named pods.  
When you think you captured what you need, ctrl-c will stop the capture, create a tgz with the capture and copy them to your local directory.

Usage: 

./pod-pod-pcap-fetch.sh -h|--usage

```
$ ./pod-pod-pcap-fetch.sh --usage 
pod-pod-pcap-fetch.sh 
    parameters (in any order) 
        -k|--kubeconfig: path to kubeconfig if  env isn't set
       -p1|--podOne: name of first pod 
       -n1|--namespaceOne: namespace of first pod (default: "default")
       -p2|--podTwo: second Podname 
       -n2|--namespaceTwo: namespace of second pod (default: "default") 
    -nsCni|--namespaceCni: namespace used by OCP CNI (default: "openshift-ovn-kubernetes") 
       -pa|--pcapArgs: arguments to tcpdump (default: "-nn -e --number -U -s 512 -i any") 
       -pf|--pcapFilter: tcpdump filter (default: "host <ip of podOne> and host <ip of podTwo>") 
      -all|--allNodes: capture pcapArgs and pcapFilter on all nodes; not just where podOne and podTwo run
        -h|--usage: This usage message 
$ 
```

Example:

./pod-pod-pcap-fetch.sh -p1 socksink-744f44d8b-jcqw8 -p2 socksink-744f44d8b-l8g2t -n1 default -n2 default


## Current limitations:

- error checking and cleanup


