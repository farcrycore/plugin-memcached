<cfsetting enablecfoutputonly="true" />
<!--- @@fuAlias: server --->

<cfimport taglib="/farcry/core/tags/webskin" prefix="skin">

<cfset memcached = createobject("component","facry.plugins.memcached.packages.lib.memcached") />

<!--- get data --->
<cfset start = getTickCount() />
<cfset items = memcached.itemStats(url.server) />
<cfset stApplications = memcached.getApplicationStats(items) />
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
	<h1>Memcache Status - #url.server# - Overview</h1>
	<p>
		<cfif structkeyexists(url,"module")>
			<a href="#application.fapi.fixURL(addvalues='module=utilities/status.cfm',removevalues='server')#">&lt; back to servers</a> 
			| 
			<a href="#application.fapi.fixURL(addvalues='module=utilities/status_app.cfm&app=#application.applicationname#')#">this application</a>
		<cfelse>
			<a href="#application.fapi.getLink(type='configMemcached',view='webtopPageStandard',bodyView='webtopBody',urlParameters='id=#url.id#')#">&lt; back to servers</a>
			| 
			<a href="#application.fapi.getLink(type='configMemcached',view='webtopPageStandard',bodyView='webtopBodyApplication',urlParameters='id=#url.id#&server=#url.server#&app=#application.applicationname#')#">this application</a>
		</cfif>
	</p>
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
					<td width="20%">
						<cfif structkeyexists(url,"module")>
							<a href="#application.fapi.fixURL(addvalues='module=utilities/status_app.cfm&app=#stApplications.stats.application#')#">#stApplications.stats.application#</a>
						<cfelse>
							<a href="#application.fapi.getLink(type='configMemcached',view='webtopPageStandard',bodyView='webtopBodyApplication',urlParameters='id=#url.id#&server=#url.server#&app=#stApplications.stats.application#')#">#stApplications.stats.application#</a>
						</cfif>
					</td>
					<td width="40%">
						<div class="progress progress-info progress-striped">
							<div class="bar" style="width: width:#round(stApplications.stats.num / stApplications.maxnum * 100)#%;">&nbsp;#stApplications.stats.num#</div>
						</div>
					</td>
					<td width="40%">
						<div class="progress progress-success progress-striped">
							<div class="bar" style="width: #round(stApplications.stats.size / stApplications.maxsize * 100)#%;">&nbsp;#numberformat(stApplications.stats.size,"0.00")#</div>
						</div>
					</td>
				</tr>
			</cfloop>
		</tbody>
	</table>
</cfoutput>

<cfsetting enablecfoutputonly="false" />