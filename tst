package com.hireright.sourceintelligence.reports.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Intermediate DTO to receive flat fields from MongoDB aggregation for Operator role
 * This will be mapped to OperatorReportDTO with nested ActionStatusCountDTO objects
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OperatorReportFlatDTO {
    
    @JsonProperty("operatorName")
    private String operatorName;
    
    @JsonProperty("hon")
    private String hon;
    
    // Added - Create action counts by status
    @JsonProperty("addedNew")
    private int addedNew;
    
    @JsonProperty("addedInProgress")
    private int addedInProgress;
    
    @JsonProperty("addedOnHold")
    private int addedOnHold;
    
    @JsonProperty("addedCancelled")
    private int addedCancelled;
    
    @JsonProperty("addedCompleted")
    private int addedCompleted;
    
    // Changed - Update action counts by status
    @JsonProperty("changedNew")
    private int changedNew;
    
    @JsonProperty("changedInProgress")
    private int changedInProgress;
    
    @JsonProperty("changedOnHold")
    private int changedOnHold;
    
    @JsonProperty("changedCancelled")
    private int changedCancelled;
    
    @JsonProperty("changedCompleted")
    private int changedCompleted;
    
    // Archived - Archive action counts by status
    @JsonProperty("archivedNew")
    private int archivedNew;
    
    @JsonProperty("archivedInProgress")
    private int archivedInProgress;
    
    @JsonProperty("archivedOnHold")
    private int archivedOnHold;
    
    @JsonProperty("archivedCancelled")
    private int archivedCancelled;
    
    @JsonProperty("archivedCompleted")
    private int archivedCompleted;
    
    // Deleted - Delete action counts by status
    @JsonProperty("deletedNew")
    private int deletedNew;
    
    @JsonProperty("deletedInProgress")
    private int deletedInProgress;
    
    @JsonProperty("deletedOnHold")
    private int deletedOnHold;
    
    @JsonProperty("deletedCancelled")
    private int deletedCancelled;
    
    @JsonProperty("deletedCompleted")
    private int deletedCompleted;
}

  /**
     * Map flat DTO list to nested DTO list
     * Converts OperatorReportFlatDTO to OperatorReportDTO with nested ActionStatusCountDTO objects
     */
    private List<OperatorReportDTO> mapFlatToNestedOperatorReport(List<OperatorReportFlatDTO> flatList) {
        List<OperatorReportDTO> nestedList = new ArrayList<>();

        for (OperatorReportFlatDTO flat : flatList) {
            // Create ActionStatusCountDTO for 'added' action
            ActionStatusCountDTO added = ActionStatusCountDTO.builder()
                    .newCount(flat.getAddedNew())
                    .inProgress(flat.getAddedInProgress())
                    .onHold(flat.getAddedOnHold())
                    .cancelled(flat.getAddedCancelled())
                    .completed(flat.getAddedCompleted())
                    .build();

            // Create ActionStatusCountDTO for 'changed' action
            ActionStatusCountDTO changed = ActionStatusCountDTO.builder()
                    .newCount(flat.getChangedNew())
                    .inProgress(flat.getChangedInProgress())
                    .onHold(flat.getChangedOnHold())
                    .cancelled(flat.getChangedCancelled())
                    .completed(flat.getChangedCompleted())
                    .build();

            // Create ActionStatusCountDTO for 'archived' action
            ActionStatusCountDTO archived = ActionStatusCountDTO.builder()
                    .newCount(flat.getArchivedNew())
                    .inProgress(flat.getArchivedInProgress())
                    .onHold(flat.getArchivedOnHold())
                    .cancelled(flat.getArchivedCancelled())
                    .completed(flat.getArchivedCompleted())
                    .build();

            // Create ActionStatusCountDTO for 'deleted' action
            ActionStatusCountDTO deleted = ActionStatusCountDTO.builder()
                    .newCount(flat.getDeletedNew())
                    .inProgress(flat.getDeletedInProgress())
                    .onHold(flat.getDeletedOnHold())
                    .cancelled(flat.getDeletedCancelled())
                    .completed(flat.getDeletedCompleted())
                    .build();

            // Create OperatorReportDTO with nested objects
            OperatorReportDTO nested = OperatorReportDTO.builder()
                    .operatorName(flat.getOperatorName())
                    .added(added)
                    .changed(changed)
                    .archived(archived)
                    .deleted(deleted)
                    .build();

            nestedList.add(nested);
        }

        return nestedList;
    }
