/**
 * @description       :
 * @author            : Malin Nilsson (Stretch Customer AB)
 * @group             :
 * @last modified on  : 2024-03-14
 * @last modified by  : Malin Nilsson (Stretch Customer AB)
 **/
public with sharing class BCI_IntegrationException extends Exception {
  public BCI_IntegrationException(
    String className,
    String method,
    String message
  ) {
    this(message);
    ApexLog.Error error = new ApexLog.Error(className, method, true, this);
    ApexLog.createLogDebug(error);

    System.debug('Message: ' + this.getMessage());
    System.debug('Cause: ' + this.getCause());
    System.debug('Line number: ' + this.getLineNumber());
    System.debug('Stack trace: ' + this.getStackTraceString());
  }
}