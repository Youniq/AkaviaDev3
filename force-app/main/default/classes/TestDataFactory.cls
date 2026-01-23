/* @Author Jenny Blomberg
 * Generic helper to create records used in test classes
 *
 */
public class TestDataFactory {
  private static Map<ID, Account> testAccountMap = new Map<ID, Account>();
  private static Map<ID, Callout__c> testCalloutMap = new Map<ID, Callout__c>();
  private static Map<ID, Account> testEmployersMap = new Map<ID, Account>();
  private static Map<ID, Account> testWorkplacesMap = new Map<ID, Account>();
  private static Map<ID, Employment__c> testEmploymentsMap = new Map<ID, Employment__c>();
  private static Map<Id, Membership__c> testMembershipMap = new Map<Id, Membership__c>();
  private static Map<Id, Assignment__c> testAssignmentMap = new Map<Id, Assignment__c>();
  private static Map<Id, MembershipBenefit__c> testMembershipBenefitMap = new Map<Id, MembershipBenefit__c>();
  private static Map<ID, Invoice__c> testUnpaidInvoiceMap = new Map<ID, Invoice__c>();
  private static Map<ID, Invoice__c> testPayedInvoiceMap = new Map<ID, Invoice__c>();
  private static Map<ID, Case> testCaseMap = new Map<ID, Case>();
  private static Map<ID, User> testMemberUserMap = new Map<ID, User>();

  /*
   * Call this function when you want the test class to set up all your test data and insert it.
   * Creates objects based on parameter passed and links them. Creates records with basic data.
   */
  public static void setupTestData(TestDataFactorySetupParams params) {
    if (params.numberOfAccounts != null) {
      testAccountMap = TestDataFactory.createTestAccounts(params);
    }
    if (params.numberOfCallouts != null) {
      testCalloutMap = TestDataFactory.createTestCallouts(params);
    }
    if (params.numberOfEmployerAccounts != null) {
      testEmployersMap = TestDataFactory.createTestEmployerAccounts(params);
    }
    if (params.numberOfWorkplaceAccounts != null) {
      testWorkplacesMap = TestDataFactory.createTestWorkplaceAccounts(
        params,
        testEmployersMap
      );
    }
    if (params.addEmploymentsToMembers == true) {
      Account workplace = null;
      if (!testWorkplacesMap.isEmpty())
        workplace = testWorkplacesMap.values()[0];
      testEmploymentsMap = TestDataFactory.createTestEmployments(
        params,
        workplace,
        testAccountMap
      );
    }
    if (params.addMembershipsToMembers == true) {
      testMembershipMap = TestDataFactory.createTestMemberships(
        params,
        testAccountMap
      );
    }
    if (params.addAssignmentToMembers == true) {
      testAssignmentMap = TestDataFactory.createTestAssignments(
        params,
        testAccountMap
      );
    }
    if (params.addMembershipBenefitsToMembers == true) {
      testMembershipBenefitMap = TestDataFactory.createTestMembershipBenefits(
        params,
        testMembershipMap
      );
    }
    if (params.addStudentFeeCategoryToMemberships == true) {
      TestDataFactory.createTestFeeCategories(
        testMembershipMap,
        GlobalConstants.STUDERANDE
      );
    }
    if (params.addYrkesverksamFeeCategoryToMemberships == true) {
      TestDataFactory.createTestFeeCategories(
        testMembershipMap,
        GlobalConstants.YRKESVERKSAM
      );
    }
    if (params.numberOfUnpaidInvoices != null) {
      testUnpaidInvoiceMap = TestDataFactory.createTestInvoice(
        params,
        params.numberOfUnpaidInvoices,
        false,
        new List<Id>(testAccountMap.keySet())
      );
    }
    if (params.numberOfPaidInvoices != null) {
      testPayedInvoiceMap = TestDataFactory.createTestInvoice(
        params,
        params.numberOfPaidInvoices,
        true,
        new List<Id>(testAccountMap.keySet())
      );
    }
    if (params.numberOfCases != null) {
      // We need to have at least one account to add the case to.
      if (params.numberOfAccounts == null) {
        params.numberOfAccounts = 1;
        testAccountMap = TestDataFactory.createTestAccounts(params);
      }

      testCaseMap = TestDataFactory.createTestCases(params);

      // numberOfCaseFiles only have an effect when used together with numberOfCases.
      if (params.numberOfCaseFiles != null) {
        TestDataFactory.createTestCaseFiles(params);
      }

      if (params.numberOfCaseFeedItems != null) {
        TestDataFactory.createTestCaseFeedItems(params);
      }
    }

    if (params.numberOfMemberUsers != null) {
      TestDataFactory.createTestMemberUsers(params);
    }

    if (params.numberOfContentVersions != null) {
      TestDataFactory.createTestContentVersions(params);
    }
  }

