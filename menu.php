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
?><tr><td><a href="<?=$url?>"><img name="menu_<?=$text?>" src="images/menu_<?=$text?>.gif" width="100" height="20" border="0" alt="<?=$alt?>" onmouseover="active('menu_<?=$text?>')" onmouseout="inactive('menu_<?=$text?>')"></a></td></tr><?
}
?>