/*-
 * Copyright (c) 2006-2011 The Board of Trustees of The Leland Stanford Junior
 * University
 *
 * Author: Jad Naous <jnaous@stanford.edu>
 *
 * We are making the NetFPGA tools and associated documentation (Software)
 * available for public use and benefit with the expectation that others will
 * use, modify and enhance the Software and contribute those enhancements back
 * to the community. However, since we would like to make the Software
 * available for broadest use, with as few restrictions as possible permission
 * is hereby granted, free of charge, to any person obtaining a copy of this
 * Software) to deal in the Software under the copyrights without restriction,
 * including without limitation the rights to use, copy, modify, merge,
 * publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to the
 * following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * The name and trademarks of copyright holder(s) may NOT be used in
 * advertising or publicity pertaining to the Software or any derivatives
 * without specific, written prior permission.
 */

/*
 * Filename: reg_proxy_server.c
 * Description:
 * Implements a server that will accept connection requests and
 * then translate packets to regRead/regWrite calls
 */

#include "reg_proxy_server.h"

int main(int argc, char** argv) {

	int listening_socket;
	int socket_to_client;
	int yes_local;
	int error;
	in_port_t port_num;
	struct sockaddr_in local_addr;
	struct sockaddr_in client_addr;
	socklen_t client_len;
	int num_netfpgas;
	struct nf2device *nf2devices[10];

	yes_local=1;

	DPRINTF("Starting proxy...\n");

	if (argc < 4) {
		printf("Usage: reg_proxy_server <num_NetFPGAs> <ip_addr> <port_num>\n");
		printf("   num_NetFPGAs is the number of netfpga card in the system.\n");
		printf("   ip_addr is the address to accept connections on.\n");
		printf("   port_num is the port number to accept connections on.\n");
		exit(0);
	}

	/* get the parameters for the proxy */
	if (!inet_aton(argv[2], &local_addr.sin_addr)) {
		perror("inet_aton");
		fprintf(stderr, "Error: IP address specified is invalid.\n");
		exit(1);
	}

	port_num = strtol(argv[3], NULL, 0);
	if (errno == EINVAL || errno == ERANGE || port_num < 1024 || port_num > 65535) {
	  fprintf(stderr, "Error: port number has to be between 1024 and 65535. Saw %s.\n", argv[3]);
		exit(1);
	}

	num_netfpgas = strtol(argv[1], NULL, 0);
	if (num_netfpgas < 0 || num_netfpgas > 10) {
	  fprintf(stderr, "Error: Number of NetFPGAs has to be between 1 and 10. Saw %s.\n", argv[1]);
		exit(1);
	}
	DPRINTF("Args have been parsed. num_netfpgas=%d\n", num_netfpgas);

	open_interfaces(nf2devices, num_netfpgas);
	DPRINTF("Interfaces now open.\n");

	DPRINTF("Starting a connection...\n");

	/* fill in the local address struct */
	memset(&local_addr, 0, sizeof(SA));
	local_addr.sin_family = AF_INET;
	local_addr.sin_port = htons(port_num);

	/* get a socket fd */
	if ( (listening_socket = socket(PF_INET, SOCK_STREAM, 0)) < 0) {
		perror("socket");
DPRINTF();
				exit(1);
	}

	/* allow reuse to get around port in use problem */
	if (setsockopt(listening_socket, SOL_SOCKET, SO_REUSEADDR, &yes_local,
			sizeof(int)) == -1) {
		perror("setsockopt");
DPRINTF();
        		exit(1);
	}

	/* bind the socket to a port */
	if (bind(listening_socket, (SA *)&local_addr, sizeof(SA)) < 0) {
		perror("bind");
		DPRINTF("Exiting...\n");
		exit(1);
	}

	DPRINTF("Socket is now bound to port %d\n", port_num);

	/* start listening to connections */
	if (listen(listening_socket, 10) < 0) {
		perror("listen");
DPRINTF();
        		close(listening_socket);
		exit(1);
	}

	DPRINTF("Now listening to connections\n");

	/* loop until we are interrupted, servicing every request */
	while (1) {
		client_len=sizeof(client_addr);
		/* accept the connection and start parsing */
		if ( (socket_to_client = accept(listening_socket, (SA *) &client_addr,
				&client_len)) < 0) {
DPRINTF();
            			perror("accept");
			continue;
		}

		DPRINTF("Accepted connection from client");

		/* read the request, parse,
		 * send response back to client */
		if (parse_request(socket_to_client, nf2devices, num_netfpgas) < 0) {
DPRINTF();
            			fprintf(stderr, "Error parsing the request\n");
		}
		close(socket_to_client);
	}

	return 0;
}

