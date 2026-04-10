package com.hireright.sourceintelligence.service.extraction;

import java.util.List;
import java.util.Map;

public interface DataExtractionProcessor<T> {
    Map<String, Object> processInstitutionRecords(List<T> records);

    String getDataExtractionTypeType();

    default boolean supports(String dataExtractionType) {
        return getDataExtractionTypeType().equalsIgnoreCase(dataExtractionType);
    }
}




package com.hireright.sourceintelligence.service.extraction;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;

@Slf4j
@Component
@RequiredArgsConstructor
public class DataExtractionProcessorFactory {

    private final List<DataExtractionProcessor<?>> processors;

    @SuppressWarnings("unchecked")
    public <T> DataExtractionProcessor<T> getProcessor(String dataExtractionType) {
        if (dataExtractionType == null || dataExtractionType.trim().isEmpty()) {
            throw new IllegalArgumentException("Data Extraction type cannot be null or empty");
        }

        Optional<DataExtractionProcessor<?>> processor = processors.stream()
                .filter(p -> p.supports(dataExtractionType))
                .findFirst();

        if (processor.isEmpty()) {
            throw new IllegalArgumentException(
                    String.format("Unsupported Data Extraction type: '%s'. Available types: %s",
                            dataExtractionType,
                            getSupportedTypes())
            );
        }

        return (DataExtractionProcessor<T>) processor.get();
    }

    public String getSupportedTypes() {
        return processors.stream()
                .map(DataExtractionProcessor::getDataExtractionTypeType)
                .reduce((a, b) -> a + ", " + b)
                .orElse("none");
    }

    public boolean isSupported(String dataExtractionType) {
        if (dataExtractionType == null || dataExtractionType.trim().isEmpty()) {
            return false;
        }

        return processors.stream()
                .anyMatch(p -> p.supports(dataExtractionType));
    }
}




package com.hireright.sourceintelligence.api.v1;

import com.hireright.sourceintelligence.api.dto.DataExtractionResponseDTO;
import com.hireright.sourceintelligence.service.excel.ExcelParserFactory;
import com.hireright.sourceintelligence.service.excel.ExcelParserStrategy;
import com.hireright.sourceintelligence.service.extraction.DataExtractionProcessor;
import com.hireright.sourceintelligence.service.extraction.DataExtractionProcessorFactory;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;
import java.util.Map;

import static com.hireright.sourceintelligence.constants.ErrorConstants.*;
import static com.hireright.sourceintelligence.domain.constants.Constants.DataExtractionConstants.*;
import static com.hireright.sourceintelligence.util.LoggingThrowable.logAndThrowInvalidRequest;

@Slf4j
@RestController
@RequiredArgsConstructor
@Validated
@CrossOrigin
public class DataExtractionApiController implements DataExtractionApi {

    private final DataExtractionProcessorFactory processorFactory;
    private final ExcelParserFactory excelParserFactory;

    @Value("${data.extraction.file.max-size-mb:10}")
    private int maxDataExtractionFileSizeMb;

    @Override
    public ResponseEntity<DataExtractionResponseDTO> uploadDataExtractionExcelFile(MultipartFile file, String dataExtractionType) {
        long startTime = System.currentTimeMillis();
        String filename = file.getOriginalFilename();

        log.info("Received Data Extraction file upload - filename: {}, size: {} bytes, type: {}",
                filename, file.getSize(), dataExtractionType);

        validateDataExtractionRequest(file, filename, dataExtractionType);

        try {
            Map<String, Object> processingResult = parseAndProcessRecords(file, filename, dataExtractionType);
            processingResult.put(DATA_EXTRACTION_TYPE, dataExtractionType);

            DataExtractionResponseDTO response = buildSuccessResponse(
                    filename,
                    dataExtractionType,
                    processingResult,
                    System.currentTimeMillis() - startTime
            );

            logDataExtractionSuccess(dataExtractionType, response);
            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logAndThrowInvalidRequest(DATA_EXTRACTION_PROCESSING_ERROR, e, e.getMessage());
            return null;
        }
    }

    private void validateDataExtractionRequest(MultipartFile file, String filename, String dataExtractionType) {
        if (!processorFactory.isSupported(dataExtractionType)) {
            logAndThrowInvalidRequest(DATA_EXTRACTION_TYPE_UNSUPPORTED, null,
                    dataExtractionType, processorFactory.getSupportedTypes());
        }

        if (file.isEmpty()) {
            logAndThrowInvalidRequest(DATA_EXTRACTION_FILE_EMPTY, null);
        }

        if (file.getSize() / FILE_SIZE_BYTES_PER_MB > maxDataExtractionFileSizeMb) {
            logAndThrowInvalidRequest(DATA_EXTRACTION_FILE_TOO_LARGE, null, maxDataExtractionFileSizeMb);
        }

        if (filename == null || (!filename.endsWith(FILE_FORMAT_EXCEL_XLSX) && !filename.endsWith(FILE_FORMAT_EXCEL_XLS))) {
            logAndThrowInvalidRequest(DATA_EXTRACTION_FILE_INVALID_FORMAT, null);
        }
    }

    private <T> Map<String, Object> parseAndProcessRecords(MultipartFile file, String filename, String dataExtractionType) throws IOException {
        log.info("Parsing Excel file: {}", filename);

        ExcelParserStrategy<T> parser = excelParserFactory.getParser(dataExtractionType);
        List<T> records = parser.parse(file);

        if (records.isEmpty()) {
            logAndThrowInvalidRequest(DATA_EXTRACTION_NO_RECORDS_FOUND, null);
        }

        DataExtractionProcessor<T> processor = processorFactory.getProcessor(dataExtractionType);
        return processor.processInstitutionRecords(records);
    }

    private void logDataExtractionSuccess(String dataExtractionType, DataExtractionResponseDTO response) {
        log.info("Data Extraction completed - type: {}, total: {}, dbRecordsUpdated: {}, notFound: {}, time: {}ms",
                dataExtractionType,
                response.getTotalRecords(),
                response.getTotalSourcesUpdated(),
                response.getNotFoundRecords(),
                response.getProcessingTimeMs());
    }

    private DataExtractionResponseDTO buildSuccessResponse(
            String filename,
            String dataExtractionType,
            Map<String, Object> processingResult,
            long processingTime) {

        return DataExtractionResponseDTO.builder()
                .status(RESPONSE_STATUS_SUCCESS)
                .message(RESPONSE_MESSAGE_FILE_PROCESSED)
                .dataExtractionType(dataExtractionType)
                .filename(filename)
                .totalRecords((Integer) processingResult.get(RESULT_KEY_TOTAL_RECORDS))
                .totalSourcesUpdated((Integer) processingResult.get(RESULT_KEY_TOTAL_SOURCES_UPDATED))
                .notFoundRecords((Integer) processingResult.get(RESULT_KEY_NOT_FOUND_RECORDS))
                .notFoundRecordsData((List<Map<String, Object>>) processingResult.get("notFoundRecordsData"))
                .excelMetadata((List<Map<String, String>>) processingResult.get("excelMetadata"))
                .processingTimeMs(processingTime)
                .build();
    }
}