  /*
   * Call this function when you want the test class to set up data such as Custom Settings or
   * records that should exist.
   */
  public static void setupBasicTestData() {
    insert new Billecta__c(
      Base64__c = 'Test',
      Creditor__c = 'Test',
      EndPoint__c = 'https://apitest.billecta.com/'
    );
  }

  /*
   * This function creates account records and insert them in the database.
   * It creates as many account records as specified by factory parameter.
   * Only basic number of fields is set.
   */
  public static Map<ID, Account> createTestAccounts(
    TestDataFactorySetupParams params
  ) {
    return new Map<ID, Account>(createTestAccounts(params, true));
  }

  /*
   * This function creates account records and insert them in the database if passed parameter
   * is set to true.
   * It creates as many account records as specified by factory parameter.
   * Only basic number of fields is set.
   */
  public static List<Account> createTestAccounts(
    TestDataFactorySetupParams params,
    Boolean doInsert
  ) {
    List<Account> accountsToCreate = new List<Account>();

    for (Integer i = 0; i < params.numberOfAccounts; i++) {
      Account acc = new Account();
      acc.FirstName = 'First';
      acc.LastName = 'Last' + i;
      acc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName()
        .get('Personkonto')
        .getRecordTypeId();
      acc.Status__c = 'Aktiv';
      acc.PersonBirthdate = randomDateFromYears(1910, 2000);
      acc.PersonHasOptedOutOfEmail = false;
      String fourLast = String.valueOf(
        Integer.valueof((Math.random() * 10000))
      );
      fourLast = fourLast.rightPad(4, String.valueOf(i)); // Ensure string is 4 chars long.
      //String fourLast = i > 9 ? '12' + i : '123' + i;
      String ssn = string.valueOf(acc.PersonBirthdate).remove('-') + fourLast; // Was '123' + i but didnt work that well with more than 10
      acc.SocialSecurityNumber__c = ssn;
      acc.PersonMobilePhone = '+46700000' + i;
      acc.PersonEmail =
        acc.FirstName +
        '.' +
        acc.Lastname +
        i +
        '@test.akavia.se';
      acc.PersonMailingStreet = 'Gatuvägen ' + i;
      acc.PersonMailingPostalCode = '11543';
      acc.PersonMailingCity = 'Stockholm';
      acc.PersonMailingCountry = 'Sweden';
      acc.ExcludeFromUpdate__c = false;

      if (params.cancelledAccounts) {
        acc.CancellationDate__c = randomDateFromYears(2015, 2021);
      }

      accountsToCreate.add(acc);
    }

    if (doInsert && accountsToCreate.size() > 0) {
      Test.setMock(HttpCalloutMock.class, new MockHttpResponseGeneratorBCI());
      insert accountsToCreate;
    }

    return accountsToCreate;
  }

  /**
   * This function creates Benefit__c records and inserts them to the database.
   * It creates as many records as specified by factory parameter "numberOfBenefits"
   * @param params
   * @return  `Map<Id, Benefit__c>`
   */
  public static Map<Id, Benefit__c> createTestBenefits(
    TestDataFactorySetupParams params
  ) {
    return new Map<ID, Benefit__c>(createTestBenefits(params, true));
  }

  /**
   * This function creates Membership records and insert them in the database if passed parameter
   * is set to true.
   * It creates as many records as specified by factory parameter "numberOfBenefits"
   * @param params
   * @param doInsert
   * @return  `List<Benefit__c>`
   */
  public static List<Benefit__c> createTestBenefits(
    TestDataFactorySetupParams params,
    Boolean doInsert
  ) {
    List<Benefit__c> benefitsToCreate = new List<Benefit__c>();

    for (Integer i = 0; i < params.numberOfBenefits; i++) {
      Benefit__c benefit = new Benefit__c(Name = 'Testbenefit' + i);
      benefitsToCreate.add(benefit);
    }
    if (doInsert) {
      insert benefitsToCreate;
    }

    return benefitsToCreate;
  }

  /*
   * This function creates Membership records and insert them in the database.
   * It creates as many Membership records as specified by factory parameter.
   * Only basic number of fields is set.
   */
  public static Map<ID, MembershipBenefit__c> createTestMembershipBenefits(
    TestDataFactorySetupParams params,
    Map<Id, Membership__c> memberships
  ) {
    return new Map<ID, MembershipBenefit__c>(
      createTestMembershipBenefits(params, true, memberships)
    );
  }

