<cfsetting enablecfoutputonly="true" />

<cfset memcached = createobject("component","facry.plugins.memcached.packages.lib.memcached") />

<!--- get data --->
<cfset start = getTickCount() />
<cfset aUnavailable = memcached.getAvailableServers(application.fc.lib.objectbroker.memcached) />
<cfset aUnavailable = memcached.getUnavailableServers(application.fc.lib.objectbroker.memcached) />
<cfset aUnavailable = memcached.getServerStats(application.fc.lib.objectbroker.memcached) />
<cfset processingTime = (getTickCount() - start) / 1000 />

<cfoutput>
	<h1>Memcache Status - Overview</h1>
	<p>Processing time: #numberformat(processingTime,"0.00")#s</p>
	
	<h2>Average Times</h2>
	<table width="100px;" class="table">
		<tr>
			<th>Put</th>
			<td>#application.fc.lib.objectbroker.getAveragePutTime()#ms</td>
		</tr>
		<tr>
			<th>Get</th>
			<td>#application.fc.lib.objectbroker.getAverageGetTime()#ms</td>
		</tr>
	</table>
	
	<h2>Memcached Servers</h2>
	<table width="100%" class="table table-striped">
		<thead>
			<tr>
				<th>Hostname</th>
				<th>Port</th>
				<th>Resolved</th>
				<th>Uptime</th>
				<th>Stored Data</th>
				<th>Read Data</th>
				<th>Items</th>
				<th>Misses</th>
				<th>Hits</th>
				<th>Evictions</th>
			</tr>
		</thead>
		<tbody>
			<cfloop from="1" to="#arraylen(aServers)#" index="i">
				<cfset name = aServers[i].toString() />
				<tr>
					<td>
						#aServers[i].gethostname()# 
						<cfif structkeyexists(url,"module")>
							( 
								<a href="#application.fapi.fixURL(addvalues='module=utilities/status_server.cfm&server=#aServers[i].toString()#',removevalues='app')#">overview</a> 
								| 
								<a href="#application.fapi.fixURL(addvalues='module=utilities/status_app.cfm&server=#aServers[i].toString()#&app=#application.applicationname#')#">this application</a> 
							)
						<cfelse>
							( 
								<a href="#application.fapi.getLink(type='configMemcached',view='webtopPageStandard',bodyView='webtopBodyServer',urlParameters='id=#url.id#&server=#aServers[i].toString()#&app=#application.applicationname#')#">overview</a>
								| 
								<a href="#application.fapi.getLink(type='configMemcached',view='webtopPageStandard',bodyView='webtopBodyApplication',urlParameters='id=#url.id#&server=#aServers[i].toString()#')#">this application</a>
							)
						</cfif>
					</td>
					<td>#aServers[i].getPort()#</td>
					<td>#not aServers[i].isUnresolved()#</td>
					<cfif aServers[i].isUnresolved()>
						<td></td>
						<td></td>
						<td></td>
						<td></td>
						<td></td>
						<td></td>
						<td></td>
					<cfelse>
						<td>
							<cfif stServerStats[name].uptime gt 86400>#int(stServerStats[name].uptime / 86400)#d</cfif>
							<cfif stServerStats[name].uptime mod 86400 gt 3600>#int((stServerStats[name].uptime mod 86400)/3600)#h</cfif>
							<cfif stServerStats[name].uptime mod 3600 gt 60>#int((stServerStats[name].uptime mod 3600)/60)#m</cfif>
						</td>
						<td>#numberformat(stServerStats[name].bytes/1024/1024,"0.00")#Mb</td>
						<td>#numberformat(stServerStats[name].bytes_read/1024/1024,"0.00")#Mb</td>
						<td>#stServerStats[name].total_items#</td>
						<td>#stServerStats[name].get_misses#</td>
						<td>#stServerStats[name].get_hits#</td>
						<td>#stServerStats[name].evictions#</td>
					</cfif>
				</tr>
			</cfloop>
		</tbody>
	</table>
</cfoutput>

<cfsetting enablecfoutputonly="false" />