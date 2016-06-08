# RC - Remote Control

rc is a tool for automating tasks with bash over ssh. Not having used ansible, (but having read some documentation), I would say it's basically "ansible lite" for bash hackers. It automates privilege escalation with sudo, can perform tasks on multiple hosts in parallel or serial, and has the flexibility to run individual commands, scripted tasks, or more complicated jobs consisting of multiple commands / tasks. All tasks / jobs are simple bash scripts, so the learning curve is theoretically lower.

For me it solves the problem of maintaining a set of shell scripts that are useful for the fleet of systems I manage, without having to deploy that script to said hosts. In fact, it's trivial to edit my script then run it on a test system, then on 50 systems, without copying or installing the script - it just gets piped over ssh.

Here's the output of `rc -h`:
```
Usage:
rc - Run a remote shell script/command over ssh on one or more hosts,
	 optionally with elevated privileges.

rc list / rclist:
rclist sites
	List all sites
rclist tasks (<site>|user)
	List tasks
rclist hostgroups
	List hostgroups for the current site
rclist hostgroup <group>
	List all hosts in group <group>
rclist jobs (site)
	List all jobs for the current or specified site

rc cmd / rccmd:
rccmd (options) "<command>" (hostspec)
	Run a single command

rc run / rcrun:
rcrun (options) <job> (help | "var=value" ...)
	Run a job with the given variables (which may override defaults)

rc resume <jobid> ("var=value" ...)

rc do / rcdo:
rcdo (options) <task> (taskoptions) (taskarguments) (hostspec)
	<task> is the name of the task to be run, e.g. 'whois'

	(hostspec) is required for commands or if there is no default hostspec
		for the task. It can be a single host (or alias), hostgroup, or
		a space-separated combination of hosts, aliases and hostgroups
		enclosed in quotes.

	(options)
		-c
			(jobs only) Require confirmation before job runs
		-d <file>
			Specify a .defs file that is evaluated after any/all
			configured definitions file (for jobs and tasks)
		-D
			dry-run, echo the output to be sent but don't send (tasks)
		-h (task)
			print this help message or task help
		-H <host> | "<host> <host> ..." | @HOSTGROUP
			Override a default hostspec for a task
		-E (lib ... lib)
			Don't send remote libraries, e.g. -E errtrap.sh
		-o <dir>
			Send output from task to <dir>/<hostname>.out
		-p
			(jobs only) prompt user for all vars
		-s <site>
			Use <site>
		-S
			Run multiple hosts in serial (default parallel)
		-t
			Set trace debugging during task/job execution
	(taskoptions)
		'-h' will give usage for the task
	(arguments) are any arguments required by the task
```

Other features:

 * bash passdaemon for caching a password needed for remote sudo, useful for jobs scheduled with at or cron
 * support for multiple sites with custom configuration (mainly RCELEVATETYPE)

Planned features / TODO items:
 * localhost operation
 * a set of tasks and configure job for general-purpose system configuration
 * reasonable semantics and implementation of running jobs in parallel on multiple hosts
 * a libsremote library for requiring non-standard packages; e.g. requirepkg jq

## Requirements

### SSH

`rc` requires all hosts managed to be reachable via ssh `host`, and makes no
provision for configurable bastion hosts or login user names, for example.
While it's possible to configure aliases for hosts in a .hosts hostgroup file,
the practice is discouraged, as such configuration should be in the user's
`.ssh/config`.

### Managed hosts

As `rc` relies on `bash` for scripting, the reqrirements for managed hosts are
fairly minimal. A somewhat recent version of bash (certainly bash 4+), GNU
core utils, grep, sed and friends, and whatever other CLI commands are needed
by your tasks.

## Sites

rc needs an RCSITEDIR directory for user content, normally it's own git repository. `defaults` contains tasks and jobs that ship with rc; these are mostly examples for reference, though some of them may be useful for your site(s). `$RCSITEDIR/common` is for tasks, task configurations, and jobs that are common to all the sites you manage. Other subdirectories of `$RCSITEDIR/` are for grouping tasks, jobs and hostgroups. For example

* $RCSITEDIR/common - might contain a `deploy` task common to all of your sites
* $RCSITEDIR/mysite - might contain an `update` task and hostgroups for your site
* $RCSITEDIR/mylegacysite - might contain an `update` task and hostgroups for your legacy servers

When searching for task configuration, tasks, jobs, and definitions files, rc searches in this order:
* $RCSITEDIR/$RCDEFAULTSITE (from ~/.rcsite, RCDEFAULTSITE environment variable, or -s option)
* $RCSITEDIR/common
* defaults

## Definitions files

Definitions files are simple snippets of bash scripts with variable
definitions. A given task can specify the name of a definitions file to use,
and rc will search for it as listed above. Additionally, if $RCSITEDIR/site.defs
exists, it will be sourced before the task-specified file (or one specified as
an option to rc).

## Development state

rc is currently still in flux. The command-line syntax probably won't change much, and the basic layout of site directories, but location and format of configuration files is still evolving. I just wanted to go ahead and push a version out to the world in case there are other bash afficionados who are looking for an alternative to ansible for automation and system configuration. So far there's not a big library of tasks and jobs, but I expect that to grow rapidly now that the basic structure is functioning.

If you're interested in using / hacking on this, shoot me an e-mail at parsley at linuxjedi dot org. Taking a line from ESR - "release early, release often"