  /*
   * This function creates Membership records and insert them in the database if passed parameter
   * is set to true.
   * It creates as many membership records as specified by factory parameter.
   * Only basic number of fields is set.
   */
  public static List<MembershipBenefit__c> createTestMembershipBenefits(
    TestDataFactorySetupParams params,
    Boolean doInsert,
    Map<Id, Membership__c> memberships
  ) {
    List<MembershipBenefit__c> membershipBenefitsToCreate = new List<MembershipBenefit__c>();

    Date membershipBenefitStartDate = Date.today().toStartOfMonth();

    TestDataFactorySetupParams benefitParam = new TestDataFactorySetupParams();
    benefitParam.numberOfBenefits = 1;

    List<Benefit__c> benefits = createTestBenefits(benefitParam, true);

    for (Membership__c membership : memberships.values()) {
      membershipBenefitsToCreate.add(
        new MembershipBenefit__c(
          Person__c = Membership.Person__c,
          StartDate__c = membershipBenefitStartDate,
          Benefit__c = benefits[0].Id
        )
      );
    }

    if (doInsert && membershipBenefitsToCreate.size() > 0) {
      insert membershipBenefitsToCreate;
    }

    return membershipBenefitsToCreate;
  }

  /*
   * This function creates Membership records and insert them in the database.
   * It creates as many Membership records as specified by factory parameter.
   * Only basic number of fields is set.
   */
  public static Map<ID, Membership__c> createTestMemberships(
    TestDataFactorySetupParams params,
    Map<Id, Account> members
  ) {
    return new Map<ID, Membership__c>(
      createTestMemberships(params, true, members)
    );
  }

  /*
   * This function creates Membership records and insert them in the database if passed parameter
   * is set to true.
   * It creates as many membership records as specified by factory parameter.
   * Only basic number of fields is set.
   */
  public static List<Membership__c> createTestMemberships(
    TestDataFactorySetupParams params,
    Boolean doInsert,
    Map<Id, Account> members
  ) {
    List<Membership__c> membershipsToCreate = new List<Membership__c>();

    Date membershipStartDate = Date.today().toStartOfMonth();
    if (params.membershipStartDate != null)
      membershipStartDate = params.membershipStartDate;

    for (Account member : members.values()) {
      membershipsToCreate.add(
        new Membership__c(
          Person__c = member.Id,
          StartDate__c = membershipStartDate
        )
      );
    }

    if (doInsert && membershipsToCreate.size() > 0) {
      insert membershipsToCreate;
    }

    return membershipsToCreate;
  }

  /**
   *
   * @param testMembershipMap
   * @param membershipCategory
   */
  public static void createTestFeeCategories(
    Map<ID, Membership__c> testMembershipMap,
    String membershipCategory
  ) {
    List<FeeCategory__c> categories = new List<FeeCategory__c>();
    for (Membership__c membership : testMembershipMap.values()) {
      Boolean autoUpgrade = membershipCategory == GlobalConstants.STUDERANDE
        ? true
        : false;
      FeeCategory__c category = null;
      category = new FeeCategory__c(
        AutoUpgrade__c = autoUpgrade,
        Membership__c = membership.Id,
        MembershipCategory__c = membershipCategory,
        StartDate__c = membership.StartDate__c
      );
      categories.add(category);
    }

    insert categories;
  }

  /*
   * This function creates Membership records and insert them in the database.
   * It creates as many Membership records as specified by factory parameter.
   * Only basic number of fields is set.
   */
  public static Map<ID, Assignment__c> createTestAssignments(
    TestDataFactorySetupParams params,
    Map<Id, Account> members
  ) {
    return new Map<ID, Assignment__c>(
      createTestAssignments(params, true, members)
    );
  }

  /*
   * This function creates Membership records and insert them in the database if passed parameter
   * is set to true.
   * It creates as many membership records as specified by factory parameter.
   * Only basic number of fields is set.
   */
  public static List<Assignment__c> createTestAssignments(
    TestDataFactorySetupParams params,
    Boolean doInsert,
    Map<Id, Account> members
  ) {
    List<Account> membersInTest = [
      SELECT Id
      FROM Account
      WHERE isPersonAccount = TRUE
    ];
    List<Assignment__c> assignmentsToCreate = new List<Assignment__c>();

    Date assignmentStartDate = Date.today().toStartOfMonth();
    if (params.assignmentStartDate != null)
      assignmentStartDate = params.assignmentStartDate;

    for (Account member : membersInTest) {
      assignmentsToCreate.add(
        new Assignment__c(
          Person__c = member.Id,
          StartDate__c = assignmentStartDate
        )
      );
    }

    if (doInsert && assignmentsToCreate.size() > 0) {
      insert assignmentsToCreate;
    }

    return assignmentsToCreate;
  }

