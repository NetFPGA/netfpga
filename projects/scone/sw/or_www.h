/*
 * Authors: David Erickson, Filip Paun
 * Date: 06/2007
 *
 */

#ifndef OR_WWW_H_
#define OR_WWW_H_

void www_main(void* subsystem);
void www_client_thread_np(void* arg);
void* www_client_thread(void *arg);


#endif /*OR_WWW_H_*/
