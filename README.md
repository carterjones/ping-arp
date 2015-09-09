# ping-arp
This is a script to perform a ping-sweep of a network, and obtain results from the system's arp cache. This can be useful when responses cannot be seen from hosts for whatever reason (ICMP is blocked, no open ports, etc.).

The script pings a range of hosts and then looks at the system's ARP cache to identify any existing IPs that can be resolved to a MAC address. This indicates that the host exists.

Usage:

    ./ping-arp.sh <ip range in CIDR notation>

Example:

    ./ping-arp.sh 192.168.1.0/24

Results are both sent to stdout as well as stored in a results.txt file.
