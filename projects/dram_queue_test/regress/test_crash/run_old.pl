#!/usr/bin/perl

system 'nice -n -19 ../src/burn.pl --internal_loopback --num_ports 1 --run_length 20 --load_timeout 0.0 --len 1496 --batch_size 20 --packets_to_loop 255';
