<?$page="pictorial";include("counter.php");include("header.php")?>

<?section_header("An Illustrated Guide")?>
<?section_header("Chapter 1: Initial Boot Up")?>
<br>
I will skip many technical details about how the system powers up (you can find necessary
references at <a href="#bottom">bottom of this page</a>).

We will start at the moment BIOS is going to load our boot loader into memory and execute it.
Lets first take a look at how the boot image is structured on disk:<br>
<br>
<div align=center><img src="images/pictorial1/bootdisk.gif" alt="Boot Image Structure on Boot Media"></div>
<br>
And in detail:

<ul>
<li>Boot loader - its the thing the BIOS will load in the very first place. The purpose of the
boot loader is to load selected operating system in memory and pass control to it.
Odin bootloader is multiboot compliant (that is, it complies with the
<a href="guides.php#mboot">Multiboot standard</a>). However, this bootloader fits into 512 bytes
and therefore does not support extra facilities such as providing system memory map and
some others.</li>
<li>ORB bootstrapper - initializes environment so that ORB will find everything it expects to
find in their right places :). <b>Note</b> that ORB itself is not multiboot compliant and therefore
needs an Agent or a "proxy" that will be multiboot compliant and will give control to the ORB
after setting up correct environment.</li>
<li>The ORB image - its the ORB itself.</li>
<li>The Library OS bootstrapper image - its the library OS part that gets loaded before the
rest of the library OS and provides some basic functionality such as disk drives access and
basic filesystem support so the rest of the OS can be loaded. In very simple cases this
bootstrapper can be replaced with the OS itself - this is suitable for some simple testcases
or embedded systems.</li>
</ul>

<?section_header("Boot loader operation")?>
<br>
The first thing BIOS does is load the boot loader from boot media into memory at location
0x7c00 and passes control to it.<br>
<br>
<div align=center><img src="images/pictorial1/boot1.gif" alt="Boot Loader started off Boot Media"></div>
<br>
The bootloader performs these actions, in order:
<ul>
<li>CPU is checked to be 80386 or better, if it is not so, halt with error.</li>
<li>Address line A20 is enabled, so that addressing memory above 1Meg is possible.</li>
<li>Check is made to see if IBM/Microsoft extensions of BIOS disk service 0x13 are present,
if so LBA addressing is used, otherwise CHS addressing is used instead.</li>
<li>If loaded off any media other than Floppy Disk, partition table is read into memory
at location 0x7a000 and searched for a partition with code 0xAB
(Odin Persistence FS Partition). If this partition code is found, the system is going to load
off this partition, otherwise bootstrap is aborted with an error message.</li>
<li>The system (ORB bootstrapper, ORB and LibOS bootstrapper) is loaded into memory at
address 0x10000.</li>
<li>System is switched into protected mode.</li>
<li>Multiboot information header is prepared.</li>
<li>Image is moved to its destined location.</li>
<li>Control is passed to image entry point.</li>
</ul>
<div align=center><img src="images/pictorial1/boot2.gif" alt="Boot image prepared for bootstrap"></div>
<br>
Then the ORB bootstrapper comes into action, as depicted in <a href="pictorial2.php">Chapter 2</a>.<br>
<br>
<a name="bottom"/>
<?section_header("references")?>
<br>
<a href="guides/multiboot.html" target="_blank">Multiboot standard</a><br>
<a href="guides/Master_Boot_Record.txt" target="_blank">Master Boot Sector</a><br>
<a href="guides/Partition_Tables.txt" target="_blank">Partition Tables</a><br>
<a href="guides/DOS_Floppy_Boot_Sector.txt" target="_blank">DOS Boot Sector</a><br>
<a href="guides/OS2_Boot_Sector.txt" target="_blank">OS/2 Boot Sector</a><br>
<a href="guides/CHS_Translation.txt" target="_blank">CHS Translation</a><br>
<br>
<?section_header()?>

<?include("footer.php")?>