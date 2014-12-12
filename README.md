# flintlock

``flintlock`` is a simple application deployer inspired by Heroku's buildpacks. 

At its core, it's a simple scripting API which allows developers/ops the ability
to create re-usable application deployments. In ``flintlock``, these deployments 
are called "modules".

## Installation

The latest release of ``flintlock`` will be published to ``rubygems.org``. To install,
just run:

```console
$ gem install flintlock
```

If you're running on a RHEL/CentOS 6 machine (or derivative), you might be able to
make use of the ``flintlock`` RPM spec file located in the git repository 
(``flintlock.spec``) to build RPM packages. Assuming all of the dependencies are
installed, this should just be a matter of running:

```console
$ rpmbuild -ba flintlock.spec --define "scl ruby193"
```

## Tutorial

Let's deploy a sample ``redis`` module I've written. This tutorial assumes you 
are running on a CentOS 6 machine with access to the EPEL package repository.
You'll also need ``git``.

After installing ``flintlock``, run the following:

```console
$ flintlock deploy git://github.com/jcmcken/flintlock-redis.git /some/empty/directory
```

In this case, the ``deploy`` command will recognize that you want to deploy from ``git``.
It will clone the remote repository, stage it, and then begin deploying the necessary
files and directories to ``/some/empty/directory``. Let's see what happens:


```console
$ flintlock deploy git://github.com/jcmcken/flintlock-redis.git /some/empty/directory
         run  fetching module
         run  detecting compatibility
        info  deploying jcmcken/redis (0.0.1) to '/some/empty/directory'
      create  creating deploy directory
         run  installing and configuring dependencies
      create  staging application files
         run  launching the application
         run  altering application runtime environment
         run  verifying the app is still up
        info  complete!
$
```

Assuming the module was written well enough, these messages should indicate that our
``redis`` server is running. Let's verify:

```console
$ ps -ef | grep redis
jcmcken  24846     1  0 17:41 ?        00:00:00 /usr/sbin/redis-server /some/empty/directory/etc/redis.conf
jcmcken  24865 19343  0 17:41 pts/1    00:00:00 grep redis
```

Let's take a look at the deploy directory, ``/some/empty/directory``:

```console
$ tree /some/empty/directory
/some/empty/directory
|-- bin
|   |-- defaults
|   |-- redis
|   |-- start
|   |-- status
|   `-- stop
|-- data
|-- etc
|   `-- redis.conf
|-- log
|   |-- redis.log
|   |-- stderr.log
|   `-- stdout.log
`-- run
    `-- redis.pid
```

You'll notice that everything for this ``redis`` server is self-contained within our deploy
directory. This is a central tenet of ``flintlock``:

**An application deployment is always self-contained within a single directory**

How well an application adheres to this philosophy depends on the application. For instance,
some applications may not have configurable ``/tmp`` directories. For transient data, this
is usually acceptable. But all of the important files should really be located together.

As a simple example, consider a Java application. On Linux, Java will store temporary files
at ``/tmp``. You can override this with the system property ``java.io.tmpdir``, e.g.
``java -Djava.io.tmpdir=/path/to/tmpdir ...etc...``.

## Supported Formats

Currently ``flintlock`` can install modules from a number of sources:

* From a local directory
* From a local tarball (``tar`` or ``tar.gz``)
* Over ``git`` supported protocols (``git://..``)
* Over ``svn`` supported protocols (``svn://...``)
* ``tar`` or ``tar.gz`` over ``http``/``https``

Attempting to install any other way will throw an error message similar to the following:

```console
         run  fetching module
       error  don't know how to download 'https://github.com'!
