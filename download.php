<?$page="download";include("counter.php");include("header.php")?>

<?section_header("bootimage")?>
<br>
<a href="<?=$DLLOC?>/odinboot.img">Bootimage</a>, Odin 1.2 build 140<br>
<dt>Under Linux:</dt>
<dd>dd if=odinboot.img of=/dev/fd0 bs=512</dd>
<dt>Under DOS/Windows:</dt>
<dd>use <a href="<?=$DLLOC?>/rawrite.exe">rawrite</a> -d a: -f odinboot.img</dd>
You can obtain rawrite.exe and fdimage.exe from <a href="http://www.kiarchive.ru/pub/FreeBSD/tools/" target="_blank">kiarchive</a><br>
<br>
<?section_header("tools")?>
<br>
Latest <a href="http://nasm.2y.net">NASM</a> always at The Official NASM Site.<br>
<br>
<?section_header()?>

<?include("footer.php")?>
