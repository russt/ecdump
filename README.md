Ecdump
======
Dumps out user source code from an Electric Commander database to the local file system, in a form that can be submitted to a Source Control Management system.

Currently dumps named EC projects, including the procedure and property hierarchies, as well as the resource pool definitions.

Automation scripts are provided that can be used to periodically submit changes to a Perforce server, via the Perforce Git Fusion product.

The ecdump program is implemented in Perl, but uses Java JDBC for database connectivity.

System Requirements:
====================
* Perl 5.8.x, with Inline::Java and JDBC.pm installed.  (Later versions of perl will *not* work with Inline::Java).
* JDBC driver for MySql.  Other databases are possible, but not tested.

See Also:
=========
Help message:  `ecdump -help`

The automation scripts and some examples can be found in the directory: `tl/src/cmn/ecdump/scripts`
