<?include("header.php");require("db.php");$db = new DB;?>

<?section_header("visits stats")?>
<br>
<table cellspacing=2 cellpadding=2>
<tr>
	<td bgcolor="#005600">page name</td>
	<td bgcolor="#005600">visits</td>
	<td bgcolor="#005600">last visit</td>
</tr>
<?
$pages = $db->query_array( "select page from visit_stats" );

for( $i = 0; $i < count($pages); $i++ )
{
	$p = $pages[$i][page];
	$r = $db->query( "select views,UNIX_TIMESTAMP(lastvisit) AS lastvisit from visit_stats where page='$p'" );
	echo "<tr><td>$p</td><td>$r[views]</td><td>".date("Y.m.d H:i:s", $r[lastvisit])."</td></tr>";
}
?>
</table>
<br>
<?section_header()?>

<?include("footer.php")?>
