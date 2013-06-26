<cfcomponent extends="farcry.core.packages.forms.forms" displayname="Memcached" hint="Memcached object broker settings" key="memcached">

	<cfproperty name="servers" type="longchar" required="false" 
		ftSeq="1" ftWizardStep="" ftFieldset="Memcached" ftLabel="Servers"
		ftHint="One server per line in the form 'hostname:port'. NOTE: you can also enter an Amazon ElastiCache configuration endpoint.">

	<cfproperty name="protocol" type="string" required="false" 
		ftSeq="2" ftWizardStep="" ftFieldset="Memcached" ftLabel="Protocol" 
		ftType="list" ftDefault="binary" 
		ftList="TEXT:Text,BINARY:Binary"
		ftHint="NOTE: this is not used when the server is an Amazon ElastiCache configuration endpoint.">

	<cfproperty name="locator" type="string" required="false" 
		ftSeq="3" ftWizardStep="" ftFieldset="Memcached" ftLabel="Locator" 
		ftType="list" ftDefault="ARRAY_MOD" 
		ftList="ARRAY_MOD:Array modulus,CONSISTENT:Consistent hash algorithm,VBUCKET:vBucket"
		ftHint="NOTE: this is not used when the server is an Amazon ElastiCache configuration endpoint.">
	
	<cfproperty name="operationTimeout" type="string" required="false" 
		ftSeq="4" ftWizardStep="" ftFieldset="Memcached" ftLabel="Operation Timeout" 
		ftType="integer" ftDefault="2500"
		ftHint="NOTE: this is not used when the server is an Amazon ElastiCache configuration endpoint.">
	
	
	<cffunction name="process" access="public" output="false" returntype="struct">
		<cfargument name="fields" type="struct" required="true" />
		
		<cfset application.fc.lib.objectbroker.cacheInitialise(arguments.fields) />
		
		<cfreturn fields />
	</cffunction>
	
</cfcomponent>