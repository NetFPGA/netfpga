/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <assert.h>
#include <errno.h>

#include "sr_base_internal.h"

#include "or_sping.h"
#include "or_utils.h"
#include "or_icmp.h"
#include "or_iface.h"


void cli_sping(router_state *rs, cli_request *req) {

	char *error;

	/* Recover the address to be pinged */
	struct in_addr dst;
	char *dst_str = req->command + strlen("sping ");
	if(inet_pton(AF_INET, dst_str, &dst) != 1) {
		error = "syntax error : destination ip\n";
		send_to_socket(req->sockfd, error, strlen(error));
		return;
	}

	if (iface_match_ip(rs, dst.s_addr)) {
		char* msg = "That is one of our interfaces!\n";
		send_to_socket(req->sockfd, msg, strlen(msg));
		return;
	}

	/* Generate a pseudo-random id for this ping */
	unsigned int iseed = (unsigned int)time(NULL);
	srand(iseed);
	unsigned short id = (unsigned short) rand();


	/* Send the ECHO request packet */
	if(send_icmp_echo_request_packet((struct sr_instance *)rs->sr, dst, id) != 0) {
		error = "error : failed to send ICMP echo request packet\n";
		send_to_socket(req->sockfd, error, strlen(error));
		return;
	}


	if(wait_for_reply(rs, id) != 0) {
		error = "no reply from : ";
		send_to_socket(req->sockfd, error, strlen(error));
		send_to_socket(req->sockfd, dst_str, strlen(dst_str));
	}
	else {
		error = "GOT reply from : ";
		send_to_socket(req->sockfd, error, strlen(error));
		send_to_socket(req->sockfd, dst_str, strlen(dst_str));
	}
	send_to_socket(req->sockfd, "\n", 1);
}


int wait_for_reply(router_state *rs, unsigned short id) {

	int response = 1;
	int ret = 0;
	struct timespec wake_up;
	struct timeval now;

	gettimeofday(&now, NULL);

	/* Determine the time when to wake up next */
	wake_up.tv_sec = now.tv_sec + 5;
	wake_up.tv_nsec = now.tv_usec + (5*1000);


	lock_mutex_sping_queue(rs);

	/* Wait until reply is pushed onto the queue */
	while(rs->sping_queue == NULL || ret == 0) {

		ret = pthread_cond_timedwait(rs->sping_cond, rs->sping_mutex, &wake_up);

		if(ret == ETIMEDOUT) {
			// goto exit_loop;
			break;
		}
		else {
			/* Iterate over the sping queue for our reply */
			node *sping_walker = rs->sping_queue;
			while(sping_walker) {
				sping_queue_entry *se = (sping_queue_entry *)sping_walker->data;

				icmp_hdr *icmp = get_icmp_hdr(se->packet, se->len);
		       		uint8_t *icmp_data = ((uint8_t *)icmp) + sizeof(icmp_hdr);
				unsigned short *pckt_id = (unsigned short*)icmp_data;

				if(*pckt_id == id) {
					/* remove entry */
					free(se->packet);
					node_remove(&rs->sping_queue, sping_walker);

					response = 0;
					// goto exit_loop;

					/* found a match, get out of the inner loop */
					break;
				}

				sping_walker = sping_walker->next;

			} /* end of while(sping_walker ... */

			/* found a match, get out of the first loop */
			if(response == 0) { break; }

		} /* end of ret != ETIMEDOUT */

	} /* end of while(rs->sping_queue ... */

//exit_loop:
	unlock_mutex_sping_queue(rs);

	return response;
}


void cli_sping_help(router_state *rs, cli_request *req) {

	char *usage = "usage: sping [address]\n";
	send_to_socket(req->sockfd, usage, strlen(usage));

}


void lock_mutex_sping_queue(router_state* rs) {
	assert(rs);
	if(pthread_mutex_lock(rs->sping_mutex) != 0) {
		perror("Failure getting sping mutex lock");
	}
}


void unlock_mutex_sping_queue(router_state* rs) {
	assert(rs);
	if(pthread_mutex_unlock(rs->sping_mutex) != 0) {
		perror("Failure unlocking sping mutex");
	}
}


void sping_queue_cleanup_thread_np(void *arg) {
	sping_queue_cleanup_thread(arg);
}

void* sping_queue_cleanup_thread(void *arg) {

	router_state *rs = (router_state *)arg;
	time_t now;
	double diff = 0;
	node *sping_walker = 0;
	sping_queue_entry *sqe = 0;

	while(1) {
		sleep(30);

		lock_mutex_sping_queue(rs);

		sping_walker = rs->sping_queue;
		while(sping_walker) {

			node *sping_current = NULL;
			sqe = (sping_queue_entry *)sping_walker->data;

			time(&now);
			diff = difftime(now, sqe->arrival_time);

			/* mark this entry for removal if it's been on the queue for too long */
			if(diff > 30) {
				sping_current = sping_walker;
			}

			sping_walker = sping_walker->next;
			if(sping_current) {
				free(sqe->packet);
				node_remove(&rs->sping_queue, sping_current);
			}
		}

		unlock_mutex_sping_queue(rs);
	}
}





