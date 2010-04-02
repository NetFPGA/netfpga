#!/usr/bin/perl -w

system 'nice -n -19 ../src/burn.pl --internal_loopback --num_ports 4 --run_length 20 --load_timeout 2.0 --len 1024 --batch_size 1 --packets_to_loop 255 --noignore_load_timeout';

