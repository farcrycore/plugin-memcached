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
		
		<cflog type="information" application="true" file="memcached" text="Creating memcached client" />
		
		<cfif refindnocase(".*\.cfg.\w+.cache.amazonaws.com",arguments.config.servers)>
			
			<cfset addresses = javaLoader.create("net.spy.memcached.AddrUtil").getAddresses(
				listchangedelims(arguments.config.servers,"#chr(13)##chr(10)#,"," ")
			) />
			<cflog type="information" application="true" file="memcached" text="Configuration nodes: #addresses.toString()#" />
			
	        <cfset memcached = javaLoader.create("net.spy.memcached.MemcachedClient").init(addresses) />
			<cflog type="information" application="true" file="memcached" text="Memcached client set up" />
			
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
			<cflog type="information" application="true" file="memcached" text="Configuration: #connectionFactory.toString()#" />
			
			<cfset addresses = javaLoader.create("net.spy.memcached.AddrUtil").getAddresses(
				listchangedelims(arguments.config.servers,"#chr(13)##chr(10)#,"," ")
			) />
			<cflog type="information" application="true" file="memcached" text="Server nodes: #addresses.toString()#" />
			
	        <cfset memcached = javaLoader.create("net.spy.memcached.MemcachedClient").init(connectionFactory, addresses) />
			<cflog type="information" application="true" file="memcached" text="Memcached client set up" />
			
		</cfif>

		<cfreturn memcached />
	</cffunction>

	<cffunction name="get" access="public" output="false" returntype="struct" hint="Returns an object from cache if it is there, an empty struct if not. Note that garbage collected data counts as a miss.">
		<cfargument name="memcached" type="any" required="true" />
		<cfargument name="key" type="string" required="true" />
		
		<cfset var stLocal = structnew() />

        <cfset stLocal.value = structnew() />
		
		<cftry>
			<cfset stLocal.value = arguments.memcached.get(arguments.key) />
			
			<!--- catch nulls --->
			<cfif StructKeyExists(stLocal,"value")>
				<cfset stLocal.value = deserializeByteArray(stLocal.value) />
			<cfelse>
				<cfset stLocal.value = structnew() />
			</cfif>
			
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
				<cflog type="error" application="true" file="memcached" text="Error adding to cache: #cfcatch.message#" />
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
		<cfargument name="qItems" type="query" required="true">
		
		<cfset var q = querynew("webskin,num,size","varchar,varchar,integer")>
		<cfset var stResult = {} />
		
		<cfquery dbtype="query" name="q">
			<cfif application.dbType EQ "mssql">
				select 		webskin,count(key) as [num], sum([size]) as [size]
			</cfif>
			<cfif application.dbType EQ "mysql">
				select 		webskin,count(key) as num, sum(size) as size
			</cfif>
			from 		arguments.qItems 
			where		webskin<>''
			group by 	webskin
			order by 	webskin
		</cfquery>
		<cfset stResult.stats = q />

		<cfquery dbtype="query" name="q">
			<cfif application.dbType EQ "mssql">
				select 	sum([num]) as sumnum, 
						max([num]) as maxnum, 
						max([size]) as sumsize, 
						max([size]) as maxsize 
			</cfif>
			<cfif application.dbType EQ "mysql">
				select 	sum(num) as sumnum, 
						max(num) as maxnum, 
						max(size) as sumsize, 
						max(size) as maxsize 
			</cfif>
			from 	q
		</cfquery>
		<cfif q.recordcount>
			<cfset stResult.sumnum = q.sumnum />
			<cfset stResult.maxnum = q.maxnum />
			<cfset stResult.sumsize = q.sumsize />
			<cfset stResult.maxsize = q.maxsize />
		<cfelse>
			<cfset stResult.sumnum = 0 />
			<cfset stResult.maxnum = 0 />
			<cfset stResult.sumsize = 0 />
			<cfset stResult.maxsize = 0 />
		</cfif>
		
		<cfreturn stResult />
	</cffunction>

	<cffunction name="getItemSizeStats" returntype="struct" output="false">
		<cfargument name="qItems" type="query" required="true">
		
		<cfset var q = querynew("size,num","integer,integer")>
		<cfset var stResult = {} />
		
		<cfquery dbtype="query" name="q">
			<cfif application.dbType EQ "mssql">
				select		CAST(size as INTEGER) as [size], count(*) as [num]
				from		arguments.qItems
				group by 	[size]
				order by 	[size]
			</cfif>
			<cfif application.dbType EQ "mysql">
				select		CAST(size as INTEGER) as size, count(*) as num
				from		arguments.qItems
				group by 	size
				order by 	size
			</cfif>
		</cfquery>
		<cfset stResult.stats = q />
		
		<cfquery dbtype="query" name="q">
			<cfif application.dbType EQ "mssql">
				select 	sum([num]) as sumnum, 
						max([num]) as maxnum 
				from 	q
			</cfif>
			<cfif application.dbType EQ "mysql">
				select 	sum(num) as sumnum, 
						max(num) as maxnum 
				from 	q
			</cfif>
		</cfquery>
		<cfset stResult.sumnum = q.sumnum />
		<cfset stResult.maxnum = q.maxnum />
		
		<cfreturn stResult />
	</cffunction>

	<cffunction name="getItemTypeStats" returntype="struct" output="false">
		<cfargument name="qItems" type="query" required="true">
		
		<cfset var q = querynew("typename,objectsize,objectnum,webskinsize,webskinnum","varchar,bigint,integer,bigint,integer")>
		<cfset var stObjectSize = structnew() />
		<cfset var stObjectCount = structnew() />
		<cfset var stWebskinSize = structnew() />
		<cfset var stWebskinCount = structnew() />
		<cfset var stResult = {} />

		<cfloop query="arguments.qItems">
			<cfif not structkeyexists(stObjectSize,arguments.qItems.typename)>
				<cfset stObjectSize[arguments.qItems.typename] = 0 />
				<cfset stObjectCount[arguments.qItems.typename] = 0 />
				<cfset stWebskinSize[arguments.qItems.typename] = 0 />
				<cfset stWebskinCount[arguments.qItems.typename] = 0 />
			</cfif>
			
			<cfif listlen(arguments.qItems.key,"_") eq 3>
				<!--- object --->
				<cfset stObjectSize[arguments.qItems.typename] = stObjectSize[arguments.qItems.typename] + arguments.qItems.size />
				<cfset stObjectCount[arguments.qItems.typename] = stObjectCount[arguments.qItems.typename] + 1 />
			<cfelse>
				<!--- webskin --->
				<cfset stWebskinSize[arguments.qItems.typename] = stWebskinSize[arguments.qItems.typename] + arguments.qItems.size />
				<cfset stWebskinCount[arguments.qItems.typename] = stWebskinCount[arguments.qItems.typename] + 1 />
			</cfif>
		</cfloop>
		
		<cfloop collection="#stObjectSize#" item="i">
			<cfset queryaddrow(q) />
			<cfset querysetcell(q,"typename",i) />
			<cfset querysetcell(q,"objectsize",stObjectSize[i]) />
			<cfset querysetcell(q,"objectnum",stObjectCount[i]) />
			<cfset querysetcell(q,"webskinsize",stWebskinSize[i]) />
			<cfset querysetcell(q,"webskinnum",stWebskinCount[i]) />
		</cfloop>
		
		<cfloop collection="#application.stCOAPI#" item="i">
			<cfif listfindnocase("type,rule",application.stCOAPI[i].class) and not structkeyexists(stObjectSize,i)>
				<cfset queryaddrow(q) />
				<cfset querysetcell(q,"typename",i) />
				<cfset querysetcell(q,"objectsize",0) />
				<cfset querysetcell(q,"objectnum",0) />
				<cfset querysetcell(q,"webskinsize",0) />
				<cfset querysetcell(q,"webskinnum",0) />
			</cfif>
		</cfloop>

		<cfquery dbtype="query" name="q">select * from q order by typename asc</cfquery>
		<cfset stResult.stats = q />

		<cfquery dbtype="query" name="q">
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

	<cffunction name="getItemExpiryStats" returntype="struct" output="false">
		<cfargument name="qItems" type="query" required="true">
		<cfargument name="bBreakdown" type="boolean" required="false" default="false">
		
		<cfset var q = querynew("expires,expires_epoch,num","date,bigint,integer")>
		<cfset var stCount = structnew() />
		<cfset var expires = "" />
		<cfset var stResult = structnew() />

		<cfloop query="arguments.qItems">
			<cfset expires = "" & int(arguments.qItems.expires/60/15) * 60 * 15 />
			
			<cfif not structkeyexists(stCount,expires)>
				<cfset stCount[expires] = 0 />
			</cfif>
			
			<cfset stCount[expires] = stCount[expires] + 1 />
		</cfloop>
		
		<cfloop collection="#stCount#" item="i">
			<cfset queryaddrow(q) />
			<cfset querysetcell(q,"expires",DateAdd("s", i, "January 1 1970 00:00:00")) />
			<cfset querysetcell(q,"expires_epoch",i) />
			<cfset querysetcell(q,"num",stCount[i]) />
		</cfloop>
		
		<cfquery dbtype="query" name="q">select * from q order by expires asc</cfquery>
		<cfset stResult.stats = q />
		
		<cfquery dbtype="query" name="q">
			<cfif application.dbType EQ "mssql">
				select 	sum([num]) as sumnum, 
						max([num]) as maxnum
				from 	q
			</cfif>
			<cfif application.dbType EQ "mysql">
				select 	sum(num) as sumnum, 
						max(num) as maxnum
				from 	q
			</cfif>
		</cfquery>
		<cfset stResult.sumnum = q.sumnum />
		<cfset stResult.maxnum = q.maxnum />
		
		<!--- breakdowns for expiry times --->
		<cfif arguments.bBreakdown>
			<cfset stResult.breakdown = structnew() />
			<cfloop collection="#stCount#" item="expires">
				<cfif stCount[expires]>
					<cfquery dbtype="query" name="q">
						select		*
						from		arguments.qItems
						where		expires>=#expires# and expires<#expires+60*15#
					</cfquery>
					<cfset stResult.breakdown[expires] = getItemTypeStats(q) />
				<cfelse>
					<cfset stResult.breakdown[expires] = querynew("typename,objectsize,objectnum,webskinsize,webskinnum","varchar,bigint,integer,bigint,integer") />
				</cfif>
			</cfloop>
		</cfif>

		<cfreturn stResult />
	</cffunction>

	<cffunction name="getApplicationStats" returntype="struct" output="false">
		<cfargument name="qItems" type="query" required="true">
		
		<cfset var q = querynew("application,size,num","varchar,bigint,integer")>
		<cfset var stCount = structnew() />
		<cfset var stSize = structnew() />
		<cfset var i = 0 />
		<cfset var app = "" />
		<cfset var stResult = structnew() />
		
		<cfquery dbtype="query" name="q">
			<cfif application.dbType EQ "mssql">
				select		application, count(*) as [num], sum([size]) as [size]
			</cfif>
			<cfif application.dbType EQ "mysql">
				select		application, count(*) as num, sum(size) as size
			</cfif>
			from		arguments.qItems
			group by 	application
			order by 	application asc
		</cfquery>
		<cfset stResult.stats = q />
		
		<cfquery dbtype="query" name="q">
			<cfif application.dbType EQ "mssql">
				select 	sum([size]) as sumsize, 
						max([size]) as maxsize, 
						sum([num]) as sumnum, 
						max([num]) as maxnum
				from 	q
			</cfif>
			<cfif application.dbType EQ "mysql">
				select 	sum(size) as sumsize, 
						max(size) as maxsize, 
						sum(num) as sumnum, 
						max(num) as maxnum
				from 	q
			</cfif>
		</cfquery>
		<cfset stResult.sumsize = q.sumsize />
		<cfset stResult.maxsize = q.maxsize />
		<cfset stResult.sumnum = q.sumnum />
		<cfset stResult.maxnum = q.maxnum />
		
		<cfreturn stResult />
	</cffunction>

	<cffunction name="getItems" returntype="query" output="false">
		<cfargument name="server" type="string" required="true" />
		<cfargument name="app" type="string" required="false" />
		
		<cfset var slabs = slabStats(arguments.server) />
		<cfset var slabID = "" />
		<cfset var hostname = rereplace(arguments.server,"[^/]+/([^:]+):\d+","\1") />
		<cfset var port = rereplace(arguments.server,"[^/]+/[^:]+:(\d+)","\1") />
		<cfset var keys = "" />
		<cfset var item = "" />
		<cfset var st = "" />
		<cfset var qItems = querynew("key,size,expires,application,typename,webskin","varchar,integer,bigint,varchar,varchar,varchar") />
		
		<cfloop collection="#slabs#" item="slabID">
			<cfset keys = easySocket(hostname,port,"stats cachedump #slabID# #slabs[slabID].number#") />
			
			<cfloop from="1" to="#arraylen(keys)#" index="i">
				<cfset item = listtoarray(keys[i]," ") />
				<cfif not structkeyexists(arguments,"app") or listfirst(item[2],"_") eq arguments.app>
					<cfset queryaddrow(qItems) />
					<cfset querysetcell(qItems,"key",item[2]) />
					<cfset querysetcell(qItems,"size",mid(item[3],2,100) / 1024) />
					<cfset querysetcell(qItems,"expires",item[5]) />
					<cfif listlen(item[2],"_") eq 3 or listlen(item[2],"_") eq 6>
						<cfset querysetcell(qItems,"application",listgetat(item[2],1,"_")) />
						<cfset querysetcell(qItems,"typename",listgetat(item[2],2,"_")) />
						<cfif listlen(item[2],"_") eq 6>
							<cfset querysetcell(qItems,"webskin",listgetat(item[2],5,"_")) />
						</cfif>
					<cfelse>
						<cfset querysetcell(qItems,"application","Unknown") />
					</cfif>
				</cfif>
			</cfloop>
		</cfloop>
		
		<cfreturn qItems />
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