<cfset VARIABLES.oerCFC = CreateObject('component','openExchangeRateCFC').init()>

<cfset VARIABLES.params = {}>
<cfset VARIABLES.params['output_type'] = 'cfm'>
<cfset VARIABLES.params['from'] = 'HRK'>
<cfset VARIABLES.params['to'] = 'IRR'>
<cfset VARIABLES.params['amt'] = 7>

<!---<cfset VARIABLES.params['historical'] = '2003-05-31'>--->

<cfset VARIABLES.currencies = VARIABLES.oerCFC.convert(argumentcollection=VARIABLES.params)>

<cfdump var="#VARIABLES.currencies#">