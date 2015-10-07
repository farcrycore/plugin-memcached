<cfcomponent hint="Trigger flushes on schema deployments" component="fcTypes">

	<cffunction name="saved" access="public" hint="I am invoked when a content object has been saved">
		<cfargument name="typename" type="string" required="true" hint="The type of the object" />
		<cfargument name="oType" type="any" required="true" hint="A CFC instance of the object type" />
		<cfargument name="stProperties" type="struct" required="true" hint="The object" />
		<cfargument name="user" type="string" required="true" />
		<cfargument name="auditNote" type="string" required="true" />
		<cfargument name="bSessionOnly" type="boolean" required="true" />
		<cfargument name="bAfterSave" type="boolean" required="true" />	
		
		<cfif arguments.typename eq "farCOAPI" and isDefined("application.objectbroker.#arguments.stProperties.name#")>
			<cfset application.fc.lib.objectbroker.loadCOAPIKeys() />
		</cfif>
	</cffunction>

</cfcomponent>