/* mallocs the array of nf2device structs and
 * populates them */
void open_interfaces(struct nf2device **nf2devices, int num_netfpgas) {
	int i;

	for (i=0; i<num_netfpgas; i++) {
		/* allocate memory for struct */
		nf2devices[i] = (struct nf2device *) malloc(sizeof(struct nf2device));
		if (nf2devices[i] == NULL) {
			fprintf(stderr, "Error: Do not have enough memory to open %u interfaces.\n", num_netfpgas);
			close_interfaces(nf2devices, i);
			exit(1);
		}

		/* allocate enough memory for "nf2cXX". Don't forget '\0' */
		nf2devices[i]->device_name = (char *) malloc(7);
		if (nf2devices[i] == NULL) {
			fprintf(stderr, "Error: Do not have enough memory to open %u interfaces.\n", num_netfpgas);
			free(nf2devices[i]);
			close_interfaces(nf2devices, i);
			exit(1);
		}

		/* copy interface name */
		sprintf(nf2devices[i]->device_name, "%s%d", NF2C, i*4);

		if (check_iface(nf2devices[i]) || openDescriptor(nf2devices[i])) {
			fprintf(stderr, "Error: check_iface or openDescriptor %s\n", nf2devices[i]->device_name);
			free(nf2devices[i]->device_name);
			free(nf2devices[i]);
			close_interfaces(nf2devices, i);
			exit(1);
		}
	}
}

/* closes all open interfaces */
void close_interfaces(struct nf2device **nf2devices, int num_netfpgas) {
	int i;

	for (i=0; i<num_netfpgas; i++) {
		closeDescriptor(nf2devices[i]);
		free(nf2devices[i]->device_name);
		free(nf2devices[i]);
	}
}

/* Implements the register protocol:
 * - Read which device
 * - Read request (struct reg_request)
 * - Return result
 */
int parse_request(int socket_to_client, struct nf2device **nf2devices,
		int num_netfpgas) {
	int nread;
	struct reg_request req;

	/* Read the request struct */
	while ( (nread=readn(socket_to_client, (char *)&req,
			sizeof(struct reg_request))) == sizeof(struct reg_request)) {
		DPRINTF("Received reg_request:\n");
		dprint_req(&req);

		/* execute request */
		if (req.device_num < num_netfpgas) {
			DPRINTF("Device num checks out.\n");
			if (req.type == READ_REQ) {
				DPRINTF("Executing read.\n");
				readReg(nf2devices[req.device_num], req.address, &req.data);
			} else if (req.type == WRITE_REQ) {
				DPRINTF("Executing write.\n");
				writeReg(nf2devices[req.device_num], req.address, req.data);
			} else if (req.type == CHECK_REQ) {
				DPRINTF("Executing check.\n");
				req.data = 1;
			} else if (req.type == OPEN_REQ) {
				DPRINTF("Executing open.\n");
				req.data = 1;
			} else if (req.type == CLOSE_REQ) {
				DPRINTF("Executing close.\n");
				DPRINTF("Sending response:\n");
				dprint_req(&req);
				if (writen(socket_to_client, (const char *)&req,
						sizeof(struct reg_request))
						< sizeof(struct reg_request)) {
					fprintf(stderr, "Error: could not write to client.\n");
					return -1;
				}
				return 0;
			} else {
				fprintf(stderr, "Error: Unknown request type %u.\n", req.type);
				req.error = -1;
			}
		} else {
			DPRINTF("Device number bad.\n");
			if (req.type == CHECK_REQ) {
				DPRINTF("Executing check_req.\n");
				req.data = 0;
			} else {
				DPRINTF("Executing else.\n");
				req.error = -1;
			}
		}

		/* send response */
		DPRINTF("Sending response:\n");
		dprint_req(&req);
		if (writen(socket_to_client, (const char *)&req,
				sizeof(struct reg_request)) < sizeof(struct reg_request)) {
			fprintf(stderr, "Error: could not write to client.\n");
			return -1;
		}
	}

	if (nread == 0) {
		return 0;
	} else if (nread < 0) {
		fprintf(stderr, "Error reading the reg_request struct.\n");
		return -1;
	} else if (nread < sizeof(struct reg_request)) {
		fprintf(stderr, "Error: Did not read full reg_request struct.\n");
		return -1;
	}
}
