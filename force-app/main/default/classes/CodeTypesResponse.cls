public class CodeTypesResponse{
	@AuraEnabled public cls_countries[] countries;
	@AuraEnabled public String name;	//Status
	@AuraEnabled public String unknownCode;	//ST99
	@AuraEnabled public String codetype;	//ST
	//public cls__links _links;
	//public String $schema;	//https://api.bisnode.com/bbc/v2/schemas/local-code-type.schema.json
	public class cls_countries {
		@AuraEnabled public String countryCode;	//--
		@AuraEnabled public cls_codeDescriptions[] codeDescriptions;
	}
	public class cls_codeDescriptions {
		@AuraEnabled public String code;	//ST95
		@AuraEnabled public cls_descriptions[] descriptions;
	}
	public class cls_descriptions {
		@AuraEnabled public String lang;	//EN
		@AuraEnabled public String description;	//No recent updates
	}
	class cls_links {
		public cls_self self;
	}
	class cls_self {
		public String href;	//https://api.bisnode.com/bbc/v2/codetypes/ST
	}
	public static CodeTypesResponse parse(String json){
		return (CodeTypesResponse) System.JSON.deserialize(json, CodeTypesResponse.class);
	}
}