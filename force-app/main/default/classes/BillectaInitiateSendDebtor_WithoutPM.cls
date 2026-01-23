/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2025-04-25
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public class BillectaInitiateSendDebtor_WithoutPM {
  public class Request {
    @InvocableVariable(
      label='Account Id'
      description='Det Account id som ska skickas till Billecta'
      required=true
    )
    public String recordId;

    @InvocableVariable(
      label='create / update / createOrUpdate'
      description='Skriv in \'create\', \'update\' eller \'createOrUpdate\' beroende på vilken uppdatering du vill göra i Billecta'
      required=true
    )
    public String billectaAction;
  }

  public class Response {
    @invocableVariable(
      label='Error Message'
      description='Om det förekom ett valideringsfel vid körning så returneras det här.'
    )
    public String errorMsg;
  }

  @Invocablemethod
  public static List<Response> sendDebtorWithoutPaymentMethod(
    List<Request> requests
  ) {
      Map<Id, String> accountIdsToAction = new Map<Id, String>();
      for (Request r : requests) {
        accountIdsToAction.put(r.recordId, r.billectaAction);
      }  

      List<String> responseMsgList = BillectaInitiateSendDebtor.sendDebtor(accountIdsToAction, false);
      List<Response> responses = new List<Response>();
      for (String msg : responseMsgList) {
        Response resp = new Response();
        resp.errorMsg = msg;
        responses.add(resp);
      }

      return responses;
    }

}