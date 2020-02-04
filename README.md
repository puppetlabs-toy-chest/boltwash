# boltwash

A [Wash](https://puppetlabs.github.io/wash/) plugin for [Bolt](https://puppetlabs.github.io/bolt/). This plugin presents a view of Bolt targets organized by groups, and allows you to navigate their filesystems
```
wash . > stree bolt
bolt
└── [group]
    └── [target]
        └── fs
```

As an example, suppose you have a cluster of machines that are having problems
```
wash bolt/webservers > ls
server1/
server2/
server3/
```
You've noticed an issue in one of their logs, and want to see if it's present everywhere
```
wash bolt/webservers > grep OutOfMemory */fs/var/log/syslog
server1/fs/var/log/syslog:Jan 28 12:09:34 server1 my-server[435]: ...java.lang.OutOfMemoryError...
server2/fs/var/log/syslog:Jan 28 12:09:43 server2 my-server[435]: ...java.lang.OutOfMemoryError...
server3/fs/var/log/syslog:Jan 28 12:09:01 server3 my-server[435]: ...java.lang.OutOfMemoryError...
```
Seeing that they're all experiencing these issues, let's see where the server process is still running
```
wash bolt/webservers > wps * | grep bin/java
server1     9027   12:10.02   /usr/bin/java -Xmx2048m -cp /opt/my-server/server.jar ...
server2    21204   12:13.02   /usr/bin/java -Xmx2048m -cp /opt/my-server/server.jar ...
```
Looks like they've restarted recently, and the server's not running on `server3`. Let's reconfigure the servers to allow more memory (using Bolt or by directly modifying config/service files) and restart them
```
wash bolt/webservers > bolt task run service -t webservers action=restart name=my-server
Started on server1...
Started on server2...
Started on server3...
Finished on server1:
  {
    "status": "MainPID=751,LoadState=loaded,ActiveState=active"
  }
Finished on server2:
  {
    "status": "MainPID=2927,LoadState=loaded,ActiveState=active"
  }
Finished on server3:
  {
    "status": "MainPID=21936,LoadState=loaded,ActiveState=active"
  }
Successful on 3 targets: server1,server2,server3
Ran on 3 targets in 1.91 sec
```

The Bolt plugin for Wash provides an accessible, interactive means of investigating multiple systems. Combined with Bolt inventory, it's natural to then take action with Bolt.

> Currently supports Bolt v1 and v2 inventories, but not inventory plugins.

## Installation and configuration

1. `gem install boltwash`
2. Get the path to the boltwash script with `gem contents boltwash`.
3. Add to `~/.puppetlabs/wash/wash.yaml`

    ```yaml
    external-plugins:
        - script: '/path/to/boltwash/bolt.rb'
    # Uncomment this to get the inventory from a Boltdir instead
    # of the default ~/.puppetlabs/bolt
    #bolt:
    #  dir: /path/to/boltdir
    ```
4. Enjoy!

> If you're a developer, you can use the bolt plugin from source with `bundle install` and set `script: /path/to/boltwash/bolt`.

## Quirks

When sending complex commands over WinRM, you can pass the command as a single string with appropriate escaping, as in
```
wash bolt/win > wexec target 'Get-Process | Where StartTime -gt $([DateTime]::Today)'
```

## Future improvements

* Bolt inventory plugins
* Implement the 'metadata' method to retrieve facts
