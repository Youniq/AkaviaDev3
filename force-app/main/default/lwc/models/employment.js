class Employment {
  id; // employmentId
  workplaceName;
  workplaceId;
  orgNum;
  employerName;
  isManager;
  endDate;
  labels;

  constructor(
    id,
    name,
    workplaceId,
    orgNumber,
    employerName,
    isManager,
    endDate
  ) {
    this.id = id || "";
    this.workplaceName = name;
    this.workplaceId = workplaceId;
    this.orgNum = orgNumber;
    this.employerName = employerName;
    this.isManager = isManager;
    this.endDate = endDate;
  }
}

export { Employment };