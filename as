package com.hireright.sourceintelligence.service.impl.helperservices;

import com.hireright.sourceintelligence.api.dto.CycleResult;
import com.hireright.sourceintelligence.api.dto.SourceOrganizationDTO;
import com.hireright.sourceintelligence.api.dto.UIActionsDTO;
import com.hireright.sourceintelligence.domain.entity.Source;
import com.hireright.sourceintelligence.domain.enums.ApprovalStatus;
import com.hireright.sourceintelligence.domain.enums.SourceOrganizationStatus;
import com.hireright.sourceintelligence.domain.mapper.SourceMapper;
import com.hireright.sourceintelligence.service.impl.SearchConstants;
import com.hireright.sourceintelligence.service.impl.elasticsearch.ElasticsearchService;
import com.hireright.sourceintelligence.service.impl.MongoSourceService;
import com.hireright.sourceintelligence.util.Helper;
import com.mongodb.DBObject;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.bson.types.ObjectId;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.io.IOException;
import java.time.Instant;
import java.util.ArrayList;

import static com.hireright.sourceintelligence.constants.ApplicationConstants.*;
import static com.hireright.sourceintelligence.constants.ApplicationConstants.UPDATE;
import static com.hireright.sourceintelligence.constants.ErrorConstants.*;
import static com.hireright.sourceintelligence.domain.enums.ApprovalStatus.*;
import static com.hireright.sourceintelligence.service.impl.SearchConstants.SearchFields.USED_COUNT;
import static com.hireright.sourceintelligence.util.LoggingThrowable.*;
import static com.hireright.sourceintelligence.service.impl.SearchConstants.LogFlagConstants.*;


@Primary
@Slf4j
@RequiredArgsConstructor
@Transactional
@Service
public class UpdateSourceService {

    private final SourceMapper sourceMapper;
    private final SourceUtils sourceUtils;
    private final CountryRegionMappingUtils countryRegionMappingUtils;
    private final MongoSourceService mongoSourceService;
    private final ElasticsearchService elasticsearchService;
    private final ReportDataUtils reportDataUtils;

    @Transactional
    public SourceOrganizationDTO updateSource(SourceOrganizationDTO sourceDTO, UIActionsDTO uiActionsDTO) throws Exception {
        boolean isEdit = uiActionsDTO.getUserAction().equals(ACTION_SAVE) || uiActionsDTO.getUserAction().equals(ACTION_SAVE_AND_USE);
        boolean isCreateEdit = isEdit && sourceDTO.getAction().equals(CREATE);
        boolean isVersionExists = sourceDTO.getVersion() > 0;
        Source source;
        if (isEdit && isCreateEdit && !isVersionExists) {
            //editing the creation source
            source = updateSourceByResearcher(sourceDTO, uiActionsDTO, NEW_SOURCE);
        } else if (isEdit && isVersionExists) {
            //Editing the existing source
            source = updateSourceByResearcher(sourceDTO, uiActionsDTO, EXISTING_SOURCE);
        } else if (!isEdit) {
            //Approve or reject or on hold
            source = updateSourceByApprovalManager(sourceDTO, uiActionsDTO);
        } else {
            source = null;
            logAndThrowInvalidRequest(INVALID_ACTION_REQUEST, null);
        }
        return sourceMapper.entitySourceToDTO(source);
    }

    private Source updateSourceByResearcher(SourceOrganizationDTO sourceDTO, UIActionsDTO uiActionsDTO, String sourceType) throws Exception {
        SourceUpdateContext context = prepareSourceUpdateContext(sourceDTO, sourceType);
        Source updateSource = sourceMapper.dtoToEntitySource(sourceDTO);

        if (sourceType.equals(EXISTING_SOURCE)) {
            return handleExistingSourceUpdate(sourceDTO, uiActionsDTO, context, updateSource);
        } else {
            return handleNewSourceUpdate(sourceDTO, uiActionsDTO, context, updateSource);
        }
    }

    private SourceUpdateContext prepareSourceUpdateContext(SourceOrganizationDTO sourceDTO, String sourceType) {
        SourceUpdateContext context = new SourceUpdateContext();
        context.entityFromDb = mongoSourceService.findSourceByHonAndApprovalStatus(sourceDTO.getHon(), sourceDTO.getApprovalStatus());

        if (context.entityFromDb == null && sourceType.equals(NEW_SOURCE) && sourceDTO.getAction().equals(CREATE)) {
            context.entityFromDb = mongoSourceService.findSourceByHon(sourceDTO.getHon());
            context.isNewSource = isInProgressOrOnHold(context.entityFromDb);
        }

        if (context.entityFromDb == null) {
            logAndThrowResourceNotFound(SOURCE_NOT_FOUND, null, sourceDTO.getHon());
        }

        return context;
    }

