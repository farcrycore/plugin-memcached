<cfcomponent>

	<cffunction name="initializeClient" access="public" output="false" returntype="any">
		<cfargument name="config" type="struct" required="true" />

		<cfset var memcached = "" />
		<cfset var javaLoader = CreateObject("component", "farcry.core.packages.farcry.javaloader.JavaLoader").init(
			listtoarray(expandpath("/farcry/plugins/memcached/packages/java/AmazonElastiCacheClusterClient-1.0.jar"))
		) />
		<cfset var addresses = "" />
		<cfset var clientMode = "" />
		<cfset var protocolType = "" />
		<cfset var locatorType = "" />
		<cfset var connectionFactory = "" />
		
		<cflog type="information" file="#application.applicationname#_memcached" text="Creating memcached client" />
		
		<cfif refindnocase(".*\.cfg.\w+.cache.amazonaws.com",arguments.config.servers)>
			
			<cfset addresses = javaLoader.create("net.spy.memcached.AddrUtil").getAddresses(
				listchangedelims(arguments.config.servers,"#chr(13)##chr(10)#,"," ")
			) />
			<cflog type="information" file="#application.applicationname#_memcached" text="Configuration nodes: #addresses.toString()#" />
			
	        <cfset memcached = javaLoader.create("net.spy.memcached.MemcachedClient").init(addresses) />
			<cflog type="information" file="#application.applicationname#_memcached" text="Memcached client set up" />
			
		<cfelse>
		
			<cfset clientMode = javaLoader.create("net.spy.memcached.ClientMode") />
			<cfset protocolType = javaLoader.create("net.spy.memcached.ConnectionFactoryBuilder$Protocol") />
			<cfset locatorType = javaLoader.create("net.spy.memcached.ConnectionFactoryBuilder$Locator") />
			<cfset connectionFactory = javaLoader.create("net.spy.memcached.ConnectionFactoryBuilder")
				.setProtocol(protocolType[arguments.config.protocol])
				.setLocatorType(locatorType[arguments.config.locator])
				.setOpTimeout(JavaCast( "int", arguments.config.operationTimeout ) )
				.setClientMode(clientMode["Static"])
				.build() />
			<cflog type="information" file="#application.applicationname#_memcached" text="Configuration: #connectionFactory.toString()#" />
			
			<cfset addresses = javaLoader.create("net.spy.memcached.AddrUtil").getAddresses(
				listchangedelims(arguments.config.servers,"#chr(13)##chr(10)#,"," ")
			) />
			<cflog type="information" file="#application.applicationname#_memcached" text="Server nodes: #addresses.toString()#" />
			
	        <cfset memcached = javaLoader.create("net.spy.memcached.MemcachedClient").init(connectionFactory, addresses) />
			<cflog type="information" file="#application.applicationname#_memcached" text="Memcached client set up" />
			
		</cfif>

		<cfreturn memcached />
	</cffunction>

	<cffunction name="get" access="public" output="false" returntype="struct" hint="Returns an object from cache if it is there, an empty struct if not. Note that garbage collected data counts as a miss.">
		<cfargument name="memcached" type="any" required="true" />
		<cfargument name="key" type="string" required="true" />
		
		<cfset var stLocal = structnew() />

        <cfset stLocal.value = structnew() />
		
		<cftry>
			<cfset stLocal.value = arguments..memcached.get(arguments.key) />
			
			<!--- catch nulls --->
			<cfif NOT StructKeyExists(stLocal,"value")>
				<cfset stLocal.value = structnew() />
			</cfif>
			
			<cfset stLocal.value = deserializeByteArray(stLocal.value) />
			
			<cfcatch>
				<cfset stLocal.value = structnew() />
			</cfcatch>
		</cftry>
		
		<cfreturn stLocal.value />
	</cffunction>
	
	<cffunction name="set" access="public" output="false" returntype="void" hint="Puts the specified key in the cache. Note that if the key IS in cache or the data is deliberately empty, the cache is updated but cache queuing is not effected.">
		<cfargument name="memcached" type="any" required="true" />
		<cfargument name="key" type="string" required="true" />
		<cfargument name="data" type="struct" required="true" />
		<cfargument name="timeout" type="numeric" required="false" default="3600" hint="Number of seconds until this item should timeout" />
		
		<cftry>
			<cfset arguments.memcached.set(arguments.key, min(arguments.timeout,60*60*24*30), serializeByteArray(arguments.data)) />
			
			<cfcatch>
				<cflog type="error" file="#application.applicationname#_memcached" text="Error adding to cache: #cfcatch.message#" />
				<cfset application.fc.lib.error.logData(application.fc.lib.error.normalizeError(cfcatch)) />
			</cfcatch>
		</cftry>
	</cffunction>
	
	<cffunction name="flush" access="public" output="false" returntype="void" hint="Removes items from the cache that match the specified regex. Does NOT change the cache management stats.">
		<cfargument name="memcached" type="any" required="true" />
		<cfargument name="key" type="string" required="false" default="" />
		
		<cftry>
			<cfset arguments.memcached.delete(arguments.key) />
			
			<cfcatch>
				<!--- do nothing --->
			</cfcatch>
		</cftry>
	</cffunction>
	
	<cffunction name="getAvailableServers" access="public" returntype="any" output="false" hint="Get the addresses of available servers.">
		<cfargument name="memcached" type="any" required="true" />

		<cfreturn arguments.memcached.getAvailableServers() />
	</cffunction>
	
	<cffunction name="getServerStats" access="public" returntype="any" output="false" hint="Get all of the stats from all of the connections.">
		<cfargument name="memcached" type="any" required="true" />
		
		<cfset var stats = structnew() />
		<cfset var i = "" />
		
		<cfset stats = mapToStruct(arguments.memcached.getStats()) />
		
		<cfloop collection="#stats#" item="i">
			<cfset stats[i] = mapToStruct(stats[i]) />
		</cfloop>
		
		<cfreturn stats />
	</cffunction>
	
	<cffunction name="getUnavailableServers" access="public" returntype="any" output="false" hint="Get the addresses of unavailable servers.">
		<cfargument name="memcached" type="any" required="true" />
		
		<cfreturn arguments.memcached.getUnavailableServers() />
	</cffunction>
	
	<cffunction name="getVersions" access="public" returntype="any" output="false" hint="Get the versions of all of the connected memcacheds.">
		<cfargument name="memcached" type="any" required="true" />
		
		<cfset var versions = structnew() />
		
		<cfif structkeyexists(this,"memcached")>
			<cfset versions = mapToStruct(arguments.memcached.getVersions()) />
		</cfif>
		
		<cfreturn versions />
	</cffunction>
	
    <cffunction name="mapToStruct" access="private" returntype="struct" output="false">
        <cfargument name="map" type="any" required="true" />

        <cfset var theStruct = {} />
        <cfset var entrySet = "" />
        <cfset var iterator = "" />
        <cfset var entry = "" />
        <cfset var key = "" />
        <cfset var value = "" />

        <cfset entrySet = arguments.map.entrySet() />
        <cfset iterator = entrySet.iterator() />

        <cfloop condition="#iterator.hasNext()#">
            <cfset entry = iterator.next() />
            <cfset key = entry.getKey() />
            <cfset value = entry.getValue() />
            <cfset theStruct[key] = value />
        </cfloop>

        <cfreturn theStruct />
    </cffunction>
	
	<cffunction name="getItemWebskinStats" returntype="struct" output="false">
		<cfargument name="items" type="array" required="true">
		<cfargument name="typename" type="string" required="true">
		
		<cfset var q = querynew("webskin,num","varchar,varchar,integer")>
		<cfset var stCount = structnew() />
		<cfset var i = 0 />
		<cfset var thistype = "" />
		<cfset var webskin = "" />
		<cfset var stResult = {} />
		
		<cfloop from="1" to="#arraylen(arguments.items)#" index="i">
			<cfset thistype = listgetat(arguments.items[i].key,2,"_") />
			<cfif thistype eq arguments.typename and listlen(arguments.items[i],"_") eq 6>
				<cfset webskin = listgetat(arguments[i],5,"_") />
				
				<cfif not structkeyexists(stCount,typename)>
					<cfset stCount[webskin] = 0 />
				</cfif>
				
				<cfset stCount[webskin] = stCount[webskin] + 1 />
			</cfif>
		</cfloop>
		
		<cfloop collection="#stCount#" item="i">
			<cfset queryaddrow(q) />
			<cfset querysetcell(q,"webskin",i) />
			<cfset querysetcell(q,"num",stCount[i]) />
		</cfloop>
		
		<cfquery dbtype="query" name="q">select * from q order by webskin asc</cfquery>
		<cfset stResult.stats = q />

		<cfquery dbtype="query" name="q">
			select 	sum([num]) as sumnum, 
					max([num]) as maxnum 
			from 	q
		</cfquery>
		<cfset stResult.sumnum = q.sumnum />
		<cfset stResult.maxnum = q.maxnum />
		
		<cfreturn stResult />
	</cffunction>

	<cffunction name="getItemSizeStats" returntype="struct" output="false">
		<cfargument name="items" type="array" required="true">
		
		<cfset var q = querynew("size,num","integer,integer")>
		<cfset var st = structnew() />
		<cfset var i = 0 />
		<cfset var size = 0 />
		<cfset var stResult = {} />
		
		<cfloop from="1" to="#arraylen(arguments.items)#" index="i">
			<cfset size = "" & (int(arguments.items[i].size / 1024)) />
			<cfif not structkeyexists(st,size)>
				<cfset st[size] = 0 />
			</cfif>
			<cfset st[size] = st[size] + 1 />
		</cfloop>
		
		<cfloop collection="#st#" item="i">
			<cfset queryaddrow(q) />
			<cfset querysetcell(q,"size",i) />
			<cfset querysetcell(q,"num",st[i]) />
		</cfloop>
		
		<cfquery dbtype="query" name="q">select * from q order by size asc</cfquery>
		<cfset stResult.stats = q />
		
		<cfquery dbtype="query" name="q">
			select 	sum([num]) as sumnum, 
					max([num]) as maxnum 
			from 	q
		</cfquery>
		<cfset stResult.sumnum = q.sumnum />
		<cfset stResult.maxnum = q.maxnum />
		
		<cfreturn stResult />
	</cffunction>

	<cffunction name="getItemTypeStats" returntype="query" output="false">
		<cfargument name="items" type="array" required="true">
		
		<cfset var q = querynew("typename,objectsize,objectnum,webskinsize,webskinnum","varchar,bigint,integer,bigint,integer")>
		<cfset var stObjectSize = structnew() />
		<cfset var stObjectCount = structnew() />
		<cfset var stWebskinSize = structnew() />
		<cfset var stWebskinCount = structnew() />
		<cfset var i = 0 />
		<cfset var typename = "" />
		<cfset var stResult = {} />
		
		<cfloop from="1" to="#arraylen(arguments.items)#" index="i">
			<cfset typename = listgetat(arguments.items[i].key,2,"_") />
			<cfif not structkeyexists(stObjectSize,typename)>
				<cfset stObjectSize[typename] = 0 />
				<cfset stObjectCount[typename] = 0 />
				<cfset stWebskinSize[typename] = 0 />
				<cfset stWebskinCount[typename] = 0 />
			</cfif>
			
			<cfif listlen(arguments.items[i].key,"_") eq 3>
				<!--- object --->
				<cfset stObjectSize[typename] = stObjectSize[typename] + arguments.items[i].size />
				<cfset stObjectCount[typename] = stObjectCount[typename] + 1 />
			<cfelse>
				<!--- webskin --->
				<cfset stWebskinSize[typename] = stWebskinSize[typename] + arguments.items[i].size />
				<cfset stWebskinCount[typename] = stWebskinCount[typename] + 1 />
			</cfif>
		</cfloop>
		
		<cfloop collection="#stObjectSize#" item="i">
			<cfset queryaddrow(q) />
			<cfset querysetcell(q,"typename",i) />
			<cfset querysetcell(q,"objectsize",stObjectSize[i]/1024) />
			<cfset querysetcell(q,"objectnum",stObjectCount[i]) />
			<cfset querysetcell(q,"webskinsize",stWebskinSize[i]/1024) />
			<cfset querysetcell(q,"webskinnum",stWebskinCount[i]) />
		</cfloop>
		
		<cfquery dbtype="query" name="q">select * from q order by typename asc</cfquery>
		<cfset stResult.stats = q />

		<cfquery dbtype="query" name="qItemTypeSummary">
			select 	sum(objectsize) as sumobjectsize, 
					max(objectsize) as maxobjectsize, 
					sum(objectnum) as sumobjectnum, 
					max(objectnum) as maxobjectnum, 
					sum(webskinsize) as sumwebskinsize, 
					max(webskinsize) as maxwebskinsize, 
					sum(webskinnum) as sumwebskinnum, 
					max(webskinnum) as maxwebskinnum 
			from 	q
		</cfquery>
		<cfset stResult.sumobjectsize = q.sumobjectsize />
		<cfset stResult.maxobjectsize = q.maxobjectsize />
		<cfset stResult.sumobjectnum = q.sumobjectnum />
		<cfset stResult.maxobjectnum = q.maxobjectnum />
		<cfset stResult.sumwebskinsize = q.sumwebskinsize />
		<cfset stResult.maxwebskinsize = q.maxwebskinsize />
		<cfset stResult.sumwebskinnum = q.sumwebskinnum />
		<cfset stResult.maxwebskinnum = q.maxwebskinnum />
		
		<cfreturn stResult />
	</cffunction>

	<cffunction name="getItemExpiryStats" returntype="query" output="false">
		<cfargument name="items" type="array" required="true">
		
		<cfset var q = querynew("expires,num","date,integer")>
		<cfset var stCount = structnew() />
		<cfset var i = 0 />
		<cfset var expires = "" />
		<cfset var stResult = structnew() />
		
		<cfloop from="1" to="#arraylen(arguments.items)#" index="i">
			<cfset expires = "" & int(arguments.items[i].expires/60/15) * 60 * 15 />
			
			<cfif not structkeyexists(stCount,expires)>
				<cfset stCount[expires] = 0 />
			</cfif>
			
			<cfset stCount[expires] = stCount[expires] + 1 />
		</cfloop>
		
		<cfloop collection="#stCount#" item="i">
			<cfset queryaddrow(q) />
			<cfset querysetcell(q,"expires",DateAdd("s", i, "January 1 1970 00:00:00")) />
			<cfset querysetcell(q,"num",stCount[i]) />
		</cfloop>
		
		<cfquery dbtype="query" name="q">select * from q order by expires asc</cfquery>
		<cfset stResult.stats = q />
		
		<cfquery dbtype="query" name="q">
			select 	sum([num]) as sumnum, 
					max([num]) as maxnum
			from 	q
		</cfquery>
		<cfset stResult.sumnum = q.sumnum />
		<cfset stResult.maxnum = q.maxnum />
		
		<cfreturn stResult />
	</cffunction>

	<cffunction name="getApplicationStats" returntype="query" output="false">
		<cfargument name="items" type="array" required="true">
		
		<cfset var q = querynew("application,size,num","varchar,bigint,integer")>
		<cfset var stCount = structnew() />
		<cfset var stSize = structnew() />
		<cfset var i = 0 />
		<cfset var app = "" />
		<cfset var stResult = structnew() />
		
		<cfloop from="1" to="#arraylen(arguments.items)#" index="i">
			<cfif refindnocase("^[^_]+_.*?_[\w\d]{8}-[\w\d]{4}-[\w\d]{4}-[\w\d]{16}",arguments.items[i].key)>
				<cfset app = listgetat(arguments.items[i].key,1,"_") />
				<cfset type = listgetat(arguments.items[i].key,2,"_") />
				
				<cfif not structkeyexists(stCount,app)>
					<cfset stCount[app] = 0 />
					<cfset stSize[app] = 0 />
				</cfif>
				
				<cfset stCount[app] = stCount[app] + 1 />
				<cfset stSize[app] = stSize[app] + arguments.items[i].size />
			</cfif>
		</cfloop>
		
		<cfloop collection="#stCount#" item="i">
			<cfset queryaddrow(q) />
			<cfset querysetcell(q,"application",i) />
			<cfset querysetcell(q,"size",stSize[i]/1024) />
			<cfset querysetcell(q,"num",stCount[i]) />
		</cfloop>
		
		<cfquery dbtype="query" name="q">select * from q order by application asc</cfquery>
		<cfset stResult.stats = q />
		
		<cfquery dbtype="query" name="q">
			select 	sum([size]) as sumsize, 
					max([size]) as maxsize, 
					max([num]) as maxnum, 
					max([num]) as maxnum
			from 	q
		</cfquery>
		<cfset stResult.sumsize = q.sumsize />
		<cfset stResult.maxsize = q.maxsize />
		<cfset stResult.sumnum = q.sumnum />
		<cfset stResult.maxnum = q.maxnum />
		
		<cfreturn stResult />
	</cffunction>

	<cffunction name="itemStats" returntype="array" output="false">
		<cfargument name="server" type="string" required="true" />
		<cfargument name="app" type="string" required="false" />
		
		<cfset var slabs = slabStats(arguments.server) />
		<cfset var slabID = "" />
		<cfset var hostname = rereplace(arguments.server,"[^/]+/([^:]+):\d+","\1") />
		<cfset var port = rereplace(arguments.server,"[^/]+/[^:]+:(\d+)","\1") />
		<cfset var items = arraynew(1) />
		<cfset var keys = "" />
		<cfset var item = "" />
		<cfset var st = "" />
		
		<cfloop collection="#slabs#" item="slabID">
			<cfset keys = easySocket(hostname,port,"stats cachedump #slabID# #slabs[slabID].number#") />
			<cfloop from="1" to="#arraylen(keys)#" index="i">
				<cfset item = listtoarray(keys[i]," ") />
				<cfif not structkeyexists(arguments,"app") or listfirst(item[2],"_") eq arguments.app>
					<cfset st = structnew() />
					<cfset st["key"] = item[2] />
					<cfset st["size"] = mid(item[3],2,100) />
					<cfset st["expires"] = item[5] />
					<cfset arrayappend(items,st) />
				</cfif>
			</cfloop>
		</cfloop>
		
		<cfreturn items />
	</cffunction>

	<cffunction name="slabStats" returntype="struct" output="false">
		<cfargument name="server" type="string" required="false" />
		
		<cfset var stats = mapToStruct(application.fc.lib.objectbroker.memcached.getStats('items')) />
		<cfset var socket = "" />
		
		<cfloop collection="#stats#" item="socket">
			<cfif structkeyexists(arguments,"server")>
				<cfif findnocase(arguments.server,socket)>
					<cfreturn slabifyStats(stats[socket]) />
				</cfif>
			<cfelse>
				<cfset stats[socket] = slabifyStats(stats[socket]) />
			</cfif>
		</cfloop>
		
		<cfif structkeyexists(arguments,"server")>
			<!--- can only get here if the server wasn't found in the stats --->
			<cfset stats = structnew() />
		</cfif>
		
		<cfreturn stats />
	</cffunction>

	<cffunction name="slabifyStats" returntype="struct" output="false">
		<cfargument name="map" type="any" required="true" />
		
		<cfset var stats = mapToStruct(arguments.map) />
		<cfset var result = structnew() />
		<cfset var key = "" />
		<cfset var slabID = "" />
		
		<cfloop collection="#stats#" item="key">
			<cfset slabID = listgetat(key,2,":") />
			<cfif not structkeyexists(result,slabID)>
				<cfset result[slabID] = structnew() />
			</cfif>
			<cfset result[slabID][listgetat(key,3,":")] = stats[key] />
		</cfloop>
		
		<cfreturn result />
	</cffunction>

	<!---
	 Connect to sockets through your ColdFusion application.
	 Mods by Raymond Camden
	 
	 @param host      Host to connect to. (Required)
	 @param port      Port for connection. (Required)
	 @param message      Message to be sent. (Required)
	 @return Returns a string. 
	 @author George Georgiou (george1977@gmail.com) 
	 @version 1, August 27, 2009 
	--->
	<cffunction name="easySocket" access="private" returntype="any" hint="Uses Java Sockets to connect to a remote socket over TCP/IP" output="false">
		<cfargument name="host" type="string" required="yes" default="localhost" hint="Host to connect to and send the message">
		<cfargument name="port" type="numeric" required="Yes" default="8080" hint="Port to connect to and send the message">
		<cfargument name="message" type="string" required="yes" default="" hint="The message to transmit">

		<cfset var result = arraynew(1)>
		<cfset var socket = createObject( "java", "java.net.Socket" )>
		<cfset var streamOut = "">
		<cfset var output = "">
		<cfset var input = "">
		<cfset var line = "" />

		<cftry>
			<cfset socket.init(arguments.host,arguments.port)>
			<cfcatch type="Object">
				<cfthrow message="Could not connected to host <strong>#arguments.host#</strong>, port <strong>#arguments.port#</strong>">
			</cfcatch>  
		</cftry>

		<cfif socket.isConnected()>
			<cfset streamOut = socket.getOutputStream()>

			<cfset output = createObject("java", "java.io.PrintWriter").init(streamOut)>
			<cfset streamInput = socket.getInputStream()>

			<cfset inputStreamReader= createObject( "java", "java.io.InputStreamReader").init(streamInput)>
			<cfset input = createObject( "java", "java.io.BufferedReader").init(InputStreamReader)>

			<cfset output.println(arguments.message)>
			<cfset output.println()> 
			<cfset output.flush()>

			<cfset line = input.readLine()>
			<cfloop condition="line neq 'END'">
				<cfset arrayappend(result,line) />
				<cfset line = input.readLine()>
			</cfloop>
			<cfset socket.close()>
		<cfelse>
			<cfthrow message="Could not connected to host <strong>#arguments.host#</strong>, port <strong>#arguments.port#</strong>.">
		</cfif>

		<cfreturn result>
	</cffunction>

	<!--- General utility functions --->
	<cffunction name="serializeByteArray" access="private" returntype="any" output="false">
		<cfargument name="value" type="any" required="true" />
		
		<cfset var byteArrayOutputStream = "" />
		<cfset var objectOutputStream = "" />
		<cfset var serializedValue = "" />
		
		<cfif IsSimpleValue(arguments.value)>
			<cfreturn arguments.value />
		<cfelse>
			<cfset byteArrayOutputStream = CreateObject("java","java.io.ByteArrayOutputStream").init() />
			<cfset objectOutputStream = CreateObject("java","java.io.ObjectOutputStream").init(byteArrayOutputStream) />
			<cfset objectOutputStream.writeObject(arguments.value) />
			<cfset serializedValue = byteArrayOutputStream.toByteArray() />
			<cfset objectOutputStream.close() />
			<cfset byteArrayOutputStream.close() />
		</cfif>
		
		<cfreturn serializedValue />
	</cffunction>
	
	<cffunction name="deserializeByteArray" access="private" returntype="any" output="false">
		<cfargument name="value" type="any" required="true" />
		
		<cfset var deserializedValue = "" />
		<cfset var objectInputStream = "" />
		<cfset var byteArrayInputStream = "" />
		
		<cfif IsSimpleValue(arguments.value)>
			<cfreturn arguments.value />
		<cfelse>
			<cfset objectInputStream = CreateObject("java","java.io.ObjectInputStream") />
			<cfset byteArrayInputStream = CreateObject("java","java.io.ByteArrayInputStream") />
			<cfset objectInputStream.init(byteArrayInputStream.init(arguments.value)) />
			<cfset deserializedValue = objectInputStream.readObject() />
			<cfset objectInputStream.close() />
			<cfset byteArrayInputStream.close() />
		</cfif>
		
		<cfreturn deserializedValue />
	</cffunction>

</cfcomponent>