/*-----------------------------------------------------------------------------
 * file:   getarg.c
 * date:   Tue Mar 30 14:24:27 PST 2004
 * Author: Martin Casado
 *
 * Description:
 *
 * Extremely dopy method of extracting command line args by modifying
 * argc and argv. Intended for use by libraries that require command line
 * args (using getopt(..) is a bit inflexible for such things).
 *
 *---------------------------------------------------------------------------*/

#include <string.h>
#include <assert.h>

#include <stdio.h>

int getarg(int* argc, char*** argv, char* arg, char** val)
{
    int i = 0;

    assert(argc); assert(argv); assert(arg); assert(val);

    for ( i = 0 ; i < *argc; ++i)
    {
        if ( ! strcmp ( (*argv)[i], arg ) )
        { /* -- match -- */

            /* -- if last arg or next arg is a '-' assume no value.
             *    Remove arg and return                            -- */
            if ( i == (*argc) - 1 ||
                 (*argv)[i+1][0] == '-')
            {
                *val = 0; /* -- let caller know there was no value -- */
                (*argc) -- ;
                while ( i < *argc )
                { (*argv)[i] = (*argv)[i+1]; ++i;}
                return 1;
            }

            /* -- arg has value -- */
            *val = (*argv)[i+1];
            (*argc) -=2 ;
            while ( i < *argc )
            { (*argv)[i] = (*argv)[i+2]; ++i;}
            return 1;
        }
    }

    return 0; /* -- no matches found -- */
} /* -- getarg -- */

/* test with: ./a.out --icecream yummy -t hi -h
int main(int argc, char** argv)
{
    int i = 0;
    char argval[32];
    char* expval;



    for ( i = 0; i < argc; ++ i )
    { printf("[%s]",argv[i]); }
    printf("\n");

    if ( ! getarg(&argc, &argv, "-h", &expval) )
    { assert(0); }
    if ( expval )
    { assert(0); }

    for ( i = 0; i < argc; ++ i )
    { printf("[%s]",argv[i]); }
    printf("\n");

    if ( ! getarg(&argc, &argv, "-t", &expval ) )
    { assert(0); }
    if ( ! expval )
    { assert(0); }

    for ( i = 0; i < argc; ++ i )
    { printf("[%s]",argv[i]); }
    printf("\n");

    if ( getarg(&argc, &argv, "-x", &expval) )
    { assert(0); }

    for ( i = 0; i < argc; ++ i )
    { printf("[%s]",argv[i]); }
    printf("\n");

    if ( ! getarg(&argc, &argv, "--icecream", &expval ) )
    { assert(0); }
    assert(expval);


    assert(argc);
    for ( i = 0; i < argc; ++ i )
    { printf("[%s]",argv[i]); }
    printf("\n");

    return 0;
} */