    private boolean isInProgressOrOnHold(Source source) {
        return source != null &&
               (source.getApprovalStatus().equals(IN_PROGRESS) ||
                source.getApprovalStatus().equals(ONHOLD));
    }

    private Source handleExistingSourceUpdate(SourceOrganizationDTO sourceDTO, UIActionsDTO uiActionsDTO,
                                              SourceUpdateContext context, Source updateSource) throws Exception {
        Source compareSource = mongoSourceService.findSourceByHonAndApprovalStatus(sourceDTO.getHon(), APPROVED);

        if (Helper.checkIsSkipApprovalFlow(updateSource, compareSource)) {
            return updateSourceByResearcherWithManual(context.entityFromDb, updateSource, uiActionsDTO, context.isNewSource);
        }

        if (Helper.checkIsAutoApproval(updateSource, compareSource)) {
            return updateSourceByResearcherWithAutoApproval(context.entityFromDb, updateSource, uiActionsDTO);
        }

        return updateSourceBasedOnTrustCycle(context.entityFromDb, updateSource, sourceDTO.getCountry(),
                                            context.isNewSource, uiActionsDTO);
    }

    private Source handleNewSourceUpdate(SourceOrganizationDTO sourceDTO, UIActionsDTO uiActionsDTO,
                                        SourceUpdateContext context, Source updateSource) throws Exception {
        if (hasOrganizationAlias(sourceDTO, context.entityFromDb)) {
            return updateSourceByResearcherWithManual(context.entityFromDb, updateSource, uiActionsDTO, context.isNewSource);
        }

        return updateSourceBasedOnTrustCycle(context.entityFromDb, updateSource, sourceDTO.getCountry(),
                                            context.isNewSource, uiActionsDTO);
    }

    private boolean hasOrganizationAlias(SourceOrganizationDTO sourceDTO, Source entityFromDb) {
        return sourceDTO.getOrganizationAlias().length > 0 || entityFromDb.getOrganizationAlias().length > 0;
    }

    private static class SourceUpdateContext {
        Source entityFromDb;
        boolean isNewSource = false;
    }

    private Source updateSourceBasedOnTrustCycle(Source entityFromDb, Source updateSource, String country, boolean isNewSource, UIActionsDTO uiActionsDTO) throws Exception {
        String region = countryRegionMappingUtils.getRegionByCountry(country);
        String approvalStatus = AUTO_APPOVED;
        CycleResult cycleResult;
        if (Helper.fromActionForApprovalFlow(uiActionsDTO.getUserAction()) == null) {
            cycleResult = sourceUtils.checkForAutoApproval(uiActionsDTO.getUserTrustScore(), region, uiActionsDTO.getUserEmail());
            approvalStatus = cycleResult.getStatus();
        }
        if (approvalStatus.equals(AUTO_APPOVED)) {
            return updateSourceByResearcherWithAutoApproval(entityFromDb, updateSource, uiActionsDTO);
        } else {
            //Manual flow
            return updateSourceByResearcherWithManual(entityFromDb, updateSource, uiActionsDTO, isNewSource);
        }
    }

    private Source updateSourceByResearcherWithManual(Source entityFromDb, Source updateSource, UIActionsDTO uiActionsDTO, boolean isNewSource) {
        updateSource.setVersion(entityFromDb.getVersion());
        updateSource.setTempVersion(entityFromDb.getTempVersion() + 1);
        updateSource.setAction(updateSource.getVersion() > 0 ? UPDATE : CREATE);
        updateSource.setLogFlag(updateSource.getVersion() > 0 ? DETAILS_CHANGED : NEW_RECORD);

        updateSource.setLastModifiedDate(Instant.now());
        updateSource.setLastModifiedBy(uiActionsDTO.getUserName());
        updateSource.setLastModifierId(uiActionsDTO.getUserEmail());
        updateSource.setSearchOrg(updateSource.getOrganizationName().toLowerCase().trim());
        if (updateSource.getAction().equals(CREATE)) {
            updateSource.setCreatedDate(Instant.now());
            updateSource.setCreatedBy(uiActionsDTO.getUserName());
            updateSource.setCreatorId(uiActionsDTO.getUserEmail());
            updateSource.setAssignedTo(UNASSIGNED);
            updateSource.setAssignedId(UNASSIGNED);
        }
        if (entityFromDb.getTempVersion() == 0) {
            updateSource.setAssignedTo(UNASSIGNED);
            updateSource.setAssignedId(UNASSIGNED);
        }
        copyUsedCount(entityFromDb, updateSource);
        updateSource.setApprovalStatus(Helper.fromAction(uiActionsDTO.getUserAction()));
        updateSource.setStatus(SourceOrganizationStatus.INACTIVE);
        String collectionName = Helper.getCollectionName(updateSource.getHon(), SOURCE_COLLECTION_SUFFIX);
        if (!isNewSource && (entityFromDb.getApprovalStatus().equals(PENDING_APPROVAL) || entityFromDb.getApprovalStatus().equals(SAVE_PENDING_APPROVAL))) {
            deleteSourceById(entityFromDb.getId(), collectionName);
        }
        updateSource.setLastActionDate(Instant.now());
        mongoSourceService.insert(updateSource, collectionName);
        mongoSourceService.insertSourceHistory(updateSource);
        reportDataUtils.reportData(updateSource, updateSource.getAction(), SIDB_APPROVAL_FLOW, 0, MANUAL_PROCESS, updateSource.getVersion(), updateSource.getTempVersion(),APPROVAL_FLOW);
        return updateSource;
    }

