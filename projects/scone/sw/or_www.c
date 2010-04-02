/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#include "or_www.h"
#include "or_data_types.h"
#include "or_utils.h"
#include "or_cli.h"
#include "or_output.h"
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>
#ifdef _NOLWIP_
	#include <netinet/in.h>
	#include <pthread.h>
#else
	#define LWIP_COMPAT_SOCKETS
	#include "lwip/sockets.h"
	#include "lwip/sys.h"
	#include "lwip/arch.h"
#endif

int contains_crlfcrlf(uint8_t* buf, int len);
char* list_commands(router_state* rs, www_client_thread_info* info);
int send_file(router_state* rs, www_client_thread_info* info, FILE* file);
int send_all(router_state* rs, www_client_thread_info* info, uint8_t* msg, int len);
void service_request(www_client_thread_info* info);

void www_main(void* subsystem) {
	router_state* rs = (router_state*)subsystem;

	int sock_len = sizeof(struct sockaddr);
	int bindfd = -1;
 	int clientfd = 0;
	//int ret = 0;
	struct sockaddr_in addr;
	struct sockaddr    client_addr;

	bindfd = socket(AF_INET, SOCK_STREAM, 0);

	addr.sin_port = htons(8080);
	addr.sin_addr.s_addr = 0;
	memset(&(addr.sin_zero), 0, sizeof(addr.sin_zero));
	int on = 1;
	setsockopt(bindfd, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on));
	if( bind(bindfd, (struct sockaddr*)&addr, sizeof(struct sockaddr)))
	{
		printf("error binding to port\n");
		return;
  }

	/* Tell connection to go into listening mode. */
	listen(bindfd, 10);

	/* spawn a 5 threads to handle www connections */
	#ifndef _NOLWIP_

	sys_thread_new(www_client_thread_np, subsystem);
	sys_thread_new(www_client_thread_np, subsystem);
	sys_thread_new(www_client_thread_np, subsystem);
	sys_thread_new(www_client_thread_np, subsystem);
	sys_thread_new(www_client_thread_np, subsystem);

	#else

	pthread_t* t = (pthread_t*)malloc(sizeof(pthread_t));
  if(pthread_create(t, NULL, www_client_thread, subsystem) != 0) {
    perror("Thread create error");
  }

	t = (pthread_t*)malloc(sizeof(pthread_t));
  if(pthread_create(t, NULL, www_client_thread, subsystem) != 0) {
    perror("Thread create error");
  }

	t = (pthread_t*)malloc(sizeof(pthread_t));
  if(pthread_create(t, NULL, www_client_thread, subsystem) != 0) {
    perror("Thread create error");
  }

	t = (pthread_t*)malloc(sizeof(pthread_t));
  if(pthread_create(t, NULL, www_client_thread, subsystem) != 0) {
    perror("Thread create error");
  }

	t = (pthread_t*)malloc(sizeof(pthread_t));
  if(pthread_create(t, NULL, www_client_thread, subsystem) != 0) {
    perror("Thread create error");
  }
  #endif


	while (1) {
 		/* Grab new connection. */
		clientfd = accept(bindfd, &client_addr, &sock_len);

		/* Build the www thread information */
		www_client_thread_info* info = (www_client_thread_info*)calloc(1, sizeof(www_client_thread_info));
		info->sockfd = clientfd;
		info->rs = rs;

		node* n = node_create();
		n->data = info;

		pthread_mutex_lock(rs->www_mutex);
		if (!rs->www_request_queue) {
			rs->www_request_queue = n;
		} else {
			node_push_back(rs->www_request_queue, n);
		}

		pthread_mutex_unlock(rs->www_mutex);
		pthread_cond_broadcast(rs->www_cond);
	}
}

void www_client_thread_np(void* arg) {
	www_client_thread(arg);
}

void* www_client_thread(void *arg) {
	router_state* rs = (router_state*)arg;
	struct timespec wake_up_time;
	struct timeval now;

	while (1) {
		/* grab mutex, check for pending request, if none go to sleep */
		pthread_mutex_lock(rs->www_mutex);
		if (!rs->www_request_queue) {
			/* wake up one second in the future even if no signal */
			gettimeofday(&now, NULL);
			wake_up_time.tv_sec = now.tv_sec + 1;
			wake_up_time.tv_nsec = now.tv_usec + 1000;

			pthread_cond_timedwait(rs->www_cond, rs->www_mutex, &wake_up_time);
			pthread_mutex_unlock(rs->www_mutex);
			continue;
		} else {
			/* pop the top off the queue */
			node* cur = rs->www_request_queue;
			rs->www_request_queue = cur->next;
			if (rs->www_request_queue) {
				rs->www_request_queue->prev = NULL;
			}
			/* unlock our mutex */
			pthread_mutex_unlock(rs->www_mutex);

			www_client_thread_info* info = cur->data;
			service_request(info);

			free(info);
			free(cur);

		}
	}
	return NULL;
}

