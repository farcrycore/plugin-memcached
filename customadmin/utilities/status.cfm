<cfsetting enablecfoutputonly="true" />

<cfimport taglib="/farcry/core/tags/admin" prefix="admin" />

<admin:header>

<cfoutput><h1>Memcache Status</h1></cfoutput>

<cfoutput>
	<h2>Average Times</h2>
	<table width="100px;">
		<tr>
			<th>Put</th>
			<td>#application.fc.lib.objectbroker.getAveragePutTime()#ms</td>
		</tr>
		<tr>
			<th>Get</th>
			<td>#application.fc.lib.objectbroker.getAverageGetTime()#ms</td>
		</tr>
	</table>
</cfoutput>

<cfset aServers = application.fc.lib.objectbroker.memcachedAvailableServers() />
<cfset aUnavailable = application.fc.lib.objectbroker.memcachedUnavailableServers() />
<cfset stServerStats = application.fc.lib.objectbroker.memcachedStats() />
<cfoutput>
	<h2>Available Servers</h2>
	<table width="100%">
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
					<td>#aServers[i].gethostname()#</td>
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

<admin:footer>

<cfsetting enablecfoutputonly="false" />