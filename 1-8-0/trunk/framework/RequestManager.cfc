<!---
License:
Copyright 2008 GreatBizTools, LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

Copyright: GreatBizTools, LLC
Author: Peter J. Farrell (peter@mach-ii.com)
$Id$

Created version: 1.5.0
Updated version: 1.5.0

Notes:
--->
<cfcomponent 
	displayname="RequestManager"
	output="false"
	hint="Manages request functionality for the framework.">

	<!---
	PROPERTIES
	--->
	<cfset variables.appManager = "" />
	<cfset variables.requestHandler = "" />
	<cfset variables.defaultUrlBase = "" />
	<cfset variables.eventParameter = "" />
	<cfset variables.parameterPrecedence = "" />
	<cfset variables.parseSes = "" />
	<cfset variables.queryStringDelimiter = "" />
	<cfset variables.seriesDelimiter ="" />
	<cfset variables.pairDelimiter = "" />
	<cfset varibales.moduleDelimiter = "" />
	<cfset variables.maxEvents = 0 />
	<cfset variables.onRequestEndCallbacks = ArrayNew(1) />
	<cfset variables.preRedirectCallbacks = ArrayNew(1) />
	<cfset variables.postRedirectCallbacks = ArrayNew(1) />
	<cfset variables.callbackGroupNames = "onRequestEndCallbacks,preRedirectCallbacks,postRedirectCallbacks" />
	<cfset variables.requestRedirectPersist = "" />
	<cfset variables.log = "" />
	<cfset variables.routes = StructNew() />
	<cfset variables.routeAliases = StructNew() />
	
	<!---
	INITIALIZATION / CONFIGURATION
	--->
	<cffunction name="init" access="public" returntype="RequestManager" output="false"
		hint="Initializes the manager.">
		<cfargument name="appManager" type="MachII.framework.AppManager" required="true"
			hint="Sets the base AppManager." />

		<cfset var urlDelimiters = "" />	
		
		<cfset setAppManager(arguments.appManager) />
		<cfset setLog(arguments.appManager.getLogFactory()) />

		<!--- Setup defaults --->
		<cfset urlDelimiters = getPropertyManager().getProperty("urlDelimiters") />
		<cfset setDefaultUrlBase(getPropertyManager().getProperty("urlBase")) />
		<cfset setEventParameter(getPropertyManager().getProperty("eventParameter")) />
		<cfset setParameterPrecedence(getPropertyManager().getProperty("parameterPrecedence")) />
		<cfset setParseSES(getPropertyManager().getProperty("urlParseSES")) />
		<cfset setModuleDelimiter(getPropertyManager().getProperty("moduleDelimiter")) />
		<cfset setMaxEvents(getPropertyManager().getProperty("maxEvents")) />
		
		<!--- Parse through the complex list of delimiters --->
		<cfset setQueryStringDelimiter(ListGetAt(urlDelimiters, 1, "|")) />
		<cfset setSeriesDelimiter(ListGetAt(urlDelimiters, 2, "|")) />
		<cfset setPairDelimiter(ListGetAt(urlDelimiters, 3, "|")) />
		
		<!--- Setup the RequestRedirectPersist --->
		<cfset setRequestRedirectPersist(CreateObject("component", "MachII.framework.RequestRedirectPersist").init(arguments.appManager)) />

		<cfreturn this />
	</cffunction>

	<cffunction name="configure" access="public" returntype="void" output="false"
		hint="Configures nothing.">
		<!--- Does nothing --->
	</cffunction>

	<!---
	PUBLIC FUNCTIONS
	--->
	<cffunction name="getRequestHandler" access="public" returntype="MachII.framework.RequestHandler" output="false"
		hint="Returns a new or cached instance of a RequestHandler.">
		
		<cfset var appKey = getAppManager().getAppKey() />
		
		<cfif NOT StructKeyExists(request, "_MachIIRequestHandler_" & appKey)>
			<cfset request["_MachIIRequestHandler_" & appKey] = 
					CreateObject("component", "MachII.framework.RequestHandler").init(getAppManager(), getEventParameter(), getParameterPrecedence(), getModuleDelimiter(), getMaxEvents(), getOnRequestEndCallbacks()) />
		</cfif>
		
		<cfreturn request["_MachIIRequestHandler_" & appKey]  />
	</cffunction>
	
	<cffunction name="buildUrl" access="public" returntype="string" output="false"
		hint="Builds a framework specific url.">
		<cfargument name="moduleName" type="string" required="true"
			hint="Name of the module to build the url with." />
		<cfargument name="eventName" type="string" required="true"
			hint="Name of the event to build the url with." />
		<cfargument name="urlParameters" type="any" required="false" default=""
			hint="Name/value pairs (urlArg1=value1|urlArg2=value2) to build the url with or a struct of data." />
		<cfargument name="urlBase" type="string" required="false" default="#getDefaultUrlBase()#"
			hint="Base of the url. Defaults to the value of the urlBase property." />
		
		<cfset var builtUrl = "" />
		<cfset var queryString = "" />
		<cfset var params = getUtils().parseAttributesIntoStruct(arguments.urlParameters) />
		<cfset var value = "" />
		<cfset var i = "" />

		<!--- Attach the module/event name if defined --->
		<cfif Len(arguments.moduleName) AND Len(arguments.eventName)>
			<cfset queryString = queryString & getEventParameter() & getPairDelimiter() & arguments.moduleName & getModuleDelimiter() & arguments.eventName />
		<cfelseif NOT Len(arguments.moduleName) AND Len(arguments.eventName)>
			<cfset queryString = queryString & getEventParameter() & getPairDelimiter()& arguments.eventName />
		</cfif>
		
		<!--- Attach each additional arguments if it exists and is a simple value --->
		<cfloop collection="#params#" item="i">
			<cfif IsSimpleValue(params[i])>
				<!--- Encode all ';' to 'U+03B' (unicode) which is part of the fix for the path info truncation bug in JRUN --->
				<cfif getParseSes()>
					<cfset params[i] = Replace(params[i], ";", "U_03B", "all") />
				</cfif>
				<cfif NOT Len(params[i]) AND getSeriesDelimiter() EQ getPairDelimiter() AND getParseSes()>
					<cfset params[i] = "_-_NULL_-_" />
				</cfif>
				<cfset queryString = queryString & getSeriesDelimiter() & i & getPairDelimiter() & URLEncodedFormat(params[i]) />
			</cfif>
		</cfloop>
		
		<!--- Prepend the urlBase and add trailing series delimiter --->
		<cfif Len(queryString)>
			<cfset builtUrl = arguments.urlBase & getQueryStringDelimiter() & queryString />
			<cfif getSeriesDelimiter() NEQ "&">
				<cfset builtUrl = builtUrl & getSeriesDelimiter() />
			</cfif>
		<cfelse>
			<cfset builtUrl = arguments.urlBase />
		</cfif>
		
		<cfreturn builtUrl />
	</cffunction>
	
	<cffunction name="buildRouteUrl" access="public" returntype="string" output="false"
		hint="Builds a framework specific url.">
		<cfargument name="moduleName" type="string" required="true"
			hint="Name of the module to build the url with." />
		<cfargument name="routeName" type="string" required="true"
			hint="Name of the event to build the url with." />
		<cfargument name="urlParameters" type="any" required="false" default=""
			hint="Name/value pairs (urlArg1=value1|urlArg2=value2) to build the url with or a struct of data." />
		<cfargument name="urlBase" type="string" required="false" default="#getDefaultUrlBase()#"
			hint="Base of the url. Defaults to the value of the urlBase property." />
		
		<cfset var params = getUtils().parseAttributesIntoStruct(arguments.urlParameters) />
		<cfset var route = getRoute(arguments.routeName) />	
		
		<cfreturn route.buildRouteUrl(arguments.moduleName, params, arguments.urlBase, getSeriesDelimiter(), getQueryStringDelimiter())>
	</cffunction>
	
	<cffunction name="parseSesParameters" access="public" returntype="struct" output="false"
		hint="Parse SES parameters.">
		<cfargument name="pathInfo" type="string" required="true" />
		
		<cfset var names = "" />
		<cfset var value = "" />
		<cfset var params = StructNew() />
		<cfset var i = "" />
		<cfset var routeName = "" />

		<!--- Parse SES if necessary --->
		<cfif getParseSes() AND Len(arguments.pathInfo) GT 1>
			
			<!--- Remove the query string delimiter --->
			<cfset arguments.pathInfo = Mid(arguments.pathInfo, 2, Len(arguments.pathInfo)) />
			<!--- Remove trailing series delimiter if defined --->
			<cfif Right(arguments.pathInfo, 1) IS getSeriesDelimiter()>
				<cfset arguments.pathInfo = Mid(arguments.pathInfo, 1, Len(arguments.pathInfo) - 1) />
			</cfif>
			
			<!--- Decode all 'U+03B' back to ';' which is part of the fix for the path info truncation bug in JRUN --->
			<cfset arguments.pathInfo = Replace(arguments.pathInfo, "U_03B", ";", "all") />
			
			<cfset names = ListToArray(arguments.pathInfo, getSeriesDelimiter()) />

			<!--- Check to see if we are dealing with processing routes --->
			<cfif ListFindNoCase(arguments.pathInfo, getEventParameter(), getSeriesDelimiter()) gt 0>
				<!--- The SES url has the event parameter in it so routes are disabled --->
				<cfset params = parseNonRoute(names) />
			<cfelse>
				<!--- No event parameter was found so check to see if a route name is present --->
				<cfif ListFindNoCase(getRouteNames(), names[1])>
					<cfset params = parseRoute(names[1], names) />
				<cfelse>
					<!--- No route found for this url --->
					<cfset params = parseNonRoute(names) />
				</cfif>
			</cfif>
			
		</cfif>
		
		<cfreturn params />
	</cffunction>
	
	<cffunction name="parseNonRoute" access="private" returntype="struct" output="false">
		<cfargument name="urlElements" type="array" required="true" />
		
		<cfset var value = "" />
		<cfset var i = 0 />
		<cfset var names = arguments.urlElements />
		<cfset var params = StructNew() />
	
		<cfif getSeriesDelimiter() EQ getPairDelimiter()>
			<cfloop from="1" to="#ArrayLen(names)#" index="i" step="2">
				<cfif i + 1 LTE ArrayLen(names) AND names[i+1] NEQ "_-_NULL_-_">
					<cfset value = names[i+1] />
				<cfelse>
					<cfset value = "" />
				</cfif>
				<cfset params[names[i]] = value />
			</cfloop>
		<cfelse>
			<cfloop from="1" to="#ArrayLen(names)#" index="i">
				<cfif ListLen(names[i], getPairDelimiter()) EQ 2>
					<cfset value = ListGetAt(names[i], 2, getPairDelimiter()) />
				<cfelse>
					<cfset value = "" />
				</cfif>
				<cfset params[ListGetAt(names[i], 1, getPairDelimiter())] =  value />
			</cfloop>
		</cfif>
		
		<cfreturn params />
	</cffunction>
	
	<cffunction name="parseRoute" access="private" returntype="struct" output="false">
		<cfargument name="routeName" type="string" required="true" />
		<cfargument name="urlElements" type="array" required="true" />
		
		<cfset var route = getRoute(arguments.routeName) />
		
		<cfreturn route.parseRoute(urlElements, getModuleDelimiter(), getEventParameter()) />
	</cffunction>

	<cffunction name="readPersistEventData" access="public" returntype="struct" output="false"
		hint="Gets a persisted event by id if found in event args.">
		<cfargument name="eventArgs" type="struct" required="true" />
		
		<cfset var data = "" />
		<cfset var postRedirectCallbacks = getPostRedirectCallbacks() />
		<cfset var i = "" />
		<cfset var parameterId = getPropertyManager().getProperty("redirectPersistParameter") />
		
		<cfif getPropertyManager().getProperty("redirectPersistParameterLocation") EQ "cookie">
			<cfif StructKeyExists(cookie, parameterId)>
				<cfset eventArgs[parameterId] = cookie[parameterId] />
				<cfcookie name="#parameterId#" expires="now" />
			</cfif>
		</cfif>
		
		<cfset data = getRequestRedirectPersist().read(arguments.eventArgs) />

		
		<!--- If there is data, run post-redirect callbacks --->
		<cfif StructCount(data)>
			
			<cfloop from="1" to="#ArrayLen(postRedirectCallbacks)#" index="i">
				<cfinvoke component="#postRedirectCallbacks[i].callback#"
					method="#postRedirectCallbacks[i].method#">
					<cfinvokeargument name="data" value="#data#" />
				</cfinvoke>
			</cfloop>
			
			<cfreturn data.eventArgs />	
		<cfelse>
			<cfreturn data />
		</cfif>
	</cffunction>
	
	<cffunction name="savePersistEventData" access="public" returntype="string" output="false"
		hint="Saves persisted event data and returns the persistId.">
		<cfargument name="eventArgs" type="struct" required="true" />
		
		<cfset var persistId = "" />
		<cfset var data = StructNew() />
		<cfset var preRedirectCallbacks = getPreRedirectCallbacks() />
		<cfset var i = "" />
		
		<cfloop from="1" to="#ArrayLen(preRedirectCallbacks)#" index="i">
			<cfinvoke component="#preRedirectCallbacks[i].callback#"
				method="#preRedirectCallbacks[i].method#">
				<cfinvokeargument name="data" value="#data#" />
			</cfinvoke>
		</cfloop>
		
		<cfset data.eventArgs = arguments.eventArgs />
		
		<cfset persistId = getRequestRedirectPersist().save(data) />
		
		<cfif getPropertyManager().getProperty("redirectPersistParameterLocation") EQ "cookie">
			<cfcookie name="#getPropertyManager().getProperty("redirectPersistParameter")#" value="#persistId#" />
		</cfif>
		
		<cfreturn persistId />
	</cffunction>
	
	<cffunction name="addOnRequestEndCallback" access="public" returntype="void" output="false"
		hint="Adds an on request end callback to be run at the end of processing an event.">
		<cfargument name="callback" type="any" required="true" />
		<cfargument name="method" type="string" required="true" />
		<cfset ArrayAppend(variables.onRequestEndCallbacks, arguments) />
	</cffunction>
	<cffunction name="removeOnRequestEndCallback" access="public" returntype="void" output="false"
		hint="Removes an onRequestEndCallback from the stack by passing in the callback object.">
		<cfargument name="callback" type="any" required="true" />
		
		<cfset var utils = getAppManager().getUtils() />
		<cfset var i = 0 />
		
		<cfloop from="1" to="#ArrayLen(variables.onRequestEndCallbacks)#" index="i">
			<cfif utils.assertSame(variables.onRequestEndCallbacks[i].callback, arguments.callback)>
				<cfset ArrayDeleteAt(variables.onRequestEndCallbacks, i) />
				<cfbreak />
			</cfif>
		</cfloop>
	</cffunction>
	<cffunction name="getOnRequestEndCallbacks" access="public" returntype="array" output="false"
		hints="Gets the on request end callbacks.">
		<cfreturn variables.onRequestEndCallbacks />
	</cffunction>
	
	<cffunction name="addPreRedirectCallback" access="public" returntype="void" output="false"
		hint="Adds a pre-redirect callback to be run before a redirect occurs.">
		<cfargument name="callback" type="any" required="true" />
		<cfargument name="method" type="string" required="true" />
		<cfset ArrayAppend(variables.preRedirectCallbacks, arguments) />
	</cffunction>
	<cffunction name="removePreRedirectCallback" access="public" returntype="void" output="false"
		hint="Removes an preRedirect from the stack by passing in the callback object.">
		<cfargument name="callback" type="any" required="true" />
		
		<cfset var utils = getAppManager().getUtils() />
		<cfset var i = 0 />
		
		<cfloop from="1" to="#ArrayLen(variables.preRedirectCallbacks)#" index="i">
			<cfif utils.assertSame(variables.preRedirectCallbacks[i].callback, arguments.callback)>
				<cfset ArrayDeleteAt(variables.preRedirectCallbacks, i) />
				<cfbreak />
			</cfif>
		</cfloop>
	</cffunction>
	<cffunction name="getPreRedirectCallbacks" access="public" returntype="array" output="false"
		hints="Gets the pre-redirect callbacks.">
		<cfreturn variables.preRedirectCallbacks />
	</cffunction>

	<cffunction name="addPostRedirectCallback" access="public" returntype="void" output="false"
		hint="Adds a post-redirect callback to be run after a redirect occurs.">
		<cfargument name="callback" type="any" required="true" />
		<cfargument name="method" type="string" required="true" />
		<cfset ArrayAppend(variables.postRedirectCallbacks, arguments) />
	</cffunction>
	<cffunction name="removePostRedirectCallback" access="public" returntype="void" output="false"
		hint="Removes an postRedirect from the stack by passing in the callback object.">
		<cfargument name="callback" type="any" required="true" />
		
		<cfset var utils = getAppManager().getUtils() />
		<cfset var i = 0 />
		
		<cfloop from="1" to="#ArrayLen(variables.postRedirectCallbacks)#" index="i">
			<cfif utils.assertSame(variables.postRedirectCallbacks[i].callback, arguments.callback)>
				<cfset ArrayDeleteAt(variables.postRedirectCallbacks, i) />
				<cfbreak />
			</cfif>
		</cfloop>
	</cffunction>
	<cffunction name="getPostRedirectCallbacks" access="public" returntype="array" output="false"
		hints="Gets the post-redirect callbacks.">
		<cfreturn variables.postRedirectCallbacks />
	</cffunction>
	
	<cffunction name="getRouteNames" access="public" returntype="string" output="false">
		<cfreturn StructKeyList(variables.routes) & "," & StructKeyList(variables.routeAliases) />
	</cffunction>
	
	<cffunction name="getRoutes" access="public" returntype="struct" output="false">
		<cfreturn variables.routes />
	</cffunction>
	<cffunction name="setRoutes" access="public" returntype="void" output="false">
		<cfargument name="routes" type="struct" required="true" />
		<cfset variables.routes = arguments.routes />
	</cffunction>
	
	<cffunction name="getRoute" access="public" returntype="MachII.framework.UrlRoute" output="false">
		<cfargument name="routeName" type="string" required="true" />
		
		<cfset var routes = getRoutes() />
		
		<!--- TODO: handle getting routes from the parent app if there is one --->
		
		<cfif StructKeyExists(routes, arguments.routeName)>
			<cfreturn variables.routes[arguments.routeName] />
		<cfelseif StructKeyExists(variables.routeAliases, arguments.routeName)>
			<cfreturn variables.routes[variables.routeAliases[arguments.routeName]] />
		<cfelse>
			<cfthrow type="MachII.RequestManager.NoRouteConfigured"
				message="No route named '#arguments.routeName#' could be found.'" />
		</cfif>
	</cffunction>
	
	<cffunction name="getRouteByAlias" access="public" returntype="struct" output="false">
		<cfargument name="routeAlias" type="string" required="true" />
		
		<cfset var routeAliases = variables.routeAliases />
		
		<!--- TODO: handle getting routes by alias from the parent module if there is one --->
		
		<cfif NOT StructKeyExists(routeAliases, arguments.routeAlias)>
			<cfthrow type="MachII.RequestManager.NoRouteConfigured"
				message="No route with alias '#arguments.routeAlias#' could be found.'" />
		</cfif>
		
		<cfreturn getRoute(routeAliases[arguments.routeAlias]) />
	</cffunction>

	<cffunction name="addRoute" access="public" returntype="void" output="false">
		<cfargument name="routeName" type="string" required="true" />
		<cfargument name="route" type="MachII.framework.UrlRoute" required="true" />
		
		<cfset variables.routes[arguments.routeName] = arguments.route />
		<cfif arguments.route.getUrlAlias() neq "">
			<cfset variables.routeAliases[arguments.route.getUrlAlias()] = arguments.routeName />
		</cfif>
	</cffunction>
	
	<cffunction name="removeRoute" access="public" returntype="void" output="false">
		<cfargument name="routeName" type="string" required="true" />
		<cfset StructDelete(variables.routes, arguments.routeName) />
	</cffunction>
	<cffunction name="removeRouteAlias" access="public" returntype="void" output="false">
		<cfargument name="routeAlias" type="string" required="true" />
		<cfset StructDelete(variables.routesAliases, arguments.routeAlias) />
	</cffunction>
	
	<!---
	ACCESSORS
	--->
	<cffunction name="setAppManager" access="private" returntype="void" output="false">
		<cfargument name="appManager" type="MachII.framework.AppManager" required="true" />
		<cfset variables.appManager = arguments.appManager />
	</cffunction>
	<cffunction name="getAppManager" access="private" returntype="MachII.framework.AppManager" output="false">
		<cfreturn variables.appManager />
	</cffunction>
	
	<cffunction name="getPropertyManager" access="private" returntype="MachII.framework.PropertyManager" output="false">
		<cfreturn getAppManager().getPropertyManager() />
	</cffunction>
	
	<cffunction name="getUtils" access="private" returntype="MachII.util.Utils" output="false">
		<cfreturn getAppManager().getUtils() />
	</cffunction>
	
	<cffunction name="setEventParameter" access="private" returntype="void" output="false">
		<cfargument name="eventParameter" type="string" required="true" />
		<cfset variables.eventParameter = arguments.eventParameter />
	</cffunction>
	<cffunction name="getEventParameter" access="private" returntype="string" output="false">
		<cfreturn variables.eventParameter />
	</cffunction>
	
	<cffunction name="setParameterPrecedence" access="private" returntype="void" output="false">
		<cfargument name="parameterPrecedence" type="string" required="true" />
		<cfset variables.parameterPrecedence = arguments.parameterPrecedence />
	</cffunction>
	<cffunction name="getParameterPrecedence" access="private" returntype="string" output="false">
		<cfreturn variables.parameterPrecedence />
	</cffunction>
	
	<cffunction name="setParseSes" access="private" returntype="void" output="false">
		<cfargument name="parseSes" type="string" required="true" />
		<cfset variables.parseSes = arguments.parseSes />
	</cffunction>
	<cffunction name="getParseSes" access="private" returntype="string" output="false">
		<cfreturn variables.parseSes />
	</cffunction>
	
	<cffunction name="setDefaultUrlBase" access="private" returntype="void" output="false">
		<cfargument name="defaultUrlBase" type="string" required="true" />
		<cfset variables.defaultUrlBase = arguments.defaultUrlBase />
	</cffunction>
	<cffunction name="getDefaultUrlBase" access="private" returntype="string" output="false">
		<cfreturn variables.defaultUrlBase />
	</cffunction>
	
	<cffunction name="setQueryStringDelimiter" access="private" returntype="void" output="false">
		<cfargument name="queryStringDelimiter" type="string" required="true" />
		<cfset variables.queryStringDelimiter = arguments.queryStringDelimiter />
	</cffunction>
	<cffunction name="getQueryStringDelimiter" access="private" returntype="string" output="false">
		<cfreturn variables.queryStringDelimiter />
	</cffunction>

	<cffunction name="setSeriesDelimiter" access="private" returntype="void" output="false">
		<cfargument name="seriesDelimiter" type="string" required="true" />
		<cfset variables.seriesDelimiter = arguments.seriesDelimiter />
	</cffunction>
	<cffunction name="getSeriesDelimiter" access="private" returntype="string" output="false">
		<cfreturn variables.seriesDelimiter />
	</cffunction>
	
	<cffunction name="setPairDelimiter" access="private" returntype="void" output="false">
		<cfargument name="pairDelimiter" type="string" required="true" />
		<cfset variables.pairDelimiter = arguments.pairDelimiter />
	</cffunction>
	<cffunction name="getPairDelimiter" access="private" returntype="string" output="false">
		<cfreturn variables.pairDelimiter />
	</cffunction>
	
	<cffunction name="setModuleDelimiter" access="private" returntype="void" output="false">
		<cfargument name="moduleDelimiter" type="string" required="true" />
		<cfset variables.moduleDelimiter = arguments.moduleDelimiter />
	</cffunction>
	<cffunction name="getModuleDelimiter" access="private" returntype="string" output="false">
		<cfreturn variables.moduleDelimiter />
	</cffunction>
	
	<cffunction name="setMaxEvents" access="private" returntype="void" output="false">
		<cfargument name="maxEvents" type="numeric" required="true" />
		<cfset variables.maxEvents = arguments.maxEvents />
	</cffunction>
	<cffunction name="getMaxEvents" access="private" returntype="numeric" output="false">
		<cfreturn variables.maxEvents />
	</cffunction>

	<cffunction name="setRequestRedirectPersist" access="public" returntype="void" output="false">
		<cfargument name="requestRedirectPersist" type="any" required="true" />
		<cfset variables.requestRedirectPersist = arguments.requestRedirectPersist />
	</cffunction>
	<cffunction name="getRequestRedirectPersist" access="public" returntype="any" output="false">
		<cfreturn variables.requestRedirectPersist />
	</cffunction>
	
	<cffunction name="setLog" access="private" returntype="void" output="false"
		hint="Uses the log factory to create a log.">
		<cfargument name="logFactory" type="MachII.logging.LogFactory" required="true" />
		<cfset variables.log = arguments.logFactory.getLog(getMetadata(this).name) />
	</cffunction>
	<cffunction name="getLog" access="private" returntype="MachII.logging.Log" output="false"
		hint="Gets the log.">
		<cfreturn variables.log />
	</cffunction>

</cfcomponent>