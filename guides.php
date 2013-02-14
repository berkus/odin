<?$page="guides";include("counter.php");include("header.php")?>

<?section_header("site docs")?>
<br>
<a name="guide"></a>
<a href="pictorial.php">An Illustrated Guide</a> to the Odin internals and functionality,<br>
by Stanislav Karchebny, online doc<br>
As title says, this is highly illustrated guide describing various Odin operating internals,
starting from very boot up process and into every piece of run-time operation.<br>
Recommended for people trying to understand "under-the-hood" operation of Odin.<br>
<br>
<?section_header("misc docs")?>
<br>
<a name="mboot"></a>
<a href="<?=$DLLOC?>/multiboot-0.6.90.tar.gz">Multiboot standard 0.6.90</a>,<br>
original location: <a href="http://voyager.sparta.lu.se/doc/grub/multiboot.html">http://voyager.sparta.lu.se/doc/grub/multiboot.html</a><br>
Obviously, Multiboot standard is one of the most important standards to the OS writers,
because it describes an uniform way of bootstrapping various operating systems and
therefore lowers the burden associated with having many operating systems on one computer.<br>
<br>
<a href="<?=$DLLOC?>/os-research.pdf">System Software Research is Irrelevant</a>,<br>
by Rob Pike, Bell Labs, 25Kb<br>
A nice paper on topic. Be sure to read it right away!<br>
<br>
<a href="<?=$DLLOC?>/vade.mecum.pdf.gz">An Operating Systems Vade Mecum</a>,<br>
by Raphael A. Finkel, University of Wisconsin at Madison, 1Mb<br>
One of the best works describing internals of an operating system in easy and
educational way. A lot of primers and excercises make it valuable for personal
study as well as university use.<br>
<br>
<?section_header()?>

<?include("footer.php")?>