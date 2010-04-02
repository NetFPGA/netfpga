#!/bin/sh

# Define a gigabyte
GIGABYTE=1048576
GRUB_FILE=/etc/grub.conf


MEMSIZE=`cat /proc/meminfo | grep MemTotal | awk '{print $2}'`

echo $MEMSIZE

if [ $MEMSIZE -ge $GIGABYTE ] ; then
	echo "You have 1GB of RAM or more"

	num_entries=`grep -c '^title' $GRUB_FILE`
	positions=`grep -n '^title' $GRUB_FILE | awk -F : '{print $1}' | head -2`
	if [ $num_entries -eq 1 ] ; then
		entry=`tail -n +$positions $GRUB_FILE`
		pos1=$positions
	else
		pos1=`echo "$positions" | head -1`
		pos2=`echo "$positions" | tail -n -1`
		pos2=`expr $pos2 - 1`
		entry=`head -$pos2 $GRUB_FILE`
		entry=`echo "$entry" | tail -n +$pos1`
	fi

	num_NetFPGA_entries=`echo "$entry" | grep -c 'NetFPGA'`
	if [ $num_NetFPGA_entries -eq 1 ] ; then
		echo "First entry in grub.conf is already set for NetFPGA"
		exit 0
	fi

	#add NetFPGA to the end of the title
	entry=`echo "$entry" | sed 's/^\(title.*\)/\1 NetFPGA/'`

	num_uppermem=`echo "$entry" | awk '/uppermem/' | wc -l`
	# Modify all "kernel" lines in grub.conf
  if [ $num_uppermem -ne 0 ] ; then
		echo "uppermem value already exists"
		num_vmalloc=`echo "$entry" | awk '/uppermem/' | head -1 | sed 's/.*uppermem \([[:digit:]]\\)/\1/'`
		if [ $num_vmalloc -lt 524288 ] ; then
			entry=`echo "$entry" | sed 's/^\([[:space:]]\+uppermem\).[[:digit:]]\+/\1 524288/'`
		fi
	else
		entry=`echo "$entry" | sed 's/^\([[:space:]]\+root.*\)/\1 \n\tuppermem 524288/'`
	fi

	num_vmalloc=`echo "$entry" | awk '/vmalloc/' | wc -l`
	if [ $num_vmalloc -ne 0 ] ; then
		echo "vmalloc already exists"
		vmalloc=`echo "$entry" | awk '/vmalloc/' | head -1 | sed 's/.*vmalloc=\([[:digit:]]\+[[:alpha:]]\)/\1/'`
		num_vmalloc=`echo "$vmalloc" | sed 's/[[:alpha:]]\+//'`
		mult=1
		if [ `echo $vmalloc | grep -c '[kK]'` -gt 0 ] ; then
			mult=1024
		elif [ `echo $vmalloc | grep -c '[mM]'` -gt 0 ] ; then
			mult=1048576
		elif [ `echo $vmalloc | grep -c '[gG]'` -gt 0 ] ; then
		  mult=1073741824
		fi
		num_vmalloc=`expr $num_vmalloc "*" $mult`
		if [ $num_vmalloc -lt 268435456 ] ; then
			entry=`echo "$entry" | sed 's/^\([[:space:]]\+kernel.*\)\( vmalloc=[[:digit:]]\+[[:alpha:]]\)/\1 vmalloc=256M/'`
		fi
	else
		entry=`echo "$entry" | sed 's/^\([[:space:]]\+kernel.*\)/\1 vmalloc=256M/'`
	fi
	entry=`echo -e "\n$entry\n"`
 	pos_begin=`expr $pos1 - 1`
	end_of_file=`tail -n +$pos1 $GRUB_FILE`
	end_of_file=`echo -e "\n$end_of_file"`
	entry=`head -$pos_begin $GRUB_FILE`$entry$end_of_file
	echo "$entry" > $GRUB_FILE
else
	echo "You have less than 1GB of RAM"
fi

