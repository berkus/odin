//---------------------------------------------------------------------------------------
// Generic Options Support
//
// Copyright (c) 2001, Stanislav Karchebny <berk@madfire.net>
// Distributed under BSD License.
//---------------------------------------------------------------------------------------

#ifndef __MADFIRE_generic_options_h
#define __MADFIRE_generic_options_h


// an option structure
// operate on either -sopt, --lopt, -sopt <val> or --lopt=<val>

typedef struct opt_option
{
   char   sopt;
   char  *lopt;
   int    takes_param;                                     // !=0 if option requires parameter, 0 if no parameter
   int  (*handler)(char *cmd, char *param, int extra);
   int    extra;                                           // extra value for handler
   char  *description;                                     // description to use in help_msg()
   char  *param_desc;                                      // optional description for the param taken (short - will be printed after option sopt/lopt)
};

// handle everything that is not an option
extern int not_an_option_handler( char *param );


// parse command line calling handlers when appropriate
// argc, argv - pass directly from main(argc,argv)
// options - array of options
// nopts - options count
int parse_cmdline( int argc, char **argv, opt_option *options, int nopts );

// display help message msg followed by list of options in options and followed by tail
void help_msg( char *msg, char *tail, opt_option *options, int nopts );


#endif
