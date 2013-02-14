<? // a simple php/mysql counter
   // counter.php?page=<tablename>[&show=][&show_extra=]

require("db.php");
$db = new DB();

$timeout = 60; // seconds for single IP
$now = time(); // current time

// first off, remove all obsolete IPs
$db->query_raw( "delete from ipstore where $now-UNIX_TIMESTAMP(visit)>$timeout" );

$r = $db->query( "select * from ipstore where ip='$REMOTE_ADDR'" );

if( !$r ) {
   $db->query_raw( "insert into ipstore values ('$REMOTE_ADDR', now())" );
   $db->query_raw( "update visit_stats set views=views+1, lastvisit=now() where page='$page'" );
}

if( $show )
{
   $r = $db->query( "select views, UNIX_TIMESTAMP(since) AS since, UNIX_TIMESTAMP(lastvisit) AS lastvisit from visit_stats where page='$page'" );
   $count = $r["views"];
   $since = $r["since"];
   $visit = $r["lastvisit"];

   echo "page views: ";

   for($i = 0; $i < strlen($count); $i++)
   {
      $sign = substr($count, $i, 1);
      if( !file_exists("images/$sign.gif") ) echo "$sign";
      else echo "<img src=\"images/$sign.gif\" border=\"0\" alt=\"$sign\">";
   }

   if( $show_extra )
      echo "<br>last accessed:<br>" . date("d.m.Y H:i:s ", $visit) . "<br>running since: " .  date("d.m.Y ", $since);
}
?>