/***************************************************************
* $Id$
* Author: Jad Naous
* Filename: reg_proxy.c
* Description:
* common utilities for client and server
****************************************************************/

#include "reg_proxy.h"

void dprint_req(struct reg_request *req) {
    DPRINTF("   type     : %s (%d)\n",
            (req->type == READ_REQ) ? "read"
            : (req->type == WRITE_REQ) ? "write"
            : (req->type == CHECK_REQ) ? "check_iface"
            : (req->type == OPEN_REQ) ? "open_iface"
            : (req->type == CLOSE_REQ) ? "close_iface"
            : "unknown", req->type);
    DPRINTF("   device_n : %u\n", req->device_num);
    DPRINTF("   address  : %08x\n", req->address);
    DPRINTF("   data     : %08x (%u)\n", req->data, req->data);
    DPRINTF("   error    : %u\n", req->error);
}

/* read len characters from the sockfd file descriptor */
ssize_t readn(int sockfd, char *ptr, size_t len){
    size_t nleft;
    ssize_t nread;

    assert(sockfd>=0);
    assert(ptr!=NULL);
    assert(len>=0);

    nleft = len;
    while(nleft > 0){
        if( (nread = read(sockfd, ptr, nleft)) < 0) {
            if (errno == EINTR)
                nread = 0;
            else {
                perror("read");
                return (-1);
            }
        }

        else if (nread == 0)
            break;

        nleft -= nread;
        ptr += nread;
    }
    return (len - nleft);
}

/* write len characters to the sockfd */
ssize_t writen(int sockfd, const char *ptr, size_t len) {
    size_t nleft;
    ssize_t nwritten;

    assert(sockfd>=0);
    assert(ptr!=NULL);
    assert(len>=0);

    nleft = len;
    while (nleft > 0) {
        if ( (nwritten = write(sockfd, ptr, nleft)) <= 0) {
            if (nwritten < 0 && errno == EINTR)
                nwritten = 0;
            else {
                perror("write");
                return (-1);
            }
        }

        nleft -= nwritten;
        ptr += nwritten;
    }
    return (len);
}
