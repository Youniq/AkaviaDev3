@isTest
public class LightningFileUploadHandler_Test {
    
    @testSetup
    static void setup() {
        System.debug('*** LightningFileUploadHandler_Test Setup() starting ***');
       
        TestDataFactory.setupBasicTestData();
        TestDataFactorySetupParams setupParams = new TestDataFactorySetupParams();
        setupParams.numberOfAccounts = 1;
        TestDataFactory.setupTestData(setupParams);
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        //create file
        Blob file = blob.valueOf('TestBlob');
        
        ContentVersion conVer = new ContentVersion();
        conVer.ContentLocation = 'S'; 
        conVer.PathOnClient = 'testFile.pdf'; 
        conVer.Title = 'testFile'; 
        conVer.VersionData = file;
        insert conVer;
        
        Id conDoc = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:conVer.Id].ContentDocumentId;
        //create ContentDocumentLink  record 
        ContentDocumentLink conDocLink = New ContentDocumentLink();
        conDocLink.LinkedEntityId = acc.Id;
        conDocLink.ContentDocumentId = conDoc;  //ContentDocumentId Id from ContentVersion
        conDocLink.shareType = 'V';
        insert conDocLink;
    }
    
    @isTest
    static void testGetFiles() {
        System.debug('*** LightningFileUploadHandler_Test testGetFiles() starting ***');
        
        Account testAcc = [SELECT Id FROM Account LIMIT 1];
       
        Test.startTest(); 
        List<ContentDocument> cdList = LightningFileUploadHandler.getFiles(testAcc.Id);
        Test.stopTest();
        
        System.assertEquals(cdList.size(), 1);
        
    }
    
    @isTest
    static void testDeleteFiles() {
        System.debug('*** LightningFileUploadHandler_Test testGetFiles() starting ***');
        
        Account testAcc = [SELECT Id FROM Account LIMIT 1];
        Id conDoc = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1].ContentDocumentId;
       
        Test.startTest(); 
        LightningFileUploadHandler.deleteFile(conDoc);
        List<ContentDocument> cdList = LightningFileUploadHandler.getFiles(testAcc.Id);
        Test.stopTest();
        
        System.assertEquals(cdList.size(), 0);
        
    }

}