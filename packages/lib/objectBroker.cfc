<cfcomponent name="objectBroker" displayname="objectBroker" access="public" hint="Stores and manages cache of objects to enable faster access">

	<cffunction name="init" access="public" output="false" returntype="struct">
		<cfargument name="bFlush" default="false" type="boolean" hint="Allows the application to force a total flush of the objectbroker." />
		
		<cfset loadCOAPIKeys() />

		<cfparam name="application.objectbroker" default="#structnew()#" />

		<cfset this.bFlush = arguments.bFlush />
		<cfset this.cacheMeta = {} />

		<cfreturn this />
	</cffunction>

	<cffunction name="loadCOAPIKeys" access="public" output="false" returntype="void">
		<cfset var qCOAPI = "" />

		<cfquery datasource="#application.dsn#" name="qCOAPI">
			SELECT 	name, datetimeLastUpdated
			FROM 	farCOAPI
		</cfquery>

		<cfset this.coapiKeys = {} />

		<cfloop query="qCOAPI">
			<cfset this.coapiKeys[qCOAPI.name] = dateformat(qCOAPI.datetimeLastUpdated, "mmdd") & timeformat(qCOAPI.datetimeLastUpdated, "hhmm") />
		</cfloop>
	</cffunction>
	
	<cffunction name="GetFromObjectBroker" access="public" output="false" returntype="struct">
		<cfargument name="ObjectID" required="yes" type="string">
		<cfargument name="typename" required="true" type="string">
		
		<cfif isCacheable(typename=arguments.typename,action="read")>
			<cfreturn cachePull(getCacheKey(typename=arguments.typename, objectid=arguments.objectid)) />
		<cfelse>
			<cfreturn structnew() />
		</cfif>
	</cffunction>

	<cffunction name="log" access="public" output="false" returntype="void">
		<cfargument name="cachename" type="string" required="true">
		<cfargument name="key" type="string" required="true">
		<cfargument name="line" type="string" required="true">

		<cfset var starttime = getTickCount() />
		<cfset var memcached = getMemcached() />
		<cfset var actualkey = getCacheKey(typename=arguments.cachename, objectid=arguments.key) />

		<cfif not structIsEmpty(memcached)>
			<cfset application.fc.lib.memcached.add(memcached, actualkey, "", application.objectbroker[arguments.cachename].timeout) />
			<cfset application.fc.lib.memcached.append(memcached, actualkey, arguments.line & chr(10)) />

			<cfset this.add_total = this.add_total + getTickCount() - starttime />
			<cfset this.add_count = this.add_count + 1 />
		</cfif>
	</cffunction>

	<cffunction name="getLog" access="public" output="false" returntype="query">
		<cfargument name="cachename" type="string" required="true">
		<cfargument name="key" type="string" required="true">
		<cfargument name="headers" required="no" type="string" default="Message">

		<cfset var actualkey = getCacheKey(typename=arguments.cachename, objectid=arguments.key) />
		<cfset var data = cachePull(actualkey) />
		<cfset var qResult = queryNew(arguments.headers) />
		<cfset var i = 0 />
		<cfset var delimiter = "," />
		<cfset var Pattern = CreateObject("java","java.util.regex.Pattern").Compile(JavaCast("string",
			"\G(#delimiter#|\r?\n|\r|^)" & <!--- Delimiter. --->
			"(?:""([^""]*+(?>""""[^""]*+)*)""|" & <!--- Quoted field value. --->
			"([^""#delimiter#\r\n]*+))" <!--- Standard field value --->
			)) />
		<cfset var Matcher = "" />
		<cfset var columns = listToArray(arguments.headers) />
		<cfset var columnIndex = 0 />
		<cfset var value = "" />

		<cfif isStruct(data)><!--- No item in cache, or someone put structured data here --->
			<cfreturn qResult />
		</cfif>

		<cfset data = listToArray(data, '#chr(10)##chr(13)#') />

		<cfloop from="1" to="#arrayLen(data)#" index="i">
			<cfif len(trim(data[i]))>
				<cfset Matcher = Pattern.Matcher(JavaCast( "string", trim(data[i]) )) />
				<cfset queryaddrow(qResult) />
				<cfset columnindex = 1 />

				<cfloop condition="Matcher.Find()">
					<!---
						Get the field token value in group 2 (which may
						not exist if the field value was not qualified.
					--->
					<cfset value = Matcher.Group(JavaCast( "int", 2 )) />

					<!---
						Check to see if the value exists. If it doesn't
						exist, then we want the non-qualified field. If
						it does exist, then we want to replace any escaped
						embedded quotes.
					--->
					<cfif isDefined("value")>
						<cfset value = Replace(value,"""""","""","all") />
					<cfelse>
						<cfset value = Matcher.Group(JavaCast( "int", 3 )) />
					</cfif>

					<!--- Add the field value to the query --->
					<cfif columnindex lte arrayLen(columns)>
						<cfset querysetcell(qResult, columns[columnindex], value) />
					</cfif>
					<cfset columnindex += 1 />
				</cfloop>
			</cfif>
		</cfloop>

		<cfreturn qResult />
	</cffunction>

	<cffunction name="getWebskin" access="public" output="true" returntype="struct" hint="Searches the object broker in an attempt to locate the requested webskin template. Returns a struct containing the webskinCacheID and the html.">
		<cfargument name="ObjectID" required="false" type="UUID">
		<cfargument name="typename" required="true" type="string">
		<cfargument name="template" required="true" type="string">
		<cfargument name="hashKey" required="true" type="string">
		<cfargument name="datetimeLastUpdated" required="true" type="date" />
		
		<cfset var stResult = structNew() />
		<cfset var i = "" />
		<cfset var j = "" />
		<cfset var k = "" />
		<cfset var bFlushCache = 0 />
		<cfset var stCacheWebskin = structNew() />
		<cfset var webskinTypename = arguments.typename /><!--- Default to the typename passed in --->
		<cfset var stCoapi = structNew() />
		
		<cfset stResult.webskinCacheID = "" />
		<cfset stResult.webskinHTML = "" />
		
		<cfif arguments.typename EQ "farCoapi">
			<!--- This means its a type webskin and we need to look for the timeout value on the related type. --->			
			<cfset stCoapi = application.fc.factory['farCoapi'].getData(objectid="#arguments.objectid#") />
			<cfset webskinTypename = stCoapi.name />
		</cfif>

		<cfif isCacheable(typename=webskinTypename,template=arguments.template,action="read")>
				
			<cfset stResult.webskinCacheID = generateWebskinCacheID(
					typename="#webskinTypename#", 
					template="#arguments.template#",
					hashKey="#arguments.hashKey#"
			) />
			
			<cfset stCacheWebskin = cachePull(getCacheKey(typename=webskinTypename, objectid=arguments.objectid, objectdate=arguments.datetimeLastUpdated, template=arguments.template, webskinCacheID=stResult.webskinCacheID)) />
			
			<cfif not structisempty(stCacheWebskin) AND 
				structKeyExists(stCacheWebskin, "datetimecreated") AND
				structKeyExists(stCacheWebskin, "webskinHTML") AND
				DateDiff('n', stCacheWebskin.datetimecreated, now()) LT stCacheWebskin.cacheTimeout >
				
				<cfset stResult.webskinHTML = stCacheWebskin.webskinHTML />
				
				<!--- Update request browser timeout --->
				<cfif stCacheWebskin.browserCacheTimeout neq -1 and (not structkeyexists(request.fc,"browserCacheTimeout") or stCacheWebskin.browserCacheTimeout lt request.fc.browserCacheTimeout)>
					<cfset request.fc.browserCacheTimeout = stCacheWebskin.browserCacheTimeout />
				</cfif>
				
				<!--- Update request proxy timeout --->
				<cfif stCacheWebskin.proxyCacheTimeout neq -1 and (not structkeyexists(request.fc,"proxyCacheTimeout") or stCacheWebskin.proxyCacheTimeout lt request.fc.proxyCacheTimeout)>
					<cfset request.fc.proxyCacheTimeout = stCacheWebskin.proxyCacheTimeout />
				</cfif>
				
				<!--- Place any request.inHead variables back into the request scope from which it came. --->
				<cfparam name="request.inHead" default="#structNew()#" />
				<cfparam name="request.inhead.stCustom" default="#structNew()#" />
				<cfparam name="request.inhead.aCustomIDs" default="#arrayNew(1)#" />
				<cfparam name="request.inhead.stOnReady" default="#structNew()#" />
				<cfparam name="request.inhead.aOnReadyIDs" default="#arrayNew(1)#" />
				
				<!--- CSS --->
				<cfparam name="request.inhead.stCSSLibraries" default="#structNew()#" />
				<cfparam name="request.inhead.aCSSLibraries" default="#arrayNew(1)#" />
				
				<!--- JS --->
				<cfparam name="request.inhead.stJSLibraries" default="#structNew()#" />
				<cfparam name="request.inhead.aJSLibraries" default="#arrayNew(1)#" />
				
				<cfloop list="#structKeyList(stCacheWebskin.inHead)#" index="i">
					<cfswitch expression="#i#">
						<cfcase value="stCustom">
							<cfloop list="#structKeyList(stCacheWebskin.inHead.stCustom)#" index="j">
								<cfif not structKeyExists(request.inHead.stCustom, j)>
									<cfset request.inHead.stCustom[j] = stCacheWebskin.inHead.stCustom[j] />
								</cfif>
								
								<cfset addhtmlHeadToWebskins(id="#j#", text="#stCacheWebskin.inHead.stCustom[j]#") />

							</cfloop>
						</cfcase>
						<cfcase value="aCustomIDs">
							<cfloop from="1" to="#arrayLen(stCacheWebskin.inHead.aCustomIDs)#" index="k">
								<cfif NOT listFindNoCase(arrayToList(request.inHead.aCustomIDs), stCacheWebskin.inHead.aCustomIDs[k])>
									<cfset arrayAppend(request.inHead.aCustomIDs,stCacheWebskin.inHead.aCustomIDs[k]) />
								</cfif>
							</cfloop>
						</cfcase>
						<cfcase value="stOnReady">
							<cfloop list="#structKeyList(stCacheWebskin.inHead.stOnReady)#" index="j">
								<cfif not structKeyExists(request.inHead.stOnReady, j)>
									<cfset request.inHead.stOnReady[j] = stCacheWebskin.inHead.stOnReady[j] />
								</cfif>
								
								<cfset addhtmlHeadToWebskins(id="#j#", onReady="#stCacheWebskin.inHead.stOnReady[j]#") />

							</cfloop>
						</cfcase>
						<cfcase value="aOnReadyIDs">
							<cfloop from="1" to="#arrayLen(stCacheWebskin.inHead.aOnReadyIDs)#" index="k">
								<cfif NOT listFindNoCase(arrayToList(request.inHead.aOnReadyIDs), stCacheWebskin.inHead.aOnReadyIDs[k])>
									<cfset arrayAppend(request.inHead.aOnReadyIDs,stCacheWebskin.inHead.aOnReadyIDs[k]) />
								</cfif>
							</cfloop>
						</cfcase>
						
						<!--- CSS LIBRARIES --->
						
						<cfcase value="stCSSLibraries">
							<cfloop list="#structKeyList(stCacheWebskin.inHead.stCSSLibraries)#" index="j">
								<cfif not structKeyExists(request.inHead.stCSSLibraries, j)>
									<cfset request.inHead.stCSSLibraries[j] = stCacheWebskin.inHead.stCSSLibraries[j] />
								</cfif>			
							</cfloop>
						</cfcase>
						<cfcase value="aCSSLibraries">
							<cfloop from="1" to="#arrayLen(stCacheWebskin.inHead.aCSSLibraries)#" index="k">
								<cfif NOT listFindNoCase(arrayToList(request.inHead.aCSSLibraries), stCacheWebskin.inHead.aCSSLibraries[k])>
									<cfset arrayAppend(request.inHead.aCSSLibraries,stCacheWebskin.inHead.aCSSLibraries[k]) />
								</cfif>														
								<cfset addCSSHeadToWebskins(stCacheWebskin.inHead.stCSSLibraries[stCacheWebskin.inHead.aCSSLibraries[k]]) />
							</cfloop>
						</cfcase>
						

						<!--- JS LIBRARIES --->
						
						<cfcase value="stJSLibraries">
							<cfloop list="#structKeyList(stCacheWebskin.inHead.stJSLibraries)#" index="j">
								<cfif not structKeyExists(request.inHead.stJSLibraries, j)>
									<cfset request.inHead.stJSLibraries[j] = stCacheWebskin.inHead.stJSLibraries[j] />
								</cfif>																	
							</cfloop>
						</cfcase>
						<cfcase value="aJSLibraries">
							<cfloop from="1" to="#arrayLen(stCacheWebskin.inHead.aJSLibraries)#" index="k">
								<cfif NOT listFindNoCase(arrayToList(request.inHead.aJSLibraries), stCacheWebskin.inHead.aJSLibraries[k])>
									<cfset arrayAppend(request.inHead.aJSLibraries,stCacheWebskin.inHead.aJSLibraries[k]) />
								</cfif>														
								<cfset addJSHeadToWebskins(stCacheWebskin.inHead.stJSLibraries[stCacheWebskin.inHead.aJSLibraries[k]]) />
							</cfloop>
						</cfcase>
																	
						<cfdefaultcase>
							<cfset addhtmlHeadToWebskins(library=i) />
							<cfset request.inHead[i] = stCacheWebskin.inHead[i] />
						</cfdefaultcase>
					</cfswitch>
		
				</cfloop>

			</cfif>
			
		</cfif>
		
		<cfreturn stResult />
	</cffunction>
		
	<cffunction name="generateWebskinCacheID" access="public" output="false" returntype="string" hint="Generates a webskin Cache ID that can be hashed to store a specific version of a webskin cache.">
		<cfargument name="typename" required="true" />
		<cfargument name="template" required="true" />
		<cfargument name="hashKey" required="false" default="" />
		<cfargument name="bCacheByURL" required="false" default="#application.coapi.coapiadmin.getWebskincacheByURL(typename=arguments.typename, template=arguments.template)#" />
		<cfargument name="bCacheByForm" required="false" default="#application.coapi.coapiadmin.getWebskincacheByForm(typename=arguments.typename, template=arguments.template)#" />
		<cfargument name="bCacheByRoles" required="false" default="#application.coapi.coapiadmin.getWebskincacheByRoles(typename=arguments.typename, template=arguments.template)#" />
		<cfargument name="lcacheByVars" required="false" default="#application.coapi.coapiadmin.getWebskincacheByVars(typename=arguments.typename, template=arguments.template)#" />

		<cfset var WebskinCacheID = "" />
		<cfset var iFormField = "" />
		<cfset var iViewState = "" />
	
		
		<!--- Always prefixed with the hash key. This can be overridden in the webskin call. It will include any cfparam attributes. --->
		<cfif len(arguments.hashKey)>
			<cfset WebskinCacheID = listAppend(WebskinCacheID, "#arguments.hashKey#") />
		</cfif>
		
		<cfif arguments.bCacheByURL>
			<cfset WebskinCacheID = listAppend(WebskinCacheID,"script_name:#cgi.script_name#,query_string:#cgi.query_string#") />
		</cfif>
		
		<cfif arguments.bCacheByForm AND isDefined("form")>
			<cfif structIsEmpty(form)>
				<cfset WebskinCacheID = listAppend(WebskinCacheID, "form:empty") />
			<cfelse>
				<cfloop list="#listSort(structKeyList(form),'text')#" index="iFormField">
					<cfif isSimpleValue(form[iFormField])>
						<cfset WebskinCacheID = listAppend(WebskinCacheID, "form[#iFormField#]:#form[iFormField]#") />
					<cfelse>
						<cfset WebskinCacheID = listAppend(WebskinCacheID, "form[#iFormField#]:{complex}") />
					</cfif>
				</cfloop>
			</cfif>					
		</cfif>
		
		<cfif arguments.bCacheByRoles>
			<cfif application.security.isLoggedIn()>
				<cfset WebskinCacheID = listAppend(WebskinCacheID,"roles:#listSort(session.security.roles,'text')#") />
			<cfelse>
				<cfset WebskinCacheID = listAppend(WebskinCacheID, "roles:anonymous") />
			</cfif>									
		</cfif>

		<cfif listLen(arguments.lcacheByVars)>
			<cfloop list="#listSort(arguments.lcacheByVars, 'text')#" index="iViewState">
				<cfset varname = trim(listfirst(iViewState,":")) />
				
				<cftry>
					<cfif isvalid("variablename",varname) and isdefined(varname)>
						<cfset WebskinCacheID = listAppend(WebskinCacheID, "#varname#:#evaluate(varname)#") />
					<cfelseif find("(",varname) and isdefined(listfirst(varname,"("))>
						<cfset WebskinCacheID = listAppend(WebskinCacheID, "#varname#:#evaluate(varname)#") />
					<cfelse>
						<!--- If the var is defined with a default (e.g. @@cacheByVars: url.page:1), the default is incorporated into the hash --->
						<!--- If the var does not define a default (e.g. @@cacheByVars: url.error), that valueless string indicates the null --->
						<cfset WebskinCacheID = listAppend(WebskinCacheID, "#iViewState#") />
					</cfif>		
					
					<cfcatch type="any">
						<cfset WebskinCacheID = listAppend(WebskinCacheID, "#varname#:invalidVarName") />
					</cfcatch>
				</cftry>
			</cfloop>								
		</cfif>

		<cfreturn WebskinCacheID />
	</cffunction>	
			
	<cffunction name="addhtmlHeadToWebskins" access="public" output="true" returntype="void" hint="Adds the result of a skin:htmlHead to all relevent webskin caches">
		<cfargument name="id" type="string" required="false" default="#application.fc.utils.createJavaUUID()#" />
		<cfargument name="text" type="string" required="false" default="" />
		<cfargument name="library" type="string" required="false" default="" />
		<cfargument name="libraryState" type="boolean" required="false" default="true" />
		<cfargument name="onReady" type="string" required="false" default="" />
		
		<cfset var iWebskin = "">
		<cfset var iLibrary = "">

		<cfif len(arguments.id) or listlen(arguments.library)>
			<cfif structKeyExists(request, "aAncestorWebskins") AND arrayLen(request.aAncestorWebskins)>
				<cfloop from="1" to="#arrayLen(request.aAncestorWebskins)#" index="iWebskin">
					<cfif listlen(arguments.library)>
						<cfloop list="#arguments.library#" index="iLibrary">
							<cfset request.aAncestorWebskins[iWebskin].inHead[iLibrary] = arguments.libraryState />
						</cfloop>
					<cfelseif len(arguments.onReady)>
						<!--- If we are currently inside of a webskin we need to add this id to the current webskin --->					
						<cfif NOT structKeyExists(request.aAncestorWebskins[iWebskin].inhead.stOnReady, arguments.id)>
							<cfset request.aAncestorWebskins[iWebskin].inHead.stOnReady[arguments.id] = arguments.onReady />
							<cfset arrayAppend(request.aAncestorWebskins[iWebskin].inHead.aOnReadyIDs, arguments.id) />
						</cfif>
					<cfelse>
						<!--- If we are currently inside of a webskin we need to add this id to the current webskin --->					
						<cfif NOT structKeyExists(request.aAncestorWebskins[iWebskin].inhead.stCustom, arguments.id)>
							<cfset request.aAncestorWebskins[iWebskin].inHead.stCustom[arguments.id] = arguments.text />
							<cfset arrayAppend(request.aAncestorWebskins[iWebskin].inHead.aCustomIDs, arguments.id) />
						</cfif>
					</cfif>
				</cfloop>
			</cfif>	
		</cfif>
		
	</cffunction>		
			
	<cffunction name="addCSSHeadToWebskins" access="public" output="true" returntype="void" hint="Adds the result of a skin:loadCSS to all relevent webskin caches">
		<cfargument name="stCSS" type="struct" required="true" />
		
		<cfset var iWebskin = "">

		<cfif structKeyExists(request, "aAncestorWebskins") AND arrayLen(request.aAncestorWebskins)>
			<cfloop from="1" to="#arrayLen(request.aAncestorWebskins)#" index="iWebskin">
				<!--- If we are currently inside of a webskin we need to add this id to the current webskin --->					
				<cfif NOT structKeyExists(request.aAncestorWebskins[iWebskin].inhead.stCSSLibraries, arguments.stCSS.id)>
					
					<!--- Add the id to the array to make sure we keep track of the order in which these libraries need to appear. --->
					<cfset arrayAppend(request.aAncestorWebskins[iWebskin].inHead.aCSSLibraries, arguments.stCSS.id) />
					
					<!--- Add the css information to the struct so we will be able to load it all correctly into the header at the end of the request. --->
					<cfset request.aAncestorWebskins[iWebskin].inHead.stCSSLibraries[stCSS.id] = arguments.stCSS />
					
				</cfif>
			</cfloop>
		</cfif>	
	</cffunction>
	<cffunction name="addJSHeadToWebskins" access="public" output="true" returntype="void" hint="Adds the result of a skin:loadJS to all relevent webskin caches">
		<cfargument name="stJS" type="struct" required="true" />
		
		<cfset var iWebskin = "">

		<cfif structKeyExists(request, "aAncestorWebskins") AND arrayLen(request.aAncestorWebskins)>
			<cfloop from="1" to="#arrayLen(request.aAncestorWebskins)#" index="iWebskin">
				<!--- If we are currently inside of a webskin we need to add this id to the current webskin --->					
				<cfif NOT structKeyExists(request.aAncestorWebskins[iWebskin].inhead.stJSLibraries, arguments.stJS.id)>
					
					<!--- Add the id to the array to make sure we keep track of the order in which these libraries need to appear. --->
					<cfset arrayAppend(request.aAncestorWebskins[iWebskin].inHead.aJSLibraries, arguments.stJS.id) />
					
					<!--- Add the JS information to the struct so we will be able to load it all correctly into the header at the end of the request. --->
					<cfset request.aAncestorWebskins[iWebskin].inHead.stJSLibraries[stJS.id] = arguments.stJS />
					
				</cfif>
			</cfloop>
		</cfif>	
	</cffunction>
	
	<cffunction name="countUncacheable" access="private" output="false" returntype="void" hint="Keeps track of what is deemed uncacheable">
		<cfargument name="typename" type="string" required="true" />
		<cfargument name="template" type="string" required="false" />
		<cfargument name="reason" type="string" required="true" />

		<cfset var stUncacheable = "" />

		<cfif structkeyexists(arguments,"action") and arguments.action eq "read">
			<cfreturn>
		</cfif>

		<cfif not structkeyexists(application,"stCOAPI")>
			<!--- application not initialized --->
			<cfreturn>
		</cfif>

		<cfif not structkeyexists(application.stCOAPI,arguments.typename)>
			<!--- invalid typename --->
			<cfreturn>
		</cfif>

		<cfif structkeyexists(arguments,"template") and not structkeyexists(application.stCOAPI[arguments.typename].stWebskins,arguments.template)>
			<!--- invalid webskin --->
			<cfreturn>
		</cfif>

		<cfif structkeyexists(arguments,"template")>
			<cfif not structkeyexists(application.stCOAPI[arguments.typename].stWebskins[arguments.template],"stUncacheable")>
				<cfset application.stCOAPI[arguments.typename].stWebskins[arguments.template]["stUncacheable"] = structnew() />
				<cfset application.stCOAPI[arguments.typename].stWebskins[arguments.template]["stUncacheable"]["mode"] = 0 />
				<cfset application.stCOAPI[arguments.typename].stWebskins[arguments.template]["stUncacheable"]["settings"] = 0 />
				<cfset application.stCOAPI[arguments.typename].stWebskins[arguments.template]["stUncacheable"]["post"] = 0 />
			</cfif>

			<cfset stUncacheable = application.stCOAPI[arguments.typename].stWebskins[arguments.template]["stUncacheable"] />
		<cfelse>
			<cfif not structkeyexists(application.stCOAPI[arguments.typename],"stUncacheable")>
				<cfset application.stCOAPI[arguments.typename]["stUncacheable"] = structnew() />
				<cfset application.stCOAPI[arguments.typename]["stUncacheable"]["mode"] = 0 />
				<cfset application.stCOAPI[arguments.typename]["stUncacheable"]["settings"] = 0 />
				<cfset application.stCOAPI[arguments.typename]["stUncacheable"]["post"] = 0 />
			</cfif>

			<cfset stUncacheable = application.stCOAPI[arguments.typename]["stUncacheable"] />
		</cfif>

		<cfset stUncacheable[arguments.reason] = stUncacheable[arguments.reason] + 1 />
	</cffunction>

	<cffunction name="getTypeUncacheableStats" returntype="struct" output="false">
		
		<cfset var q = querynew("typename,bObjectBroker,modenum,settingsnum","varchar,bit,bigint,bigint")>
		<cfset var webskinTypename = "" />
		<cfset var stResult = {} />

		<cfloop collection="#application.stCOAPI#" item="webskinTypename">
			<cfset queryaddrow(q) />
			<cfset querysetcell(q,"typename",webskinTypename) />
			<cfset querysetcell(q,"typename",application.stCOAPI[webskinTypename].bObjectBroker) />
			<cfif structkeyexists(application.stCOAPI[webskinTypename],"stUncacheable")>
				<cfset querysetcell(q,"modenum",application.stCOAPI[webskinTypename].stUncacheable["mode"]) />
				<cfset querysetcell(q,"settingsnum",application.stCOAPI[webskinTypename].stUncacheable["settings"]) />
			<cfelse>
				<cfset querysetcell(q,"modenum",0) />
				<cfset querysetcell(q,"settingsnum",0) />
			</cfif>
		</cfloop>
		
		<cfquery dbtype="query" name="q">select * from q order by typename asc</cfquery>
		<cfset stResult.stats = q />

		<cfquery dbtype="query" name="q">
			select 	sum(modenum) as summodenum, 
					max(modenum) as maxmodenum, 
					sum(settingsnum) as sumsettingsnum, 
					max(settingsnum) as maxsettingsnum, 
			from 	q
		</cfquery>
		<cfset stResult.summodenum = q.summodenum />
		<cfset stResult.maxmodenum = q.maxmodenum />
		<cfset stResult.sumsettingsnum = q.sumsettingsnum />
		<cfset stResult.maxsettingsnum = q.maxsettingsnum />
		
		<cfreturn stResult />
	</cffunction>

	<cffunction name="getTypeWebskinUncacheableStats" returntype="struct" output="false">
		<cfargument name="typename" type="string" required="false" />
		
		<cfset var q = querynew("typename,webskin,bObjectBroker,modenum,settingsnum","varchar,varchar,bit,bigint,bigint")>
		<cfset var webskinTypename = "" />
		<cfset var webskins = "" />
		<cfset var stResult = {} />

		<cfloop collection="#application.stCOAPI#" item="webskinTypename">
			<cfif not structkeyexists(arguments,"typename") or arguments.typename eq webskinTypename>
				<cfloop collection="#application.stCOAPI[webskinTypename].stWebskins#" item="webskin">
					<cfset queryaddrow(q) />
					<cfset querysetcell(q,"typename",webskinTypename) />
					<cfset querysetcell(q,"webskin",webskin) />
					<cfset querysetcell(q,"bObjectBroker",application.stCOAPI[webskinTypename].stWebskins[webskin].cacheStatus eq 1) />

					<cfif structkeyexists(application.stCOAPI[webskinTypename].stWebskins[webskin],"stUncacheable")>
						<cfset querysetcell(q,"modenum",application.stCOAPI[webskinTypename].stWebskins[webskin].stUncacheable.mode) />
						<cfset querysetcell(q,"settingsnum",application.stCOAPI[webskinTypename].stWebskins[webskin].stUncacheable.settings) />
					<cfelse>
						<cfset querysetcell(q,"modenum",0) />
						<cfset querysetcell(q,"settingsnum",0) />
					</cfif>
				</cfloop>
			</cfif>
		</cfloop>
		
		<cfquery dbtype="query" name="q">select * from q order by typename asc, webskin asc</cfquery>
		<cfset stResult.stats = q />

		<cfquery dbtype="query" name="q">
			select 	sum(modenum) as summodenum, 
					max(modenum) as maxmodenum, 
					sum(settingsnum) as sumsettingsnum, 
					max(settingsnum) as maxsettingsnum
			from 	q
		</cfquery>
		<cfset stResult.summodenum = q.summodenum />
		<cfset stResult.maxmodenum = q.maxmodenum />
		<cfset stResult.sumsettingsnum = q.sumsettingsnum />
		<cfset stResult.maxsettingsnum = q.maxsettingsnum />
		
		<cfreturn stResult />
	</cffunction>

	<cffunction name="isCacheable" access="public" output="false" returntype="boolean" hint="Utility function for addWebskin - returns true if the conditions for caching are met">
		<cfargument name="typename" type="string" required="true" />
		<cfargument name="template" type="string" required="false" />
		<cfargument name="action" type="string" required="false" default="read" />
		
		<cfset var baseCheck = true />

		<cfparam name="request.mode.flushcache" default="0">
		<cfparam name="request.mode.showdraft" default="0">
		<cfparam name="request.mode.lvalidstatus" default="approved">
		<cfparam name="request.mode.tracewebskins" default="0">
		<cfparam name="request.mode.design" default="0">

		<cfif not isDefined("application.config.memcached")>
			<cfreturn false />
		</cfif>

		<!--- Mode --->
		<cfset baseCheck = baseCheck and application.bObjectBroker and structKeyExists(application, "objectbroker") and
				  not (
				  	structKeyExists(request,"mode") AND 
				  	(
				  		(arguments.action eq "read" and request.mode.flushcache EQ 1) OR 
				  		request.mode.showdraft EQ 1 OR 
				  		request.mode.lvalidstatus NEQ "approved" OR
				  		(structkeyexists(arguments,"template") AND len(arguments.template) AND request.mode.tracewebskins EQ 1) OR 
				  		request.mode.design EQ 1
				  	) 
				  ) />
		<cfif baseCheck eq false>
			<cfset countUncacheable(argumentCollection=arguments,reason="mode") />
			<cfreturn false />
		</cfif>

		<!--- Cache settings --->
		<cfset baseCheck = baseCheck and not (structKeyExists(url, "updateapp") AND url.updateapp EQ 1) and len(arguments.typename) and isdefined("application.objectbroker.#arguments.typename#") />
		<cfif baseCheck eq false>
			<cfset countUncacheable(argumentCollection=arguments,reason="settings") />
			<cfreturn false />
		</cfif>
		
		<cfif structkeyexists(arguments,"template")>
			<!--- Form post --->
			<cfset baseCheck = baseCheck and not (
			  	isDefined("form") AND 
			  	not structIsEmpty(form) and 
			  	application.coapi.coapiadmin.getWebskinCacheFlushOnFormPost(typename=arguments.typename,template=arguments.template)
			  ) />
			<cfif baseCheck eq false>
				<cfset countUncacheable(argumentCollection=arguments,reason="post") />
				<cfreturn false />
			</cfif>
			
			<cfset baseCheck = baseCheck and not (
			  	structKeyExists(request,"mode") AND 
			  	(
			  		request.mode.tracewebskins eq 1 OR 
			  		request.mode.design eq 1
			  	) 
			  ) />
			<cfif baseCheck eq false>
				<cfset countUncacheable(argumentCollection=arguments,reason="mode") />
				<cfreturn false />
			</cfif>

			<cfset baseCheck = baseCheck and structKeyExists(application.stcoapi[arguments.typename].stWebskins, arguments.template) 
			  and application.stcoapi[arguments.typename].stWebskins[arguments.template].cacheStatus EQ 1 />
			<cfif baseCheck eq false>
				<cfset countUncacheable(argumentCollection=arguments,reason="settings") />
				<cfreturn false />
			</cfif>
		</cfif>
		
		<cfreturn baseCheck />
	</cffunction>
	
	<cffunction name="addWebskin" access="public" output="true" returntype="boolean" hint="Adds webskin to object broker if all conditions are met">
		<cfargument name="ObjectID" required="false" type="UUID">
		<cfargument name="typename" required="true" type="string">
		<cfargument name="template" required="true" type="string">
		<cfargument name="webskinCacheID" required="true" type="string">
		<cfargument name="HTML" required="true" type="string">
		<cfargument name="stCurrentView" required="true" type="struct">
		<cfargument name="datetimeLastUpdated" required="true" type="date" />
		
		<cfset var stCacheWebskin = structNew() />
		<cfset var webskinTypename = arguments.typename /><!--- Default to the typename passed in --->
		<cfset var stCoapi = structNew() />
		
		<cfif arguments.typename EQ "farCoapi">
			<!--- This means its a type webskin and we need to look for the timeout value on the related type. --->		
			<cfset stCoapi = application.fc.factory['farCoapi'].getData(objectid="#arguments.objectid#") />
			<cfset webskinTypename = stCoapi.name />
		</cfif>
		
		<cfif isCacheable(typename=webskinTypename,template=arguments.template,action="write")>
			
			<!--- Add the current State of the request.inHead scope into the broker --->
			<cfparam name="request.inHead" default="#structNew()#">
			
			<cfset stCacheWebskin.datetimecreated = now() />
			<cfset stCacheWebskin.webskinHTML = trim(arguments.HTML) />	
			<cfset stCacheWebskin.inHead = duplicate(arguments.stCurrentView.inHead) />
			<cfset stCacheWebskin.cacheStatus = arguments.stCurrentView.cacheStatus />
			<cfset stCacheWebskin.cacheTimeout = arguments.stCurrentView.cacheTimeout />
			<cfset stCacheWebskin.browserCacheTimeout = arguments.stCurrentView.browserCacheTimeout />
			<cfset stCacheWebskin.proxyCacheTimeout = arguments.stCurrentView.proxyCacheTimeout />

			<cfset stCacheWebskin.webskinCacheID = generateWebskinCacheID(
													typename="#webskinTypename#", 
													template="#arguments.template#",
													hashKey="#arguments.stCurrentView.hashKey#"
										) />
			
			<cfset cacheAdd(getCacheKey(typename=arguments.typename, objectid=arguments.objectid, objectdate=arguments.datetimeLastUpdated, template=arguments.template, webskinCacheID=stCacheWebskin.webskinCacheID),stCacheWebskin,stCacheWebskin.cacheTimeout*60) />
			
			<cfreturn true />
				
		</cfif>
		
		<cfreturn false />
	</cffunction>
	
	<cffunction name="removeWebskin" access="public" output="false" returntype="boolean" hint="Searches the object broker in an attempt to locate the requested webskin template">
		<cfargument name="ObjectID" required="false" type="UUID">
		<cfargument name="typename" required="true" type="string">
		<cfargument name="template" required="true" type="string">
		
		<cfreturn true />
	</cffunction>
	
	<cffunction name="AddToObjectBroker" access="public" output="true" returntype="boolean">
		<cfargument name="stObj" required="yes" type="struct">
		<cfargument name="typename" required="true" type="string">
		<cfargument name="key" required="false" type="string">
		
		<cfif not structkeyexists(arguments,"key") and structkeyexists(arguments.stObj,"objectid")>
			<cfset arguments.key = arguments.stObj.objectid />
		</cfif>

		<cfif isCacheable(typename=arguments.typename,action="write") and structkeyexists(arguments,"key")>
			<cfset cacheAdd(getCacheKey(typename=arguments.typename, objectid=arguments.key), arguments.stObj, application.objectbroker[arguments.typename].timeout) />
			<cfreturn true />
		</cfif>
		
		<cfreturn false />
	</cffunction>
	
	<cffunction name="RemoveFromObjectBroker" access="public" output="true" returntype="void">
		<cfargument name="lObjectIDs" required="true" type="string">
		<cfargument name="typename" required="true" type="string">
		<cfargument name="eventName" required="false" type="string" default="flush" hint="Name of event that triggered the removal {flush,reap,evict}">
		
		<cfset var oWebskinAncestor = application.fapi.getContentType("dmWebskinAncestor") />						
		<cfset var qWebskinAncestors = queryNew("blah") />
		<cfset var i = "" />
		<cfset var regexString = "" />

		<cfif application.bObjectBroker and len(arguments.typename) and isdefined("application.objectbroker.#arguments.typename#")>
			<cfloop list="#arguments.lObjectIDs#" index="i">
				<cfset cacheFlush(getCacheKey(typename=arguments.typename, objectid=i))>
			</cfloop>
		</cfif>
	</cffunction>
	
	<cffunction name="flushTypeWatchWebskins" access="public" output="false" returntype="boolean" hint="Finds all webskins watching this type for any CRUD functions and flushes them from the cache">
	 	<cfargument name="objectID" required="false" hint="The typename that the CRUD function was performed on." />
	 	<cfargument name="typename" required="false" hint="" />
	 	<cfargument name="stObject" required="false" hint="Alternative to objectID+typename">
		
		<cfset var stTypeWatchWebskins = "" />
		<cfset var iType = "" />
		<cfset var iWebskin = "" />
		<cfset var oCoapi = application.fapi.getContentType("farCoapi") />
		<cfset var coapiObjectID = "" />
		<cfset var qCachedAncestors = "" />
		<cfset var bSuccess = "" />
		<cfset var qWebskinAncestors = "" />

		<cfif structkeyexists(arguments,"stObject")>
			<cfset arguments.typename = arguments.stObject.typename />
			<cfset arguments.objectid = arguments.stObject.objectid />
		<cfelse>
			<cfset arguments.stObject = application.fapi.getContentObject(objectid=arguments.objectid,typename=arguments.typename)>
		</cfif>

		<cfset stTypeWatchWebskins = application.stCoapi[arguments.typename].stTypeWatchWebskins />
		
		<cfif not structKeyExists(arguments.stObject, "status") OR arguments.stObject.status EQ "approved" and not structIsEmpty(stTypeWatchWebskins)>
			<cfloop collection="#stTypeWatchWebskins#" item="iType">
				
				<cfset coapiObjectID = oCoapi.getCoapiObjectID(iType) />
				
				<cfif not structKeyExists(application.fc.webskinAncestors, iType)>
					<cfset application.fc.webskinAncestors[iType] = queryNew( 'webskinObjectID,webskinTypename,webskinRefTypename,webskinTemplate,ancestorID,ancestorTypename,ancestorTemplate,ancestorRefTypename', 'VarChar,VarChar,VarChar,VarChar,VarChar,VarChar,VarChar,VarChar' ) />
				</cfif>
				<cfset qWebskinAncestors = application.fc.webskinAncestors[iType] />
				
				<cfloop from="1" to="#arrayLen(stTypeWatchWebskins[iType])#" index="iWebskin">
					
					<cfquery dbtype="query" name="qCachedAncestors">
						SELECT * 
						FROM qWebskinAncestors
						WHERE (
								webskinTypename = <cfqueryparam cfsqltype="cf_sql_varchar" value="#iType#" />
								OR webskinObjectID = <cfqueryparam cfsqltype="cf_sql_varchar" value="#coapiObjectID#" />
						)
						AND webskinTemplate = <cfqueryparam cfsqltype="cf_sql_varchar" value="#stTypeWatchWebskins[iType][iWebskin]#" />
					</cfquery>
					
					<cfloop query="qCachedAncestors">
						<cfset bSuccess = removeWebskin(	objectID=qCachedAncestors.ancestorID,
															typename=qCachedAncestors.ancestorTypename,
															template=qCachedAncestors.ancestorTemplate ) />
						
						<cfset bSuccess = removeWebskin(	objectID=qCachedAncestors.webskinObjectID,
															typename=qCachedAncestors.webskinRefTypename,
															template=qCachedAncestors.webskinTemplate ) />
						
					</cfloop>
					
				</cfloop>
				
			</cfloop>
		</cfif>
		
		<cfreturn true />
	 </cffunction>
	
	<!--- Cache replacement functions --->
	<cffunction name="cacheInitialise" access="public" output="false" returntype="void">
		<cfargument name="config" type="struct" required="false" default="#structNew()#" />
		
		<cfset var stCacheProperties = structnew() />
		<cfset var connectionFactory = "" />
		<cfset var protocolType = "" />
		<cfset var locatorType = "" />
		<cfset var addresses = "" />
		
		<cfif structKeyExists(request, "initingMemcached")>
			<cfreturn>
		</cfif>
		<cfset request.initingMemcached = true />

		<cfparam name="arguments.config" default="#structnew()#">
		<cfset this.config = arguments.config />

		<cfparam name="this.config.servers" default="#application.fapi.getConfig('memcached','servers','')#">
		<cfparam name="this.config.protocol" default="#application.fapi.getConfig('memcached','protocol','')#">
		<cfparam name="this.config.locator" default="#application.fapi.getConfig('memcached','locator','')#">
		<cfparam name="this.config.operationTimeout" default="#application.fapi.getConfig('memcached','operationTimeout','')#">
		
		<cfif len(trim(arguments.config.servers))
			and len(trim(arguments.config.protocol))
			and len(trim(arguments.config.locator))
			and len(trim(arguments.config.operationTimeout))>
			
			<cfset this.memcached = createobject("component","farcry.plugins.memcached.packages.lib.memcached").initializeClient(arguments.config) />
			
			<cfset this.pull_total = 0 />
			<cfset this.pull_count = 0 />
			<cfset this.add_total = 0 />
			<cfset this.add_count = 0 />
		<cfelse>
			<cfif not structKeyExists(this, "bLogggedNoConfig")>
				<cfset this.bLogggedNoConfig = true />
				<cflog type="information" application="true" file="memcached" text="No config for memcached" />
			</cfif>
			<cfif structkeyexists(this,"memcached")>
				<cflog type="information" application="true" file="memcached" text="Removing memcached client" />
				<cfset structdelete(this,"memcached") />
			</cfif>
			<cfif structKeyExists(this,"config")>
				<cfset structdelete(this,"config") />
			</cfif>
		</cfif>

		<cfset structDelete(request, "initingMemcached") />
	</cffunction>

	<cffunction name="getMemcached" access="public" output="false" returntype="any">
		<cfif not structKeyExists(this, "memcached") and not structKeyExists(this, "config") and structKeyExists(application, "config")>
			<cfset cacheInitialise() />
		</cfif>

		<cfif structKeyExists(this, "memcached")>
			<cfreturn this.memcached />
		<cfelse>
			<cfreturn {} />
		</cfif>
	</cffunction>

	<cffunction name="getCacheKey" access="public" output="false" returntype="string">
		<cfargument name="typename" required="true" type="string">
		<cfargument name="ObjectID" required="true" type="string">
		<cfargument name="ObjectDate" required="false" type="date" />
		<cfargument name="template" required="false" type="string">
		<cfargument name="webskinCacheID" required="false" type="string">

		<cfset var app_name = left(rereplace(application.applicationname,'[^\w\d]','','ALL'), 10) />
		<cfset var app_version = getCacheVersion() />
		<cfset var type_version = getCacheVersion(arguments.typename) />

		<cfif structKeyExists(this.coapiKeys, arguments.typename)>
			<cfset type_version = this.coapikeys[arguments.typename] & "-" & type_version />
		</cfif>

		<cfset var key = "#app_name#_#app_version#_#arguments.typename#_#type_version#_#arguments.objectid#" />

		<cfif structKeyExists(arguments, "template")>
			<cfset key = key & "_#dateformat(arguments.ObjectDate,'yyyymmdd')##timeformat(arguments.ObjectDate,'hhmmss')#_#arguments.template#_#hash(arguments.webskinCacheID)#" />
		</cfif>
		
		<cfreturn key />
	</cffunction>

	<cffunction name="getCacheVersion" access="public" output="false" returntype="string" hint="The plugin stores a cache 'version' in memcached that should be used in all keys. Updating this version should equivilent to clearing the cache.">
		<cfargument name="typename" type="string" required="false" default="app" />
		<cfargument name="increment" type="boolean" required="false" default="false" />

		<cfset var data = { "version" = 0 } />
		<cfset var key = rereplace(application.applicationname,'[^\w\d]','','ALL') & "_" & arguments.typename & "_cachemeta" />
		<cfset var changed = false />
		<cfset var v = 0>
		<cfset var overrideKey = "cacheversion_#arguments.typename#_#application.config.memcached.accessKey#" />

		<cfif structKeyExists(url, overrideKey)>
			<cfreturn url[overrideKey] />
		</cfif>

		<!--- Initialize request scope --->
		<cfif not structKeyExists(request, "cacheMeta")>
			<cfset request.cacheMeta = {} />
		</cfif>

		<!--- Get data from cache --->
		<cfif not structKeyExists(request.cacheMeta, arguments.typename)>
			<cfset request.cacheMeta[arguments.typename] = cachePull(key) />
		</cfif>

		<!--- Handle bFlush cache --->
		<cfif this.bFlush and arguments.typename eq "app">
			<cfset arguments.increment = true />
			<cfset this.bFlush = false />
		</cfif>
		<cfif structKeyExists(request.cacheMeta[arguments.typename], "preparing")>
			<cfreturn request.cacheMeta[arguments.typename].version />
		</cfif>

		<!--- Update the version info --->
		<cfif structIsEmpty(request.cacheMeta[arguments.typename])>
			<cfset data = {
				"version" = 1,
				"version_date" = now(),
				"readd" = dateAdd("h", 6, now())
			} />
			<cfset changed = true />
		<cfelseif arguments.increment>
			<cfset v = (request.cacheMeta[arguments.typename].version + 1) mod 100>
			<cfif v == 0>
				<cfset v = 1>
			</cfif>
			<cfset data = {
				"version" = v,
				"version_date" = now(),
				"readd" = dateAdd("h", 6, now())
			} />
			<cfset changed = true />
		<cfelseif request.cacheMeta[arguments.typename].readd lt now()>
			<cfset data = {
				"version" = request.cacheMeta[arguments.typename].version,
				"version_date" = request.cacheMeta[arguments.typename].version_date,
				"readd" = dateAdd("h", 6, now())
			} />
			<cfset changed = true />
		<cfelse>
			<cfset data = request.cacheMeta[arguments.typename] />
		</cfif>

		<!--- Track the versions in the application scope and use them to ensure that version numbers don't revert --->
		<cfif not structKeyExists(this.cacheMeta, arguments.typename)>
			<cfset this.cacheMeta[arguments.typename] = data />
		<cfelseif this.cacheMeta[arguments.typename].version EQ 1 and data.version GTE 99>
			<cfset data = this.cacheMeta[arguments.typename] />
			<cfset changed = true />
		<cfelseif  this.cacheMeta[arguments.typename].version GTE 99 and data.version EQ 1>
			<cfset this.cacheMeta[arguments.typename] = data />
		<cfelseif this.cacheMeta[arguments.typename].version gt data.version>
			<cfset data = this.cacheMeta[arguments.typename] />
			<cfset changed = true />
		<cfelseif  this.cacheMeta[arguments.typename].version lt data.version >
			<cfset this.cacheMeta[arguments.typename] = data />
		</cfif>

		<cfif changed>
			<cfset request.cacheMeta[arguments.typename] = data />
			<cfset cacheAdd(key, data) />
		</cfif>

		<!--- Return the requested version --->
		<cfreturn request.cacheMeta[arguments.typename].version />
	</cffunction>

	<cffunction name="prepareCacheVersion" access="public" output="false" returntype="string" hint="Increments the cache version for the duration of this request">
		<cfargument name="typename" type="string" required="false" default="app" />

		<cfset var v = 0 />

		<cfif not isDefined("request.cacheMeta.#arguments.typename#")>
			<cfset getCacheVersion(typename) />
		</cfif>
		<cfif structKeyExists(request.cacheMeta[arguments.typename], "preparing")>
			<cfreturn request.cacheMeta[arguments.typename].version />
		</cfif>

		<cfset v = (request.cacheMeta[arguments.typename].version + 1) mod 100>
		<cfif v == 0>
			<cfset v = 1>
		</cfif>

		<cfset request.cacheMeta[arguments.typename] = {
			"version" = v,
			"version_date" = now(),
			"readd" = dateAdd("h", 6, now()),
			"preparing" = true
		} />

		<cfreturn request.cacheMeta[arguments.typename].version />
	</cffunction>

	<cffunction name="finalizeCacheVersion" access="public" output="false" returntype="string" hint="Updates the global cache version to match this request's">
		<cfargument name="typename" type="string" required="false" default="app" />

		<cfset var key = rereplace(application.applicationname,'[^\w\d]','','ALL') & "_" & arguments.typename & "_cachemeta" />

		<cfif structKeyExists(request.cacheMeta[arguments.typename], "preparing")>
			<cfset structDelete(request.cacheMeta[arguments.typename], "preparing") />
			<cfset cacheAdd(key, request.cacheMeta[arguments.typename]) />
		</cfif>
	</cffunction>

	<cffunction name="cachePull" access="public" output="false" returntype="any" hint="Returns an object from cache if it is there, an empty struct if not. Note that garbage collected data counts as a miss.">
		<cfargument name="key" type="string" required="true" />
		
		<cfset var value = structnew() />
		<cfset var starttime = getTickCount() />
		<cfset var id = "memcached-get-#application.fapi.getUUID()#" />
		<cfset var memcached = getMemcached() />

		<cfif not structIsEmpty(memcached)>
			<cfset value = application.fc.lib.memcached.get(memcached,arguments.key) />
			
			<cfset this.pull_total = this.pull_total + getTickCount() - starttime />
			<cfset this.pull_count = this.pull_count + 1 />
		</cfif>
		
		<cfreturn value />
	</cffunction>
	
	<cffunction name="cacheAdd" access="public" output="false" returntype="void" hint="Puts the specified key in the cache. Note that if the key IS in cache or the data is deliberately empty, the cache is updated but cache queuing is not effected.">
		<cfargument name="key" type="string" required="true" />
		<cfargument name="data" type="struct" required="true" />
		<cfargument name="timeout" type="numeric" required="false" default="3600" hint="Number of seconds until this item should timeout" />
		
		<cfset var starttime = getTickCount() />
		<cfset var memcached = getMemcached() />
		
		<cfif not structIsEmpty(memcached)>
			<cfset application.fc.lib.memcached.set(memcached,arguments.key,arguments.data,arguments.timeout) />

			<cfset this.add_total = this.add_total + getTickCount() - starttime />
			<cfset this.add_count = this.add_count + 1 />
		</cfif>
	</cffunction>
	
	<cffunction name="cacheFlush" access="public" output="false" returntype="void" hint="Removes items from the cache that match the specified regex. Does NOT change the cache management stats.">
		<cfargument name="key" type="string" required="false" default="" />
		
		<cfset var memcached = getMemcached() />

		<cfif not structIsEmpty(memcached)>
			<cfset application.fc.lib.memcached.flush(memcached,arguments.key) />
		</cfif>
	</cffunction>
	
	<cffunction name="configureType" access="public" output="false" returntype="boolean">
		<cfargument name="typename" required="yes" type="string">
		<cfargument name="MaxObjects" required="no" type="numeric" default="100">
		<cfargument name="Timeout" required="no" type="numeric" default="3600">
		
		<cfset var bResult = "true" />
		
		<cfset application.objectbroker[arguments.typename] = {
			"maxobjects" = arguments.MaxObjects,
			"timeout" = arguments.timeout
		} />
		
		<cfreturn bResult />
	</cffunction>
	
	<cffunction name="getAveragePutTime" access="public" returntype="numeric" output="false" hint="Average number of milliseconds for a put">
		
		<cfif this.add_count eq 0>
			<cfreturn 0 />
		<cfelse>
			<cfreturn int(this.add_total / this.add_count) />
		</cfif>
	</cffunction>
	
	<cffunction name="getAverageGetTime" access="public" returntype="numeric" output="false" hint="Average number of milliseconds for a get">
		
		<cfif this.pull_count eq 0>
			<cfreturn 0 />
		<cfelse>
			<cfreturn int(this.pull_total / this.pull_count) />
		</cfif>
	</cffunction>
	
</cfcomponent>