/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <string.h>
#include <netdb.h>

#ifdef _NOLWIP_
	#include <netinet/in.h>
	#include <unistd.h>
	#include <pthread.h>
#else
	#define LWIP_COMPAT_SOCKETS
	#include "lwip/sockets.h"
	#include "lwip/sys.h"
	#include "lwip/arch.h"
#endif

#include "or_cli.h"
#include "or_utils.h"
#include "or_sping.h"
#include "nf2/nf2util.h"

#define MAX_COMMAND_SIZE 128

int cli_main(void* subsystem) {
	router_state* rs = (router_state*)subsystem;

	int sock_len = sizeof(struct sockaddr);
	int bindfd = -1;
 	int clientfd = 0;
	//int ret = 0;
	char buf[MAX_COMMAND_SIZE];
	bzero(buf, MAX_COMMAND_SIZE);
	struct sockaddr_in addr;
	struct sockaddr    client_addr;

	bindfd = socket(AF_INET, SOCK_STREAM, 0);

	addr.sin_port = htons(23);
	addr.sin_addr.s_addr = 0;
	memset(&(addr.sin_zero), 0, sizeof(addr.sin_zero));
	int on = 1;
	setsockopt(bindfd, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on));
	if( bind(bindfd, (struct sockaddr*)&addr, sizeof(struct sockaddr)))
	{
		printf("error binding to port\n");
		return -1;
  	}

	/* Tell connection to go into listening mode. */
	listen(bindfd, 10);


	/* Spawn the sping queue cleanup thread */
	#ifndef _NOLWIP_

	sys_thread_new(sping_queue_cleanup_thread_np, (void *) rs);

	#else

	pthread_t thread;
  if(pthread_create(&thread, NULL, sping_queue_cleanup_thread, (void *)rs) != 0) {
    perror("Thread create error");
  }

  #endif

	while (1) {
	 		/* Grab new connection. */
		clientfd = accept(bindfd, &client_addr, &sock_len);

		printf("accepted new connection %d\n", clientfd);

		/* Build the CLI thread information */
		cli_client_thread_info *cli_info = calloc(1, sizeof(cli_client_thread_info));
		cli_info->sockfd = clientfd;
		cli_info->rs = rs;

		/* Spawn thread to deal with the client's cli command */
		#ifndef _NOLWIP_

		sys_thread_new(process_client_request_np, (void *)cli_info);

		#else

		pthread_t* t = (pthread_t*)malloc(sizeof(pthread_t));
		// TODO going to lose reference to this memory and be unable to free it..
	  if(pthread_create(t, NULL, process_client_request, (void *)cli_info) != 0) {
	    perror("Thread create error");
	  }

	  #endif
	}

}

cli_command_handler cli_command_lpm(router_state* rs, char* command) {

	int longest_match = 0;
	cli_entry* longest_match_entry = NULL;

	node* n = rs->cli_commands;
	while (n) {
		cli_entry* ce = (cli_entry*)n->data;

		// Only match if the incoming command is greater or equal in length to this entry
		// and the current entry is actually longer than the longest current match
		int entry_len = strlen(ce->command);
		if ((entry_len > longest_match) && (strlen(command) >= entry_len)) {
			if (strncmp(command, ce->command, entry_len) == 0) {
				longest_match = entry_len;
				longest_match_entry = ce;
			}
		}

		n = n->next;
	}

	if (longest_match_entry) {
		return longest_match_entry->handler;
	} else {
		return NULL;
	}
}


void lock_cli_commands_rd(void* subsys) {
	router_state* rs = (router_state*)subsys;

	if(pthread_rwlock_rdlock(rs->cli_commands_lock) != 0) {
		perror("Failure getting cli commands read lock");
	}
}

void unlock_cli_commands(void* subsys) {
	router_state* rs = (router_state*)subsys;

	if(pthread_rwlock_unlock(rs->cli_commands_lock) != 0) {
		perror("Failure unlocking cli commands lock");
	}
}

void process_client_request_np(void* arg) {
	process_client_request(arg);
}

void* process_client_request(void *arg) {

	cli_client_thread_info *cli_info = (cli_client_thread_info *)arg;
	int ret = 0;
	char buf[MAX_COMMAND_SIZE];
	bzero(buf, MAX_COMMAND_SIZE);



	send_to_socket(cli_info->sockfd, "> ", sizeof("> "));
	while(1) {

		/* get client's cli command */
		if( !(ret = recv(cli_info->sockfd, buf, MAX_COMMAND_SIZE, 0)) ) {
			continue;
		}
		if(ret <= 0) {
			printf("recv(..) error %d\n", ret);
			return NULL;
		}

		/* get rid of \r\n or \n when you hit enter in telnet */
	       	cleanCRLFs(buf);

		if(strncmp(buf, "exit", strlen("exit")) == 0) {
			send_to_socket(cli_info->sockfd, "bye!\n", strlen("bye!\n"));
			close(cli_info->sockfd);
			return NULL;
		}


		/* build the cli_request object */
		cli_request* req = (cli_request *)malloc(sizeof(cli_request));
		req->command = mallocCopy(buf);
		req->sockfd = cli_info->sockfd;

		cli_command_handler handler = cli_command_lpm(cli_info->rs, req->command);
		if(handler == NULL) {

			char *error = "invalid command ... type ? or help for valid command help\n";
			send_to_socket(req->sockfd, error, strlen(error));

		}
		else {
			(*handler)(cli_info->rs, req);
		}

		free(req->command);
		free(req);

		send_to_socket(cli_info->sockfd, "> ", sizeof("> "));
	}

}

