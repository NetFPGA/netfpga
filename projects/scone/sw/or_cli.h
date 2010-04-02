/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#ifndef OR_CLI_H_
#define OR_CLI_H_

#include "or_data_types.h"

int cli_main(void* subsystem);

cli_command_handler cli_command_lpm(router_state* rs, char* command);
void process_client_request_np(void* arg);
void* process_client_request(void *arg);

void lock_cli_commands_rd(void* subsys);
void unlock_cli_commands(void* subsys);

void cli_help(router_state *rs, cli_request *req);
void cli_show_help(router_state *rs, cli_request *req);
void cli_hw_help(router_state *rs, cli_request *req);

void cli_nat_test(router_state *rs, cli_request *req);

#endif /* OR_CLI_H_ */