    private Source updateSourceByResearcherWithAutoApproval(Source entityFromDb, Source updateSource, UIActionsDTO uiActionsDTO) throws Exception {
        updateSource.setVersion(entityFromDb.getVersion() + 1);
        updateSource.setTempVersion(0);
        if (entityFromDb.getVersion() >= 1) {
            updateSource.setAction(UPDATE);
            updateSource.setLogFlag(DETAILS_CHANGED);
        } else {
            updateSource.setAction(CREATE);
            updateSource.setLogFlag(NEW_RECORD);
        }
        updateSource.setLastModifiedDate(Instant.now());
        updateSource.setLastModifiedBy(uiActionsDTO.getUserName());
        updateSource.setLastModifierId(uiActionsDTO.getUserEmail());
        updateSource.setApprovalStatus(APPROVED);
        updateSource.setStatus(SourceOrganizationStatus.ACTIVE);
        updateSource.setSearchOrg(updateSource.getOrganizationName().toLowerCase().trim());
        updateApprovalDetails(updateSource, uiActionsDTO);
        copyUsedCount(entityFromDb, updateSource);
        String collectionName = Helper.getCollectionName(updateSource.getHon(), SOURCE_COLLECTION_SUFFIX);
        if (entityFromDb.getId() != null) {
            deleteSourceById(entityFromDb.getId(), collectionName);
        }
        mongoSourceService.insert(updateSource, collectionName);
        mongoSourceService.insertSourceHistory(updateSource);
        updateESLogic(updateSource);
        reportDataUtils.reportData(updateSource, updateSource.getAction(), SIDB_APPROVAL_FLOW, 0, SearchConstants.ReportActions.AUTO_APPROVED, updateSource.getVersion(), updateSource.getTempVersion(),APPROVAL_FLOW);
        return updateSource;
    }

    private Source updateSourceByApprovalManager(SourceOrganizationDTO sourceDTO, UIActionsDTO uiActionsDTO) throws Exception {
        String collectionName = Helper.getCollectionName(sourceDTO.getHon(), SOURCE_COLLECTION_SUFFIX);
        Source entityFromDb = mongoSourceService.findSourceByHonAndApprovalStatus(sourceDTO.getHon(), IN_PROGRESS);

        if (entityFromDb == null) {
            log.error("source not found");
        }
        assert entityFromDb != null;

        Source updateSource = prepareUpdateSource(sourceDTO, entityFromDb);

        switch (uiActionsDTO.getUserAction()) {
            case ACTION_APPROVED:
                handleApproval(sourceDTO, updateSource, uiActionsDTO, collectionName);
                break;
            case ACTION_REJECTED:
                handleRejection(sourceDTO, updateSource, uiActionsDTO, collectionName);
                break;
            case ACTION_ON_HOLD:
                handleOnHold(sourceDTO, updateSource, uiActionsDTO, collectionName);
                break;
            default:
                break;
        }
        return updateSource;
    }

    private Source prepareUpdateSource(SourceOrganizationDTO sourceDTO, Source entityFromDb) {
        Source updateSource = sourceMapper.dtoToEntitySource(sourceDTO);
        updateSource.setId(entityFromDb.getId());
        updateSource.setSearchOrg(updateSource.getOrganizationName().toLowerCase().trim());
        return updateSource;
    }

