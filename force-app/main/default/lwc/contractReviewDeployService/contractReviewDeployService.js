/**
 * Stateless helper module that wraps `ContractReviewMetadataService.deployBundledRecords`
 * for the admin LWCs. Provides:
 *
 *   - `deploy(records)` — Apex deploy + structured error extraction.
 *   - `buildTemplateRecord` / `buildCriterionRecord` / `buildAssignmentRecord` /
 *     `buildDeactivationRecord` — typed payload constructors.
 *   - `buildAssignmentPayload(...)` — assembles a full add/remove/deactivate
 *     bundle given current vs. desired criterion sets for a template.
 *   - `generateAssignmentDevName(...)` — deterministic, length-bounded
 *     developerName for an assignment row, with a hash suffix to avoid
 *     collisions when labels are truncated.
 */
import deployBundledRecords from "@salesforce/apex/ContractReviewMetadataService.deployBundledRecords";

/* ── Core deploy ── */

/**
 * Serializes metadata records and deploys via Metadata API.
 * Returns the deploy Job ID string.
 * Throws on Apex error — consumers must catch and handle.
 */
export async function deploy(records) {
  const serialized = JSON.parse(JSON.stringify(records));
  return deployBundledRecords({ metadataRecords: serialized });
}

/**
 * Extracts a user-facing error message from an Apex error object.
 */
export function extractDeployError(err) {
  return err.body?.message || err.message || "An unknown error occurred.";
}

/* ── Payload builders ── */

export function buildTemplateRecord(developerName, label, fields) {
  return {
    sObjectName: "ContractReviewTemplate__mdt",
    developerName,
    label,
    fields
  };
}

export function buildCriterionRecord(developerName, label, fields) {
  return {
    sObjectName: "ContractReviewCriterion__mdt",
    developerName,
    label,
    fields
  };
}

export function buildAssignmentRecord(
  developerName,
  label,
  templateDevName,
  criterionDevName,
  sequence
) {
  return {
    sObjectName: "ContractReviewTemplateAssignment__mdt",
    developerName,
    label,
    fields: {
      ContractReviewTemplate__c: templateDevName,
      ContractReviewCriterion__c: criterionDevName,
      IsActive__c: true,
      Sequence__c: sequence
    }
  };
}

export function buildDeactivationRecord(sObjectName, developerName) {
  return {
    sObjectName,
    developerName,
    label: developerName,
    fields: { IsActive__c: false }
  };
}

/* ── Assignment helpers ── */

function cleanPart(str, maxLen) {
  const cleaned = str
    .replace(/[^a-zA-Z0-9_]/g, "")
    .replace(/_+/g, "_")
    .substring(0, maxLen)
    .replace(/^_|_$/g, "");
  return cleaned || "rec";
}

function hashCode(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) - hash + str.charCodeAt(i)) | 0;
  }
  return Math.abs(hash).toString(36).padStart(6, "0");
}

export function generateAssignmentDevName(templateDevName, criterionDevName) {
  const fullKey = `${templateDevName}_${criterionDevName}`;
  const h = hashCode(fullKey);
  const tPart = cleanPart(templateDevName, 16);
  const cPart = cleanPart(criterionDevName, 16);
  return `${tPart}_${cPart}_${h}`;
}

/**
 * Builds the full assignment deploy payload — active records + deactivation
 * records for removed assignments.
 *
 * @param {Array} assignedItems - Current assigned items with {value, label, sequence}
 * @param {Map} baselineAssigned - Map of criterionDevName → {assignmentDevName, sequence}
 * @param {string} templateDevName - The template's DeveloperName
 * @param {string} templateLabel - The template's MasterLabel (for human-readable labels)
 * @returns {{ records: Array, addedCount: number, removedCount: number }}
 */
export function buildAssignmentPayload(
  assignedItems,
  baselineAssigned,
  templateDevName,
  templateLabel
) {
  const records = [];
  const currentValues = new Set(assignedItems.map((i) => i.value));
  const usedDevNames = new Set();

  for (const item of assignedItems) {
    const baseline = baselineAssigned.get(item.value);
    const devName = baseline
      ? baseline.assignmentDevName
      : generateAssignmentDevName(templateDevName, item.value);

    if (usedDevNames.has(devName)) {
      throw new Error(
        `Duplicate assignment DeveloperName generated: "${devName}". ` +
          `This indicates a hash collision — please rename one of the criteria.`
      );
    }
    usedDevNames.add(devName);

    const label = `${templateLabel.substring(0, 18)} - ${item.label.substring(0, 18)}`;
    records.push(
      buildAssignmentRecord(
        devName,
        label,
        templateDevName,
        item.value,
        item.sequence
      )
    );
  }

  let removedCount = 0;
  for (const [critDevName, baseline] of baselineAssigned) {
    if (!currentValues.has(critDevName)) {
      records.push(
        buildDeactivationRecord(
          "ContractReviewTemplateAssignment__mdt",
          baseline.assignmentDevName
        )
      );
      removedCount++;
    }
  }

  const addedCount = assignedItems.filter(
    (i) => !baselineAssigned.has(i.value)
  ).length;

  return { records, addedCount, removedCount };
}