```

## Writing a Module

### Introduction

``flintlock`` modules are simply a bunch of scripts which follow a certain convention.

At its heart, a module has the following minimal layout:

```text
sample-app-1
|-- bin
|   |-- defaults
|   |-- detect
|   |-- modify
|   |-- prepare
|   |-- stage
|   |-- start
|   |-- status
|   `-- stop
`-- metadata.json
```

Running ``flintlock new`` in an empty directory of your choosing will automatically
generate this structure.

The top-level directory (in this case, ``sample-app-1``) can be called anything. 

The files under ``bin`` are executable scripts (using any language you care to
use). More on these later.

The ``metadata.json`` file contains metadata about the module. This metadata looks as follows:

```json
{
  "author": "jcmcken",
  "name": "sample-app-1",
  "version": "0.0.1"
}
```

All three keys (``author``, ``name``, ``version``) are required, but can be any value
(as long as they're not the empty string). These metadata are merely used to namespace 
the module.

``flintlock`` developers can choose to include more files in their modules if needed.
For example, you may want to create a directory called ``artifacts`` which contains
non-``flintlock`` files that you're going to stage with the application.

### Stages

``flintlock`` has different "stages" of execution that occur in a specific order every time
you run a ``deploy``.

These stages correspond directly to the scripts under ``bin/``.

The most important stages, and their purpose, are as follows. (The stages occur in the order listed below)

* ``detect``: Detect whether the module is compatible with the current host.
* ``prepare``: Install or compile any required dependencies. This script takes no arguments.
* ``stage``: Stage the application directories and files. This script takes a single argument,
  which is the directory where your app will be deployed. This directory need not exist, but if
  it does, it must be empty. 
* ``start``: Start the application. This script takes no arguments.
* ``modify``: Once the application is started, perform some runtime modifications. For instance,
  if you've just started a MySQL server, you may want to remove the default tables or add a 
  password to the database superuser. This script takes a single argument, which is the directory
  where your app will be deployed.
* ``status``: Determine if the application is running. This is the final stage. This script 
  takes no arguments. If the script's exit code is ``0``, ``flintlock`` assumes the app is
  running. If the exit code is not ``0``, ``flintlock`` assumes the app is stopped.

The API between these scripts and ``flintlock`` is as follows:

* If the script exits with a return code of ``0``, ``flintlock`` will think that the script
  succeeded.
* If the script exits with a return code of ``1``, ``flintlock`` will think that the script
  has failed.
* Any other return code, and ``flintlock`` will think that some sort of internal error has
  occurred. In other words, something outside of the script's control failed.

When ``flintlock`` encounters a non-zero exit code, it will halt execution and display an
error.

### Configuration Defaults

A ``flintlock`` module may also choose to utilize the ``bin/defaults`` script to set
configuration defaults.

By default, ``flintlock`` will source this script prior to executing any of the other 
stages.

A user can choose to override these defaults at the command line. For example, if your
``defaults`` script looks like:

```bash
PORT=80
```

The user can override this at the command line by running:

```console
$ PORT=8080 flintlock deploy <module> <deploy_dir>
```

``flintlock`` will transparently override the default ``PORT`` with the env var passed at the
command line.

Alternatively, you can populate ``defaults`` scripts and just ``source`` them as needed. 
For example:

```console
$ source dev-defaults.sh
$ flintlock deploy <module> /path/to/dev-app
...snip...
$ source prod-defaults.sh
$ flintlock deploy <module> /path/to/prod-app
...snip...
```

### Deployment Integrity

In addition to a framework for deploying applications, ``flintlock`` also provides
facilities for verifying the integrity of each deployment. While these facilities
do not provide cryptographic integrity (yet), they do provide a convenient way
of encouraging good deployment practices.

To verify a particular deployment, simply run the following:

```console
$ flintlock diff /path/to/deployment
``` 

If this prints nothing, that means your deployment has not been altered. Otherwise,
a unified diff will be printing showing the changes that have been made.

How does this work? 

Under the hood, during the ``stage`` stage of a deployment, ``flintlock`` stores every
staged file in content-addressable storage (CAS) on the filesystem. CAS is a storage
mechanism whereby files are identified by a checksum representing their content rather
than by file name.

In the case of ``flintlock``, every staged file has its SHA256 checksum computed and
its content stored in the CAS. ``flintlock`` then generates a manifest containing the
list of files and their checksums. 

When you run a ``flintlock diff``, this manifest is examined and verified against the 
corresponding files in the CAS. It then prints the differences between what ``flintlock``
deployed and what exists currently within the deployment directory.

Keep in mind that the purpose of these facilities is not to absolutely prevent bad 
behavior -- it's relatively trivial to defeat these protections. Instead, the purpose
is to make it easy to catch yourself in bad habits. Having deterministic, well-defined
deployments is for the benefit of you, the user, not of the tool itself.

### Deployment Philosophy

``flintlock`` attempts to encourage good behavior in application deployments. In
particular, that: 

* Deployments should have a consistent structure.
* Deployments should be configurable, not static.
* Deployments should be self-contained.
* Deployments should be reproducible and repeatable by anyone, assuming they meet
  the requirements for a particular module (e.g. the ``detect`` script).
* Deployments should be shareable.
* Deployments should be immutable.
* Deployments should be verifiable.

Although users have full flexibility to use the tool however they want, the following 
practices should be shunned and vilified:

* Manually altering an application deployment by hand. In other words, running ``flintlock deploy``
  to launch an app, and then going in and manually re-configuring it. This just violates the entire
  purpose of the tool. You might as well just distribute your app in a tarball if you're going to
  do this.
* Trying to circumvent or misuse ``flintlock``'s workflow. Application deployments should be
  self-contained. You should not be trying to start app ``A`` from the ``start`` script of app
  ``B``. App ``A`` should never have any direct knowledge of anything except itself. If you 
  have some dependency between two applications, manage this externally.

### Examples

Some example ``flintlock`` modules can be found @ the following locations:

* http://github.com/jcmcken/flintlock-redis.git
* http://github.com/jcmcken/flintlock-tomcat.git
