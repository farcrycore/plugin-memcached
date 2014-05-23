<cfsetting enablecfoutputonly="true" />
<!--- @@fuAlias: application --->

<cfimport taglib="/farcry/core/tags/webskin" prefix="skin">

<cfset memcached = createobject("component","farcry.plugins.memcached.packages.lib.memcached") />

<!--- get data --->
<cfset start = getTickCount() />
<cfset qItems = memcached.getItems(url.server,url.app) />
<cfset stSizes = memcached.getItemSizeStats(qItems) />
<cfset stTypes = memcached.getItemTypeStats(qItems) />
<cfset stExpiries = memcached.getItemExpiryStats(qItems) />
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
	<h1>Memcache Status - #url.server# - #url.app#</h1>
	<p>
		<cfif not structkeyexists(url,"id")>
			<a href="#application.fapi.fixURL(addvalues='module=utilities/status.cfm',removevalues='server,app')#">&lt; back to servers</a> 
			| 
			<a href="#application.fapi.fixURL(addvalues='module=utilities/status_app.cfm&app=#application.applicationname#',removevalues='app')#">overview</a>
		<cfelse>
			<a href="#application.fapi.fixURL(addvalues='type=configMemcached&bodyView=webtopBody',removevalues='id')#">&lt; back to servers</a>
			| 
			<a href="#application.fapi.fixURL(addvalues='type=configMemcached&bodyView=webtopBodyServer&server=#url.server#',removevalues='id')#">overview</a>
		</cfif>
	</p>
	<p>Processing time: #numberformat(processingTime,"0.00")#s</p>
	
	<h2>Items sizes</h2>
	<table width="100%" class="table table-striped">
		<thead>
			<tr>
				<th width="20%">Size (Kb)</th>
				<th width="80%">Cached Items</th>
			</tr>
		</thead>
		<tbody>
			<cfloop query="stSizes.stats">
				<tr>
					<td width="20%">#stSizes.stats.size#</td>
					<td width="80%">#getProgressBar(stSizes.stats.num,stSizes.maxnum,stSizes.stats.num,"progress-info")#</td>
				</tr>
			</cfloop>
		</tbody>
	</table>
	
	<h2>Item types</h2>
	<table width="100%" class="table table-striped">
		<thead>
			<tr>
				<th width="20%">Typename</th>
				<th width="20%">Object Items</th>
				<th width="20%">Object Size (Kb)</th>
				<th width="20%">Webskin Items</th>
				<th width="20%">Webskin Size (Kb)</th>
			</tr>
		</thead>
		<tbody>
			<cfloop query="stTypes.stats">
				<tr>
					<td width="20%">#stTypes.stats.typename#</td>
					<td width="20%">#getProgressBar(stTypes.stats.objectnum,stTypes.maxobjectnum,stTypes.stats.objectnum,"progress-info")#</td>
					<td width="20%">#getProgressBar(stTypes.stats.objectsize,stTypes.maxobjectsize,numberformat(stTypes.stats.objectsize,"0.00"),"progress-success")#</td>
					<td width="20%">#getProgressBar(stTypes.stats.webskinnum,stTypes.maxwebskinnum,stTypes.stats.webskinnum,"progress-info")#</td>
					<td width="20%">#getProgressBar(stTypes.stats.webskinsize,stTypes.maxwebskinsize,numberformat(stTypes.stats.webskinsize,"0.00"),"progress-success")#</td>
				</tr>
			</cfloop>
		</tbody>
	</table>
	
	<h2>Item expiries</h2>
	<table width="100%" class="table table-striped">
		<thead>
			<tr>
				<th width="20%">Expires (15min increments)</th>
				<th width="80%">Cached Items</th>
			</tr>
		</thead>
		<tbody>
			<cfloop query="stExpiries.stats">
				<tr>
					<td width="20%"><span title="#timeformat(stExpiries.stats.expires,"HH:mm")# #dateformat(stExpiries.stats.expires,"d mmm yy")#">#application.fapi.prettyDate(stExpiries.stats.expires,true)#</span></td>
					<td width="80%">#getProgressBar(stExpiries.stats.num,stExpiries.maxnum,stExpiries.stats.num,"progress-info")#</td>
				</tr>
			</cfloop>
		</tbody>
	</table>
</cfoutput>

<cfsetting enablecfoutputonly="false" />