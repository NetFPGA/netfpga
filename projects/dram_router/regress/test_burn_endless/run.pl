#!/usr/bin/perl -w

system 'nice -n -19 ../src/burn.pl --filename \'>>./burn_log\' --print_to_console --num_ports 4 --run_length 2 --load_timeout 10.0 --len 256 --batch_size 1 --packets_to_loop 255';

