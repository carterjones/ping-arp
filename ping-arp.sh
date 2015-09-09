#!/bin/bash

# Make sure a parameter was supplied.
if [ -z $1 ]; then
  echo Please enter a CIDR to scan.
  exit
fi

# Begin adaptation of http://stackoverflow.com/a/28058660

############################
##  Methods
############################   
prefix_to_bit_netmask() {
  prefix=$1;
  shift=$(( 32 - prefix ));

  bitmask=""
  for (( i=0; i < 32; i++ )); do
    num=0
    if [ $i -lt $prefix ]; then
      num=1
    fi

    space=
    if [ $(( i % 8 )) -eq 0 ]; then
      space=" ";
    fi

    bitmask="${bitmask}${space}${num}"
  done
  echo $bitmask
}

bit_netmask_to_wildcard_netmask() {
  bitmask=$1;
  wildcard_mask=
  for octet in $bitmask; do
    wildcard_mask="${wildcard_mask} $(( 255 - 2#$octet ))"
  done
  echo $wildcard_mask;
}

check_net_boundary() {
  net=$1;
  wildcard_mask=$2;
  is_correct=1;
  for (( i = 1; i <= 4; i++ )); do
    net_octet=$(echo $net | cut -d '.' -f $i)
    mask_octet=$(echo $wildcard_mask | cut -d ' ' -f $i)
    if [ $mask_octet -gt 0 ]; then
      if [ $(( $net_octet&$mask_octet )) -ne 0 ]; then
        is_correct=0;
      fi
    fi
  done
  echo $is_correct;
}

#######################
##  MAIN
#######################

function cidr_to_ip() {
  lines=$@

  for ip in ${lines[@]}; do
    net=$(echo $ip | cut -d '/' -f 1);
    prefix=$(echo $ip | cut -d '/' -f 2);
    do_processing=1;

    bit_netmask=$(prefix_to_bit_netmask $prefix);

    wildcard_mask=$(bit_netmask_to_wildcard_netmask "$bit_netmask");

    if [ $do_processing -eq 1 ]; then
      str=
      for (( i = 1; i <= 4; i++ )); do
        range=$(echo $net | cut -d '.' -f $i)
        mask_octet=$(echo $wildcard_mask | cut -d ' ' -f $i)
        if [ $mask_octet -gt 0 ]; then
          range="{$range..$(( $range | $mask_octet ))}";
        fi
        str="${str} $range"
      done
      ips=$(echo $str | sed "s, ,\\.,g"); ## replace spaces with periods, a join...

      eval echo $ips | tr ' ' '\n'
    else
      exit
    fi

  done
}

# End adaptation of http://stackoverflow.com/a/28058660

# Get a list of IPs that should be scanned.
cidr_to_ip $1 > ips-to-scan.txt
cp ips-to-scan.txt remaining-ips.txt

# Clear the cached ARP results.
rm arpcache.txt &> /dev/null

# Scan a chunk of IPs.
export chunksize=256
while [[ -s remaining-ips.txt ]]; do
  for ip in `head -n $chunksize remaining-ips.txt`; do
    ping $ip -c 1 &
  done
  wait

  arp -a | grep -v incomplete >> arpcache.txt
  cat arpcache.txt | sort | uniq > arpcache-unique.txt

  # Move to the next chunk of IPs.
  tail -n +$chunksize remaining-ips.txt > remaining-ips-cache.txt
  mv remaining-ips-cache.txt remaining-ips.txt
done

# Filter the results to only what the scan targets are.
rm results.txt &> /dev/null
for line in `cat ips-to-scan.txt`; do
  cat arpcache-unique.txt | grep $line >> results.txt
done

# Display results.
echo
echo "Results:"
cat results.txt

# Clean up temporary files.
rm ips-to-scan.txt &> /dev/null
rm remaining-ips.txt &> /dev/null
rm arpcache.txt &> /dev/null
rm arpcache-unique.txt &> /dev/null
