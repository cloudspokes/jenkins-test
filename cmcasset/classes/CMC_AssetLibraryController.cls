// 
// (c) 2009 Appirio, Inc.
//
// Generate a new lead from a sales-related case
//
// ??    Will/Ray      Original
// 3/6/2012     Fisher	 Added callout to track search terms
//

public with sharing class CMC_AssetLibraryController {

public string Tags{ get; set; }
	public string terms{ get; set; }
	public String param;
	public boolean renderListView {get; set; }
	public Integer recordCount {get;set;}
	//list of reusable assets to display
	public List< CMC_Asset__c > ReusableAssets {get;set;}
	//current sort direction. defaults to asc
	public String SortDir 
	{
		get  { if (this.SortDir == null) {  this.SortDir = 'ASC'; } return this.SortDir;  }
		set;
	}
	//current field to sort by. defaults to name
	public String SortField 
	{
		get  { if (this.SortField == null) {this.SortField = 'Name'; } return this.SortField;  }
		set;
	}

	public String Debug { get; set; }

	public CMC_AssetLibraryController()
	{
		this.ReusableAssets = new List< CMC_Asset__c >(); 
		this.Debug = '';
		this.Terms = '';
		this.param = '';
		renderListView = false;
		recordCount = 0;
		//go get all available public tags
		string tags = '[';
		for (CMC_Asset__Tag tag : [SELECT Name FROM CMC_Asset__Tag WHERE Type = 'Public' ORDER by Name ASC limit 1000]) {  
			tags += '{ name:"' + tag.Name + '"},';
		}
		tags += ']';
		this.Tags = tags;
	}
//execute search for the text entered
	public PageReference Search() 
	{
		renderListView = false;
		String searchTerms = '';
		param = String.escapeSingleQuotes(Apexpages.currentPage().getParameters().get('terms'));
		system.debug ('param = ' + param);
		List<String> terms = param.split(',');
		for (String term : terms){
			term = term.trim();
			if (term.length() > 0)
			{
				if (searchTerms.length() > 0){
					searchTerms += ' AND ';
				}
				searchTerms +=  term ;  
			}
		}
		system.debug('indexof * = ' + searchTerms.indexOf('*'));
		Boolean executeSearch;
		executeSearch = true;
		Integer searchPos = searchTerms.indexOf('*');
		Integer termLength;
		termLength = searchTerms.Length();
		system.debug('TermLength=' + termLength);
		system.debug('searchpos = ' + searchPos);
		if (searchPos <> -1) {
			if (termLength < 3) {
				executeSearch = false;
			}
		}
		else {
			// means we have an *
			if (termLength < 3) {
			   executeSearch = false;
			}
		}
		system.debug('executeSearch =' + executeSearch);
		if (executeSearch){
			this.Terms = searchTerms;
			
			this.Terms = searchTerms += ' OR "' + removeCommainSearchTerms(param) + '"';
			system.debug('terms = ' + this.Terms);
			SoslSearch();
			// callout to REST call to track search
			// could move this to a @future call in the future
			String query = '/AssetLibrary/?searchterms=' + param + '&recordsReturned=' + recordCount ;
			CMC_SearchTermsCallout callout = new CMC_SearchTermsCallout();
			callout.SendSearchTermsToAWS(query);
		}
		else
		{
			ApexPages.Message searchMsg = new ApexPages.Message(ApexPages.Severity.FATAL,'The minimum number of characters is 3 e.g. cmc or cm*');
			ApexPages.addMessage(searchMsg);
			recordCount = 0;
			ReusableAssets.clear();
		}
		return null;
}
	//search across assets and tags
	private void SoslSearch(){
		String.escapeSingleQuotes(this.Terms);
		system.debug('Terms = ' + this.Terms);
		String searchTerms = this.Terms;
		if (searchTerms.length() > 0)
		{
			String searchquery='FIND \'' + searchTerms + '\' IN ALL FIELDS RETURNING CMC_Asset__c(id,name, Short_Description__c,  Asset_Platform__c, Number_of_Uses__c,  Preview_Media_URL__c, Preview_Media_Type__c, Asset_Type__c WHERE Release_Stage__c = \'Active\' ORDER BY ' + this.SortField + ' ' + this.SortDir +') LIMIT 50'; 
			this.Debug = searchquery;
			this.ReusableAssets = new List< CMC_Asset__c >();
			List<List<SObject>> results =search.query(searchquery);
			if (results.size() > 0){
				Set<Id> itemIds = new Set<Id>();
				CMC_Asset__c asset;
				for(SObject sobj : results[0]){
					if (!itemIds.contains(sobj.id)){
						itemIds.add(sobj.id);
						asset = (CMC_Asset__c)sobj;
						this.ReusableAssets.add(asset);
					}
				}
				recordCount = ReusableAssets.size();
			}
			else 
				recordCount = 0;
				system.debug('reusable size = ' +ReusableAssets.size());    
		}
	}
	// handle the action of the commandlink
	public PageReference processListview() {
		renderListView = true;
		return null;
	}
	// handle the action of the commandlink
	public PageReference processSearchview() {
		renderListView = false;
		return null;
	}
	// toggles the sorting of query from asc<-->desc
	public void ToggleSort() 
	{
		this.SortDir = this.SortDir.equals('ASC') ? 'DESC' : 'ASC';
		this.SoslSearch();
	}
	
	private String removeCommainSearchTerms(String terms) {
		
		system.debug('parsing term = ' + terms);
		Pattern commapattern = Pattern.compile(',');
		String retString = commapattern.matcher(terms).replaceAll(' ');
		return retString;
	}
}