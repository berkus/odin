%{
   #include "idlc.tab.h"
   #include <stdlib.h>
   #include <string.h>

   extern int yyparse(); /* you just SHUT UP! */

   /* Some versions of flex want this.  */
   #ifndef yywrap
   //int yywrap () { return 1; }
   #endif

   #define diag(s) /* printf( "lex: " ); printf */

	static void comment();

   FILE *f;

   #define PROGRAM_NAME "idlc: "


   int main( int argc, char *argv[] )
   {
      const int BUFF_LEN = 128;

      int ret_val;
      char *in_name;
      char *out_name;
      char out_buff[ BUFF_LEN ];

      printf( "idl compiler -- version 1.0.1 -- compiled " __DATE__ " " __TIME__ "\n" );

      /*
       *Ensure command line grammar is OK
       */

      if( ( argc != 2 && argc != 4 ) ||
         ( argc == 4 && strcmp( argv[1], "-o" ) )
        )
      {
         printf( "Copyright (c) Greg Law <glaw@nexwave-solutions.com>\n"
                 "Distributed under GNU Public License.\n"
                 "\n"
                 "Usage: idlc [ -o output.inf ] input.idl\n" );
         return 3;
      }

      /* printf( PROGRAM_NAME "Started ok...\n" ); */

      /*
       *Work out input and output file names
       */
      in_name = argv[ argc - 1 ];   //input file is last arg.
      yyin = fopen( in_name, "rb" );
      if( yyin == 0 )
      {
         printf( "Cannot open %s for reading.\n", in_name );
         return 1;
      }

      /* printf( PROGRAM_NAME "Opened input file %s\n", in_name ); */

      if( argc == 4 )
         out_name = argv[ 2 ];      //if out name specified with -o
      else
      {
         strncpy( out_buff, strtok( in_name, "." ), BUFF_LEN - 4 );
         out_name = strcat( out_buff, ".inf" );
      }
      f = fopen( out_name, "wb" );
      if( f == 0 )
      {
         printf( "Cannot open %s for writing.\n", out_name );
         return 2;
      }

      /* printf( PROGRAM_NAME "Opened output file %s\n", out_name ); */

      ret_val = yyparse();
      if( ret_val == 0 )
      {
         fprintf( f, "***\n" );
	      fclose( f );
	   }
      else
      {
         //printf( "PARSE ERROR!\n" );
         fclose( f );
         remove( out_name );
      }

      /* printf( PROGRAM_NAME "Parsing complete...thankyou\n" ); */

      exit( ret_val ); /* berk: return was returning -1 even on good exits */
      return ret_val;
   }

%}

%%

[ \t\n\r]         /*eat white space*/
"//"[^\n]*"\n"    /*eat one-line comment*/
"/*"              { diag("comment\n");   comment();                                 }
interface         { diag("interface\n"); return kw_interface;                       }
uint              { diag("uint\n");      yylval = 0; return type;                   }
string            { diag("string\n");    yylval = 1; return type;                   }
int               { diag("int\n");       yylval = 2; return type;                   }
comp              { diag("comp\n");      yylval = 3; return type;                   }
uint32            { diag("uint32\n");    yylval = 4; return type;                   }
uint64            { diag("uint64\n");    yylval = 5; return type;                   }
char              { diag("char\n");      yylval = 6; return type;                   }
void              { diag("void\n");      yylval = 7; return type;                   }
thread            { diag("thread\n");    yylval = 8; return type;                   }
cond              { diag("cond\n");      yylval = 9; return type;                   }
[A-z][A-z0-9]*    { diag("id\n");        yylval = (int)strdup( yytext ); return id; }
\&                { diag("&modifier\n"); yylval = yytext[0]; return modifer;        }
.                 { diag("anything\n");  return *yytext;                            }

%%

/* Eat the rest of a C-style comment.  */

static void comment()
{
  int c;

  diag("inside comment\n");

  while (1)
  {
    c = input();
    while (c != '*' && c != EOF)
    {
      c = input();
    }

    if (c == '*')
    {
      c = input();
      while (c == '*')
       c = input();
      if (c == '/')
       break;			/* found the end */
    }

    if (c == EOF)
    {
      printf( "ERROR: EOF in comment\n");
      break;
    }
  }
}
