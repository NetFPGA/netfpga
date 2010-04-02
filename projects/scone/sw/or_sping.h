/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#ifndef OR_SPING_H_
#define OR_SPING_H_

#include "or_data_types.h"

void cli_sping(router_state *rs, cli_request *req);
int wait_for_reply(router_state *rs, unsigned short id);
void cli_sping_help(router_state *rs, cli_request *req);

void sping_queue_cleanup_thread_np(void *arg);
void* sping_queue_cleanup_thread(void *arg);

void lock_mutex_sping_queue(router_state* rs);
void unlock_mutex_sping_queue(router_state* rs);

#endif /* OR_SPING_H_ */
