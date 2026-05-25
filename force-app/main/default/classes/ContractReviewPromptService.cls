/**
 * Thin wrapper around {@code ConnectApi.EinsteinLLM} that owns every Einstein
 * Prompt Template invocation in the contract-review feature. Centralising
 * the calls here keeps the queueables free of {@code ConnectApi} types and
 * makes mocking trivial — tests subclass {@link TemplateInvoker} and swap
 * the static {@code invoker} reference.
 *
 * Templates invoked:
 *   - {@code ContractReviewPromptTemplate}  — text contract review (JSON).
 *   - {@code ContractReview_Forms}          — form/checkbox contract review (JSON).
 *   - {@code Contract_Review_Contract_Type} — binary form-vs-text classifier.
 *   - {@code Contract_Review_Email_Draft}   — HTML email draft (SV or EN).
 *
 * Governor-limit notes: every public method on this class issues exactly one
 * HTTP/Einstein callout. The 100-callouts-per-transaction and 120-second
 * cumulative-callout limits apply.
 */
public with sharing class ContractReviewPromptService {

  private static final String APP_NAME = 'PromptTemplateGenerationsInvocable';
  private static final String TEMPLATE_CONTRACT_REVIEW = 'ContractReviewPromptTemplate';
  private static final String TEMPLATE_FORM_REVIEW = 'ContractReview_Forms';
  private static final String TEMPLATE_CONTRACT_TYPE = 'Contract_Review_Contract_Type';
  private static final String TEMPLATE_EMAIL_DRAFT = 'Contract_Review_Email_Draft';

  /**
   * Indirection seam over {@code ConnectApi.EinsteinLLM} so tests can
   * intercept calls without a real LLM. Subclass and override
   * {@link #invoke} in test code, then assign to the {@code invoker}
   * static field below.
   *
   * Governor-limit note: each call to {@link #invoke} consumes one HTTP
   * callout from the per-transaction quota.
   */
  public virtual class TemplateInvoker {
    /**
     * @param templateApiName Einstein Prompt Template DeveloperName.
     * @param genInput        Pre-built generation input including
     *                        {@code applicationName} and input params.
     * @return The first generation's text from the LLM response.
     * @throws CalloutException if the LLM returned no generations.
     */
    public virtual String invoke(
      String templateApiName,
      ConnectApi.EinsteinPromptTemplateGenerationsInput genInput
    ) {
      ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
        ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
          templateApiName, genInput
        );
      if (result == null || result.generations == null || result.generations.isEmpty()) {
        throw new CalloutException(
          'Prompt template ' + templateApiName + ' returned no generations'
        );
      }
      return result.generations[0].text;
    }
  }

  @TestVisible
  private static TemplateInvoker invoker = new TemplateInvoker();

  /**
   * Invokes {@code ContractReviewPromptTemplate} for traditional text
   * contracts.
   *
   * Governor-limit note: 1 HTTP/Einstein callout.
   *
   * @param reviewId   The {@link ContractReview__c} record (passed to the
   *                   prompt as {@code Input:ContractReview}).
   * @param documentId The {@link ContentDocument} to evaluate (passed as
   *                   {@code Input:Document}).
   * @return Raw JSON returned by the LLM — expected to be a list of
   *         {@code {recordId, met, extract, aicomment}} entries.
   */
  public static String generateContractReview(Id reviewId, Id documentId) {
    return invokeReviewTemplate(TEMPLATE_CONTRACT_REVIEW, 'Input:Document', reviewId, documentId);
  }

  /**
   * Invokes {@code ContractReview_Forms} for checkbox/form-style contracts.
   * Same JSON contract as {@link #generateContractReview}.
   *
   * Governor-limit note: 1 HTTP/Einstein callout.
   *
   * @param reviewId   The {@link ContractReview__c} record.
   * @param documentId The {@link ContentDocument} of the form contract
   *                   (passed as {@code Input:File}).
   * @return Raw JSON list of criterion verdicts.
   */
  public static String generateFormContractReview(Id reviewId, Id documentId) {
    return invokeReviewTemplate(TEMPLATE_FORM_REVIEW, 'Input:File', reviewId, documentId);
  }

  /**
   * Lightweight binary classifier for the contract type. Calls the
   * {@code Contract_Review_Contract_Type} prompt (Gemini Flash Lite) and
   * normalises the textual response down to a single boolean.
   *
   * Governor-limit note: 1 HTTP/Einstein callout.
   *
   * @param documentId The {@link ContentDocument} to classify.
   * @return {@code true} if the document looks like a checkbox form,
   *         {@code false} for traditional flowing-text contracts (also
   *         the safe default for any non-{@code true} response).
   */
  public static Boolean classifyContractType(Id documentId) {
    Map<String, ConnectApi.WrappedValue> inputParams =
      new Map<String, ConnectApi.WrappedValue>();

    ConnectApi.WrappedValue docValue = new ConnectApi.WrappedValue();
    docValue.value = new Map<String, String>{ 'id' => documentId };
    inputParams.put('Input:File', docValue);

    ConnectApi.EinsteinPromptTemplateGenerationsInput genInput =
      buildGenInput(inputParams);
    String response = invoker.invoke(TEMPLATE_CONTRACT_TYPE, genInput);

    if (String.isBlank(response)) {
      return false;
    }
    // Strip any whitespace/punctuation/quotes the model may add and compare
    // case-insensitively to the literal token "true".
    return response.replaceAll('[^a-zA-Z]', '').equalsIgnoreCase('true');
  }

  /**
   * Generates an HTML email draft to the union member, in the requested
   * language, by invoking the {@code Contract_Review_Email_Draft} prompt.
   *
   * Governor-limit note: 1 HTTP/Einstein callout.
   *
   * @param caseId     The parent {@link Case} (passed as {@code Input:Case})
   *                   so the prompt can resolve member context.
   * @param outputText The pre-compiled SV or EN summary text (the prompt
   *                   refuses to invent facts not present here).
   * @param langLabel  Either {@code 'Svenska'} or {@code 'English'}.
   * @return HTML body suitable for direct write to
   *         {@code ResponseDraft__c} / {@code ResponseDraft_Eng__c}.
   */
  public static String generateEmailDraft(
    Id caseId, String outputText, String langLabel
  ) {
    Map<String, ConnectApi.WrappedValue> inputParams =
      new Map<String, ConnectApi.WrappedValue>();

    ConnectApi.WrappedValue caseValue = new ConnectApi.WrappedValue();
    caseValue.value = new Map<String, String>{ 'id' => caseId };
    inputParams.put('Input:Case', caseValue);

    ConnectApi.WrappedValue outputValue = new ConnectApi.WrappedValue();
    outputValue.value = outputText;
    inputParams.put('Input:Contract_Review_Output_Text', outputValue);

    ConnectApi.WrappedValue langValue = new ConnectApi.WrappedValue();
    langValue.value = langLabel;
    inputParams.put('Input:Language', langValue);

    ConnectApi.EinsteinPromptTemplateGenerationsInput genInput =
      buildGenInput(inputParams);
    return invoker.invoke(TEMPLATE_EMAIL_DRAFT, genInput);
  }

  private static String invokeReviewTemplate(
    String templateName, String docInputKey, Id reviewId, Id documentId
  ) {
    Map<String, ConnectApi.WrappedValue> inputParams =
      new Map<String, ConnectApi.WrappedValue>();

    ConnectApi.WrappedValue docValue = new ConnectApi.WrappedValue();
    docValue.value = new Map<String, String>{ 'id' => documentId };
    inputParams.put(docInputKey, docValue);

    ConnectApi.WrappedValue reviewValue = new ConnectApi.WrappedValue();
    reviewValue.value = new Map<String, String>{ 'id' => reviewId };
    inputParams.put('Input:ContractReview', reviewValue);

    ConnectApi.EinsteinPromptTemplateGenerationsInput genInput =
      buildGenInput(inputParams);
    return invoker.invoke(templateName, genInput);
  }

  private static ConnectApi.EinsteinPromptTemplateGenerationsInput buildGenInput(
    Map<String, ConnectApi.WrappedValue> inputParams
  ) {
    ConnectApi.EinsteinPromptTemplateGenerationsInput genInput =
      new ConnectApi.EinsteinPromptTemplateGenerationsInput();
    genInput.isPreview = false;
    genInput.inputParams = inputParams;
    genInput.additionalConfig =
      new ConnectApi.EinsteinLlmAdditionalConfigInput();
    genInput.additionalConfig.applicationName = APP_NAME;
    return genInput;
  }
}