    private void handleApproval(SourceOrganizationDTO sourceDTO, Source updateSource, UIActionsDTO uiActionsDTO, String collectionName) throws Exception {
        updateSource.setApprovalStatus(APPROVED);
        updateSource.setStatus(SourceOrganizationStatus.ACTIVE);
        updateSource.setTempVersion(0);
        updateSource.setGeneralErrors(new ArrayList<>());
        updateSource.setFieldErrors(new ArrayList<>());
        updateSource.setComments("");
        updateApprovalDetails(updateSource, uiActionsDTO);

        Source approvedDbEntity = mongoSourceService.findSourceByHonAndApprovalStatus(sourceDTO.getHon(), APPROVED);

        if (approvedDbEntity == null) {
            handleFirstApproval(updateSource, collectionName);
        } else {
            handleSubsequentApproval(updateSource, approvedDbEntity, collectionName);
        }

        mongoSourceService.updateById(updateSource, collectionName);
        updateESLogic(updateSource);
        mongoSourceService.insertSourceHistory(updateSource);
        reportDataUtils.reportData(updateSource, sourceDTO.getAction(), SIDB_APPROVAL_FLOW, 0,
                                   MANUAL_PROCESS, sourceDTO.getVersion(), sourceDTO.getTempVersion() + 1, APPROVAL_FLOW);
    }

    private void handleFirstApproval(Source updateSource, String collectionName) {
        updateSource.setVersion(1.0);
        Source entityFromDb = mongoSourceService.findSourceByHonAndApprovalStatus(updateSource.getHon(), IN_PROGRESS);
        copyUsedCount(entityFromDb, updateSource);
    }

    private void handleSubsequentApproval(Source updateSource, Source approvedDbEntity, String collectionName) {
        updateSource.setAction(UPDATE);
        updateSource.setVersion(approvedDbEntity.getVersion() + 1.0);
        deleteSourceById(approvedDbEntity.getId(), collectionName);
        copyUsedCount(approvedDbEntity, updateSource);
    }

    private void handleRejection(SourceOrganizationDTO sourceDTO, Source updateSource, UIActionsDTO uiActionsDTO, String collectionName) {
        updateSource.setApprovalStatus(REJECTED);
        updateSource.setStatus(SourceOrganizationStatus.INACTIVE);
        updateApprovalDetails(updateSource, uiActionsDTO);
        mongoSourceService.updateById(updateSource, collectionName);
        mongoSourceService.insertSourceHistory(updateSource);
        reportDataUtils.reportData(updateSource, updateSource.getAction(), SIDB_APPROVAL_FLOW, 0,
                                   MANUAL_PROCESS, sourceDTO.getVersion(), sourceDTO.getTempVersion(), APPROVAL_FLOW);
    }

    private void handleOnHold(SourceOrganizationDTO sourceDTO, Source updateSource, UIActionsDTO uiActionsDTO, String collectionName) {
        updateSource.setApprovalStatus(ONHOLD);
        updateSource.setStatus(SourceOrganizationStatus.INACTIVE);
        updateApprovalDetails(updateSource, uiActionsDTO);
        mongoSourceService.updateById(updateSource, collectionName);
        mongoSourceService.insertSourceHistory(updateSource);
        reportDataUtils.reportData(updateSource, updateSource.getAction(), SIDB_APPROVAL_FLOW, 0,
                                   MANUAL_PROCESS, sourceDTO.getVersion(), sourceDTO.getTempVersion(), APPROVAL_FLOW);
    }

    private void updateApprovalDetails(Source updateSource, UIActionsDTO uiActionsDTO) {
        updateSource.setApprovedBy(uiActionsDTO.getUserName());
        updateSource.setApproverId(uiActionsDTO.getUserEmail());
        updateSource.setLastApprovedDate(Instant.now());
        updateSource.setLastActionDate(Instant.now());
    }

    private void deleteSourceById(ObjectId id, String collectionName) {
        mongoSourceService.deleteSourceById(id, collectionName);
    }

    protected void updateESLogic(Source updateSource)
            throws IOException, IllegalAccessException {

        String action = updateSource.getAction();
        ApprovalStatus approval = updateSource.getApprovalStatus();

        if (CREATE.equals(action) && APPROVED.equals(approval)) {
            elasticsearchService.createSource(updateSource);
            return;
        }
        if (UPDATE.equals(action) && APPROVED.equals(approval)) {
            elasticsearchService.updateSourceIndex(updateSource);
        }
    }

    private void copyUsedCount(Source entityFromDb, Source updateSource) {
        DBObject obj = updateSource.getPayload();
        DBObject entityPayload = entityFromDb.getPayload();
        var usedCount = entityPayload.get(USED_COUNT);
        obj.put(USED_COUNT, usedCount);
        updateSource.setPayload(obj);
    }
}
