<cfsetting enablecfoutputonly="true" />
<!--- @@fuAlias: key --->

<cfset memcached = createobject("component","farcry.plugins.memcached.packages.lib.memcached") />
<cfset memcachedClient = application.fc.lib.objectbroker.getMemcached() />
<cfset data = memcached.get(memcachedClient, url.key) />

<cfoutput><h1>#url.key#</h1></cfoutput>

<cfdump var="#data#">

<cfsetting enablecfoutputonly="false" />