void service_request(www_client_thread_info* info) {
	router_state* rs = info->rs;
	int read = 0;

	int buf_alloc_size = 100;
	int buf_size = 0;
	uint8_t* buf = calloc(1,buf_alloc_size);
	uint8_t* buf_ptr = buf;

	uint8_t received_crlfcrlf = 0;

	/* we need to continue reading until we get a \r\n\r\n from the client */
	while (!received_crlfcrlf) {
		read = recv(info->sockfd, buf_ptr, buf_alloc_size - buf_size, 0);
		if (read > 0) {
			// increment buf ptr, size
			buf_size += read;
			buf_ptr += read;

			if (contains_crlfcrlf(buf, buf_size)) {
				received_crlfcrlf = 1;
			}

			// are we at our max allocation?
			if (buf_size == buf_alloc_size) {
				uint8_t* new_buf = NULL;
				if ((new_buf = calloc(1, buf_alloc_size*2)) == 0) {
					perror("malloc error reading html request");
					free(buf);
					return;
				}
				memmove(new_buf, buf, buf_alloc_size);

				buf_alloc_size *= 2;
				free(buf);
				buf = new_buf;
				buf_ptr = buf + buf_size;
			}

		} else if (read == 0) {
			// other side closed writing
			if (contains_crlfcrlf(buf, buf_size)) {
				received_crlfcrlf = 1;
			} else {
				// free the buffer and exit
				free(buf);
				close(info->sockfd);
				return;
			}
		} else {
			// error
			free(buf);
			close(info->sockfd);
			return;
		}
	}

	// get request line
	char* method = NULL;
	char* url = NULL;
	if (sscanf(buf, "%as %as", &method, &url) != 2) {
		free(buf);
		close(info->sockfd);
		return;
	}

	if (strcmp(url, "/list.html") == 0) {
		/* check for command list */
	  char* body = list_commands(rs, info);
	  int body_len = strlen(body);

	  int alloc_size = 512;
	  char* result = calloc(1, 512);
	  strcpy(result, "HTTP/1.0 200 OK\r\n");
	  char content_length[128];
	  sprintf(content_length, "Content-Length: %u\r\n\r\n", body_len);
	  result = my_strncat(result, content_length, &alloc_size);
	  result = my_strncat(result, body, &alloc_size);

	  send_all(rs, info, result, strlen(result));

	  free(body);
	  free(result);

	} else if (strncmp(url, "/stats.html", 11) == 0) {
	  int alloc_size = 512;
	  char* result = calloc(1, alloc_size);
  	strcpy(result, "HTTP/1.0 200 OK\r\nContent-Type: text/html; charset=UTF-8\r\n\r\n");

		char* statsBuf;
		int statsLen;
		sprint_hw_stats(rs, &statsBuf, &statsLen);
		strcpy(result, statsBuf);
		//strcpy(result, "</pre>");
		send_all(rs, info, result, strlen(result));

		free(statsBuf);
		free(result);
	}	else if (strncmp(url, "/command.html", 13) == 0) {
	  int alloc_size = 512;
	  char* result = calloc(1, alloc_size);
		/*
    <SCRIPT LANGUAGE="JavaScript" SRC="prototype.js"/>
    <SCRIPT LANGUAGE="JavaScript" SRC="our_router.js"/>
		*/
	  if (strstr(url, "refresh=1")) {
	  	strcpy(result, "HTTP/1.0 200 OK\r\n\r\n");
	  } else {
	  	strcpy(result, "HTTP/1.0 200 OK\r\n\r\n");
	  }

		// get the command
		char* command = strtok(url, "=&");
		command = strtok(NULL, "=&");
		char* decodedCommand;

		if (!command) {
			decodedCommand = calloc(1, 2);
		} else {
			decodedCommand = urldecode(command);
		}


	  //result = my_strncat(result, "<h2>Command: ", &alloc_size);
	  //result = my_strncat(result, decodedCommand, &alloc_size);
	  //result = my_strncat(result, "<pre>", &alloc_size);
		send_all(rs, info, result, strlen(result));
		free(result);

		/* build the cli_request object */
		cli_request* req = (cli_request *)malloc(sizeof(cli_request));
		req->command = mallocCopy(decodedCommand);
		free(decodedCommand);
		req->sockfd = info->sockfd;

		lock_cli_commands_rd(rs);

		cli_command_handler handler = cli_command_lpm(rs, req->command);
		if (handler == NULL) {
			char *error = "invalid command\n";
			send_to_socket(req->sockfd, error, strlen(error));
		} else {
			(*handler)(rs, req);
		}

		free(req->command);
		free(req);

		unlock_cli_commands(rs);

		//strcpy(result, "</pre></body>");
		//send_all(rs, info, result, strlen(result));
	} else {

		/* see if a file matches the request */
		char fileName[512]; // super long path
		bzero(fileName, 512);
		getcwd(fileName, 512);
		strncat(fileName, "/www", 511 - strlen(fileName));

		if (strcmp(url, "/") == 0) {
			strncat(fileName, "/index.html", 511 - strlen(fileName));
		} else {
			strncat(fileName, url, 511 - strlen(fileName));
		}

		/* try and get a file */
		FILE* file = fopen(fileName, "rb");
	  if (file == NULL) {
	  	char* msg = "HTTP/1.0 404 Not Found\r\n\r\n";
	  	send(info->sockfd, msg, strlen(msg), 0);
	  	msg = "<html><head><title>404 Not Found</title></head><body><h1>Not Found</h1><p>The requested URL was not found on this server.</p></body></html>";
	  	send(info->sockfd, msg, strlen(msg), 0);
	  } else {
	  	char* msg = "HTTP/1.0 200 OK\r\n";
	  	send(info->sockfd, msg, strlen(msg), 0);

	  	send_file(rs, info, file);

	  	fclose(file);
	  }
	}

	free(buf);
	free(method);
	free(url);
	close(info->sockfd);
	return;
}

