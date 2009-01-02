
%{
   #include <stdio.h>
   #include <stdlib.h>

   void yyerror(char *mess)
   {
      printf( "ERROR! %s\n", mess );
   }

   void
   yywrap()
   {
   }

   extern FILE *f;

   int yylex(void);
%}


%token id
%token modifer
%token kw_interface
%token type

%%
input : inf input
   |

inf   :  kw_interface id base body tail { fprintf( f, "***%s\0", $2 ); }
inf   :  kw_interface type base body tail {
                  if( $2 == 8 )
                     fprintf( f, "***thread\0" );
                  else
                  {
                     printf( "ERROR: invalid interface id\n" );
                     exit( 1 );
                  }
                    }

base  : ':' id { fprintf( f, "[%s]\n", $2 ); }
   |     { fprintf( f, "[-]\n" ); };

body  : '{' methods '}'

methods  : methods method ';'
   |

method   : type id '(' param_l ')' {     fprintf( f, " :" );
                 switch( $1 )
                 {
                 case 0:
                  fprintf( f, "uint" );
                  break;
                 case 1:
                  fprintf( f, "char*" );
                  break;
                 case 2:
                  fprintf( f, "int" );
                  break;
                 case 3:
                  fprintf( f, "comp&" );
                  break;
                 case 4:
                  fprintf( f, "uint32" );
                  break;
                 case 5:
                  fprintf( f, "uint64" );
                  break;
                 case 6:
                  fprintf( f, "char" );
                  break;
                 case 7:
                  fprintf( f, "void" );
                  break;
                 case 8:
                  fprintf( f, "thread&" );
                  break;
                 case 9:
                  fprintf( f, "cond&" );
                  break;
                 default:
                  printf( "Error! unknown return type!!\n" );
                 }
                 fprintf( f, " %s\n", $2 );
                 free( (void *)$2 );
            }

param_l  :
   | param
   | param ',' param_l

param : type id         {
                 switch( $1 )
                 {
                 case 0:
                  fprintf( f, "uint" );
                  break;
                 case 1:
                  fprintf( f, "const_pchar" );
                  break;
                 case 2:
                  fprintf( f, "int" );
                  break;
                 case 3:
                  fprintf( f, "comp&" );
                  break;
                 case 4:
                  fprintf( f, "uint32" );
                  break;
                 case 5:
                  fprintf( f, "uint64" );
                  break;
                 case 6:
                  fprintf( f, "char" );
                  break;
                 case 7:
                  fprintf( f, "void" );
                  break;
                 case 8:
                  fprintf( f, "thread&" );
                  break;
                 case 9:
                  fprintf( f, "cond&" );
                  break;
                 default:
                  printf( "Error! unknown parameter type!!\n" );
                 }
                 fprintf( f, " %s;", $2 );
                 free( (void *)$2 );
               }

   | id id           { printf( "Type error: Uknown type: %s\n", $1 );exit(1);}
   | id type         { printf( "Type error: Uknown type: %s\n", $1 );exit(1);}
   | type type       { printf( "Type error: Keyword %s used as parameter name\n", $2 );exit(1);}


tail  : ';'
