# Memcached Plugin

NOTE: This plugin is compatible with FarCry 7.1.0 and over.

*Memcached is available under LGPL and compatible with the open source and commercial licenses of FarCry Core*

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

## Cache Invalidation

Updating or restarting the application does _not_ clear the cache. See the following
sections for the different ways to invalidate cache data.

### COAPI deployments

Content type data is cache keys include the last schema change date for that type.
Deploying schema updates automatically causes the app to stop using previous cache
items.

*NOTE*: other servers will conetinue to use the old cache items until you update the
application to refresh the schema change dates. This allows you to deploy changes
on one server without breaking the site on another unupdated server.

### Rebuild Site

This option, in the Tray, invalidates every key used by the site, and will affect
every server using the same Memcached server.

### Fine Grained

The Memcached page in the webtop (Admin -> General Admin -> Application Settings -> 
Memcached Summary) has options for manually triggering invalidation either across the
entire application or for specific sections of the cache.

[1]: http://memcached.org/
