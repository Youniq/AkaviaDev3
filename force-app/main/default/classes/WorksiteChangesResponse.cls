public class WorksiteChangesResponse {
  public String schema; //string
  public cls_changes[] changes;

  public class cls_changes {
    //public cls_addedAndRemovedEmployments[] addedAndRemovedEmployments;
    public String changeType; //updated
    public cls_changedFields[] changedFields;
    public String worksiteId; //string
  }
  /*class cls_addedAndRemovedEmployments {
    public String at; //2015-02-13T12:05:16.565Z
    public String id; //110:404396642
    public String type; //removal
  }*/
  public class cls_changedFields {
    public String jsonPath; //$.positions.mainPosition
    public String lastModifiedAt; //2015-03-23T11:02:32.527Z
  }

  public class WorksiteChangesJSON {
    public String worksiteId; //string
    public String since; //2015-01-01T00:00:00.000Z
  }

  public static WorksiteChangesResponse parse(String json) {
    json = json.replaceAll('\\$', '');
    return (WorksiteChangesResponse) System.JSON.deserialize(
      json,
      WorksiteChangesResponse.class
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
		'      "addedAndRemovedEmployments": ['+
		'        {'+
		'          "at": "2015-02-13T12:05:16.565Z",'+
		'          "id": "110:404396642",'+
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
		'      "worksiteId": "string"'+
		'    }'+
		'  ]'+
		'}';
		fromJSON obj = parse(json);
		System.assert(obj != null);
	}
}*/