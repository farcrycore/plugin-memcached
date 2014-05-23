<cfsetting enablecfoutputonly="true" />

<cfimport taglib="/farcry/core/tags/admin" prefix="admin" />
<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />

<admin:header>

<skin:view typename="configMemcached" webskin="webtopBodyApplication" />

<admin:footer>

<cfsetting enablecfoutputonly="false" />