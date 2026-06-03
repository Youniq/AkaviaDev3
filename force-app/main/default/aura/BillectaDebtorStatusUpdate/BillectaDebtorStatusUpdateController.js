({
  doUpdate: function (component, event, helper) {
    component.set("v.spinner", true);
    var action = component.get("c.getUpdatedInfo");
    action.setParams({ recordId: component.get("v.recordId") });

    action.setCallback(this, function (response) {
      var state = response.getState();
      if (state === "SUCCESS") {
        component.set("v.obj", response.getReturnValue());
        component.set("v.spinner", false);
        if (component.get("v.obj").Status === "OK") {
          location.reload();
        }
      } else {
        console.log("Failed with state: " + state);
        component.set("v.spinner", false);
      }
    });
    $A.enqueueAction(action);
  },

  doCreateInvoice: function (component, event, helper) {
    component.set("v.showScreenflow", true);
    // component.set("v.spinner", true);
    var flow = component.find("flowCreateInvoice");
    var inputVariables;

    if (flow) {
      inputVariables = [
        {
          name: "recordId",
          type: "String",
          value: component.get("v.recordId")
        }
      ];
    }
    flow.startFlow(
      "Account_ScreenFlow_CreateInvoiceInBillecta",
      inputVariables
    );

    // var action = component.get("c.sendInvoice");
    // action.setParams({ recordId: component.get("v.recordId") });

    // action.setCallback(this, function (response) {
    //   var state = response.getState();
    //   if (state === "SUCCESS") {
    //     component.set("v.spinner", false);
    //     var label = $A.get("$Label.c.Billecta_AlertNewInvoice");
    //     alert(label);
    //   } else {
    //     console.log("Failed with state: " + state);
    //     component.set("v.spinner", false);
    //   }
    // });
    // $A.enqueueAction(action);
  },

  doCloseScreenflow: function (component, event, helper) {
    // if (event.getParam("status") === "FINISHED") {
    component.set("v.showScreenflow", false);
    //   }
  },

  doSendSMS: function (component, event, helper) {
    component.set("v.spinner", true);
    var action = component.get("c.SendSMS");
    action.setParams({ recordId: component.get("v.recordId") });

    action.setCallback(this, function (response) {
      var state = response.getState();
      if (state === "SUCCESS") {
        var respStatus = response.getReturnValue();
        if (respStatus === "OK") {
          var label = $A.get("$Label.c.Billecta_SMSAlert");
          alert(label);
          location.reload();
        } else {
          alert(respStatus);
          location.reload();
        }
      } else {
        console.log("Failed with state: " + state);
        component.set("v.spinner", false);
      }
    });
    $A.enqueueAction(action);
  },

  doInit: function (component, event, helper) {
    component.set("v.spinner", true);
    var action = component.get("c.getLastUpdated");
    action.setParams({ recordId: component.get("v.recordId") });

    action.setCallback(this, function (response) {
      var state = response.getState();
      if (state === "SUCCESS") {
        component.set("v.obj", response.getReturnValue());
        component.set("v.spinner", false);
      } else {
        console.log("Failed with state: " + state);
        component.set("v.spinner", false);
      }
    });
    $A.enqueueAction(action);
  }
});