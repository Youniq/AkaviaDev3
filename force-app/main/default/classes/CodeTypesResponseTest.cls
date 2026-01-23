@isTest
public with sharing class CodeTypesResponseTest {
    @isTest
	static void testParse() {
		String json = jsonResponse();
		CodeTypesResponse obj = CodeTypesResponse.parse(json);
		System.assert(obj != null);
        for(CodeTypesResponse.cls_countries c: obj.countries){
            if(c.countryCode == 'SE'){
                System.debug(c.codeDescriptions.size());
            }
        }
	}


    private static string jsonResponse (){
        return '{'+
    '    "countries": ['+
    '        {'+
    '            "countryCode": "CZ",'+
    '            "codeDescriptions": ['+
    '                {'+
    '                    "code": "ST00",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "CS",'+
    '                            "description": "Active"'+
    '                        },'+
    '                        {'+
    '                            "lang": "DE",'+
    '                            "description": "Aktiv"'+
    '                        },'+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Active"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Aktiv"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST10",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "CS",'+
    '                            "description": "Ceased Trading"'+
    '                        },'+
    '                        {'+
    '                            "lang": "DE",'+
    '                            "description": "Tätigkeit eingestellt"'+
    '                        },'+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Ceased Trading"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Upphört"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST90",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "DE",'+
    '                            "description": "Unbekannt adresse"'+
    '                        },'+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Unknown address"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Okänd adress"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST99",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "CS",'+
    '                            "description": "Removed"'+
    '                        },'+
    '                        {'+
    '                            "lang": "DE",'+
    '                            "description": "Entfernt"'+
    '                        },'+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Removed"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Borttagen"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "STRL",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "CS",'+
    '                            "description": "Blocked for Direct Marketing"'+
    '                        },'+
    '                        {'+
    '                            "lang": "DE",'+
    '                            "description": "Blockierte für Direct Marketing"'+
    '                        },'+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Blocked for Direct Marketing"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Reklamspärrad"'+
    '                        }'+
    '                    ]'+
    '                }'+
    '            ]'+
    '        },'+
    '        {'+
    '            "countryCode": "PL",'+
    '            "codeDescriptions": ['+
    '                {'+
    '                    "code": "ST00",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "DE",'+
    '                            "description": "Aktiv"'+
    '                        },'+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Active"'+
    '                        },'+
    '                        {'+
    '                            "lang": "PL",'+
    '                            "description": "Aktywny"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Aktiv"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST10",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "DE",'+
    '                            "description": "Tätigkeit eingestellt"'+
    '                        },'+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Ceased Trading"'+
    '                        },'+
    '                        {'+
    '                            "lang": "PL",'+
    '                            "description": "Działania ustawiony"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Upphört"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST90",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "DE",'+
    '                            "description": "Unbekannt adresse"'+
    '                        },'+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Unknown address"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Okänd adress"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST99",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "DE",'+
    '                            "description": "Entfernt"'+
    '                        },'+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Removed"'+
    '                        },'+
    '                        {'+
    '                            "lang": "PL",'+
    '                            "description": "Usunięty"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Borttagen"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "STRL",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "DE",'+
    '                            "description": "Blockierte für Direct Marketing"'+
    '                        },'+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Blocked for Direct Marketing"'+
    '                        },'+
    '                        {'+
    '                            "lang": "PL",'+
    '                            "description": "Reklama zablokowany"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Reklamspärrad"'+
    '                        }'+
    '                    ]'+
    '                }'+
    '            ]'+
    '        },'+
    '        {'+
    '            "countryCode": "RU",'+
    '            "codeDescriptions": ['+
    '                {'+
    '                    "code": "ST00",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Active"'+
    '                        },'+
    '                        {'+
    '                            "lang": "RU",'+
    '                            "description": "Active"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST10",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Ceased Trading"'+
    '                        },'+
    '                        {'+
    '                            "lang": "RU",'+
    '                            "description": "Ceased Trading"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST20",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Merger/split"'+
    '                        },'+
    '                        {'+
    '                            "lang": "RU",'+
    '                            "description": "Merger/split"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST30",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Bankruptcy"'+
    '                        },'+
    '                        {'+
    '                            "lang": "RU",'+
    '                            "description": "Bankruptcy"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST40",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Liquidation"'+
    '                        },'+
    '                        {'+
    '                            "lang": "RU",'+
    '                            "description": "Liquidation"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST50",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Assumed out of business"'+
    '                        },'+
    '                        {'+
    '                            "lang": "RU",'+
    '                            "description": "Assumed out of business"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST51",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Out of business - Merger/Split "'+
    '                        },'+
    '                        {'+
    '                            "lang": "RU",'+
    '                            "description": "Out of business - Merger/Split "'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST60",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Inactive"'+
    '                        },'+
    '                        {'+
    '                            "lang": "RU",'+
    '                            "description": "Inactive"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST61",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Not yet active "'+
    '                        },'+
    '                        {'+
    '                            "lang": "RU",'+
    '                            "description": "Not yet active "'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST70",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Out of business - Unfavourable"'+
    '                        },'+
    '                        {'+
    '                            "lang": "RU",'+
    '                            "description": "Out of business - Unfavourable"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST80",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Out of business - Favourable "'+
    '                        },'+
    '                        {'+
    '                            "lang": "RU",'+
    '                            "description": "Out of business - Favourable "'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST90",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "DE",'+
    '                            "description": "Unbekannt adresse"'+
    '                        },'+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Unknown address"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Okänd adress"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST99",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Removed"'+
    '                        },'+
    '                        {'+
    '                            "lang": "RU",'+
    '                            "description": "Removed"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "STRL",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Blocked for Direct Marketing"'+
    '                        },'+
    '                        {'+
    '                            "lang": "RU",'+
    '                            "description": "Blocked for Direct Marketing"'+
    '                        }'+
    '                    ]'+
    '                }'+
    '            ]'+
    '        },'+
    '        {'+
    '            "countryCode": "SE",'+
    '            "codeDescriptions": ['+
    '                {'+
    '                    "code": "ST00",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Active"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Aktiv"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST10",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Discontinued company"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Upphört företag"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST11",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Deceased owner"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Avliden"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST12",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Discontinued company, not with SCB"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Upphört ftg, ej hos SCB"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST13",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Discontinued unit"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Upphörd enhet"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST14",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Discontinued unit, not with SCB"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Upphörd enhet, ej hos SCB"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST15",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Company deregistered"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Företaget avregistrerat"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST16",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Discontinued unit due to merger"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Upphört företag på grund av fusion"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST20",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Company bankrupt"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Företaget i konkurs"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST25",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Company in liquidation"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Företaget i likvidation"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST30",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Company non-active"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Företaget ej aktivt"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST40",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Unknown company address"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Företagets adress okänd"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST41",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Address investigation in progress"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Adressundersökning pågår"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST42",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Unknown address"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Adress okänd"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST43",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Under investigation"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Under utredning"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST50",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Advertising-blocked unit"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Reklamspärrad enhet"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST51",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Advertising-blocked person"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Reklamspärrad person"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST52",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Advertising-blocked link"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Reklamspärrad koppling"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST53",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "No mailing"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Utskicksspärr enhet"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST54",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "No mailbox"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Brevlåda saknas"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST55",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Winter block"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Vinteradress"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST56",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Summer block"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Sommaradress"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST57",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Double-blocked unit"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Dubblettspärrad enhet"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST58",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Double-blocked person"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Dubblettspärrad person"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST59",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Advertising-blocked company"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Reklamspärrat företag"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST60",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Person staying abroad"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Utlandsvistelse"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST61",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Retired"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Pensionär"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST62",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "On leave"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Tjänstledig"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST63",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Not in gainful employment"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Ej yrkesverksam"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST64",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Blocked with National Board of Health and Welfare"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST65",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Personal investigation in progress"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Personundersökning pågår"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST66",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Visits not accepted"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Utskicksspärr"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST70",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Deregistered in SPAR"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Avregistrerad i SPAR"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST71",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Secrecy-blocked person SPAR"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Skyddad personuppg Spar"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST90",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Not yet active"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Ännu ej aktivt"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST99",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Removed"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Borttagen"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "STRL",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Blocked for Direct Marketing"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Reklamspärrad"'+
    '                        }'+
    '                    ]'+
    '                }'+
    '            ]'+
    '        },'+
    '        {'+
    '            "countryCode": "SK",'+
    '            "codeDescriptions": ['+
    '                {'+
    '                    "code": "ST00",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "DE",'+
    '                            "description": "Aktiv"'+
    '                        },'+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Active"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SK",'+
    '                            "description": "Active"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Aktiv"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST10",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "DE",'+
    '                            "description": "Tätigkeit eingestellt"'+
    '                        },'+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Ceased Trading"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SK",'+
    '                            "description": "Ceased Trading"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Upphört"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST90",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "DE",'+
    '                            "description": "Unbekannt adresse"'+
    '                        },'+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Unknown address"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Okänd adress"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "ST99",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "DE",'+
    '                            "description": "Entfernt"'+
    '                        },'+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Removed"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SK",'+
    '                            "description": "Removed"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Borttagen"'+
    '                        }'+
    '                    ]'+
    '                },'+
    '                {'+
    '                    "code": "STRL",'+
    '                    "descriptions": ['+
    '                        {'+
    '                            "lang": "DE",'+
    '                            "description": "Blockierte für Direct Marketing"'+
    '                        },'+
    '                        {'+
    '                            "lang": "EN",'+
    '                            "description": "Blocked for Direct Marketing"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SK",'+
    '                            "description": "Blocked for Direct Marketing"'+
    '                        },'+
    '                        {'+
    '                            "lang": "SV",'+
    '                            "description": "Reklamspärrad"'+
    '                        }'+
    '                    ]'+
    '                }'+
    '            ]'+
    '        }'+
    '    ],'+
    '    "name": "Status",'+
    '    "unknownCode": "ST99",'+
    '    "codetype": "ST",'+
    '    "_links": {'+
    '        "self": {'+
    '            "href": "https://api.bisnode.com/bbc/v2/codetypes/ST"'+
    '        }'+
    '    },'+
    '    "$schema": "https://api.bisnode.com/bbc/v2/schemas/local-code-type.schema.json"'+
    '}';
    } 
}