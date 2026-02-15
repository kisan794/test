 public static GroupOperation operatorRoleGroupOperation() {
        return Aggregation.group(CREATED_BY)
                .first(CREATED_BY).as("operatorName")
             //   .last(HON).as(HON)
                // Added - Create action counts by status
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(CREATE),
                                Criteria.where(APPROVAL_STATUS).in(ApprovalStatus.PENDING_APPROVAL.getStatus(), ApprovalStatus.SAVE_PENDING_APPROVAL.getStatus())))
                        .then(1).otherwise(0)).as("addedNew")
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(CREATE),
                                Criteria.where(APPROVAL_STATUS).is(ApprovalStatus.IN_PROGRESS.getStatus())))
                        .then(1).otherwise(0)).as("addedInProgress")
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(CREATE),
                                Criteria.where(APPROVAL_STATUS).is(ApprovalStatus.ONHOLD.getStatus())))
                        .then(1).otherwise(0)).as("addedOnHold")
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(CREATE),
                                Criteria.where(APPROVAL_STATUS).is(ApprovalStatus.REJECTED.getStatus())))
                        .then(1).otherwise(0)).as("addedCancelled")
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(CREATE),
                                Criteria.where(APPROVAL_STATUS).is(ApprovalStatus.APPROVED.getStatus())))
                        .then(1).otherwise(0)).as("addedCompleted")
                // Changed - Update action counts by status
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(UPDATE),
                                Criteria.where(APPROVAL_STATUS).in(ApprovalStatus.PENDING_APPROVAL.getStatus(), ApprovalStatus.SAVE_PENDING_APPROVAL.getStatus())))
                        .then(1).otherwise(0)).as("changedNew")
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(UPDATE),
                                Criteria.where(APPROVAL_STATUS).is(ApprovalStatus.IN_PROGRESS.getStatus())))
                        .then(1).otherwise(0)).as("changedInProgress")
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(UPDATE),
                                Criteria.where(APPROVAL_STATUS).is(ApprovalStatus.ONHOLD.getStatus())))
                        .then(1).otherwise(0)).as("changedOnHold")
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(UPDATE),
                                Criteria.where(APPROVAL_STATUS).is(ApprovalStatus.REJECTED.getStatus())))
                        .then(1).otherwise(0)).as("changedCancelled")
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(UPDATE),
                                Criteria.where(APPROVAL_STATUS).is(ApprovalStatus.APPROVED.getStatus())))
                        .then(1).otherwise(0)).as("changedCompleted")
                // Archived - Archive action counts by status
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(ReportConstants.AggregateFields.ARCHIVED_ACTION),
                                Criteria.where(APPROVAL_STATUS).in(ApprovalStatus.PENDING_APPROVAL.getStatus(), ApprovalStatus.SAVE_PENDING_APPROVAL.getStatus())))
                        .then(1).otherwise(0)).as("archivedNew")
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(ReportConstants.AggregateFields.ARCHIVED_ACTION),
                                Criteria.where(APPROVAL_STATUS).is(ApprovalStatus.IN_PROGRESS.getStatus())))
                        .then(1).otherwise(0)).as("archivedInProgress")
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(ReportConstants.AggregateFields.ARCHIVED_ACTION),
                                Criteria.where(APPROVAL_STATUS).is(ApprovalStatus.ONHOLD.getStatus())))
                        .then(1).otherwise(0)).as("archivedOnHold")
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(ReportConstants.AggregateFields.ARCHIVED_ACTION),
                                Criteria.where(APPROVAL_STATUS).is(ApprovalStatus.REJECTED.getStatus())))
                        .then(1).otherwise(0)).as("archivedCancelled")
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(ReportConstants.AggregateFields.ARCHIVED_ACTION),
                                Criteria.where(APPROVAL_STATUS).is(ApprovalStatus.APPROVED.getStatus())))
                        .then(1).otherwise(0)).as("archivedCompleted")
                // Deleted - Delete action counts by status
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(DELETE),
                                Criteria.where(APPROVAL_STATUS).in(ApprovalStatus.PENDING_APPROVAL.getStatus(), ApprovalStatus.SAVE_PENDING_APPROVAL.getStatus())))
                        .then(1).otherwise(0)).as("deletedNew")
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(DELETE),
                                Criteria.where(APPROVAL_STATUS).is(ApprovalStatus.IN_PROGRESS.getStatus())))
                        .then(1).otherwise(0)).as("deletedInProgress")
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(DELETE),
                                Criteria.where(APPROVAL_STATUS).is(ApprovalStatus.ONHOLD.getStatus())))
                        .then(1).otherwise(0)).as("deletedOnHold")
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(DELETE),
                                Criteria.where(APPROVAL_STATUS).is(ApprovalStatus.REJECTED.getStatus())))
                        .then(1).otherwise(0)).as("deletedCancelled")
                .sum(ConditionalOperators.Cond.when(new Criteria().andOperator(
                                Criteria.where(ACTION).is(DELETE),
                                Criteria.where(APPROVAL_STATUS).is(ApprovalStatus.APPROVED.getStatus())))
                        .then(1).otherwise(0)).as("deletedCompleted");
    }
