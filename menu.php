<?
function menu_start()
{
?><table border="0" cellspacing="0" cellpadding="0" align="center"><?
}
function menu_stop()
{
?></table><?
}
function menu_item( $text, $alt = "", $url = "" )
{
	$url = $url?$url:"$text.php";
?><tr>
}
?>