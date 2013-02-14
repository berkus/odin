<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0//EN">
<html>
<head>
   <meta name="description" content="Odin Operating System Development">
   <meta name="keywords"    content="Odin, Operating System, Core, OS, assembly, C, C++, ORB, exceptions, interrupts, source code, programmer, project, network, TCP, IPX, developer, kernel, Object Oriented, OO, Component, inter-process, IPC, open source">

   <title>&lt; odin &gt;</title>
   <link rel="stylesheet" href="odin.css" type="text/css">
   <script language="javascript" src="odin.js"></script>
</head>

<body bgcolor="#003f00" text="#ccffcc" link="#77ff77" alink="#ccffcc" vlink="#aaffaa">
<div align="center">
<table width="640" border="0" cellspacing="0" cellpadding="0">
<tr>
   <td align="center" colspan="3"><div class="topimage"><img src="images/odin-page-logo.gif" width="400" height="100" border="0" alt="ODIN"><br><br></div></td>
</tr>
<tr>
   <td valign="top" class="menu"><img src="images/empty.gif" width="120" height="0" border="0" alt="">
<?
   include( "menu.php" );
   include( "mainmenu.php" );
   echo "<br>";
   if( $ADDLEFTMENU != "" ) include( $ADDLEFTMENU."menu.php" );
?>
   </td>
   <td width="400" valign="top">
<? // here will be the content

$DLLOC = "download"; // download location, absolute or relative

include("people.php");

function emailto( $handle )
{
   global $people;

   if( $people[$handle] )
   {
      echo "<a href=\"mailto:".$people[$handle][email]."\">".$people[$handle][name]."</a>";
   }
   else
   {
      echo "<font size=\"+2\" color=\"red\">emailto() error: NO HANDLE</font>";
   }
}

function section_header( $header = "" )
{
   if( $header ) $height = 20; else $height = 24;
?><table width="100%" cellpadding="0" cellspacing="0" border="0"><tr><td background="images/header-filler.gif" width="100%" valign="top"><div class="sheader"><img src="images/empty.gif" width="1" height="<?=$height?>" alt=""><?=$header?></div></td></tr></table><?
}

function smallarrow()
{
?><img src="images/small-arrow.gif" width="16" height="16" border="0" alt=""><?
}

function start_bordered_table( $addargs = "" )
{
   global $HTTP_USER_AGENT;

   if( stristr( $HTTP_USER_AGENT, "Mozilla/4" ) && !stristr( $HTTP_USER_AGENT, "MSIE" ) ) $b = "border=1 ";
   echo "<table $b$addargs>";
}

function progress_bar( $done )
{
   $steps = 20;
?><img src="images/progress_left.gif" width="3" height="10" border="0" alt=""><?
   for( $i = 0; $i < $steps; $i++ )
   {
      if( $done > (100/$steps)*$i ) { ?><img src="images/progress_done.gif" width="12" height="10" border="0" alt=""><? }
      else                          { ?><img src="images/progress_empty.gif" width="12" height="10" border="0" alt=""><? }
   }
?><img src="images/progress_right.gif" width="3" height="10" border="0" alt=""> <?=$done?>%<?
}


?>