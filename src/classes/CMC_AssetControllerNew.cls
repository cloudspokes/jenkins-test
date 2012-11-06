/*************************************************************************************
Name    : AssetControllerNew 
Author  : wsupinski
Created : 5/10/2011
Usage   : Controller for overridden new button on custom object Asset.  Saves the record and does the following:
 *  Create tags for the Reusable Asset based on the custom tag cloud in the vf page.
 *  Create a Reusable Asset Contributor for the user creating the Reusable Asset.
 *  Create a junction record to project

History:

4/13/2012 - Fisher added new fields for story S-39414
5/21/2012 - Fisher changing redirect to asset page view after an edit.   
***************************************************************************************/

public with sharing class CMC_AssetControllerNew 
{
    public CMC_Asset__c curAsset                {get;set;}
    public CMC_Asset_Contributor__c contrib     {get;set;}
   // public CMC_Asset_Usage__c usage {get;set;}  Fisher per story S-23001
    public String tagsString                {get;set;}      //string holding the tags
    public Long initHours                   {get;set;}      //number holding the # of hours
    public string availableTags             {get;set;}
    public boolean renderReadOnly      {get;set;}
    public List<CMC_Asset__Tag> tagsList    {get;set;}
    public boolean editMode                 {get;set;}
    public String id            {get;set;}
    
    public CMC_AssetControllerNew(ApexPages.StandardController stdController) 
    {
      
      
        curAsset = (CMC_Asset__c)stdController.getRecord();
        contrib = new CMC_Asset_Contributor__c();
     //   usage = new CMC_Asset_Usage__c();  Fisher per story S-23001
            
        curAsset.Legal_Status__c = CMC_CONSTANTS.LEGAL_STATUS_DEFAULT;
        curAsset.Asset_Maturity_Level__c = CMC_CONSTANTS.ASSET_CLASSIFICATION_DEFAULT;
        contrib.Primary_Contact__c = CMC_CONSTANTS.PRIMARY_CONTACT_DEFAULT;
        
        // lets see if we have the id on the querystring.  If so this is from the override button on edit
         //   id = getIdFromQueryString();  Fisher 9/6 began using generic class
          id = CMC_SFURLHelper.getCurrentId();
          
        system.debug ('Edit Id = ' + id);
        
        if (id != null){
          curAsset = [SELECT Name, Is_Public__c, Description__c, Asset_SubType__c, Asset_Source_Channel__c, Created_for_Project__c, Appirio_Audience__c, Appirio_Services_Practice__c, Implements_Open_Source__c, Internal_Priority__c, Internal_Review_Notes__c, Open_Source_Implementation_Type__c, Open_Source_License__c, Release_Stage__c, Technologies__c, Asset_Maturity_Level__c, Asset_Location__c, Tips_and_Tricks__c, External_Id__c, Legal_Status__c, Number_of_Uses__c, Asset_Platform__c, Preview_Media_Type__c, Created_for_Story__c, Preview_Media_URL__c,   Short_Description__c, Total_Hours__c, Asset_Type__c, Version__c FROM CMC_Asset__c where Id =: id];
            renderReadOnly = false;
             tagsList = [SELECT Name from CMC_Asset__Tag where itemid =: id];
           editMode = true;
            CombineTags(tagsList);
            
        }
        else {
           renderReadOnly = true;
           editMode = false;
        }
       system.debug('Editmode = ' + editMode);
        //go get all available public tags
        string tags = '[';
        Integer popularity = 0;
        Integer tagCount = 0;
        Map<String, Integer> tagsWithPop = assignPop();
        
        //The order the tags are returned in is nondeterministic
        for (String tagName :tagsWithPop.keyset() ) 
        {  
        	tagCount = tagCount+1;
            popularity = tagsWithPop.get(tagName); 
            tags += '{ name:"' + tagName + '", popularity:"' + popularity + '"},';
            system.debug('tags = ' + tags);
        }
        if (tagCount==0) {
        	tags = tags+']';
        }
        // remove the ',' from the last position to avoid problems in the ui
        integer tagLength;
        tagLength = tags.length();
        tags = tags.substring(0, tagLength -1);
        
        
          
          
        
        tags += ']';
        this.availableTags = tags;
        system.debug('Available Tags ' + availableTags);
        system.debug('tagstring  = ' + tagsString);
           
    }
    
    private void CombineTags(List<CMC_Asset__Tag> tags){
       string tagName;
        
       for (CMC_Asset__Tag tagStr : tags) 
          {
          tagName = tagStr.Name.trim();
          if (tagName != '') 
          {
            if (tagsstring != null) {
              tagsString = tagsString + ',' + tagName;
            }
            else {
              tagsString = tagName;
            }
             
          }
         }
           
    }
    
    private String getIdFromQueryString(){
      String idValue = System.currentPageReference().getParameters().get('Id');
      return idValue;
    }
    //search through the queried list of tags and count up the popularity of each tag
    private Map<String, Integer> assignPop()
    {
      
      Map<String, Integer> tagPop = new Map<String, Integer>();
      List<CMC_Asset__Tag> tags = [SELECT Name FROM CMC_Asset__Tag WHERE Type = 'Public' limit 1000];
      system.debug('tag size = ' + tags.size());
      
      for(CMC_Asset__Tag tag: tags)
      {
        Integer popVal = tagPop.get(tag.Name);
        
        if(popVal != null)  //increment the pop by 1 and put back in the map
        {
          popVal = popVal + 1;
          tagPop.put(tag.name, popVal);
        }
        else  //not in the map yet.  give it a pop of 1
        {
          tagPop.put(tag.Name, 1);
        }
      }
      system.debug('tagPop size = ' + tagPop.size());
      
      return tagPop;
    }
    
    //override the save button to insert tags, contributor, and project junction record.
  public pageReference save()
  {
    PageReference retVal = null;
    try {
    system.debug('curAsset.Implements_Open_Source__c = ' + curAsset.Implements_Open_Source__c);
    
    
    system.debug('Before editMode check');
    system.debug('Editmode in save = ' + editMode);
    if (editMode) {
      system.debug('in edit mode in save');
      
      if (ValidData()) {
        system.debug ('after validdata');
        Update curAsset;
        UpdateTags();
        String returnpage;
        returnpage = '/' + curAsset.Id;
        retVal = new PageReference(returnpage);
        retVal.setRedirect(true);
      }
      else {
        ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.Error, 'Asset uses open source so please select the type of implementation and License Type.');
        ApexPages.addMessage(msg);
      }
      
    }
    else {
      system.debug('in new save else');
    if (ValidInput()) {
      if (ValidData()) {
      system.debug('inside validInput check');
      
        //x retVal = null;
            Savepoint sp = Database.setSavepoint();
           // insert tags;
            List<CMC_Asset__Tag> tags;
            String returnPage;
            try {
              system.debug ('in new mode');
              if (curAsset.Id == null) {
                 insert curAsset;
                 contrib.Asset__c = curAsset.Id;
                  tags = splitTags(curAsset.Id);
                  
                    returnPage = '/' + curAsset.Id;
              }
              else {
                // do a deep clone without preserving id
                CMC_Asset__c cloneAsset = curAsset.clone(false, true,true, true);
                insert cloneAsset;
                contrib.Asset__c = cloneAsset.Id;
                tags = splitTags(cloneAsset.Id);
                returnPage = '/' + cloneAsset.Id;
               }
           
              
        insert tags;
        //insert the contributor
        // let validate to ensure contributor hrs are positive
        insert contrib;
        // insert story if one is present.
        // commented out per story S-23001
             /* if (usage.Story__c != null)
              {
                usage.Asset__c = curAsset.Id;
                 insert usage;
              } */
        system.debug ('returnpage = ' + returnPage );
        retVal = new PageReference(returnPage);
        retVal.setRedirect(true);
        }
        catch (System.Dmlexception e) {
          Database.rollback(sp);
          //  system.debug('currentAsset = ' + curAsset);
          //  system.debug('contrib = ' + contrib);
          system.debug('in rollback');
          ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.Error,e.getDmlMessage(0));
          ApexPages.addMessage(msg);
          system.debug('after adding error');
        }
      }
    }
    else {
      ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.Error,CMC_CONSTANTS.ERROR_NEGATIVECONTRIBUTEDHRS);
      ApexPages.addMessage(msg);
    }
  }
    
    }
    
    catch (DmlException ex)
    {
    system.debug('exception on new asset' + ex.getMessage());
    }
    if (retval != null) {
      system.debug('returnURL = ' + retVal.getUrl());
       return retVal;
    }
     else {
       return null;
     }
  }

    public boolean getRenderAddOnly(){
      return renderReadOnly;
      }
    
    
    //split the tags string and generate a list of Asset__Tag records for insert during save
    private List<CMC_Asset__Tag> splitTags()
    {
      List<CMC_Asset__Tag> tags  = new List<CMC_Asset__Tag>();
      for (String tagStr : tagsString.split(',', 0)) 
      {
        tagStr = tagStr.trim();
        if (tagStr != '') 
        {
          CMC_Asset__Tag tag = new CMC_Asset__Tag();
          tag.ItemId = curAsset.Id;
          tag.Name = tagStr;
          tag.Type = 'Public';
          tags.add(tag);
        }
      }
      
      return tags;
    }
    
      //split the tags string and generate a list of Asset__Tag records for insert during save
    private List<CMC_Asset__Tag> splitTags(String aId)
    {
      List<CMC_Asset__Tag> tags  = new List<CMC_Asset__Tag>();
      for (String tagStr : tagsString.split(',', 0)) 
      {
        tagStr = tagStr.trim();
        if (tagStr != '') 
        {
          CMC_Asset__Tag tag = new CMC_Asset__Tag();
          tag.ItemId = aId;
          tag.Name = tagStr;
          tag.Type = 'Public';
          tags.add(tag);
        }
      }
      
      return tags;
    }
    
    public void UpdateTags(){
      system.debug ('in updatetags ');
      
      List<CMC_Asset__Tag> requestedTagList = splitTags(); //what's on the screen
      system.debug('requestedTagList = ' + requestedTagList);
     // upsert requestedTagList;
      Map<String, CMC_Asset__Tag>  existingTagMap = getTags(id); // here is what's stored in Sf
      // insert tags that were added 
      system.debug('existingTagMap = ' + existingTagMap);
       
      List<CMC_Asset__Tag> insertList = new List<CMC_Asset__Tag>();
      List<CMC_Asset__Tag> deleteList = new List<CMC_Asset__Tag>();
     
      // set to contain tag values
      Set<String> setTag = new Set<String>();
      Set <String>deleteTag = new Set<String>();
      
     
      for (CMC_Asset__Tag tage :requestedTagList) {
        deleteTag.Add(tage.Name);
      }
      // populating set from list to use contains
      for (CMC_Asset__Tag tagr : existingTagMap.Values()) {
        setTag.Add(tagr.Name);
      }
      
      
      for (CMC_Asset__Tag tag : requestedTagList) {
        // if item not found in map then add to a new list
        if (!setTag.contains(tag.Name))  {
            insertList.Add(tag);
        }
      }
      system.debug ('insertlist = ' + insertList);
      insert insertList;
      
      for (CMC_Asset__Tag tagd : existingTagMap.Values()) {
        // if item not found in map then add to a new list
        if (!deleteTag.contains(tagd.Name))  {
            deleteList.Add(tagd);
        }
      }
      system.debug ('deleteList = ' + deleteList);
      delete deleteList;
   
      
    /*
      List<CMC_Asset__Tag> newList = generateTagAdditions(requestedTagList, existingTagMap);
      insert newList;
    
        List<CMC_Asset__Tag> requestedTagMap = convertTagMapToList(existingTagMap);
        List<CMC_Asset__Tag> DelList = generateTagRemovals(requestedTagList, existingTagMap);
        delete DelList;
        
        */
     
    }
    
    
     Private List<CMC_Asset__Tag>  convertTagMapToList (Map<String, CMC_Asset__Tag> mapTag) {
       List<CMC_Asset__Tag> listTag = new List<CMC_Asset__Tag>(); 
       
       listTag = mapTag.values();
       
       return listTag;
     }
     Private List<CMC_Asset__Tag> generateTagAdditions(List<CMC_Asset__Tag> requested, Map<String, CMC_Asset__Tag> existing){
       List<CMC_Asset__Tag> returnList = new List<CMC_Asset__Tag>();
       
       for (CMC_Asset__tag tag : requested)
       {
         if (!existing.containsKey(tag.Id)){
           returnList.add(tag);
         }
       }
       
       return returnList;
     }
     
      Private List<CMC_Asset__Tag> generateTagRemovals(List<CMC_Asset__Tag> existing, Map<String, CMC_Asset__Tag> requested){
       List<CMC_Asset__Tag> returnList = new List<CMC_Asset__Tag>();
       
       for (CMC_Asset__tag tag : existing)
       {
         if (!requested.containsKey(tag.Id)){
           returnList.add(tag);
         }
       }
       
       return returnList;
     }
    
    
    Private Map<String, CMC_Asset__Tag> getTags(string recordId){
      List<CMC_Asset__Tag> savedTagsList = new List<CMC_Asset__Tag>();
      Map<String, CMC_Asset__Tag> tagmap = new Map<String, CMC_Asset__Tag>();
      
      savedTagsList = [SELECT Name from CMC_Asset__Tag where itemid =: recordId];
      
      for (CMC_Asset__Tag tag : savedTagsList) {
        tagmap.put(tag.Id, tag);
      }
      
      return tagmap;
    }
    
  private boolean ValidInput() {
    boolean valid = true; 
    if (contrib.Hours_Contributed__c > 0 ) {
      valid =  true;
    }
    else {
      valid = false;
    }
    
    
    //if (curAsset.Implements_Open_Source__c != null)
    return valid;
  }
  
  private boolean ValidData() {
    boolean valid = true;
    if (curAsset.Implements_Open_Source__c == 'Yes') {
      if (curAsset.Open_Source_Implementation_Type__c == null || curAsset.Open_Source_License__c == null) {
        ApexPages.Message msg = new ApexPages.Message(ApexPages.Severity.Error, 'Asset uses open source so please select the type of implementation and License Type.');
        ApexPages.addMessage(msg);
        valid = false;
        
      }
      system.debug('Open_Source_Implementation_Type__c = ' + curAsset.Open_Source_Implementation_Type__c);
      system.debug('Open_Source_License__c = ' + curAsset.Open_Source_License__c);
    }
    
    return valid;
  }

}