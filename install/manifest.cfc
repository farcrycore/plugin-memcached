<cfcomponent extends="farcry.core.webtop.install.manifest" name="manifest">

	<!--- IMPORT TAG LIBRARIES --->
	<cfimport taglib="/farcry/core/packages/fourq/tags/" prefix="q4">
	
	
	<cfset this.name = "Memcached" />
	<cfset this.description = "<strong>Memcached</strong> plugin replaces the default object and webskin caching mechanism in Core with an external memcached server." />
	<cfset this.lRequiredPlugins = "" />
	

</cfcomponent>