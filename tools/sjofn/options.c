//---------------------------------------------------------------------------------------
// Generic Options Support
//
// Copyright (c) 2001, Stanislav Karchebny <berk@madfire.net>
// Distributed under BSD License.
//---------------------------------------------------------------------------------------

#include <stdio.h>
#include <string.h>
#include "options.h"

extern void error( const char *mess, ... );


#ifdef __DEBUG__
#define DEBUG(x) fprintf ## x ;
#else
#define DEBUG(x)
#endif


//------------------------------------------------------------------------
// Options Parser
//------------------------------------------------------------------------
int parse_cmdline( int argc, char **argv, opt_option *options, int nopts )
{
   int errors = 0;

   DEBUG(( stderr, "parse_cmdline: entered\n" ));

 fail:
   while( --argc )
   {
      argv++;

      if( argv[0][0] == '-' ) // opt
      {
         int got_it = 0;
         if( argv[0][1] == '-' ) // lopt
         {
            for( int i = 0; i < nopts; i++ )
            {
               if( strncmp( &argv[0][2], options[i].lopt, strlen(options[i].lopt) ) == 0 )
               {
                  char *param;
                  if( options[i].takes_param )
                  {
                     param = strchr( &argv[0][2], '=' );
                     if( !param ) { error( "option '--%s' needs an argument!", options[i].lopt ); errors++; goto fail; }
                     else         { *param = '\0'; param++; }
                  }
                  else param = NULL;

                  if( !options[i].handler( &argv[0][2], param, options[i].extra ) ) got_it = 1;
                  break;
               }
            }
            if( !got_it ) { error( "unrecognized option '%s'", argv[0] ); errors++; }
         }
         else                    // sopt
         {
            for( int i = 0; i < nopts; i++ )
            {
               if( argv[0][1] == options[i].sopt )
               {
                  char *cmd = &argv[0][1];
                  char *param;
                  if( options[i].takes_param )
                  {
                     param = argv[1];
                     if( *param == '-' || param == NULL ) { error( "option '-%c' needs an argument!", options[i].sopt ); errors++; goto fail; }
                     else                                 { argc--; argv++; }
                  }
                  else param = NULL;

                  if( !options[i].handler( cmd, param, options[i].extra ) ) got_it = 1;
                  break;
               }
            }
            if( !got_it ) { error( "unrecognized option '%s'", argv[0] ); errors++; }
         }
      }
      else // not an option, then it should be a file or something
      {
         not_an_option_handler( argv[0] );
      }
   }

   DEBUG(( stderr, "parse_cmdline: finished\n" ));
   return errors;
}

void help_msg( char *msg, char *tail, opt_option *options, int nopts )
{
   char optbuf[100], optopt[100];

   fprintf( stdout, msg );

   for( int i = 0; i < nopts; i++ )
   {
      optbuf[0] = 0;
      optopt[0] = 0;

      if( options[i].takes_param )
      {
         if( options[i].sopt )
         {
            sprintf( optbuf, "-%c <%s>", options[i].sopt,
                                         options[i].param_desc?options[i].param_desc:"param" );
         }
         if( options[i].sopt && options[i].lopt ) strcat( optbuf, ", " );
         if( options[i].lopt )
         {
            sprintf( optopt, "--%s=<%s>", options[i].lopt,
                                          options[i].param_desc?options[i].param_desc:"param" );
            strcat( optbuf, optopt );
         }
      }
      else
      {
         if( options[i].sopt )
         {
            sprintf( optbuf, "-%c", options[i].sopt );
         }
         if( options[i].sopt && options[i].lopt ) strcat( optbuf, ", " );
         if( options[i].lopt )
         {
            sprintf( optopt, "--%s", options[i].lopt );
            strcat( optbuf, optopt );
         }
      }

      fprintf( stdout, "    %-24s  ", optbuf );
      fprintf( stdout, options[i].description, options[i].extra );
      fprintf( stdout, "\n" );
   }

   fprintf( stdout, tail );
}
