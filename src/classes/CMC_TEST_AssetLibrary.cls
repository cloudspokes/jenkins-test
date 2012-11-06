/*************************************************************************************
Name    : TestAssetLibrary 
Author  : wsupinski & rdehler 
Created : 2011-04-07
Modified: 2011-05-19
Usage   : test class for AssetControllerNew and AssetLibraryController as related to Asset__c.  
***************************************************************************************/
@isTest
private class CMC_TEST_AssetLibrary 
{
    //testing for AssetControllerNew class
    static testMethod void testAssetNew() 
    {
        CMC_Asset__c asset = new CMC_Asset__c();
        asset.Name = 'Test Reusable Asset';
      
        Test.startTest();
        ApexPages.StandardController stdController = new ApexPages.StandardController(new CMC_Asset__c());
        CMC_AssetControllerNew acn = new CMC_AssetControllerNew(stdController);
        
        //fill the asset fields       
        acn.tagsString = 'bob, sally';
        acn.curAsset.Name = 'Test Asset';
        acn.curAsset.Short_Description__c = 'some short desc';
       // acn.curAsset.Department__c = 'Marketing';
        acn.curAsset.Asset_Type__c = 'Utility';
        acn.curAsset.Asset_Platform__c = 'SFDC';
        acn.curAsset.Legal_Status__c = 'Not Reviewed';
        acn.curAsset.Implements_Open_Source__c = 'No';
        
        //need a region, practice, and group to set for projects and Resource to pass validation rule - Scott M.
        pse__Region__c region = new pse__Region__c(name='Corp');
        pse__Practice__c practice = new pse__Practice__c(name='Corp');
        pse__Grp__c pgroup = new pse__Grp__c(name='Corp');
        insert region;
        insert practice;
        insert pgroup;
        
        String regionId = [select id from pse__Region__c][0].id;
        String practiceId = [select id from pse__Practice__c][0].id;
        String groupId = [select id from pse__Grp__c][0].id;
                
       
        //add a contributor
            //need a user
            // moved from user to contact
            
        Account acct = createAcct('Appirio');
        
        Contact cbob = createContact('John', 'Doe', acct);
        insert acct;
        insert cbob;
        
        CMC_Story__c newStory = createStory();
         
        insert newStory;
        
      //  acn.usage.Story__c = newstory.Id;
        
        
        User bob = createUser(null, 'fname', 'lname', 'will@appirio.com', 'willtest0987654321_blarg@appirio.com', 'wsdfsfsafdsafs', 'faf31');
        insert bob;
  //      acn.contrib.User__c = bob.id;
        acn.contrib.Contact__c = cbob.id;
        acn.contrib.Hours_Contributed__c = 10;
        acn.contrib.Primary_Contact__c = true;
        
        
      
        
        //save it all!
        
        acn.save();
      
        boolean render;
        
        render =  acn.getRenderAddOnly();
        
        // create tags for CMC Asset object;
        
          CMC_Asset__Tag tag = new CMC_Asset__Tag();
          tag.ItemId = acn.curAsset.Id;
          tag.Name = 'CMC';
          tag.Type = 'Public';
          insert tag;
          
          acn.UpdateTags();
      
        system.debug('First assert');
        //check to see if the asset was inserted
        List<CMC_Asset__c> assets = [select id from CMC_Asset__c where Id =:acn.curAsset.Id];
     //   System.assertEquals(1, assets.size());
        
        system.debug('Second assert');
        //check to see if the tags were created
        List<CMC_Asset__Tag> tags = [select name from CMC_Asset__Tag where ItemId = :acn.curAsset.Id];
     //   System.assertEquals(2, tags.size());  //2 tags bob and sally
      
        system.debug('third assert');
        //check to see if the contributor was insert     
        List<CMC_Asset_Contributor__c> contributors = [select primary_contact__c from CMC_Asset_Contributor__c where Asset__c = :acn.curAsset.Id];
     //   System.assertEquals(1, contributors.size());
  
        //TEST AssetLibraryController
        //do a test on the search class since we already have a bunch of data created.
        CMC_AssetLibraryController alc = new CMC_AssetLibraryController();
        ApexPages.currentPage().getParameters().put('terms', 'sally');  //set a page param for the search
        alc.ToggleSort();
        PageReference pageRef = ApexPages.currentPage();
        
        alc.renderListView = false;
        alc.processListview();
        
        alc.processSearchview();
        
        alc.Search();
        
        Test.stopTest();
  }
  
  static testMethod void testAssetEdit() 
    {
    	 Test.startTest();
      
		    	CMC_Asset__c newAsset = new CMC_Asset__c();
		    	newAsset.Name = 'Test Asset';
		    	newAsset.Asset_Type__c = 'Application';
		    	newAsset.Asset_Platform__c = 'Android';
		    	newAsset.Legal_Status__c = 'Not Reviewed';
		    	newAsset.Short_Description__c = 'Short Desc';
		    	newAsset.Implements_Open_Source__c = 'No';
		    	
		    	insert newAsset;
    	
    	        ApexPages.StandardController stdController = new ApexPages.StandardController(new CMC_Asset__c());
                CMC_AssetControllerNew acn = new CMC_AssetControllerNew(stdController);
                String aid = (String) newAsset.Id;
                ApexPages.currentPage().getParameters().put('id', aid);  //set a page param for the search
		
         Test.stopTest();
    	
		      
    	
    }
  //static helper for creating test data 
  
  //static helper for creating test data 
  public static Account createAcct(string actname)
  {
    Account acct;
    
    if(actname != null){
        acct = new Account(name = actname);
    }
   
    return acct;
  }
  
 
   //static helper for creating test data 
  public static CMC_Story__c createStory()
  {
  	
  	
  	// Need to create Account, Product, component all before story :-(;
       Account unitTestAccount = new Account(name='UnitTestAccount') ;
        insert unitTestAccount ;
        
        CMC_Product__c product = new CMC_Product__c(Name ='UnitTestProduct', Account__C=unitTestAccount.Id);
        insert product;
        
        CMC_Component__c component = new CMC_Component__c(Name='UnitTestComponent' , Product__C = product.id) ;
        insert component ;
        
        CMC_Story__c story = new CMC_Story__c(Component__C = component.Id, Story_Name__c='Unit Test Story') ;
        return story;
  }
  
  public static Contact createContact(string fName,string lName, Account acct)
  {
   Contact con = new Contact(LastName = lname, Account = acct);
    
    return con;
  }
  
  //static helper for creating test data 
  public static User createUser(Id userId, string fName,string lName,string email,string userName,string nickName,string alias)
  {
    User user;
    
    if(userId != null){
        user = new User(Id = userId);
    }
    else
    {
        user = new User();
        user.FirstName = fName;
        user.LastName = lName;
        user.Email = email;
        user.Username = userName;   
        user.CommunityNickname = nickName;
        user.Alias = alias;
        user.profileId = [SELECT Id from Profile WHERE Name = 'System Administrator' limit 1 ][0].Id;
        user.EmailEncodingKey = 'ISO-8859-1';
        user.LanguageLocaleKey = 'en_US';
        user.LocaleSidKey = 'en_US';
        user.IsActive = true;
        user.TimeZoneSidKey = 'America/New_York';
    }
    return user;
  }

}