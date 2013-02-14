<?$page="milestones";include("counter.php");include("header.php")?>

<?section_header("milestone 1")?>
<?progress_bar(0)?>
<br>
Component model.<br>
Protection.<br>
Interfaces.<br>
Component interaction dynamics.<br>
<br>
<!--
<?section_header("milestone 2")?>
<?progress_bar(5)?>
<br>
GTE-like start-up library os. First versions of:
interrupt dispatcher, thread scheduler, memory manager, console.<br>
Generic (keyboard, mouse) I/O.<br>
Test versions of FDD/HDD I/O components. First filesystem support
(minimally required, e.g. simple FAT) components.<br>
<br>
<?section_header("milestone 3")?>
<?progress_bar(0)?>
<br>
idisp, sched, mem_mgr totally working and optimized.
generic i/o optimized. storage i/o optimized.<br>
first versions of orthogonal component persistence support.<br>
optimized filesystems support, more filesystems.<br>
First video drivers.<br>
<br>
<?section_header("milestone 4")?>
<?progress_bar(0)?>
<br>
component persistence working and optimized.<br>
more filesystems support and persistence emulation layer over
any arbitrary supported filesystem.<br>
video drivers optimized.<br>
first gui versions.<br>
<br>
<table border=0><tr>
<td valign=top>sidenote:</td>
<td>I think to experiment over on 3d gui concepts (such as seen
in first 3dtop 'filesystem in 3d' presentation models plus
various 3d 'fancies' for more productive work).<br>
currently i only have various ideas floating around.
we will discuss those later.
</td>
</tr></table>
<br>
<?section_header("milestone 5")?>
<?progress_bar(0)?>
<br>
networking drivers working. tcp/ip stack working.<br>
first versions of various protocols components.<br>
every protocol might be supported by separate component
that will save us from burden of keeping libraries and
stuff up to date etc etc etc (just change a component
and all programs start to use bugfixed code..)<br>
<br>
<?section_header("milestone 6")?>
<?progress_bar(0)?>
<br>
working gui.<br>
working network.<br>
most computer-devices-support components working.<br>
system is functional.<br>
start of applications. first thing to port: development
tools (at least asm and make).<br>
<br>
<?section_header("milestone 7")?>
<?progress_bar(0)?>
<br>
distributed components working.<br>
<br>-->
<?section_header()?>

<?include("footer.php")?>
