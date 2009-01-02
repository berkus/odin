# "Version Information"
# Copyright (C) 2001 by Next Generation
# Written by Chris Hansen.
# Modified for Odin by Stanislav Karchebny <berk@madfire.net>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# NEXT GENERATION on the Web: www.nextgeneration.dk
# CONTACT: info@nextgeneration.dk

BEGIN {
  i = 0
  split (ARGV[2], version, ".")

  while ((getline < ARGV[1]) > 0)
    {
      verinfo[i] = $0

      if($2 == "__odin_VERSION_MAJOR")
      {
  			verinfo[i] = sprintf ("%s %s\t%d", $1, $2, version[1])
      }

      if($2 == "__odin_VERSION_MINOR")
      {
  			verinfo[i] = sprintf ("%s %s\t%d", $1, $2, version[2])
      }

      if($2 == "__odin_VERSION_BUILD")
      {
  			build = $3
  			build++
  			if( build > 65535 )
  			{
  				build = 0
  				print "*\n* DAMN! You're a whacking builder!\n* I've reached top build count (65535). Increase major version!\n*"
  			}
  			verinfo[i] = sprintf ("%s %s\t%d", $1, $2, build)
      }

      i++
    }

  # Write the new version file
  print verinfo[0] > ARGV[1]
  f = 1
  while (f < i)
    {
      print verinfo[f] >> ARGV[1]
      f++
    }
}