  /**
   * Creates Employer Accounts. This variant is using the TestDataFactorySetupParams
   */
  public static Map<ID, Account> createTestEmployerAccounts(
    TestDataFactorySetupParams params
  ) {
    return new Map<ID, Account>(
      createTestEmployerAccounts(params.numberOfEmployerAccounts)
    );
  }

  /**
   * Creates Employer accounts. This variant takes an int as input for how many accounts to create.
   * Made it this way (forwarding calls using TestDataFactorySetupParams to this one) because this method will also be called
   * here internally from when workplaces is to be created. Validation rule requires every workplace to have an employer.
   */
  public static List<Account> createTestEmployerAccounts(
    Integer numberOfEmployers
  ) {
    List<Account> empsToCreate = new List<Account>();
    if (numberOfEmployers > 0) {
      Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
        .get('Employer')
        .getRecordTypeId();
      for (Integer i = 0; i < numberOfEmployers; i++) {
        Account employer = new Account();
        employer.Name = 'Employer ' + i;
        employer.BasunID__c = String.valueOf('employer' + i + 1);
        employer.BasunLastModified__c = system.now();
        employer.recordtypeId = recordTypeId;
        empsToCreate.add(employer);
      }
      insert empsToCreate;
    }
    return empsToCreate;
  }

  /**
   * This method create the number of workplaces requested and also creates employers to which they are connected to.
   */
  public static Map<ID, Account> createTestWorkplaceAccounts(
    TestDataFactorySetupParams params,
    Map<Id, Account> employersMap
  ) {
    List<Account> wplsToCreate = new List<Account>();
    List<Account> employers = employersMap != null
      ? employersMap.values()
      : null;

    if (employers == null || employers.size() == 0) {
      employers = createTestEmployerAccounts(1);
    }

    Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('Workplace')
      .getRecordTypeId();
    for (Integer i = 0; i < params.numberOfWorkplaceAccounts; i++) {
      Account workplace = new Account();
      workplace.Name = 'Workplace ' + i;
      workplace.BasunID__c = String.valueOf('workplace' + i + 1);
      workplace.BasunLastModified__c = system.now();
      workplace.recordtypeId = recordTypeId;
      workplace.ParentId = employers.size() - 1 >= i
        ? employers[i].Id
        : employers[0].Id;
      wplsToCreate.add(workplace);
    }
    insert wplsToCreate;

    Map<ID, Account> workplaceMap = new Map<ID, Account>();
    workplaceMap.putAll((wplsToCreate));
    return workplaceMap;
  }

  /**
   * Method to create employments to each member
   * @param params
   * @return  `Map<ID, Employment__c>`
   */
  public static Map<ID, Employment__c> createTestEmployments(
    TestDataFactorySetupParams params,
    Account workplace,
    Map<Id, Account> members
  ) {
    List<Employment__c> employmentsToCreate = new List<Employment__c>();

    for (Account member : members.values()) {
      Employment__c employment = new Employment__c();
      employment.Workplace__c = workplace != null ? workplace.Id : null;
      employment.StartDate__c = Date.today().addMonths(-1);
      employment.Person__c = member.Id;
      employmentsToCreate.add(employment);
    }
    insert employmentsToCreate;
    System.debug(employmentsToCreate);
    Map<ID, Employment__c> employmentMap = new Map<ID, Employment__c>();
    employmentMap.putAll((employmentsToCreate));
    return employmentMap;
  }

  public static Map<ID, Invoice__c> createTestInvoice(
    TestDataFactorySetupParams params,
    Integer numberOfInvoices,
    Boolean markAsPayed,
    List<Id> testAccountIdList
  ) {
    return new Map<ID, Invoice__c>(
      createTestInvoice(
        params,
        numberOfInvoices,
        markAsPayed,
        testAccountIdList,
        true
      )
    );
  }

  /*
   * This function creates Invoice__c records and insert them in the database if passed parameter
   * is set to true.
   * It creates as many Invoice__c records as specified by factory parameter.
   * Only basic number of fields is set.
   */
  public static List<Invoice__c> createTestInvoice(
    TestDataFactorySetupParams params,
    Integer numberOfInvoices,
    Boolean markAsPayed,
    List<Id> testAccountIdList,
    boolean doInsert
  ) {
    List<Invoice__c> invoicesToCreate = new List<Invoice__c>();

    for (Integer i = 0; i < numberOfInvoices; i++) {
      Invoice__c testInvoice = new Invoice__c();

      testInvoice.Name = generateRandomString(15);
      testInvoice.Person__c = testAccountIdList.size() > i
        ? testAccountIdList.get(i)
        : testAccountIdList.get(0);
      testInvoice.InvoiceDate__c = Date.Today() + i;
      testInvoice.ExpirationDate__c = Date.Today() + i;
      testInvoice.PaymentStatus__c = markAsPayed ? 'Betald' : 'Ej Betald';
      testInvoice.BillectaId__c = 'testBillectaId' + generateRandomString(6);

      invoicesToCreate.add(testInvoice);
    }

    if (invoicesToCreate.size() > 0 && doInsert) {
      insert invoicesToCreate;
    }

    return invoicesToCreate;
  }

