# Memcached Plugin V1

NOTE: Compatable with FarCry <=7.0.X

*Memcached is a commercial plugin (available with the FarCry Commercial Licence)*

Memcached replaces the default object and webskin caching mechanism in Core with 
an external memcached server. This is an excellent approach for moving memory load 
out of ColdFusion and off the application server. A key benefit for sites running 
in high availability environments is that all the application servers in the 
cluster can be made to share a central cache.

This plugin also works with Amazon ElastiCache.

![Server overview](install/screenshot_servers.png?raw=true "Server overview")
![Server breakdown](install/screenshot_server.png?raw=true "Server breakdown")
![Application breakdown](install/screenshot_application.png?raw=true "Application breakdown")
![Type breakdown](install/screenshot_type.png?raw=true "Type breakdown")

## Setup

1. Install [memcached][1]
2. Add this plugin to the project
3. Restart your application
4. Open the "Memcached" config
5. Copy in your server details, in the form "your.memcachedhost.com:11211" (if you 
   don't understand the other settings, it is safe to leave the default values)
6. Save the config
7. Restart the application
8. Test

## Testing / Debugging

### Logging

The plugin logs status and errors to "yourappname_memcached.log" using cflog. This 
will sometimes have information pertaining to the plugin's ability to access the 
memcached server.

### Reports

The memcached reports are accessible in the Webtop under Admin -> General Admin ->
Application Settings -> Memcached Summary.

The main screen has information about the general health of the memcached servers 
(or clusters, in the case of ElastiCache). You can drill down to a specific server 
or application by clicking "overview" or "this application".

*NOTE*: the information provided on the drill-down pages is aquired via an undocumented
feature of memcached which the developers are planning to deprecate.

*NOTE*: generating the drill-down reports can have a performance impact on the
application and memcached servers. If you have more than 100 000 items in your cache,
you may find that the reports time out.


[1]: http://memcached.org/