#!/usr/bin/perl -w

for (;;) {
	system 'nice -n -19 ../src/burn.pl --filename \'>>/root/burn_log\' --noprint_to_console --num_ports 4 --run_length 600 --print_interval 60 --load_timeout 4.0 --len 128 --batch_size 1 --packets_to_loop 255';
}