  public static Map<ID, ContentVersion> createTestContentVersions(
    TestDataFactorySetupParams params
  ) {
    return new Map<ID, ContentVersion>(createTestContentVersions(params, true));
  }

  public static List<ContentVersion> createTestContentVersions(
    TestDataFactorySetupParams params,
    Boolean doInsert
  ) {
    List<ContentVersion> cvsToCreate = new List<ContentVersion>();

    // CREATE FILE
    for (Integer i = 0; i < params.numberOfContentVersions; i++) {
      ContentVersion contentVersion = new ContentVersion(
        Title = 'Penguins ' + i,
        PathOnClient = 'Penguins' + i + '.txt',
        VersionData = Blob.valueOf('Test Content ' + i),
        IsMajorVersion = true
      );
      cvsToCreate.add(contentVersion);
    }

    if (doInsert) {
      insert cvsToCreate;
    }

    return cvsToCreate;
  }

  public static Map<ID, Case> createTestCases(
    TestDataFactorySetupParams params
  ) {
    return new Map<ID, Case>(createTestCases(params, true));
  }

  /**
   * Creates cases
   */
  public static List<Case> createTestCases(
    TestDataFactorySetupParams params,
    Boolean doInsert
  ) {
    List<Case> casesToCreate = new List<Case>();
    List<Id> accIds = new List<Id>();

    for (Account acc : [SELECT Id FROM Account]) {
      accIds.add(acc.Id);
    }

    String rtId = Schema.getGlobalDescribe()
      .get('Case')
      .getDescribe()
      .getRecordTypeInfosByDeveloperName()
      .get('ServiceCase')
      .getRecordTypeId();

    Integer accIndex;

    for (Integer i = 0; i < params.numberOfCases; i++) {
      accIndex = (i < accIds.size()) ? i : 0;
      Case c = new Case();
      c.Subject = 'Test Subject';
      c.AccountId = accIds[accIndex];
      c.recordTypeId = rtID;
      casesToCreate.add(c);
    }

    if (doInsert) {
      insert casesToCreate;
    }
    return casesToCreate;
  }

  public static void createTestCaseFiles(TestDataFactorySetupParams params) {
    createTestCaseFiles(params, true);
  }

  public static void createTestCaseFiles(
    TestDataFactorySetupParams params,
    Boolean doInsert
  ) {
    params.numberOfContentVersions = params.numberOfCaseFiles; // Makes sure that correct number on content versions are created.
    List<ContentVersion> cvs = createTestContentVersions(params, true);

    List<Id> caseIds = new List<Id>(testCaseMap.keySet());
    Integer caseIndex;

    // CREATE FILE

    // for (Integer i = 0; i < params.numberOfCaseFiles; i++) {
    //   ContentVersion contentVersion = new ContentVersion(
    //     Title = 'Penguins ' + i,
    //     PathOnClient = 'Penguins' + i + '.txt',
    //     VersionData = Blob.valueOf('Test Content ' + i),
    //     IsMajorVersion = true
    //   );
    //   cvsToCreate.add(contentVersion);
    // }

    // if (doInsert) {
    //   insert cvsToCreate;
    // }

    // RELATE FILE TO CASE
    // The just created content versions. Needed when make an outer join in next step
    Map<Id, ContentVersion> cvsMap = new Map<Id, ContentVersion>(cvs);
    List<Id> cdIds = new List<Id>();

    for (ContentVersion cv : [
      SELECT ContentDocumentId
      FROM ContentVersion
      WHERE Id IN :cvsMap.keyset()
    ]) {
      cdIds.add(cv.ContentDocumentId);
    }

    // Fetch Content Document Link records related to the just created ContentVersions, as we want to set LinkedEntityId to a case Id.
    List<ContentDocumentLink> cdlToCreate = [
      SELECT Id, LinkedEntityId, Visibility, ShareType
      FROM ContentDocumentLink
      WHERE ContentDocumentId IN :cdIds
    ];

    // Set related case on Content Document Link
    for (Integer u = 0; u < cdlToCreate.size(); u++) {
      ContentDocumentLink currCdl = cdlToCreate[u];
      System.debug('Case List size: ' + caseIds.size());
      caseIndex = (u < caseIds.size()) ? u : 0;

      currCdl.Id = null; // set Id as null in order to create a new record.
      currCdl.LinkedEntityId = caseIds[caseIndex];
    }

    insert cdlToCreate;
  }

