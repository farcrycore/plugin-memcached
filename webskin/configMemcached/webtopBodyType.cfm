<cfsetting enablecfoutputonly="true" />
<!--- @@fuAlias: cachetype --->

<cfimport taglib="/farcry/core/tags/webskin" prefix="skin">

<cfset memcached = createobject("component","farcry.plugins.memcached.packages.lib.memcached") />
<cfset memcachedClient = application.fc.lib.objectbroker.getMemcached() />

<!--- get data --->
<cfset start = getTickCount() />
<cfset qItems = memcached.getItems(server=url.server, app=url.app, version=application.fc.lib.objectbroker.getCacheVersion()) />
<cfquery dbtype="query" name="qItems">select * from qItems where typename='#url.cachetype#'</cfquery>
<cfset stUncacheableWebskins = application.fc.lib.objectbroker.getTypeWebskinUncacheableStats(url.cachetype) />
<cfset stCachedWebskins = memcached.getItemWebskinStats(qItems) />
<cfset stWebskins = structnew() />
<cfquery dbtype="query" name="stWebskins.stats">
	select stUncacheableWebskins.stats.webskin, bObjectBroker, num, size, modenum,settingsnum
	from stUncacheableWebskins.stats, stCachedWebskins.stats
	where stUncacheableWebskins.stats.webskin = stCachedWebskins.stats.webskin

	union

	select stUncacheableWebskins.stats.webskin, bObjectBroker, 0 as num, 0 as size, modenum,settingsnum
	from stUncacheableWebskins.stats
	<cfif stCachedWebskins.stats.recordcount>
		where stUncacheableWebskins.stats.webskin not in (<cfqueryparam cfsqltype="cf_sql_varchar" list="true" value="#valuelist(stCachedWebskins.stats.webskin)#">)
	</cfif>

	order by webskin
</cfquery>
<cfset stWebskins.sumnum = stCachedWebskins.sumnum />
<cfset stWebskins.maxnum = stCachedWebskins.maxnum />
<cfset stWebskins.sumsize = stCachedWebskins.sumsize />
<cfset stWebskins.maxsize = stCachedWebskins.maxsize />
<cfset stWebskins.summodenum = stUncacheableWebskins.summodenum />
<cfset stWebskins.maxmodenum = stUncacheableWebskins.maxmodenum />
<cfset stWebskins.sumsettingsnum = stUncacheableWebskins.sumsettingsnum />
<cfset stWebskins.maxsettingsnum = stUncacheableWebskins.maxsettingsnum />
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
	<h1>Memcache Status - #url.server# - #url.app# - #url.cachetype#</h1>
	<p><a href="#getServersURL()#">&lt; back to servers</a> | <a href="#getApplicationURL(url.server,url.app)#">&lt; back to application</a></p>
	<p>Processing time: #numberformat(processingTime,"0.00")#s</p>
	
	<h2>
		Webskins
		<div class="btn-toolbar pull-right">
			<div class="btn-group">
				<a class="btn active" data-contentgroup="##itemtypes .itemtype" data-content="##webskins .webskin.cached" onclick="toggleContent(this,false); return false;">cached</a>
				<a class="btn" data-contentgroup="##itemtypes .itemtype" data-content="##webskins .webskin.uncached" onclick="toggleContent(this,false); return false;">uncached</a>
			</div>
		</div>
	</h2>
	<p>NOTE: uncacheable information is logged in the application scope, and is only relevant to this server since the last appliation init.</p>
	<table width="100%" id="webskins" class="table table-striped">
		<thead>
			<tr>
				<th width="20%">Webskin</th>
				<th width="20%">Cached Items</th>
				<th width="20%">Cache Size (Kb)</th>
				<th width="20%">Uncacheable (<a title="When viewing draft content, editing rules, disabling cache, etc">mode</a>)</th>
				<th width="20%">Uncacheable (<a title="When a type or webskin has caching disabled">settings</a>)</th>
			</tr>
		</thead>
		<tbody>
			<cfloop query="stWebskins.stats">
				<cfif stWebskins.stats.bObjectBroker>
					<tr class="webskin cached">
						<td width="20%">#stWebskins.stats.webskin#</td>
						<td width="20%">#getProgressBar(stWebskins.stats.num,stWebskins.maxnum,stWebskins.stats.num,"progress-info")#</td>
						<td width="20%">#getProgressBar(stWebskins.stats.size,stWebskins.maxsize,stWebskins.stats.size,"progress-success")#</td>
						<td width="20%">#getProgressBar(stWebskins.stats.modenum,stWebskins.maxmodenum,stWebskins.stats.modenum,"progress-warning")#</td>
						<td width="20%">#getProgressBar(stWebskins.stats.settingsnum,stWebskins.maxsettingsnum,stWebskins.stats.settingsnum,"progress-danger")#</td>
					</tr>
				<cfelse>
					<tr class="webskin uncached" style="display:none;">
						<td width="20%">#stWebskins.stats.webskin#</td>
						<td colspan="4">cacheStatus: -1</td>
					</tr>
				</cfif>
			</cfloop>
		</tbody>
	</table>

	<h2>Keys</h2>
	<cfset max = arrayMax(listToArray(valueList(qItems.size))) />
	<table width="100%" class="table table-stiped">
		<thead>
			<tr>
				<th>Cache Key</th>
				<th>Cache Size</th>
			</tr>
		</thead>
		<cfloop query="qItems">
			<tr>
				<td><a href="#getKeyURL(url.server, url.app, url.cachetype, qItems.key)#" onclick="$fc.objectAdminAction('Cache Content', this.href, { onHidden : function(){} }); return false;">#qItems.key#</a></td>
				<td width="80%">#getProgressBar(qItems.size, max, qItems.size, "progress-info")#</td>
			</tr>
		</cfloop>
	</table>
</cfoutput>

<cfsetting enablecfoutputonly="false" />