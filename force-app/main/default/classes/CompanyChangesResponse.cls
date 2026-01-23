public class CompanyChangesResponse {
  //public String schema; //string
  public cls_changes[] changes;

  public class cls_changes {
    public cls_addedAndRemovedWorksites[] addedAndRemovedWorksites;
    public String changeType; //updated
    public cls_changedFields[] changedFields;
    public String companyId; //110:103793982
  }
  public class cls_addedAndRemovedWorksites {
    public String at; //2015-02-13T12:05:16.565Z
    public String worksiteId; //110:404396642
    public String type; //removal
  }
  public class cls_changedFields {
    public String jsonPath; //$.positions.mainPosition
    public String lastModifiedAt; //2015-03-23T11:02:32.527Z
  }
  public static CompanyChangesResponse parse(String json) {
    // json = json.replaceAll('\\$', '');
    return (CompanyChangesResponse) System.JSON.deserialize(
      json,
      CompanyChangesResponse.class
    );
  }

  /**
   * Checks if any entry in the changes list has any update (another value than 'unchanged' in changeType)
   */
  public Boolean hasAnyUpdates() {
    Boolean updated = false;
    for (cls_changes ch : this.changes) {
      if (ch.changeType != 'unchanged') {
        updated = true;
        break;
      }
    }
    return updated;
  }
}

/*
	static testMethod void testParse() {
		String json=		'{'+
		'  "$schema": "string",'+
		'  "changes": ['+
		'    {'+
		'      "addedAndRemovedWorksites": ['+
		'        {'+
		'          "at": "2015-02-13T12:05:16.565Z",'+
		'          "worksiteId": "110:404396642",'+
		'          "type": "removal"'+
		'        }'+
		'      ],'+
		'      "changeType": "updated",'+
		'      "changedFields": ['+
		'        {'+
		'          "jsonPath": "$.positions.mainPosition",'+
		'          "lastModifiedAt": "2015-03-23T11:02:32.527Z"'+
		'        }'+
		'      ],'+
		'      "companyId": "110:103793982"'+
		'    }'+
		'  ]'+
		'}';
		fromJSON obj = parse(json);
		System.assert(obj != null);
	}*/