/*
 * CLI help for general usage functions
 */
void cli_help(router_state* rs, cli_request* req) {

	char *usage = "usage: <args>\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tshow vns [user server vhost lhost topology]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tshow ip [route interface arp]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tip [route interface arp]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tsping [dest]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));


	/* PWOSPF */

	usage = "\tshow pwopsf [iface router info]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tset aid [area id]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tset hello interval [interval]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tset lsu broadcast [on off]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tset lsu interval [interval]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tsend hello\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tsend lsu\n";
	send_to_socket(req->sockfd, usage, strlen(usage));



	/* HARDWARE */

	usage = "\tshow hw rtable\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tshow hw arp\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tshow hw iface\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\thw iface add [eth0 eth1 eth2 eth3] [mac adress]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\thw iface del [eth0 eth1 eth2 eth3]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tnuke arp\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tnuke hw arp [row]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\thw iface [eth0 eth1 eth2 eth3] up\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\thw iface [eth0 eth1 eth2 eth3] down\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\thw packts fwd\n";
	send_to_socket(req->sockfd, usage, strlen(usage));



}

void cli_show_help(router_state *rs, cli_request* req) {

	char *usage0 = "usage: show <args>\n";
	send_to_socket(req->sockfd, usage0, strlen(usage0));

	char *usage1 = "show vns [user server vhost lhost topology]\n";
	send_to_socket(req->sockfd, usage1, strlen(usage1));

	char *usage2 = "show ip [route interface arp]\n";
	send_to_socket(req->sockfd, usage2, strlen(usage2));
}


void cli_hw_help(router_state *rs, cli_request* req) {
	char *usage;

	usage = "\tshow hw rtable\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tshow hw arp\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tshow hw iface\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tnuke arp\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\tnuke hw arp [row]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\thw iface add [eth0 eth1 eth2 eth3] [mac addr]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\thw iface del [eth0 eth1 eth2 eth3]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\thw iface [eth0 eth1 eth2 eth3] up\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\thw iface [eth0 eth1 eth2 eth3] down\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

	usage = "\thw packts fwd\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

}


void cli_nat_test(router_state *rs, cli_request *req) {

	char *msg;
	char line[1024];
	int sockfd;
	struct sockaddr_in servaddr;
	struct hostent *servhost;
	int error;

	servhost = gethostbyname("www.cs.stanford.edu");
	if(servhost == NULL) {
		msg = "GetHostByName Error: 'www.cs.stanford.edu'\n";
		send_to_socket(req->sockfd, msg, strlen(msg));
		return;
	}

	sockfd = socket(AF_INET, SOCK_STREAM, 0);
	if(sockfd < 1) {
		msg = "Socket Error\n";
		send_to_socket(req->sockfd, msg, strlen(msg));
		return;
	}

	bzero(&servaddr, sizeof(struct sockaddr_in));
	servaddr.sin_family = AF_INET;
	servaddr.sin_port = htons(80);
	memcpy(&servaddr.sin_addr, servhost->h_addr_list[0], servhost->h_length);

	bzero(line, 1024);
	char ip_str[16];
	snprintf(line, 1024, "IP: %s\n", inet_ntop(AF_INET, &servaddr.sin_addr, ip_str, 16));
	send_to_socket(req->sockfd, line, strlen(line));


	if(connect(sockfd, (struct sockaddr *) &servaddr, sizeof(struct sockaddr_in)) < 0) {
		msg = "Connect error\n";
		send_to_socket(req->sockfd, msg, strlen(msg));
		return;
	}


	/* ask for the website */
	msg = "GET www.cs.stanford.edu HTTP/1.0\n\n";
	if(write(sockfd, msg, strlen(msg)) < 0) {
		msg = "Write error\n";
		send_to_socket(req->sockfd, msg, strlen(msg));
		return;
	}

	/* retrieve the website */
	bzero(line, 1024);
	error = read(sockfd, line, 1024);
	while(error > 0) {

		error = write(req->sockfd, line, strlen(line));
		if(error < 0) {
			msg = "Write error\n";
			send_to_socket(req->sockfd, msg, strlen(msg));
			return;
		}

		error = read(sockfd, line, 1024);
		if(error < 0) {
			msg = "Read error\n";
			send_to_socket(req->sockfd, msg, strlen(msg));
			return;
		}
	}
	send_to_socket(req->sockfd, "\n\n", 2);
}


