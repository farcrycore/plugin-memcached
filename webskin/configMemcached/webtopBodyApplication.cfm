<cfsetting enablecfoutputonly="true" />
<!--- @@fuAlias: application --->

<cfimport taglib="/farcry/core/tags/webskin" prefix="skin">

<cfset memcached = createobject("component","facry.plugins.memcached.packages.lib.memcached") />

<!--- get data --->
<cfset start = getTickCount() />
<cfset items = memcached.itemStats(url.server,url.app) />
<cfset stSizes = memcached.getItemSizeStats(items) />
<cfset stTypes = memcached.getItemTypeStats(items) />
<cfset stExpiries = memcached.getItemExpiryStats(items) />
<cfset processingTime = (getTickCount() - start) / 1000 />

<skin:htmlHead>
	<style>
		.progress { margin-bottom: 5px; margin-right:5px; }
		<cfif not structkeyexists(application.fc.stCSSLibraries,"fc-bootstrap")>
			.progress .bar { color:##ffffff; }
		<cfelse>
			.progress .bar { background-color:##6096ee; }
		</cfif>
	</style>
</skin:htmlHead>

<cfoutput>
	<h1>Memcache Status - #url.server# - #url.app#</h1>
	<p>
		<cfif structkeyexists(url,"module")>
			<a href="#application.fapi.fixURL(addvalues='module=utilities/status.cfm&removevalues='server,app')#">&lt; back to servers</a> 
			| 
			<a href="#application.fapi.fixURL(addvalues='module=utilities/status_app.cfm&app=#application.applicationname#',removevalues='app')#">overview</a>
		<cfelse>
			<a href="#application.fapi.getLink(type='configMemcached',view='webtopPageStandard',bodyView='webtopBody',urlParameters='id=#url.id#')#">&lt; back to servers</a>
			| 
			<a href="#application.fapi.getLink(type='configMemcached',view='webtopPageStandard',bodyView='webtopBodyServer',urlParameters='id=#url.id#&server=#url.server#">overview</a>
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
					<td width="80%">
						<div class="progress progress-info progress-striped">
							<div class="bar" style="width:#round(stSizes.stats.num / stSizes.maxnum * 100)#%;">&nbsp;#stSizes.stats.num#</div>
						</div>
					</div>
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
					<td width="20%">
						<div class="progress progress-info progress-striped">
							<div class="bar" style="width:#round(stTypes.stats.objectnum / stTypes.maxobjectnum * 100)#%;">&nbsp;#stTypes.stats.objectnum#</div>
						</div>
					</td>
					<td width="20%">
						<div class="progress progress-success progress-striped">
							<div class="bar" style="width:#round(stTypes.stats.objectsize / stTypes.maxobjectsize * 100)#%;">&nbsp;#numberformat(stTypes.stats.objectsize,"0.00")#</div>
						</div>
					</td>
					<td width="20%">
						<div class="progress progress-info progress-striped">
							<div class="bar" style="width:#round(stTypes.stats.webskinnum / stTypes.maxwebskinnum * 100)#%;">&nbsp;#stTypes.stats.webskinnum#</div>
						</div>
					</td>
					<td width="20%">
						<div class="progress progress-success progress-striped">
							<div class="bar" style="width:#round(stTypes.stats.webskinsize / stTypes.maxwebskinsize * 100)#%;">&nbsp;#numberformat(stTypes.stats.webskinsize,"0.00")#</div>
						</div>
					</td>
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
					<td width="80%">
						<div class="progress progress-info progress-striped">
							<div class="bar" style="width:#round(stExpiries.stats.num / stExpiries.maxnum * 100)#%;">&nbsp;#stExpiries.stats.num#</div>
						</div>
					</td>
				</tr>
			</cfloop>
		</tbody>
	</table>
</cfoutput>

<cfsetting enablecfoutputonly="false" />