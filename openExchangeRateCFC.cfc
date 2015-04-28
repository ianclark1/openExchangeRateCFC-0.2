<!---
	Name: openExchangeRateCFC
	Author: Andy Matthews
	Website: http://www.andyMatthews.net || http://openExchangeRateCFC.riaforge.org
	Created: 12/19/2011
	History:
			12/19/2011			Initial creation
			12/20/2011			Added convert method based on http://josscrowcroft.github.com/money.js/
	Purpose: A ColdFusion wrapper for the Open Exchange Rate project
	Version: Listed in contructor
	Todo: none
--->

<cfcomponent hint="A ColdFusion wrapper for the Open Exchange Rate project" displayname="openExchangeRateCFC" output="false" accessors="true" >

	<cfproperty name="currentVersion" default="0.2">
	<cfproperty name="appName" default="openExchangeRateCFC">
	<cfproperty name="lastUpdated">
	<cfproperty name="apiRoot" default="http://openexchangerates.org">
	<cfproperty name="docURL" default="http://josscrowcroft.github.com/open-exchange-rates/">
	<cfproperty name="base" default="USD">

	<!--- ## INTERNAL METHODS ## --->
	<cffunction name="init" description="Initializes the CFC, returns itself" returntype="openExchangeRateCFC" access="public" output="false">

		<cfscript>
			VARIABLES.currentVersion = '0.2';
			VARIABLES.appName = 'openExchangeRateCFC';
			VARIABLES.lastUpdated = DateFormat(CreateDate(2011,12,19),'mm/dd/yyyy');
	        VARIABLES.apiRoot = 'http://openexchangerates.org';
	        VARIABLES.docURL = 'http://josscrowcroft.github.com/open-exchange-rates/';
	        VARIABLES.base = 'USD';
		</cfscript>

		<cfreturn THIS>
	</cffunction>

	<cffunction name="introspect" description="Returns detailed info about this CFC" returntype="struct" access="public" output="false">
		<cfreturn getMetaData(this)>
	</cffunction>

	<cffunction name="call" description="The actual http call to the remote server" returntype="struct" access="private" output="false">
		<cfargument name="attr" required="true" type="struct">
		<cfargument name="params" required="true" type="struct">

		<cfscript>
			// what fieldtype will this be?
			var fieldType = iif( ARGUMENTS.attr['method'] == 'GET', De('URL'), De('formField') );
		</cfscript>

		<cfhttp attributecollection="#ARGUMENTS.attr#">
			<cfloop collection="#ARGUMENTS.params#" item="key">
				<cfhttpparam name="#key#" type="#fieldType#" value="#ARGUMENTS.params[key]#">
			</cfloop>
		</cfhttp>

		<cfreturn cfhttp>

	</cffunction>

	<cffunction name="prep" description="Prepares data for call to remote servers" returntype="struct" access="private" output="false">
		<cfargument name="config" type="struct" required="true">

		<cfscript>
			var attributes = {};
			var returnColdFusion = false;
			var params = Duplicate(ARGUMENTS['config']['params']);
			var returnStruct = {};

			// make sure the format type is allowed
			if (NOT ListFindNoCase('cfm,json',LCase(ARGUMENTS['config']['format']))) {
				throw('Allowed output types are cfm, and json');
			}

			// does the user want a coldfusion object returned?
			if (ARGUMENTS['config']['format'] == 'cfm') {
				returnColdFusion = true;
				attributes['format'] = 'json';
			} else {
				attributes['format'] = ARGUMENTS['config']['format'];
			}

			// finish setting up the attributes for the http call
			attributes['url'] = VARIABLES.apiRoot & ARGUMENTS['config']['url'];
			attributes['method'] = ARGUMENTS['config']['method'];

			try {
				var data = call(attributes, params);
				var stringified = data.filecontent.toString();

				// it is so proceed as normal
				returnStruct.data = (returnColdFusion)  ? deserializeJSON(stringified) : stringified;
				returnStruct.success = 1;
				returnStruct.message = data.StatusCode & ' - Request successful';

			} catch(any e) {
				//set success and message value
				returnStruct.data = '';
				returnStruct.success = 0;
				returnStruct.message = 'An error occurred. Please check your parameters and try your request again.';
			}
		</cfscript>

		<cfreturn returnStruct>
	</cffunction>

	<!--- ## AVAILABLE METHODS ## --->
	<cffunction name="currency_types" description="Returns a list of all available currencies" returntype="struct" access="public" output="false">
		<cfargument name="output_type" type="string" required="false" default="cfm">

		<cfscript>
			config = {};

			// prepare packet required by the main call method
			// the following values are required for EVERY call
			config['method'] = 'GET';
			config['format'] = ARGUMENTS['output_type'];
			config['url'] = '/currencies.json';

			// the params object should always exist, but may be empty
			config['params'] = {};
		</cfscript>

		<cfreturn prep(config)>
	</cffunction>

	<cffunction name="currencies" description="Returns currency values" returntype="struct" access="public" output="false">
		<cfargument name="output_type" type="string" required="false" default="cfm">
		<cfargument name="currency" type="string" required="false" default="" hint="Leave blank to retrieve all currencies. Pass in multiple currencies for multiple values">
		<cfargument name="historical" type="date" required="false" default="#Now()#" hint="Must be between 1999-01-01 and the current day">

		<cfscript>
			config = {};
			finalData = {};
			oldestDate = CreateDate(1999, 01, 01);
			newestDate = Now();

			// prepare packet required by the main call method
			// the following values are required for EVERY call
			config['method'] = 'GET';
			config['format'] = ARGUMENTS['output_type'];
			if ( (ARGUMENTS.historical < oldestDate) OR (ARGUMENTS.historical > newestDate) ) {
				throw('Available dates range from #DateFormat(oldestDate,'mmmm d, yyyy')# to #DateFormat(Now(),'mmmm d, yyyy')#');
			} else {
				config['url'] = '/historical/#DateFormat(ARGUMENTS.historical,'yyyy-mm-dd')#.json';
			}

			// the params object should always exist, but may be empty
			config['params'] = {};

			finalData = prep(config);

			if (ARGUMENTS.currency != '') {
				rates = {};
				for (c=1; c LTE ListLen(ARGUMENTS['currency']); c++) {
					key = ListGetAt(ARGUMENTS['currency'],c);
					try {
						rates[key] = finalData.data.rates[ key ];
					} catch(any e) {
						rates[key] = 'Currency not found';
					}
				}
				finalData.data.rates = Duplicate(rates);
			}
		</cfscript>

		<cfreturn finalData>
	</cffunction>

	<cffunction name="convert" description="Performs a currency conversion between two specified currencies" returntype="struct" access="public" output="false">
		<cfargument name="output_type" type="string" required="false" default="cfm">
		<cfargument name="from" type="string" required="true">
		<cfargument name="to" type="string" required="true">
		<cfargument name="amt" type="numeric" required="true">
		<cfargument name="historical" type="date" required="false" default="#Now()#" hint="Must be between 1999-01-01 and the current day">

		<cfscript>

			// get the list of currencies we'll need for this conversion
			var ratesParams = {};
			ratesParams['output_type'] = ARGUMENTS.output_type;
			ratesParams['currency'] = 'USD,#ARGUMENTS.from#,#ARGUMENTS.to#';
			ratesParams['historical'] = ARGUMENTS.historical;
			rates = currencies(argumentCollection=ratesParams);

			var toAmt = rates.data.rates[ARGUMENTS.to];
			var frAmt = rates.data.rates[ARGUMENTS.from];

			if ( !isNumeric(toAmt) || !isNumeric(frAmt)) {
				rates.DATA['converted_value'] = 0;
				rates['MESSAGE'] = (!isNumeric(toAmt) ? '#ARGUMENTS.to# is not supported' : '#ARGUMENTS.from# is not supported');
				rates['SUCCESS'] = 0;
				return rates;
			}

			rates.DATA['converted_value'] = ARGUMENTS.amt * ((toAmt == VARIABLES.base) ? (1/frAmt) : (toAmt * (1 / frAmt)));
		</cfscript>

		<cfreturn rates>
	</cffunction>

</cfcomponent>