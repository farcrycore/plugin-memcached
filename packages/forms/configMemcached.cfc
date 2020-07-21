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
		ftType="integer" ftDefault="10"
		ftHint="NOTE: this is not used when the server is an Amazon ElastiCache configuration endpoint.">
	
    <cfproperty name="accessKey" type="string" ftDefault=""
		ftSeq="5" ftWizardStep="" ftFieldset="Memcached" ftLabel="Access Key"
		ftHint="This key needs to be passed into HTTP requests that override the cache version. This should be valid as a query parameter key.">

	
	<cffunction name="process" access="public" output="false" returntype="struct">
		<cfargument name="fields" type="struct" required="true" />
		
		<cfset application.fc.lib.objectbroker.cacheInitialise(arguments.fields) />
		
		<cfreturn fields />
	</cffunction>
	

	<cffunction name="getProgressBar" access="public" output="false" returntype="string">
		<cfargument name="value" type="numeric" required="true" />
		<cfargument name="max" type="numeric" required="true" />
		<cfargument name="label" type="string" required="true" />
		<cfargument name="styleClass" type="string" required="false" default="progress-info" />

		<cfset var html = "" />
		<cfset var width = 0 />

		<cfif arguments.max>
			<cfset width = round(arguments.value / arguments.max * 100) />
		</cfif>

		<cfsavecontent variable="html"><cfoutput>
			<div class="progress #arguments.styleClass# progress-striped">
				<div class="bar" style="width:#width#%;">&nbsp;#arguments.label#</div>
			</div>
		</cfoutput></cfsavecontent>

		<cfreturn html>
	</cffunction>

	<cffunction name="isNewWebtop" access="public" output="false" returntype="boolean">

		<cfreturn structkeyexists(url,"id") />
	</cffunction>

	<cffunction name="getServersURL" access="public" output="false" returntype="string">

		<cfreturn application.fapi.fixURL(addvalues='type=configMemcached&bodyView=webtopBody',removevalues='server,app,cachetype') />
	</cffunction>

	<cffunction name="getServerURL" access="public" output="false" returntype="string">
		<cfargument name="server" type="string" required="true" />

		<cfreturn application.fapi.fixURL(addvalues='type=configMemcached&bodyView=webtopBodyServer&server=#arguments.server#',removevalues='app,cachetype') />
	</cffunction>

	<cffunction name="getApplicationURL" access="public" output="false" returntype="string">
		<cfargument name="server" type="string" required="true" />
		<cfargument name="app" type="string" required="true" />

		<cfreturn application.fapi.fixURL(addvalues='type=configMemcached&bodyView=webtopBodyApplication&server=#arguments.server#&app=#arguments.app#',removevalues='cachetype') />
	</cffunction>

	<cffunction name="getTypeURL" access="public" output="false" returntype="string">
		<cfargument name="server" type="string" required="true" />
		<cfargument name="app" type="string" required="true" />
		<cfargument name="typename" type="string" required="true" />

		<cfreturn application.fapi.fixURL(addvalues='type=configMemcached&bodyView=webtopBodyType&server=#arguments.server#&app=#arguments.app#&cachetype=#arguments.typename#',removevalues='') />
	</cffunction>

	<cffunction name="getKeyURL" access="public" output="false" returntype="string">
		<cfargument name="server" type="string" required="true" />
		<cfargument name="app" type="string" required="true" />
		<cfargument name="typename" type="string" required="true" />
		<cfargument name="key" type="string" required="true" />

		<cfreturn application.fapi.fixURL(addvalues='type=configMemcached&view=webtopPageModal&bodyView=webtopBodyKey&server=#arguments.server#&app=#arguments.app#&cachetype=#arguments.typename#&key=#arguments.key#',removevalues='') />
	</cffunction>

</cfcomponent>