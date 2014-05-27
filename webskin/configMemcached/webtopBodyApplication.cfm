<cfsetting enablecfoutputonly="true" />
<!--- @@fuAlias: application --->

<cfimport taglib="/farcry/core/tags/webskin" prefix="skin">

<cfset memcached = createobject("component","farcry.plugins.memcached.packages.lib.memcached") />

<!--- get data --->
<cfset start = getTickCount() />
<cfset qItems = memcached.getItems(url.server,url.app) />
<cfset stSizes = memcached.getItemSizeStats(qItems) />
<cfset stTypes = memcached.getItemTypeStats(qItems) />
<cfset stExpiries = memcached.getItemExpiryStats(qItems,true) />
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
	<h1>Memcache Status - #url.server# - #url.app#</h1>
	<p><a href="#getServersURL()#">&lt; back to servers</a> | <a href="#getServerURL(url.server)#">overview</a></p>
	<p>Processing time: #numberformat(processingTime,"0.00")#s</p>
	
	<h2>Item sizes</h2>
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
	
	<h2>
		Item types 
		<div class="btn-toolbar pull-right">
			<div class="btn-group">
				<a class="btn active" data-contentgroup="##itemtypes .itemclass" data-content="##itemtypes .itemclass.objects" onclick="toggleContent(this); return false;">objects</a>
				<a class="btn" data-contentgroup="##itemtypes .itemclass" data-content="##itemtypes .itemclass.webskins" onclick="toggleContent(this); return false;">webskins</a>
			</div>
			<div class="btn-group">
				<a class="btn active" data-contentgroup="##itemtypes .itemtype" data-content="##itemtypes .itemtype.cached" onclick="toggleContent(this,false); return false;">cached</a>
				<a class="btn" data-contentgroup="##itemtypes .itemtype" data-content="##itemtypes .itemtype.uncached" onclick="toggleContent(this,false); return false;">uncached</a>
			</div>
		</div>
	</h2>
	<table width="100%" id="itemtypes" class="table table-striped">
		<thead>
			<tr>
				<th width="20%">Typename</th>
				<th width="40%">Cached Items</th>
				<th width="40%">Cache Size (Kb)</th>
			</tr>
		</thead>
		<tbody>
			<cfloop query="stTypes.stats">
				<tr class="itemtype <cfif stTypes.stats.objectnum or stTypes.stats.webskinnum or stTypes.stats.objectsize or stTypes.stats.webskinsize>cached"<cfelse>uncached" style="display:none;"</cfif>>
					<td width="20%"><a href="#getTypeURL(url.server,url.app,stTypes.stats.typename)#">#stTypes.stats.typename#</a></td>
					<td width="40%">
						<div class="itemclass objects">
							#getProgressBar(stTypes.stats.objectnum,stTypes.maxobjectnum,stTypes.stats.objectnum,"progress-info")#
						</div>
						<div class="itemclass webskins" style="display:none;">
							#getProgressBar(stTypes.stats.webskinnum,stTypes.maxwebskinnum,stTypes.stats.webskinnum,"progress-info")#
						</div>
					</td>
					<td width="40%">
						<div class="itemclass objects">
							#getProgressBar(stTypes.stats.objectsize,stTypes.maxobjectsize,numberformat(stTypes.stats.objectsize,"0.00"),"progress-success")#
						</div>
						<div class="itemclass webskins" style="display:none;">
							#getProgressBar(stTypes.stats.webskinsize,stTypes.maxwebskinsize,numberformat(stTypes.stats.webskinsize,"0.00"),"progress-success")#
						</div>
					</td>
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
					<td width="20%">
						<span title="#timeformat(stExpiries.stats.expires,"HH:mm")# #dateformat(stExpiries.stats.expires,"d mmm yy")#">#application.fapi.prettyDate(stExpiries.stats.expires,true)#</span>
					</td>
					<td width="80%">
						<div style="cursor:pointer;" onclick="$j(this).siblings('.breakdown').toggle();">
							#getProgressBar(stExpiries.stats.num,stExpiries.maxnum,stExpiries.stats.num,"progress-info")#
						</div>
						<div class="breakdown" style="display:none;">
							<table width="100%" class="table table-condensed">
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
									<cfset stBreakdown = stExpiries.breakdown[stExpiries.stats.expires_epoch] />
									<cfloop query="stBreakdown.stats">
										<tr>
											<td width="20%">#stTypes.stats.typename#</td>
											<td width="20%">#getProgressBar(stBreakdown.stats.objectnum,stBreakdown.maxobjectnum,stBreakdown.stats.objectnum,"progress-info")#</td>
											<td width="20%">#getProgressBar(stBreakdown.stats.objectsize,stBreakdown.maxobjectsize,numberformat(stBreakdown.stats.objectsize,"0.00"),"progress-success")#</td>
											<td width="20%">#getProgressBar(stBreakdown.stats.webskinnum,stBreakdown.maxwebskinnum,stBreakdown.stats.webskinnum,"progress-info")#</td>
											<td width="20%">#getProgressBar(stBreakdown.stats.webskinsize,stBreakdown.maxwebskinsize,numberformat(stBreakdown.stats.webskinsize,"0.00"),"progress-success")#</td>
										</tr>
									</cfloop>
								</tbody>
							</table>
						</div>
					</td>
				</tr>
			</cfloop>
		</tbody>
	</table>
</cfoutput>

<cfsetting enablecfoutputonly="false" />