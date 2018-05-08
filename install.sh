#!/bin/bash

size=`ls -all | grep all.tar.gz | gawk '{print $5}'`

cp install_hadoop.sh  install_hadoop.bin

sed -i "s/size=0/size=$size/g"  install_hadoop.bin

cat all.tar.gz >>install_hadoop.bin


