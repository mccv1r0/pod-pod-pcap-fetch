# pod-pod-pcap-fetch

The pod-pod-pcap-fetch script will start daemonset with an image used to capture traffic between named pods.  
When you think you captured what you need, ctrl-c will stop the capture, create a tgz with the capture and copy them to your local directory.

Usage: 

./pod-pod-pcap-fetch.sh --usage


Example:

./pod-pod-pcap-fetch.sh -p1 socksink-744f44d8b-jcqw8 -p2 socksink-744f44d8b-l8g2t -n1 default -n2 default


## Current limitations:

- kubeconfig must be in /tmp/kubeconfig

- error checking and cleanup

