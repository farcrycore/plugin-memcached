<cfsetting enablecfoutputonly="true" />

<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />

<cfset memcached = createobject("component","farcry.plugins.memcached.packages.lib.memcached") />
<cfset memcachedClient = application.fc.lib.objectbroker.getMemcached() />

<!--- get data --->
<cfif isStruct(memcachedClient) and structIsEmpty(memcachedClient)>
	<cfoutput>
		<h1>Memcache Status - Overview</h1>
		<p>Memcached has not initialized.</p>
	</cfoutput>
<cfelseif structKeyExists(url, "increment")>
	<cfset newVersion = application.fc.lib.objectbroker.getCacheVersion(typename=url.increment, increment=true) />
	<cfif structKeyExists(application.stCOAPI, url.increment)>
		<cfset displayname = application.fapi.getContentTypeMetadata(url.increment, "displayname", url.increment) />
	<cfelseif url.increment eq "app">
		<cfset displayname = "Application" />
	<cfelse>
		<cfset displayname = url.increment />
	</cfif>
	<skin:bubble tags="success" title="Invalidation Succeeded" message="The #displayname# key scope has has been updated to #newVersion#" />
	<skin:location url="#application.fapi.fixURL(removevalues='increment')#" />
<cfelseif structKeyExists(url, "reloadcoapidates")>
	<cfset application.fc.lib.objectbroker.loadCOAPIKeys() />
	<skin:bubble tags="success" message="The COAPI dates have been reloaded from farCOAPI" />
	<skin:location url="#application.fapi.fixURL(removevalues='reloadcoapidates')#" />
<cfelse>
	<cfset start = getTickCount() />
	<cfset aServers = memcached.getAvailableServers(memcachedClient) />
	<cfset aUnavailable = memcached.getUnavailableServers(memcachedClient) />
	<cfset stServerStats = memcached.getServerStats(memcachedClient) />
	<cfset cacheVersion = application.fc.lib.objectbroker.getCacheVersion() />
	<cfloop collection="#application.objectbroker#" item="key">
		<cfset application.fc.lib.objectbroker.getCacheVersion(typename=key) />
	</cfloop>
	<cfset processingTime = (getTickCount() - start) / 1000 />

	<skin:htmlHead><cfoutput>
		<script type="text/javascript">
			function toggleContent(el,bOnlySelected){
				var self = $j(el), selected = !self.hasClass("active"), contentgroup = self.data("contentgroup"), content = self.data("content");

				bOnlySelected = bOnlySelected === false ? false : true;

				if (bOnlySelected){
					// button style
					self.siblings().removeClass("active");
					self.addClass("active");

					// content style
					$j(contentgroup).hide();
					$j(content).show();
				}
				else {
					// button style
					self[selected ? "addClass" : "removeClass"]("active");

					// content style
					$j(content)[selected ? "show" : "hide"]();
				}
			};
		</script>
	</cfoutput></skin:htmlHead>

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
		
		<h2>
			Key Invalidation
			<div class="btn-toolbar pull-right">
				<div class="btn-group">
					<a class="btn" data-contentgroup="##itemtypes .itemtype" data-content="##scopes .scope.narrow" onclick="toggleContent(this,false); return false;">specific</a>
				</div>
			</div>
		</h2>
		<table width="100px;" id="scopes" class="table">
			<thead>
				<tr>
					<th>Key Scope</th>
					<th>Scope Version</th>
					<th>Last Scope Invalidation</th>
					<th></th>
				</tr>
			</thead>
			<tbody>
				<tr class="scope wide">
					<th>Application</th>
					<td class="text-right">#request.cacheMeta['app'].version#</td>
					<td>#lcase(timeformat(request.cacheMeta['app'].version_date, 'h:mmtt'))#, #dateformat(request.cacheMeta['app'].version_date, 'd mmmm yyyy')#</td>
					<td>
						<a href="#application.fapi.fixURL(addvalues='increment=app')#">Invalidate</a> |
						<a href="#application.fapi.fixURL(addvalues='reloadcoapidates=1')#">Reload COAPI Dates</a>
					</td>
				</tr>
				<cfloop collection="#application.objectbroker#" item="key">
					<tr class="scope narrow" style="display:none;">
						<th>
							<cfif structKeyExists(application.stCOAPI, key)>
								#application.fapi.getContentTypeMetadata(key, "displayname", key)#
							<cfelse>
								#key#
							</cfif>
						</th>
						<td class="text-right">
							<cfif structKeyExists(application.stCOAPI, key)>
								#application.fc.lib.objectbroker.coapiKeys[key]#-#request.cacheMeta[key].version#
							<cfelse>
								#request.cacheMeta[key].version#
							</cfif>
						</td>
						<td>#lcase(timeformat(request.cacheMeta[key].version_date, 'h:mmtt'))#, #dateformat(request.cacheMeta[key].version_date, 'd mmmm yyyy')#</td>
						<td><a href="#application.fapi.fixURL(addvalues='increment=#key#')#">Invalidate</a></td>
					</tr>
				</cfloop>
			</tbody>
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
						<td>#aServers[i].gethostname()# ( <a href="#getServerURL(aServers[i].toString())#">overview</a> | <a href="#getApplicationURL(aServers[i].toString(),application.applicationname)#">this application</a> )</td>
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
</cfif>

<cfsetting enablecfoutputonly="false" />