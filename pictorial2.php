<?$page="pictorial";include("counter.php");include("header.php")?>

<?section_header("An Illustrated Guide")?>
<?section_header("Chapter 2: ORB Boot Up")?>
<br>
This chapter describes preparation procedures taken to start ORB up, including execution
of ORB constructor.<br>
After the <a href="pictorial1.php">Initial Boot Up</a> memory map looks like this:<br>
<br>
<div align=center><img src="images/pictorial2/start_mem.gif" alt="Memory Map Before ORB Boot Up Phase"></div>
<br>
The ORB bootstrap prepares two GDT entries for code and data matching ORB base and size exactly.
It also makes sure the size of the ORB and LibOS does not exceed 1Mb.<br>
<br>
<div align=center><img src="images/pictorial2/temp_gdt.gif" alt="Temporary GDT before jumping to ORB constructor"></div>
<br>
When all that is ready, we jump off into the ORB constructor!<br>
<br>
<?section_header("The ORB constructor")?>
<br>
After gaining control the ORB _immediately_ moves the library OS image up in memory before it gets
overwritten by ORB's BSS variables.<br>
<br>
<div align=center><img src="images/pictorial2/libos_up.gif" alt="LibOS is moved up to the very top of physical memory"></div>
<br>
<?section_header()?>

<?include("footer.php")?>