  public static void createTestCaseFeedItems(
    TestDataFactorySetupParams params
  ) {
    createTestCaseFeedItems(params, true);
  }

  public static void createTestCaseFeedItems(
    TestDataFactorySetupParams params,
    Boolean doInsert
  ) {
    List<Case> cases = testCaseMap.values();
    List<FeedItem> feedItems = new List<FeedItem>();

    for (Integer i = 0; i < params.numberOfCaseFeedItems; i++) {
      FeedItem item = new FeedItem(
        ParentId = cases.size() - 1 > i ? cases[i].Id : cases[0].Id,
        Body = 'My comment ' + i,
        Visibility = 'AllUsers'
      );
      feedItems.add(item);
    }

    if (doInsert) {
      insert feedItems;
    }
  }

  public static Map<ID, User> createTestMemberUsers(
    TestDataFactorySetupParams params
  ) {
    return new Map<ID, User>(createTestMemberUsers(params, true));
  }

  public static List<User> createTestMemberUsers(
    TestDataFactorySetupParams params,
    Boolean doInsert
  ) {
    List<User> userList = new List<User>();

    String profileName = 'Akavia Member';
    // Get the profile with the specified name
    Profile prof = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];

    // Ensure that the profile with the specified name exists
    System.assertNotEquals(null, prof, 'Profile not found: ' + profileName);

    UserRole userrole = [
      SELECT Id, DeveloperName
      FROM UserRole
      WHERE DeveloperName = 'All'
      LIMIT 1
    ];
    User adminUser = [
      SELECT Id, UserRoleId
      FROM User
      WHERE Profile.Name in ('System Administrator','Systemadministratör') AND IsActive = TRUE
      LIMIT 1
    ];
    adminUser.UserRoleId = userRole.Id;
    update adminUser;

    System.runAs(adminUser) {
      // Create person Accounts.
      params.numberOfAccounts = params.numberOfMemberUsers;
      createTestAccounts(params, true);

      List<Account> testAccounts = [SELECT Id, PersonContactId FROM Account];

      // Create users with the specified profile and related to a contact previously created.
      for (Integer i = 0; i < params.numberOfMemberUsers; i++) {
        User u = new User(
          Alias = 'User' + i,
          Email = 'testuser' + i + '@example.com',
          EmailEncodingKey = 'UTF-8',
          LastName = 'Last' + i,
          LanguageLocaleKey = 'en_US',
          LocaleSidKey = 'en_US',
          ProfileId = prof.Id,
          TimeZoneSidKey = 'America/Los_Angeles',
          UserName = 'testuser' + i + '@example.com',
          IsActive = Math.mod(i, 2) == 0 ? true : false,
          ContactId = testAccounts[i].PersonContactId,
          EmailPreferencesAutoBcc = false
        );
        userList.add(u);
      }

      // Insert the users
      insert userList;

      // Assign the users as owners of the accounts
      for (Integer i = 0; i < userList.size(); i++) {
        User userinfo = userList[i];
        testAccounts[i].OwnerId = userinfo.Id;
      }
      update testAccounts;
    }

