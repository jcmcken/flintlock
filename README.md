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
flintlock deploy git://github.com/jcmcken/flintlock-redis.git /some/empty/directory
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
|   `-- redis
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

### Stages

``flintlock`` has different "stages" of execution that occur in a specific order every time
you run a deployment.

These stages correspond directly to the scripts under ``bin/``.

The most important stages, and their purpose, are as follows. (The stages occur in the order listed below)

* ``detect``: Detect whether the module is compatible with the current host.
* ``prepare``: Install or compile any required dependencies. This script takes no arguments.
* ``stage``: Stage the application directories and files. This script takes a single argument,
  which is the directory where your app will be deployed. This directory need not exist, but if
  it does, it must be empty.
* ``start``: Start the application. This script takes the same argument passed to ``stage``.
* ``modify``: Once the application is started, perform some runtime modifications. For instance,
  if you've just started a MySQL server, you may want to remove the default tables or add a 
  password to the database superuser. This script takes the same argument passed to ``stage``
  and ``start``.

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
PORT=8080 flintlock deploy <module> <deploy_dir>
```

``flintlock`` will transparently override the default ``PORT`` with the env var passed at the
command line.

### Examples

Some example ``flintlock`` modules can be found @ the following locations:

* http://github.com/jcmcken/flintlock-redis.git
* http://github.com/jcmcken/flintlock-tomcat.git
