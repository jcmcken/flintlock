# Version 0.2.0

- Added the ``package`` subcommand, which packages up a local directory into
  a module archive.
- Added the ``defaults`` subcommand, which prints out the default configuration
  (from ``bin/defaults``) of the given module.
- Added the ``new`` subcommand, which generates an empty template module 
- Added the ``version`` subcommand, which prints the ``flintlock`` version
- Added the ``--halt`` option to the ``deploy`` subcommand. This allows users
  to halt deployment after a particular stage has run (e.g. ``--halt stage``)
- Added a new optional deployment stage called ``detect``. This script should be
  used to validate whether the module is appropriate for installation on the 
  current host.
- Fixed a bug that prevented scripts that required a TTY from working.
- Fixed a bug with relative paths passed to the ``deploy`` command
- Module scripts are now silently skipped if they don't exist or are empty
  (rather than erroring out).
- Fixed a bug where a ``/tmp`` filesystem mounted ``noexec`` would prevent 
  scripts from running.
- Can now deploy from local tarballs
- Can now deploy from subversion repositories
- Keyboard interrupts (``SIGQUIT``) are now caught and a nicer error is printed.
- External commands (e.g. ``git``, ``svn``) are validated prior to being run.
- Support a wider array of module URIs (e.g. ``svn+ssh://...``)
- Archives with root directories are now supported as valid module archives 
  (e.g. ``<archive_root>/<root_dir>/bin/*`` vs ``<archive_root>/bin/*`` layouts)
- Archive detection now uses MIME hinting rather than filename hinting
- Fixed a few issues with the RPM spec file

# Version 0.1.0

- Initial release.