    return userList;
  }

  public static Map<ID, Callout__c> createTestCallouts(
    TestDataFactorySetupParams params
  ) {
    return new Map<ID, Callout__c>(createTestCallouts(params, true));
  }

  public static List<Callout__c> createTestCallouts(
    TestDataFactorySetupParams params,
    Boolean doInsert
  ) {
    List<Callout__c> calloutToCreate = new List<Callout__c>();

    for (Integer i = 0; i < params.numberOfCallouts; i++) {
      Callout__c callout = new Callout__c();

      callout.Type__c = params.calloutType;
      callout.Status__c = params.calloutStatus;
      callout.Path__C = params.calloutPath;
      callout.Request__c = '123';

      calloutToCreate.add(callout);
    }

    if (doInsert && calloutToCreate.size() > 0) {
      insert calloutToCreate;
    }

    return calloutToCreate;
  }

  public static String generateRandomString(Integer len) {
    final String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz';
    String randStr = '';
    while (randStr.length() < len) {
      Integer idx = Math.mod(
        Math.abs(Crypto.getRandomInteger()),
        chars.length()
      );
      randStr += chars.substring(idx, idx + 1);
    }
    return randStr;
  }

  public static Date randomDateFromYears(Integer startYear, Integer endYear) {
    return randomDate(
      Date.newInstance(startYear, 1, 1),
      Date.newInstance(endYear, 31, 12)
    );
  }

  public static Date randomDate(Date min, Date max) {
    // Convert to DateTime values
    DateTime mint = min, maxt = max.addDays(1);
    // Then convert to milliseconds since Jan 1, 1970, and get difference in ms
    Long minms = mint.getTime(), maxms = maxt.getTime(), diff = maxms - minms;
    // Return a date between minms and maxms.
    return DateTime.newInstance(
        minms + Math.mod(Math.abs(Crypto.getRandomLong()), diff)
      )
      .date();
  }

  public class MockHttpResponseGeneratorBCI implements HttpCalloutMock {
    String json =
      '{' +
      '  "changedEntities": [' +
      '    {' +
      '      "person": {' +
      '        "gedi": "A2VT6BE7WP2J",' +
      '        "legalId": {' +
      '          "socialSecurityNumber": "198701270491"' +
      '        },' +
      '        "protectedIdentity": false,' +
      '        "firstNames": [' +
      '          "Hans",' +
      '          "Michael"' +
      '        ],' +
      '        "preferredFirstName": "Michael",' +
      '        "familyName": "Liljenström",' +
      '        "gender": "Male",' +
      '        "dateOfBirth": "1987-01-27",' +
      '        "yearOfBirth": 1987,' +
      '        "communicationLanguageScript": "sv-Latn-SE",' +
      '        "directMarketingRestriction": false,' +
      '        "phoneList": [],' +
      '        "addressList": [' +
      '          {' +
      '            "type": "Visiting",' +
      '            "subType": "Domicile",' +
      '            "streetName": "Banérgatan",' +
      '            "streetNumber": "31",' +
      '            "entrance": "A",' +
      '            "apartment": "1003",' +
      '            "postalCode": "11522",' +
      '            "city": "Stockholm",' +
      '            "country": "SE",' +
      '            "fullAddressString": "Banérgatan 31A lgh 1003",' +
      '            "formattedAddress": [' +
      '              "Banérgatan 31 A lgh 1003",' +
      '              "11522 Stockholm"' +
      '            ]' +
      '          }' +
      '        ],' +
      '        "relationshipList": [],' +
      '        "deregistered": false' +
      '      },' +
      '      "lastModified": "2020-05-15T11:10:55.923+0000",' +
      '      "clientData": {},' +
      '      "tags": [],' +
      '      "sourceList": []' +
      '    },' +
      '    {' +
      '      "person": {' +
      '        "gedi": "A2XZ4G46VM9U",' +
      '        "legalId": {' +
      '          "socialSecurityNumber": "196208268513"' +
      '        },' +
      '        "protectedIdentity": false,' +
      '        "firstNames": [' +
      '          "Björn",' +
      '          "Anders"' +
      '        ],' +
      '        "preferredFirstName": "Björn",' +
      '        "familyName": "Persson",' +
      '        "gender": "Male",' +
      '        "dateOfBirth": "1962-08-26",' +
      '        "yearOfBirth": 1962,' +
      '        "communicationLanguageScript": "sv-Latn-SE",' +
      '        "directMarketingRestriction": false,' +
      '        "phoneList": [],' +
      '        "addressList": [' +
      '          {' +
      '            "type": "Visiting",' +
      '            "subType": "Domicile",' +
      '            "streetName": "Umevägen",' +
      '            "streetNumber": "131",' +
      '            "postalCode": "91136",' +
      '            "city": "Vännäsby",' +
      '            "country": "SE",' +
      '            "fullAddressString": "Umevägen 131",' +
      '            "formattedAddress": [' +
      '              "Umevägen 131",' +
      '              "91136 Vännäsby"' +
      '            ]' +
      '          }' +
      '        ],' +
      '        "relationshipList": [],' +
      '        "deregistered": false' +
      '      },' +
      '      "lastModified": "2020-05-12T04:24:03.079+0000",' +
      '      "clientData": {},' +
      '      "tags": [],' +
      '      "sourceList": []' +
      '    },' +
      '    {' +
      '      "person": {' +
      '        "gedi": "A2MW8V87JD5U",' +
      '        "legalId": {' +
      '          "socialSecurityNumber": "197912042905"' +
      '        },' +
      '        "protectedIdentity": false,' +
      '        "firstNames": [' +
      '          "Sophie",' +
      '          "Elisabeth",' +
      '          "Matilda"' +
      '        ],' +
      '        "preferredFirstName": "Sophie",' +
      '        "familyName": "Agevik",' +
      '        "gender": "Female",' +
      '        "dateOfBirth": "1979-12-04",' +
      '        "yearOfBirth": 1979,' +
      '        "communicationLanguageScript": "sv-Latn-SE",' +
      '        "directMarketingRestriction": false,' +
      '        "phoneList": [],' +
      '        "addressList": [' +
      '          {' +
      '            "type": "Visiting",' +
      '            "subType": "Domicile",' +
      '            "streetName": "Pukslagargatan",' +
      '            "streetNumber": "43",' +
      '            "postalCode": "12530",' +
      '            "city": "Älvsjö",' +
      '            "country": "SE",' +
      '            "fullAddressString": "Pukslagargatan 43",' +
      '            "formattedAddress": [' +
      '              "Pukslagargatan 43",' +
      '              "12530 Älvsjö"' +
      '            ]' +
      '          }' +
      '        ],' +
      '        "relationshipList": [],' +
      '        "deregistered": false' +
      '      },' +
      '      "lastModified": "2020-05-15T08:53:15.578+0000",' +
      '      "clientData": {},' +
      '      "tags": [],' +
      '      "sourceList": []' +
      '    },' +
      '    {' +
      '      "person": {' +
      '        "gedi": "A2MG2CT72E4S",' +
      '        "legalId": {' +
      '          "socialSecurityNumber": "199011070845"' +
      '        },' +
      '        "protectedIdentity": false,' +
      '        "firstNames": [' +
      '          "Moa",' +
      '          "Joanna"' +
      '        ],' +
      '        "preferredFirstName": "Moa",' +
      '        "familyName": "Gezelius",' +
      '        "gender": "Female",' +
      '        "dateOfBirth": "1990-11-07",' +
      '        "yearOfBirth": 1990,' +
      '        "communicationLanguageScript": "sv-Latn-SE",' +
      '        "directMarketingRestriction": false,' +
      '        "phoneList": [],' +
      '        "addressList": [' +
      '          {' +
      '            "type": "Visiting",' +
      '            "subType": "Domicile",' +
      '            "streetName": "Banérgatan",' +
      '            "streetNumber": "31",' +
      '            "entrance": "A",' +
      '            "apartment": "1003",' +
      '            "postalCode": "11522",' +
      '            "city": "Stockholm",' +
      '            "country": "SE",' +
      '            "fullAddressString": "Banérgatan 31A lgh 1003",' +
      '            "formattedAddress": [' +
      '              "Banérgatan 31 A lgh 1003",' +
      '              "11522 Stockholm"' +
      '            ]' +
      '          }' +
      '        ],' +
      '        "relationshipList": [],' +
      '        "deregistered": false' +
      '      },' +
      '      "lastModified": "2020-05-15T12:29:02.282+0000",' +
      '      "clientData": {},' +
      '      "tags": [],' +
      '      "sourceList": []' +
      '    },' +
      '    {' +
      '      "person": {' +
      '        "gedi": "A27K5YM5CU5L",' +
      '        "legalId": {' +
      '          "socialSecurityNumber": "198303220746"' +
      '        },' +
      '        "protectedIdentity": false,' +
      '        "firstNames": [' +
      '          "Elahe"' +
      '        ],' +
      '        "familyName": "Abdolian",' +
      '        "gender": "Female",' +
      '        "dateOfBirth": "1983-03-22",' +
      '        "yearOfBirth": 1983,' +
      '        "communicationLanguageScript": "sv-Latn-SE",' +
      '        "directMarketingRestriction": false,' +
      '        "phoneList": [],' +
      '        "addressList": [' +
      '          {' +
      '            "type": "Visiting",' +
      '            "subType": "Domicile",' +
      '            "streetName": "Trädgårdsvägen",' +
      '            "streetNumber": "139",' +
      '            "postalCode": "19146",' +
      '            "city": "Sollentuna",' +
      '            "country": "SE",' +
      '            "fullAddressString": "Trädgårdsvägen 139",' +
      '            "formattedAddress": [' +
      '              "Trädgårdsvägen 139",' +
      '              "19146 Sollentuna"' +
      '            ]' +
      '          }' +
      '        ],' +
      '        "relationshipList": [],' +
      '        "deregistered": false' +
      '      },' +
      '      "lastModified": "2020-05-15T09:57:58.159+0000",' +
      '      "clientData": {},' +
      '      "tags": [],' +
      '      "sourceList": []' +
      '    }' +
      '  ],' +
      '  "errorEntities": [],' +
      '  "hasMoreEntities": false,' +
      '  "cursor": {' +
      '    "next": "5fbe20d9a57bb0e4f1282848"' +
      '  },' +
      '  "numberOfEntities": 5' +
      '}';
    // Implement this interface method
    public HTTPResponse respond(HTTPRequest request) {
      HttpResponse response = new HttpResponse();
      response.setHeader('Content-Type', 'application/json');
      response.setBody(json + ',"HasError":false,"ErrorMessage":null}');
      response.setStatusCode(200);
      return response;
    }
  }
}