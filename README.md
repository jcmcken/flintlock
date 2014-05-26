# flintlock

``flintlock`` is a simple application deployer inspired by Heroku's buildpacks. 

At its core, it's a simple scripting API which allows developers/ops the ability
to create re-usable application deployments. In ``flintlock``, these deployments 
are called "modules".

## Tutorial

Let's deploy a sample ``redis`` module I've written. This tutorial assumes you 
are running on a CentOS 6 machine with access to the EPEL package repository.

After installing ``flintlock``, run the following:

```shell-session
flintlock deploy git://github.com/jcmcken/flintlock-redis.git /some/empty/directory
```

In this case, the ``deploy`` command will recognize that you want to deploy from ``git``.
It will clone the remote repository, stage it, and then begin deploying the necessary
files and directories to ``/some/empty/directory``. Let's see what happens:


```shell-session
$ flintlock deploy git://github.com/jcmcken/flintlock-redis.git /some/empty/directory
         run  fetching module
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

```shell-session
$ ps -ef | grep redis
jcmcken  24846     1  0 17:41 ?        00:00:00 /usr/sbin/redis-server /some/empty/directory/etc/redis.conf
jcmcken  24865 19343  0 17:41 pts/1    00:00:00 grep redis
```

Let's take a look at the deploy directory, ``/some/empty/directory``:

```shell-session
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

## Writing a Module

### Introduction

``flintlock`` modules are simply a bunch of scripts which follow a certain convention.

At its heart, a module has the following minimal layout:

```text
sample-app-1
|-- bin
|   |-- defaults
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

The files under ``bin`` are executable scripts (using any language you care to use). All
of these scripts must exist, but they need not do anything. More on these later.

The ``metadata.json`` file contains metadata about the module. This metadata looks as follows:

```json
{
  "author": "jcmcken",
  "name": "sample-app-1",
  "version": "0.0.1"
}
```

All three keys (``author``, ``name``, ``version``) are required, but can be any value. These
metadata are merely used to namespace the module.

``flintlock`` developers can choose to include more files in their modules if needed.

### Stages

``flintlock`` has different "stages" of execution that occur in a specific order every time
you run a deployment.

These stages correspond directly to the scripts under ``bin/``.

The most important stages, and their purpose, are as follows. (The stages occur in the order listed below)

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

```shell-session
PORT=8080 flintlock deploy <module> <deploy_dir>
```

``flintlock`` will transparently override the default ``PORT`` with the env var passed at the
command line.

### Examples

An example ``flintlock`` module can be found @ http://github.com/jcmcken/flintlock-redis.git.
