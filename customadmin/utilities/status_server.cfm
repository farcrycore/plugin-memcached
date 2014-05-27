<cfsetting enablecfoutputonly="true" requesttimeout="180" />

<cfimport taglib="/farcry/core/tags/admin" prefix="admin" />

<cfimport taglib="/farcry/core/tags/admin" prefix="admin" />
<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />

<admin:header>

<skin:view typename="configMemcached" webskin="webtopBodyServer" />

<admin:footer>

<cfsetting enablecfoutputonly="false" />