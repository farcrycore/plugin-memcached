<cfsetting enablecfoutputonly="true" />
<!--- @@fuAlias: server --->

<cfimport taglib="/farcry/core/tags/webskin" prefix="skin">

<cfset memcached = createobject("component","farcry.plugins.memcached.packages.lib.memcached") />
<cfset memcachedClient = application.fc.lib.objectbroker.getMemcached() />

<!--- get data --->
<cfset start = getTickCount() />
<cfset qItems = memcached.getItems(server=url.server) />
<cfset stApplications = memcached.getApplicationStats(qItems) />
<cfset processingTime = (getTickCount() - start) / 1000 />

<skin:htmlHead><cfoutput>
	<style>
		.progress { margin-bottom: 5px; margin-right:5px; }
		<cfif structkeyexists(application.fc.stCSSLibraries,"fc-bootstrap")>
			.progress .bar { color:##000000; }
		<cfelse>
			.progress .bar { background-color:##6096ee; }
		</cfif>
	</style>
</cfoutput></skin:htmlHead>

<cfoutput>
	<h1>Memcache Status - #url.server# - Overview</h1>
	<p><a href="#getServersURL()#">&lt; back to servers</a> | <a href="#getApplicationURL(url.server,application.applicationname)#">this application</a></p>
	<p>Processing time: #numberformat(processingTime,"0.00")#s</p>
	
	<h2>Items by application</h2>
	<table width="100%" class="table table-striped">
		<thead>
			<tr>
				<th width="20%">Application</th>
				<th width="40%">Cached Items</th>
				<th width="40%">Cache Size (Kb)</th>
			</tr>
		</thead>
		<tbody>
			<cfloop query="stApplications.stats">
				<tr>
					<td width="20%"><a href="#getApplicationURL(url.server,stApplications.stats.application)#">#stApplications.stats.application#</a></td>
					<td width="40%">#getProgressBar(stApplications.stats.num,stApplications.maxnum,stApplications.stats.num,"progress-info")#</td>
					<td width="40%">#getProgressBar(stApplications.stats.size,stApplications.maxsize,stApplications.stats.size,"progress-success")#</td>
				</tr>
			</cfloop>
		</tbody>
	</table>
</cfoutput>

<cfsetting enablecfoutputonly="false" />