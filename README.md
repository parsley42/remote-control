# RC - Remote Control

rc is a tool for automating tasks with bash over ssh. Not having used ansible, (but having read some documentation), I would say it's basically "ansible lite" for bash hackers. It automates privilege escalation with sudo, can perform tasks on multiple hosts in parallel or serial, and has the flexibility to run individual commands, scripted tasks, or more complicated jobs consisting of multiple commands / tasks. All tasks / jobs are simple bash scripts, so the learning curve is theoretically lower.

For me it solves the problem of maintaining a set of shell scripts that are useful for the fleet of systems I manage, without having to deploy that script to said hosts. In fact, it's trivial to edit my script then run it on a test system, then on 50 systems, without copying or installing the script - it just gets piped over ssh.

Here's the output of `rc -h`:
```
Usage:
rc - Run a remote shell script/command over ssh on one or more hosts,
	 optionally with elevated privileges.

rc list sites
	List all sites
rc list tasks (<site>|user)
	List tasks
rc list hostgroups
	List hostgroups for the current site
rc list hostgroup <group>
	List all hosts in group <group>
rc list jobs (site)
	List all jobs for the current or specified site
rc (options) cmd "<command>" (hostspec)
	Run a single command
rc (options) job <jobname> <joboptions> <jobargs>
	Wrapper for exec'ing jobscripts/<job>
rc (options) <task> (taskoptions) (taskarguments) (hostspec)
	<task> is the name of the task to be run, e.g. 'whois'

	(hostspec) is required for commands or if there is no default hostspec
		for the task. It can be a single host (or alias), hostgroup, or
		a space-separated combination of hosts, aliases and hostgroups.

	(options) are options to rc which may override defaults from
	tasks.conf files
		-d <file>
			use <file> for the task .defs (variable definitions) file, possibly
			overriding a default
		-D
			dry-run, echo the output to be sent but don't send
		-h (task)
			print this help message or task help
		-H <host> | "<host> <host> ..." | @HOSTGROUP
			Override a default hostspec for a task
		-o <dir>
			Send output from task to <dir>/<hostname>.out
		-s <site>
			Use <site>
		-S
			Run multiple hosts in serial (default parallel)
		-t
			Set trace debugging during remote execution
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

## Development state

rc is currently still in flux. The command-line syntax probably won't change much, and the basic layout of site directories, but location and format of configuration files is still evolving. I just wanted to go ahead and push a version out to the world in case there are other bash afficionados who are looking for an alternative to ansible for automation and system configuration. So far there's not a big library of tasks and jobs, but I expect that to grow rapidly now that the basic structure is functioning.

If you're interested in using / hacking on this, shoot me an e-mail at parsley at linuxjedi dot org.