int contains_crlfcrlf(uint8_t* buf, int len) {
	if (len < 4) {
		return 0;
	}

	int i = 0;

	for (i = 0; i < (len - 3); ++i) {
		if (buf[i] == '\r') {
			if (buf[i+1] == '\n') {
				if (buf[i+2] == '\r') {
					if (buf[i+3] == '\n') {
						return 1;
					}
				}
			}
		}
	}

	return 0;
}

char* list_commands(router_state* rs, www_client_thread_info* info) {
	int alloc_size = 256;
	char* msg = calloc(1, alloc_size);
	strncpy(msg, "", 255);

	/* lock the cli read lock */
	lock_cli_commands_rd(rs);

	node* cur = rs->cli_commands;
	while (cur) {
		cli_entry* entry = (cli_entry*)cur->data;
		//msg = my_strncat(msg, "<a href=\"command.html?command=", &alloc_size);
		//char* encoded = urlencode(entry->command);
		//msg = my_strncat(msg, encoded, &alloc_size);
		//free(encoded);
		//msg = my_strncat(msg, "\">", &alloc_size);
		msg = my_strncat(msg, entry->command, &alloc_size);
		msg = my_strncat(msg, "\n", &alloc_size);
		//msg = my_strncat(msg, "</a><br/>\n", &alloc_size);
		cur = cur->next;
	}

	/* unlock the cli read lock */
	unlock_cli_commands(rs);

	//msg = my_strncat(msg, "</div></body>", &alloc_size);

	return msg;
}

int send_file(router_state* rs, www_client_thread_info* info, FILE* file) {
	// get file size
	fseek(file, 0, SEEK_END);
	int size = ftell(file);

	/* send Content-Length */
	char content_length_header[128];
	bzero(content_length_header, 128);
	snprintf(content_length_header, 127, "Content-Length: %u\r\n\r\n", size);
	send_all(rs, info, content_length_header, strlen(content_length_header));

	rewind(file);
	char* fbuf = malloc(size);
	int r = fread(fbuf, 1, size, file);
	if (r != size) {
		printf("error reading file in\n");
		return -1;
	}

	int retval = send_all(rs, info, fbuf, size);
	free(fbuf);

	return retval;
}

int send_all(router_state* rs, www_client_thread_info* info, uint8_t* msg, int len) {
	int s = 0;
	int totalSent = 0;
	uint8_t* ptr = msg;
	while (totalSent != len) {
		// send a multiple of the MSS because the buffers in lwip suck
		s = send(info->sockfd, ptr, ((len - totalSent) > 8400) ? 8400 : (len - totalSent), 0);
		if (s < 0) {
			perror("sending");
			return -1;
		}
		totalSent += s;
		ptr += s;
	}

	return 0;
}
