/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#ifndef OR_NETFPGA_H_
#define OR_NETFPGA_H_

#include "sr_base_internal.h"
#include "or_data_types.h"

#define CPU0 "cpu0"
#define CPU1 "cpu1"
#define CPU2 "cpu2"
#define CPU3 "cpu3"

#define ETH0 "eth0"
#define ETH1 "eth1"
#define ETH2 "eth2"
#define ETH3 "eth3"

unsigned char getPortNumber(char* name);
unsigned int getOneHotPortNumber(char* name);
void getIfaceFromOneHotPortNumber(char *name, unsigned int len, unsigned int port);

void netfpga_input(struct sr_instance* sr);
void* netfpga_input_threaded(void* arg);
void netfpga_input_threaded_np(void* arg);
int netfpga_output(struct sr_instance* sr, uint8_t* packet, unsigned int len, const char* iface);



/* helper functions */
unsigned get_rd_data_reg(unsigned int queue);
unsigned get_rd_ctrl_reg(unsigned int queue);
unsigned get_rd_num_of_words_avail_reg(unsigned int queue);
unsigned get_rd_num_of_pckts_in_queue_reg(unsigned int queue);
void get_incoming_interface(char *iface, unsigned int len, unsigned int queue);

void lock_netfpga_stats(router_state* rs);
void unlock_netfpga_stats(router_state* rs);
void* netfpga_stats(void* arg);

/* ip filter functions */
void trigger_local_ip_filters_change(router_state* rs);
int add_local_ip_filter(router_state* rs, struct in_addr* ip, char* name);
local_ip_filter_entry* get_local_ip_filter_by_name(router_state*rs, char* name);
local_ip_filter_entry* get_local_ip_filter_by_ip(router_state*rs, struct in_addr* ip);
void lock_local_ip_filters(router_state* rs);
void unlock_local_ip_filters(router_state* rs);

/* Functions for writing packets out */
unsigned int get_wr_num_pkts_in_q(nf2device* nf2, unsigned char port);
unsigned int get_wr_num_words_left(nf2device* nf2, unsigned char port);
unsigned int set_wr_data_word(nf2device* nf2, unsigned char port, unsigned int val);
unsigned int set_wr_ctrl_word(nf2device* nf2, unsigned char port, unsigned int val);

/* Stats Functions 0-3 eth 4-7 cpu */
unsigned int get_rx_queue_num_pkts_received(nf2device* nf2, unsigned char port);
unsigned int get_tx_queue_num_pkts_sent(nf2device* nf2, unsigned char port);
unsigned int get_rx_queue_num_bytes_received(nf2device* nf2, unsigned char port);
unsigned int get_tx_queue_num_bytes_sent(nf2device* nf2, unsigned char port);
unsigned int get_rx_queue_num_pkts_dropped_full(nf2device* nf2, unsigned char port);
unsigned int get_rx_queue_num_pkts_dropped_bad(nf2device* nf2, unsigned char port);
unsigned int get_oq_num_pkts_dropped(nf2device* nf2, unsigned char port);

void cli_hw_info(router_state *rs, cli_request *req);

#endif
