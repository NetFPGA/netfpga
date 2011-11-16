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
 * Filename: reg_proxy.c
 * Description:
 * common utilities for client and server
 */

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
